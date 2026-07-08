//
//  ClickEvent.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import UIKit

  /// Internal model representing a click event with all captured properties.
  ///
  /// Property names match the JS SDK schema for cross-platform consistency.
  struct ClickEvent {
    // MARK: - Position

    /// Touch location X coordinate (screen coordinates)
    let x: CGFloat

    /// Touch location Y coordinate (screen coordinates)
    let y: CGFloat

    // MARK: - Element Identification

    /// Primary element identifier following resolution rules:
    /// - UIKit: accessibilityIdentifier -> accessibilityLabel -> ClassName_view_<hash>
    /// - SwiftUI: accessibilityLabel -> ClassName_view_<hash>
    let elementId: String

    /// Class name of the tapped view (e.g., "UIButton", "Button")
    let tagName: String

    /// Accessibility label (maps to $attr-aria-label)
    let ariaLabel: String?

    /// Element role based on accessibility traits or control type (maps to $attr-role)
    let role: String?

    /// View hierarchy string (max 5 levels, ">" separated)
    let elements: String

    // MARK: - Conversion to Properties

    /// Convert to Mixpanel properties dictionary for tracking
    func toProperties() -> Properties {
      var props: Properties = [
        "$x": Int(x),
        "$y": Int(y),
        "$el_id": elementId,
        "$el_tag_name": tagName,
        "$elements": elements,
      ]

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
