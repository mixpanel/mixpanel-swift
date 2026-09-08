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

        // SwiftUI's .accessibilityIdentifier("…") never reaches the backing UIKit view either —
        // it lives in the same accessibility element tree as the label. Query it only for SwiftUI
        // views that carry no identifier of their own, so pure UIKit hierarchies pay nothing.
        var derivedIdentifier: String? = nil
        if AutocaptureDefaults.isSwiftUIView(targetView),
            (targetView.accessibilityIdentifier ?? "").isEmpty
        {
            derivedIdentifier = findSwiftUIAccessibilityIdentifier(at: point, view: targetView)
        }

        let elementId = resolveElementId(for: targetView, derivedIdentifier: derivedIdentifier)
        let role = determineRole(for: targetView)
        let tagName = resolveTagName(className: className, role: role, view: targetView)
        let elements = buildViewHierarchy(from: targetView)

        return ClickEvent(
            x: point.x,
            y: point.y,
            elementId: elementId,
            tagName: tagName,
            role: role,
            elements: elements,
            isInteractive: viewIsInteractive
        )
    }

    // MARK: - Element ID Resolution

    /// Resolve the `$el_id` for the target view.
    ///
    /// `DefaultElementIdExtractor` resolves it (React Native `nativeID` > `accessibilityIdentifier` >
    /// `<ClassName>_<hash>`; for SwiftUI the `nativeID` step is skipped). Accessibility labels are
    /// never used: they are localized and can carry user data.
    ///
    /// - Parameters:
    ///   - derivedIdentifier: Identifier read from SwiftUI's accessibility element tree, used at the
    ///     `accessibilityIdentifier` priority step when the view carries none itself.
    private func resolveElementId(for view: UIView, derivedIdentifier: String?) -> String {
        return DefaultElementIdExtractor.shared.elementId(
            for: view, accessibilityIdentifierFallback: derivedIdentifier)
    }

    // MARK: - Accessibility Property Discovery

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

    /// Query the SwiftUI accessibility element tree at the touch point to retrieve the identifier
    /// set by `.accessibilityIdentifier("…")`.
    ///
    /// Same mechanism (and same constraints) as `findSwiftUIAccessibilityLabel(at:view:)`: SwiftUI
    /// keeps both the label and the identifier in its own accessibility element tree rather than on
    /// the backing UIKit view, and only the `UIHostingController`'s view owns a tree that
    /// `accessibilityHitTest` will traverse.
    ///
    /// Note SwiftUI only materializes that tree while an accessibility client is attached, so this
    /// returns nil in an XCTest host — both this and the label helper are exercised on device, not
    /// by the instrumented tests. `DefaultElementIdExtractorTests` covers what happens with the
    /// values once resolved.
    private func findSwiftUIAccessibilityIdentifier(at windowPoint: CGPoint, view: UIView) -> String? {
        guard #available(iOS 18.0, *) else { return nil }
        guard let window = view.window else { return nil }

        var current: UIView? = view
        var depth = 0
        while let v = current, depth < AutocaptureDefaults.maxAncestorSearchDepth {
            let className = String(describing: type(of: v))
            if className.contains("Hosting") {
                let screenPoint = window.convert(windowPoint, to: window.screen.coordinateSpace)
                if let element = v.accessibilityHitTest(screenPoint, event: nil) as? NSObject,
                    let identifier = (element as? UIAccessibilityIdentification)?
                        .accessibilityIdentifier,
                    !identifier.isEmpty
                {
                    return identifier
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
