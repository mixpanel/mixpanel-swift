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
  /// Handles element identification, role detection, and privacy filtering.
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
      let interactiveAncestor = isInteractive(view) ? view : findInteractiveAncestor(of: view)
      let targetView = interactiveAncestor ?? view
      let viewIsInteractive = interactiveAncestor != nil

      let className = String(describing: type(of: targetView))
      let elementId = generateElementId(for: targetView)
      let accessibleLabel = findAccessibilityLabel(in: targetView)
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

    /// Generate element ID following platform-specific resolution rules:
    ///
    /// Resolution order (same for UIKit and SwiftUI):
    /// 1. `accessibilityLabel` (if non-empty)
    /// 2. `accessibilityIdentifier` (if non-empty)
    /// 3. `ClassName_<hash>`
    private func generateElementId(for view: UIView) -> String {
      // accessibilityLabel is primary for both UIKit and SwiftUI
      if let label = findAccessibilityLabel(in: view), !label.isEmpty {
        return label
      }
      // accessibilityIdentifier as fallback
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

    private func findAccessibilityLabel(in view: UIView) -> String? {
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

    /// Walk up the view hierarchy to find the nearest interactive ancestor.
    /// Returns nil if no interactive ancestor is found within maxDepth levels.
    private func findInteractiveAncestor(of view: UIView, maxDepth: Int = 5) -> UIView? {
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
