//
//  SemanticExtractor.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
import UIKit

/// Extracts semantic information from UIKit and SwiftUI views for autocapture events.
///
/// Handles element identification and role detection.
final class SemanticExtractor {
    // MARK: - Configuration

    private let autocaptureOptions: AutocaptureOptions

    init(autocaptureOptions: AutocaptureOptions = AutocaptureOptions()) {
        self.autocaptureOptions = autocaptureOptions
    }

    // MARK: - Constants

    private static let maxHierarchyDepth = AutocaptureDefaults.maxHierarchyDepth

    // MARK: - Public API

    /// Extract semantic information from a view at the given point.
    ///
    /// If the touched view is not interactive (e.g., a UILabel inside a UIButton),
    /// walks up to find the nearest interactive ancestor and extracts from that instead.
    func extractSemantics(from view: UIView, at point: CGPoint) -> ClickEvent {
        // UIKit hit-testing returns the deepest view. For UIButton > UILabel,
        // we get the UILabel — wrong role, wrong el_id, not interactive.
        // Walk up to the nearest clickable ancestor when the leaf isn't interactive.
        let interactiveAncestor: UIView? = isInteractive(view) ? view : findInteractiveAncestor(of: view)
        // Use the interactive ancestor as target for semantic extraction, but never UIWindow —
        // its gesture recognizers are infrastructure (TouchInterceptor), not user-facing controls.
        // Using UIWindow would produce wrong $el_id, tagName, role, etc.
        let targetView: UIView
        if let ancestor = interactiveAncestor, !(ancestor is UIWindow) {
            targetView = ancestor
        } else {
            targetView = view
        }
        var viewIsInteractive = interactiveAncestor != nil

        // SwiftUI buttons are rendered as internal UIKit views (e.g., PlatformGroupContainer)
        // that lack UIKit interactivity signals (UIControl targets, gesture recognizers).
        // The .button accessibility trait exists only in SwiftUI's accessibility element tree,
        // not on the UIKit views. Query the accessibility tree at the touch point.
        if !viewIsInteractive {
            viewIsInteractive = isSwiftUIButtonAtPoint(point, view: view)
        }

        let className = String(describing: type(of: targetView))
        var accessibleLabel = findAccessibilityLabel(in: targetView)

        // SwiftUI views render as internal UIKit views (e.g., PlatformGroupContainer) that
        // don't carry the SwiftUI accessibilityLabel on the UIKit view. Query the SwiftUI
        // accessibility element tree at the touch point to retrieve the label.
        if accessibleLabel == nil, AutocaptureDefaults.isSwiftUIView(targetView) {
            accessibleLabel = findSwiftUIAccessibilityLabel(at: point, view: targetView)
        }

        let elementId = accessibleLabel ?? generateElementId(for: targetView)
        let role = determineRole(for: targetView)
        let tagName = resolveTagName(className: className, role: role, view: targetView)
        let elements = buildViewHierarchy(from: targetView)

        return ClickEvent(
            x: point.x,
            y: point.y,
            elementId: elementId,
            tagName: tagName,
            accessibleLabel: accessibleLabel,
            role: role,
            elements: elements,
            isInteractive: viewIsInteractive
        )
    }

    // MARK: - Element ID Generation

    /// Generate a hash-based element ID as fallback when no accessibility label is available.
    ///
    /// Resolution order:
    /// 1. `accessibilityIdentifier` (if non-empty)
    /// 2. `ClassName_<hash>`
    ///
    /// Note: `accessibilityLabel` is checked by the caller (`extractSemantics`) via
    /// `findAccessibilityLabel` before falling back to this method.
    private func generateElementId(for view: UIView) -> String {
        // accessibilityIdentifier as primary fallback
        if let identifier = findAccessibilityIdentifier(in: view), !identifier.isEmpty {
            return identifier
        }

        // Fallback: ClassName_<hex hash>
        let className = String(describing: type(of: view))
        let safeHash = view.hash == Int.min ? Int.max : abs(view.hash)
        return "\(className)_\(String(safeHash, radix: 16))"
    }

