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
/// resolves the identifier from the React Native `nativeID`, then `accessibilityIdentifier`, then
/// `accessibilityLabel`.
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
/// 3. **`accessibilityLabel`** — only when the label was intentionally set (see
///    `intentionalAccessibilityLabel(for:)`), so framework-derived text that may contain user data
///    is not reported.
/// 4. **Anonymous fallback** — `<ClassName>_<hash>` derived from the view's class and hash.
///
/// For SwiftUI, steps 1–3 collapse to `accessibilityIdentifier` > `accessibilityLabel` > hash. Both
/// of those properties live in SwiftUI's accessibility element tree rather than on the backing
/// `UIView`, so `SemanticExtractor` resolves them from that tree and passes them in as the
/// `accessibilityIdentifierFallback` / `accessibilityLabelFallback` arguments below.
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
        return elementId(
            for: view, accessibilityIdentifierFallback: nil, accessibilityLabelFallback: nil)
    }

    /// Resolution with optional precomputed values used at priority steps 2 and 3.
    ///
    /// SwiftUI renders its views as internal UIKit views that carry neither
    /// `accessibilityIdentifier` nor `accessibilityLabel` on the UIKit view itself; the caller
    /// resolves those from SwiftUI's accessibility element tree and passes them here so SwiftUI
    /// elements still get a meaningful `$el_id`. Each fallback is consulted only after the view's
    /// own property for that step, so an identifier always outranks any label.
    func elementId(
        for view: UIView,
        accessibilityIdentifierFallback: String?,
        accessibilityLabelFallback: String?
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

        // 3. accessibilityLabel (only when intentionally set)
        if let label = intentionalAccessibilityLabel(for: view) {
            return label
        }
        if let fallbackLabel = accessibilityLabelFallback, !fallbackLabel.isEmpty {
            return fallbackLabel
        }

        // 4. Anonymous fallback
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

    // MARK: - Accessibility

    /// Returns the view's `accessibilityLabel` only when it was intentionally set.
    ///
    /// UIKit auto-derives `accessibilityLabel` from child text for container views whose
    /// `isAccessibilityElement` is false, and that derived text may contain sensitive information
    /// (account numbers, personal details). Known UIKit controls and SwiftUI views always carry an
    /// intentional (title-derived or explicitly set) label, so they are trusted; generic containers
    /// — e.g. React Native's `RCTView` — are trusted only when `isAccessibilityElement` is true,
    /// which in React Native maps to `accessible={true}`.
    private func intentionalAccessibilityLabel(for view: UIView) -> String? {
        let isKnownControl =
            view is UIButton || view is UILabel || view is UISwitch
            || view is UISlider || view is UITextField || view is UITextView
            || view is UISegmentedControl || view is UIStepper || view is UIImageView
        if !isKnownControl && !view.isAccessibilityElement
            && !AutocaptureDefaults.isSwiftUIView(view)
        {
            return nil
        }
        if let label = view.accessibilityLabel, !label.isEmpty {
            return label
        }
        return nil
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
    static func anonymousId(for view: UIView) -> String {
        let className = String(describing: type(of: view))
        // abs(Int.min) traps, so map it to Int.max.
        let safeHash = view.hash == Int.min ? Int.max : abs(view.hash)
        return "\(className)_\(String(safeHash, radix: 16))"
    }
}
#endif
