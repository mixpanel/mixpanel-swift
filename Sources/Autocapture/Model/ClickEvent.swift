//
//  ClickEvent.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import UIKit

  /// Model representing a click event with all captured properties.
  ///
  /// Use this to track click events with full element metadata.
  /// Property names match the JS SDK schema for cross-platform consistency.
  ///
  /// **Example:**
  /// ```swift
  /// let click = ClickEvent(x: 100, y: 200, elementId: "buy_button")
  /// mixpanel.autocapture.trackClick(click)
  /// ```
  public struct ClickEvent {
    // MARK: - Position

    /// Touch location X coordinate (screen coordinates)
    public let x: CGFloat

    /// Touch location Y coordinate (screen coordinates)
    public let y: CGFloat

    // MARK: - Element Identification

    /// Primary element identifier following resolution rules:
    /// - UIKit: accessibilityIdentifier -> accessibilityLabel -> ClassName_view_<hash>
    /// - SwiftUI: accessibilityLabel -> ClassName_view_<hash>
    public let elementId: String

    /// Class name of the tapped view (e.g., "UIButton", "Button")
    public let tagName: String

    /// Accessibility label (maps to $attr-aria-label)
    public let ariaLabel: String?

    /// Element role based on accessibility traits or control type (maps to $attr-role)
    public let role: String?

    /// View hierarchy string (max 5 levels, ">" separated)
    public let elements: String

    /// Creates a new ClickEvent.
    ///
    /// - Parameters:
    ///   - x: Touch location X coordinate
    ///   - y: Touch location Y coordinate
    ///   - elementId: Primary element identifier
    ///   - tagName: Class name of the tapped view (defaults to empty string)
    ///   - ariaLabel: Accessibility label (defaults to nil)
    ///   - role: Semantic role of the element (defaults to nil)
    ///   - elements: View hierarchy string (defaults to empty string)
    public init(x: CGFloat, y: CGFloat, elementId: String,
                tagName: String = "", ariaLabel: String? = nil,
                role: String? = nil, elements: String = "") {
      self.x = x
      self.y = y
      self.elementId = elementId
      self.tagName = tagName
      self.ariaLabel = ariaLabel
      self.role = role
      self.elements = elements
    }

    // MARK: - Conversion to Properties

    /// Convert to Mixpanel properties dictionary for tracking
    func toProperties() -> Properties {
      var props: Properties = [
        "$x": Int(x),
        "$y": Int(y),
        "$el_id": elementId,
      ]

      if !tagName.isEmpty {
        props["$el_tag_name"] = tagName
      }

      if !elements.isEmpty {
        props["$elements"] = elements
      }

      if let ariaLabel = ariaLabel {
        props["$attr-aria-label"] = ariaLabel
      }

      if let role = role {
        props["$attr-role"] = role
      }

      return props
    }
  }
#endif
