//
//  ElementIdExtractor.swift
//  Mixpanel
//
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
import UIKit

// MARK: - ElementIdExtractor

/// Resolves the `$el_id` property reported for an autocaptured interaction.
///
/// Provide an implementation via `AutocaptureOptions(elementIdExtractor:)` to take full control
/// over which identifier the SDK reports for a tapped view. This is the recommended way to keep
/// personally identifiable information out of autocapture events: the SDK only ever reports what
/// this method returns.
///
/// When no extractor is provided, the SDK falls back to an internal default implementation that
/// resolves the identifier from the React Native `nativeID`, then `accessibilityIdentifier`, then a
/// structural fallback. `accessibilityLabel` is deliberately not a source: it is localized, so the
/// same element would report a different identifier per language, and it can carry user data.
///
/// **Example:**
/// ```swift
/// final class TrackingIdExtractor: ElementIdExtractor {
///     func extractElementId(from view: UIView) -> String? {
///         // Only report identifiers the team explicitly opted into.
///         guard let id = view.accessibilityIdentifier, id.hasPrefix("track_") else { return nil }
///         return id
///     }
/// }
///
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     autocaptureOptions: AutocaptureOptions(elementIdExtractor: TrackingIdExtractor())
/// )
/// ```
///
/// **Threading:** `extractElementId(from:)` is called on the main thread immediately after the hit
/// test that resolved the tapped view. Keep the implementation fast and side-effect free.
///
/// - Warning: **Experimental (beta).** Autocapture may contain issues, and its API and the properties
///   it captures may change in a future release before general availability. Pin your SDK version if
///   you build reports on autocaptured events.
public protocol ElementIdExtractor {
    /// Returns the `$el_id` to report for the given view.
    ///
    /// - Parameter view: The view resolved by the autocapture hit test.
    /// - Returns: The identifier to report, or `nil` to let the SDK report an anonymous
    ///   `<ClassName>_<hash>` identifier instead. Empty strings are treated as `nil`.
    func extractElementId(from view: UIView) -> String?
}

// MARK: - DefaultElementIdExtractor

/// Default `ElementIdExtractor` used when the host app does not supply its own.
///
/// Resolution priority:
/// 1. **React Native `nativeID`** — read through the Objective-C runtime so the SDK carries no
///    compile-time dependency on React Native. Skipped for SwiftUI views: React Native renders
///    through UIKit, never SwiftUI, so the probe could only ever be wasted work there.
/// 2. **`accessibilityIdentifier`** — stable, developer-assigned, and not user-visible. Internal
///    framework identifiers (e.g. `_UIKit…`, `AXID-…`) are skipped.
/// 3. **Anonymous fallback** — `<ClassName>_<hash>`, where the hash describes the view's position in
///    the hierarchy (see `structuralPath(for:)`) rather than its identity.
///
/// `accessibilityLabel` is deliberately absent. It is user-facing text: localized, so the same
/// element would report a different identifier per language, and capable of carrying personal data.
///
/// For SwiftUI, step 1 is skipped and the identifier lives in SwiftUI's accessibility element tree
/// rather than on the backing `UIView`, so `SemanticExtractor` resolves it from that tree and passes
/// it in as the `accessibilityIdentifierFallback` argument below.
final class DefaultElementIdExtractor: ElementIdExtractor {

    static let shared = DefaultElementIdExtractor()

    /// Framework-internal identifier prefixes that carry no product meaning.
    private static let internalIdentifierPrefixes = [
        "_",  // Private Apple identifiers
        "AXID-",  // Accessibility internal
        "UITransitionView",
        "UILayoutContainerView",
    ]

    func extractElementId(from view: UIView) -> String? {
        return elementId(for: view, accessibilityIdentifierFallback: nil)
    }

