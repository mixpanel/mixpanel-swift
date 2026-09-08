//
//  ElementIdExtractor.swift
//  Mixpanel
//
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
import UIKit

// MARK: - DefaultElementIdExtractor

/// Resolves the `$el_id` property reported for an autocaptured interaction.
///
/// This is the SDK's only `$el_id` resolver; there is no way for a host app to substitute its own.
///
/// Resolution priority:
/// 1. **React Native `nativeID`** — read through the Objective-C runtime so the SDK carries no
///    compile-time dependency on React Native. Both the new-architecture (`nativeId`) and legacy
///    (`nativeID`) property spellings are probed. Skipped for SwiftUI views: React Native renders
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
final class DefaultElementIdExtractor {

    static let shared = DefaultElementIdExtractor()

    /// Where React Native puts the `nativeID` prop: `nativeId` on Fabric, `nativeID` on the legacy
    /// bridge. Probed in this order.
    private static let reactNativeIdKeys = ["nativeId", "nativeID"]

    /// Framework-internal identifier prefixes that carry no product meaning.
    private static let internalIdentifierPrefixes = [
        "_",  // Private Apple identifiers
        "AXID-",  // Accessibility internal
        "UITransitionView",
        "UILayoutContainerView",
    ]

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
        // 2. accessibilityIdentifier
        if let identifier = explicitIdentifier(for: view) {
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

    /// Steps 1 and 2 only: the identifier the view carries itself, nil when it would resolve to
    /// nothing but a structural hash. `SemanticExtractor` uses that distinction to prefer a named
    /// ancestor over an anonymous leaf.
    func explicitIdentifier(for view: UIView) -> String? {
        if let nativeId = reactNativeId(for: view) {
            return nativeId
        }
        if let identifier = view.accessibilityIdentifier,
            !identifier.isEmpty,
            !DefaultElementIdExtractor.isInternalIdentifier(identifier)
        {
            return identifier
        }
        return nil
    }

    // MARK: - React Native

    /// Reads React Native's `nativeID` prop through the Objective-C runtime, trying both spellings:
    /// Fabric assigns `RCTViewComponentView.nativeId`, the legacy bridge the `UIView (React)`
    /// category's `nativeID`. `responds(to:)` guards each read so KVC never throws — necessary but
    /// not sufficient, since React-Core compiles that category into every app: *every* `UIView`
    /// responds to `nativeID` even on Fabric, where nothing assigns it, so an empty read must fall
    /// through to the next spelling rather than end resolution.
    ///
    /// Skipped for SwiftUI views — React Native renders through UIKit, so they never carry one.
    private func reactNativeId(for view: UIView) -> String? {
        guard !AutocaptureDefaults.isSwiftUIView(view) else { return nil }
        for key in DefaultElementIdExtractor.reactNativeIdKeys {
            guard view.responds(to: NSSelectorFromString(key)) else { continue }
            if let nativeId = view.value(forKey: key) as? String, !nativeId.isEmpty {
                return nativeId
            }
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
