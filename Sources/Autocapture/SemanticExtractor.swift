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
  /// Handles element identification, text extraction, role detection, and privacy filtering.
  final class SemanticExtractor {
    // MARK: - Constants

    private static let maxTextLength = AutocaptureDefaults.maxTextLength
    private static let maxHierarchyDepth = AutocaptureDefaults.maxHierarchyDepth

    /// Markers for sensitive elements that should be excluded from all capture
    private static let sensitiveMarkers = ["mp-sensitive", "mp-no-track"]

    /// Regex patterns for redacting sensitive content
    private static let creditCardPattern = try? NSRegularExpression(
      pattern:
        "\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b",
      options: []
    )

    private static let ssnPattern = try? NSRegularExpression(
      pattern: "\\b[0-9]{3}-[0-9]{2}-[0-9]{4}\\b",
      options: []
    )

    // MARK: - Public API

    /// Extract semantic information from a view at the given point.
    ///
    /// Returns `nil` if the view is marked as sensitive.
    func extractSemantics(from view: UIView, at point: CGPoint, captureTextContent: Bool) -> ClickEvent? {
      // Check if view or ancestor is marked as sensitive
      if isSensitive(view: view) {
        MixpanelLogger.debug(message: "SemanticExtractor: skipping sensitive element")
        return nil
      }

      let className = String(describing: type(of: view))
      let elementId = generateElementId(for: view, isSwiftUI: isSwiftUIView(view))
      let ariaLabel = findAccessibilityLabel(in: view)
      let role = determineRole(for: view)
      let text = captureTextContent ? extractText(from: view) : nil
      let elements = buildViewHierarchy(from: view)
      let isInteractive = hasInteractionHandlers(view: view)

      return ClickEvent(
        x: point.x,
        y: point.y,
        elementId: elementId,
        tagName: className,
        text: text,
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

    // MARK: - Text Extraction

    private func extractText(from view: UIView) -> String? {
      // Check if this is a secure text field - never capture text
      if let textField = view as? UITextField {
        if textField.isSecureTextEntry {
          return nil
        }
        if let contentType = textField.textContentType {
          let sensitiveTypes: [UITextContentType] = [.password, .newPassword, .oneTimeCode]
          if sensitiveTypes.contains(contentType) {
            return nil
          }
        }
      }

      var text: String?

      // Try to extract text from the view
      if let label = view as? UILabel {
        text = label.text
      } else if let button = view as? UIButton {
        text = button.currentTitle
      } else if let textField = view as? UITextField {
        text = textField.text
      } else if let textView = view as? UITextView {
        // Skip if secure
        text = textView.isSecureTextEntry ? nil : textView.text
      } else if let segmentedControl = view as? UISegmentedControl {
        let index = segmentedControl.selectedSegmentIndex
        if index != UISegmentedControl.noSegment {
          text = segmentedControl.titleForSegment(at: index)
        }
      }

      // If no text found directly, try to find text in subviews (for container views)
      if text == nil {
        text = findTextInSubviews(view)
      }

      // Truncate, filter sensitive content, and return
      return text.flatMap { sanitizeText($0) }
    }

    private func findTextInSubviews(_ view: UIView, depth: Int = 0) -> String? {
      guard depth < 3 else { return nil }

      for subview in view.subviews {
        if let label = subview as? UILabel, let text = label.text, !text.isEmpty {
          return text
        }
        if let found = findTextInSubviews(subview, depth: depth + 1) {
          return found
        }
      }

      return nil
    }

    private func sanitizeText(_ text: String) -> String? {
      guard !text.isEmpty else { return nil }

      // Truncate to max length
      var sanitized = String(text.prefix(Self.maxTextLength))

      // Redact credit card numbers
      if let regex = Self.creditCardPattern {
        sanitized = regex.stringByReplacingMatches(
          in: sanitized,
          options: [],
          range: NSRange(sanitized.startIndex..., in: sanitized),
          withTemplate: "[REDACTED]"
        )
      }

      // Redact SSN patterns
      if let regex = Self.ssnPattern {
        sanitized = regex.stringByReplacingMatches(
          in: sanitized,
          options: [],
          range: NSRange(sanitized.startIndex..., in: sanitized),
          withTemplate: "[REDACTED]"
        )
      }

      return sanitized
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

    // MARK: - Privacy / Sensitive Detection

    /// Check if view or any ancestor is marked as sensitive.
    ///
    /// A view is sensitive if its accessibilityIdentifier contains "mp-sensitive" or "mp-no-track".
    /// We only check accessibilityIdentifier (not accessibilityLabel) because React Native
    /// aggregates all child labels into parent views, which would cause false positives.
    ///
    /// Additionally, we limit the hierarchy walk to a reasonable depth to avoid checking
    /// container views that have aggregated content.
    private func isSensitive(view: UIView) -> Bool {
      var currentView: UIView? = view
      var level = 0
      let maxLevels = 5  // Don't walk too far up - container views often have aggregated labels

      while let v = currentView, level < maxLevels {
        // Only check accessibilityIdentifier - this is explicitly set per-view and not aggregated
        // by React Native or UIKit container views
        if let identifier = v.accessibilityIdentifier {
          for marker in Self.sensitiveMarkers {
            if identifier.contains(marker) {
              MixpanelLogger.debug(message: "SemanticExtractor: found sensitive marker '\(marker)' in identifier")
              return true
            }
          }
        }

        currentView = v.superview
        level += 1
      }

      return false
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