    /// Resolution with an optional precomputed identifier used at priority step 2.
    ///
    /// SwiftUI renders its views as internal UIKit views that do not carry
    /// `accessibilityIdentifier` on the UIKit view itself; the caller resolves it from SwiftUI's
    /// accessibility element tree and passes it here so SwiftUI elements still get a meaningful
    /// `$el_id`. The fallback is consulted only after the view's own identifier.
    func elementId(
        for view: UIView,
        accessibilityIdentifierFallback: String?
    ) -> String {
        // 1. React Native nativeID (UIKit-backed views only)
        if let nativeId = reactNativeId(for: view) {
            return nativeId
        }

        // 2. accessibilityIdentifier
        if let identifier = view.accessibilityIdentifier,
            !identifier.isEmpty,
            !DefaultElementIdExtractor.isInternalIdentifier(identifier)
        {
            return identifier
        }
        if let fallbackIdentifier = accessibilityIdentifierFallback,
            !fallbackIdentifier.isEmpty,
            !DefaultElementIdExtractor.isInternalIdentifier(fallbackIdentifier)
        {
            return fallbackIdentifier
        }

        // 3. Anonymous fallback
        return DefaultElementIdExtractor.anonymousId(for: view)
    }

    // MARK: - React Native

    /// Reads React Native's `nativeID` property through the Objective-C runtime.
    ///
    /// `RCTView` (and friends) expose `nativeID` as an Objective-C property carrying the JS-side
    /// `nativeID` prop. `responds(to:)` is checked first so KVC never throws on views that do not
    /// declare the key.
    ///
    /// Skipped entirely for SwiftUI views — React Native renders through the UIKit view hierarchy,
    /// so a SwiftUI view can never carry a `nativeID`.
    private func reactNativeId(for view: UIView) -> String? {
        guard !AutocaptureDefaults.isSwiftUIView(view) else { return nil }
        let selector = NSSelectorFromString("nativeID")
        guard view.responds(to: selector) else { return nil }
        guard let nativeId = view.value(forKey: "nativeID") as? String, !nativeId.isEmpty else {
            return nil
        }
        return nativeId
    }

    private static func isInternalIdentifier(_ identifier: String) -> Bool {
        for prefix in internalIdentifierPrefixes where identifier.hasPrefix(prefix) {
            return true
        }
        return false
    }

    // MARK: - Anonymous Fallback

    /// The anonymous, PII-free identifier used when nothing else resolves:
    /// `<ClassName>_<hash>` (e.g. `UIButton_3f2a1b`).
    ///
    /// The hash describes the view's **position in the hierarchy**, not its identity. `view.hash` is
    /// per-instance and, because Swift seeds hashing per process, differs on every launch — an
    /// element with no identifier would get a new `$el_id` every session and could never be grouped.
    ///
    /// It identifies a *position* rather than a specific element: reordering siblings changes the id,
    /// and two rows of the same list differ by index, not by content.
    static func anonymousId(for view: UIView) -> String {
        let className = String(describing: type(of: view))
        return "\(className)_\(stableHash(structuralPath(for: view)))"
    }

    /// Class names and sibling indices only — never text — so the path cannot carry user data:
    /// `UIButton@UIStackView[2]/UIScrollView[0]/UIView[1]`.
    static func structuralPath(for view: UIView) -> String {
        var path = String(describing: type(of: view)) + "@"
        var current: UIView = view
        var depth = 0

        while let parent = current.superview, depth < AutocaptureDefaults.maxHierarchyDepth {
            if depth > 0 {
                path += "/"
            }
            let index = parent.subviews.firstIndex(of: current) ?? -1
            path += "\(String(describing: type(of: parent)))[\(index)]"
            current = parent
            depth += 1
        }

        if depth == 0 {
            path += "detached"
        }
        return path
    }

    /// FNV-1a over the path's UTF-8 bytes.
    ///
    /// Swift's `hashValue` is seeded per process, so it cannot be used here: the whole point of the
    /// structural id is that it is identical across launches.
    private static func stableHash(_ value: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return String(hash, radix: 16)
    }
}
#endif
