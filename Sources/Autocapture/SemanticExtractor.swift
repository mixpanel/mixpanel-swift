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
    func extractSemantics(from view: UIView, at point: CGPoint) -> ClickEvent {
      let className = String(describing: type(of: view))
      let elementId = generateElementId(for: view, isSwiftUI: isSwiftUIView(view))
      let ariaLabel = findAccessibilityLabel(in: view)
      let role = determineRole(for: view)
      let elements = buildViewHierarchy(from: view)
      let isInteractive = hasInteractionHandlers(view: view)

      return ClickEvent(
        x: point.x,
        y: point.y,
        elementId: elementId,
        tagName: className,
        ariaLabel: ariaLabel,
        role: role,
        elements: elements,
        isRageClick: false,
        tapCount: 1,
        isInteractive: isInteractive
      )
    }

    // MARK: - Element ID Generation

    /// Generate element ID following platform-specific resolution rules:
    ///
    /// **UIKit:**
    /// 1. `accessibilityIdentifier` (if non-empty)
    /// 2. `accessibilityLabel` (if non-empty)
    /// 3. `ClassName_view_<hash>`
    ///
    /// **SwiftUI:**
    /// 1. `accessibilityLabel` (primary - always available)
    /// 2. `accessibilityIdentifier` (only when VoiceOver active)
    /// 3. `ClassName_view_<hash>`
    private func generateElementId(for view: UIView, isSwiftUI: Bool) -> String {
      if isSwiftUI {
        // SwiftUI: accessibilityLabel is primary
        if let label = findAccessibilityLabel(in: view), !label.isEmpty {
          return label
        }
        // SwiftUI: accessibilityIdentifier only works with VoiceOver, check anyway
        if let identifier = findAccessibilityIdentifier(in: view), !identifier.isEmpty {
          return identifier
        }
      } else {
        // UIKit: accessibilityIdentifier is primary
        if let identifier = findAccessibilityIdentifier(in: view), !identifier.isEmpty {
          return identifier
        }
        // UIKit: accessibilityLabel as fallback
        if let label = findAccessibilityLabel(in: view), !label.isEmpty {
          return label
        }
      }

      // Fallback: ClassName_view_<hash>
      let className = String(describing: type(of: view))
      let safeHash = view.hash == Int.min ? Int.max : abs(view.hash)
      return "\(className)_view_\(safeHash)"
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

    private func findAccessibilityLabel(in view: UIView, maxLevels: Int = SemanticExtractor.maxHierarchyDepth)
      -> String?
    {
      var currentView: UIView? = view
      var level = 0

      while let v = currentView, level < maxLevels {
        if let label = v.accessibilityLabel, !label.isEmpty {
          return label
        }
        currentView = v.superview
        level += 1
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

    // MARK: - SwiftUI Detection

    private func isSwiftUIView(_ view: UIView) -> Bool {
      let className = String(describing: type(of: view))
      return className.contains("Hosting") || className.contains("SwiftUI")
    }

    // MARK: - Interaction Handler Detection

    /// Controls with inherent visual feedback that should be excluded from dead click monitoring.
    ///
    /// These controls always produce a UI response when tapped:
    /// - UISwitch: Toggle animation and state change
    /// - UISlider: Thumb moves with drag
    /// - UITextField/UITextView: Keyboard appears, cursor shown
    /// - UIStepper: Value changes with visual feedback
    /// - UISegmentedControl: Selection highlight changes
    /// - UIDatePicker/UIPickerView: Wheel/calendar UI appears
    private static let controlsWithInherentFeedback: [AnyClass] = [
      UISwitch.self,
      UISlider.self,
      UITextField.self,
      UITextView.self,
      UIStepper.self,
      UISegmentedControl.self,
      UIDatePicker.self,
      UIPickerView.self,
    ]

    /// SwiftUI class name patterns for controls with inherent visual feedback.
    private static let swiftUIExcludedPatterns = [
      "Toggle",       // SwiftUI Toggle (switch)
      "Slider",       // SwiftUI Slider
      "Stepper",      // SwiftUI Stepper
      "TextField",    // SwiftUI TextField
      "TextEditor",   // SwiftUI TextEditor (multiline text)
      "SecureField",  // SwiftUI SecureField (password)
      "Picker",       // SwiftUI Picker
      "DatePicker",   // SwiftUI DatePicker
    ]

    /// Check if a view should be considered interactive for dead click detection.
    ///
    /// Returns `false` for controls with inherent visual feedback (switches, text fields, etc.)
    /// since these always produce a response and should not trigger dead click events.
    ///
    /// This method walks up the view hierarchy to catch cases where the touch hits
    /// a subview of an excluded control.
    private func hasInteractionHandlers(view: UIView) -> Bool {
      // Walk up the hierarchy to check for excluded controls
      var currentView: UIView? = view
      var depth = 0
      let maxDepth = 10

      while let v = currentView, depth < maxDepth {
        // Check UIKit control types
        for controlType in Self.controlsWithInherentFeedback {
          if v.isKind(of: controlType) {
            return false
          }
        }

        // Check SwiftUI patterns by class name
        let className = String(describing: type(of: v))
        for pattern in Self.swiftUIExcludedPatterns {
          if className.contains(pattern) {
            return false
          }
        }

        // Also check accessibility traits for adjustable (sliders, steppers)
        if v.accessibilityTraits.contains(.adjustable) {
          return false
        }

        currentView = v.superview
        depth += 1
      }

      // Now check for actual interaction handlers
      // Check for tap gesture recognizers
      if let gestures = view.gestureRecognizers {
        for gesture in gestures where gesture.isEnabled {
          if gesture is UITapGestureRecognizer {
            return true
          }
        }
      }

      // Check if UIControl has targets
      if let control = view as? UIControl, !control.allTargets.isEmpty {
        return true
      }

      return false
    }
  }
#endif