    // MARK: - Accessibility Property Discovery

    private func findAccessibilityIdentifier(
        in view: UIView, maxLevels: Int = SemanticExtractor.maxHierarchyDepth
    ) -> String? {
        var currentView: UIView? = view
        var level = 0

        while let v = currentView, level < maxLevels {
            if let identifier = v.accessibilityIdentifier, !identifier.isEmpty {
                if !isInternalIdentifier(identifier) {
                    return identifier
                }
            }
            currentView = v.superview
            level += 1
        }

        return nil
    }

    /// Returns the view's accessibilityLabel only if it was explicitly set by the developer.
    ///
    /// UIKit auto-derives accessibilityLabel from child text content for container
    /// views where isAccessibilityElement is false. That derived text may contain
    /// sensitive information (e.g., account numbers, personal details).
    ///
    /// For known UIKit controls (UIButton, UILabel, etc.) and SwiftUI views, the
    /// label is always intentional (title-derived or explicitly set), so we capture it.
    /// For generic container views (e.g., React Native's RCTView), we only capture
    /// the label when isAccessibilityElement is true — in React Native, this maps
    /// to `accessible={true}`, signaling an explicitly set label.
    private func findAccessibilityLabel(in view: UIView) -> String? {
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

    /// Check if an identifier is an internal framework identifier that should be skipped
    private func isInternalIdentifier(_ identifier: String) -> Bool {
        let internalPrefixes = [
            "_",  // Private Apple identifiers
            "AXID-",  // Accessibility internal
            "UITransitionView",
            "UILayoutContainerView",
        ]

        for prefix in internalPrefixes {
            if identifier.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    // MARK: - Role Detection

    private func determineRole(for view: UIView) -> String? {
        // Check specific control types first
        if view is UIButton { return "Button" }
        if view is UISwitch { return "Switch" }
        if view is UISlider { return "Slider" }
        if view is UITextField { return "TextField" }
        if view is UITextView { return "TextArea" }
        if view is UISegmentedControl { return "SegmentedControl" }
        if view is UIStepper { return "Stepper" }
        if view is UIImageView { return "Image" }
        if view is UILabel { return "Text" }
        if view is UIScrollView { return "ScrollView" }
        if view is UITableView { return "List" }
        if view is UICollectionView { return "Grid" }

        // Check accessibility traits
        let traits = view.accessibilityTraits
        if traits.contains(.button) { return "Button" }
        if traits.contains(.link) { return "Link" }
        if traits.contains(.image) { return "Image" }
        if traits.contains(.staticText) { return "Text" }
        if traits.contains(.searchField) { return "SearchField" }
        if traits.contains(.adjustable) { return "Adjustable" }
        if traits.contains(.header) { return "Header" }
        if traits.contains(.tabBar) { return "TabBar" }

        return nil
    }

    // MARK: - Tag Name Resolution

    /// For UIKit views, uses the raw class name (e.g., "UIButton", "UITableViewCell").
    /// For SwiftUI views, the raw class name is an internal UIKit name (e.g., "_UIGraphicsView")
    /// which is meaningless — use the role instead, falling back to "View".
    private func resolveTagName(className: String, role: String?, view: UIView) -> String {
        if AutocaptureDefaults.isSwiftUIView(view) {
            return role ?? "View"
        }
        return className
    }

    // MARK: - View Hierarchy

    private func buildViewHierarchy(
        from view: UIView, maxLevels: Int = SemanticExtractor.maxHierarchyDepth
    ) -> String {
        var hierarchy: [String] = []
        var currentView: UIView? = view
        var level = 0

        while let v = currentView, level < maxLevels {
            var name = String(describing: type(of: v))

            // Add identifier if available
            if let identifier = v.accessibilityIdentifier, !identifier.isEmpty {
                name += "#\(identifier)"
            }

            hierarchy.append(name)
            currentView = v.superview
            level += 1
        }

        return hierarchy.reversed().joined(separator: " > ")
    }

    // MARK: - Interactive View Resolution

    /// Check if a view is interactive (has tap handlers or is a UIControl with targets).
    private func isInteractive(_ view: UIView) -> Bool {
        return AutocaptureDefaults.isInteractive(view)
    }

    // MARK: - SwiftUI Interactivity Detection

    /// Check if a SwiftUI button exists at the given point using the accessibility element tree.
    ///
    /// SwiftUI renders buttons as internal UIKit views (e.g., PlatformGroupContainer) that lack
    /// standard UIKit interactivity signals. The `.button` accessibility trait exists only in
    /// SwiftUI's accessibility element tree, not on the UIKit views themselves.
    private func isSwiftUIButtonAtPoint(_ windowPoint: CGPoint, view: UIView) -> Bool {
        // Only needed on iOS 18+ where SwiftUI renders buttons as PlatformGroupContainer
        // without .button trait on the UIKit view. On older iOS, SwiftUI views like
        // _UIGraphicsView carry the .button trait directly.
        guard #available(iOS 18.0, *) else { return false }

        // Find the nearest SwiftUI hosting ancestor — bails out early for pure UIKit views.
        guard let hostingView = findHostingAncestor(of: view) else { return false }
        guard let window = view.window else { return false }

        // accessibilityHitTest expects screen coordinates
        let screenPoint = window.convert(windowPoint, to: window.screen.coordinateSpace)

        // Query the hosting view's accessibility tree rather than the entire window,
        // limiting the search scope to just the SwiftUI content.
        guard let element = hostingView.accessibilityHitTest(screenPoint, event: nil) as? NSObject else {
            return false
        }

        return element.accessibilityTraits.contains(UIAccessibilityTraits.button)
    }

    /// Find the nearest SwiftUI hosting view ancestor.
    /// Returns nil if the view is not inside a SwiftUI hierarchy.
    private func findHostingAncestor(of view: UIView) -> UIView? {
        var current: UIView? = view
        var depth = 0
        while let v = current, depth < AutocaptureDefaults.maxAncestorSearchDepth {
            if AutocaptureDefaults.isSwiftUIView(v) {
                return v
            }
            current = v.superview
            depth += 1
        }
        return nil
    }

    /// Query the SwiftUI accessibility element tree at the touch point to retrieve the label.
    ///
    /// SwiftUI views render as internal UIKit views (e.g., PlatformGroupContainer) that don't
    /// expose `accessibilityLabel` on the UIKit view. The label lives in SwiftUI's accessibility
    /// element tree, which we can query via `accessibilityHitTest`.
    ///
    /// We walk up to find the UIHostingController's view (class name contains "Hosting"),
    /// which owns the full SwiftUI accessibility tree. Calling `accessibilityHitTest` on
    /// a leaf PlatformGroupContainer won't traverse the tree properly.
    private func findSwiftUIAccessibilityLabel(at windowPoint: CGPoint, view: UIView) -> String? {
        guard #available(iOS 18.0, *) else { return nil }
        guard let window = view.window else { return nil }

        // Walk up to find the UIHostingController's view which owns the accessibility tree
        var current: UIView? = view
        var depth = 0
        while let v = current, depth < AutocaptureDefaults.maxAncestorSearchDepth {
            let className = String(describing: type(of: v))
            if className.contains("Hosting") {
                let screenPoint = window.convert(windowPoint, to: window.screen.coordinateSpace)
                if let element = v.accessibilityHitTest(screenPoint, event: nil) as? NSObject,
                    let label = element.accessibilityLabel, !label.isEmpty
                {
                    return label
                }
                break
            }
            current = v.superview
            depth += 1
        }

        return nil
    }

    /// Walk up the view hierarchy to find the nearest interactive ancestor.
    /// Returns nil if no interactive ancestor is found within maxDepth levels.
    private func findInteractiveAncestor(of view: UIView, maxDepth: Int = AutocaptureDefaults.maxAncestorSearchDepth)
        -> UIView?
    {
        var current = view.superview
        var depth = 0
        while let v = current, depth < maxDepth {
            if isInteractive(v) {
                return v
            }
            current = v.superview
            depth += 1
        }
        return nil
    }

}
#endif
