//
//  ClickEvent.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import UIKit

  /// Represents a captured click event with element metadata.
  ///
  /// Contains all semantic information about the clicked element and its context.
  /// Create a `ClickEvent` and pass it to `mixpanel.autocapture.trackClick(_:)` to
  /// track click events with full element metadata.
  public struct ClickEvent {
    // MARK: - Position

    /// Touch X coordinate in the window's coordinate space (points).
    ///
    /// The SDK captures this as `touch.location(in: window).x`.
    /// When tracking manually, use `touch.location(in: view.window).x`.
    public let x: CGFloat

    /// Touch Y coordinate in the window's coordinate space (points).
    ///
    /// The SDK captures this as `touch.location(in: window).y`.
    /// When tracking manually, use `touch.location(in: view.window).y`.
    public let y: CGFloat

    // MARK: - Element Identification

    /// A stable identifier for the tapped element, used to group clicks in analytics.
    ///
    /// Recommended sources (in order of preference):
    /// - `accessibilityLabel` — human-readable, consistent across UIKit and SwiftUI
    /// - `accessibilityIdentifier` — stable and not user-visible
    /// - A custom string like `"buy_button"` or `"settings_cell_notifications"`
    ///
    /// Avoid dynamic values (e.g., cell index, timestamp) — they prevent meaningful grouping.
    public let elementId: String

    /// The class name or component type of the tapped element.
    ///
    /// Examples: `"UIButton"`, `"UITableViewCell"`, `"Button"` (SwiftUI).
    /// Use `String(describing: type(of: view))` to get the class name.
    /// Defaults to empty string if not provided.
    public let tagName: String

    /// The human-readable accessibility label of the element.
    ///
    /// This is the text read aloud by VoiceOver — typically the view's `accessibilityLabel`.
    /// Examples: `"Add to cart"`, `"Play video"`, `"Close"`.
    /// Set to `nil` if the element has no accessibility label.
    public let accessibleLabel: String?

    /// The semantic role describing what the element does.
    ///
    /// Common values: `"button"`, `"link"`, `"switch"`, `"checkbox"`, `"slider"`,
    /// `"tab"`, `"textfield"`, `"image"`.
    /// Set to `nil` if the element has no specific role.
    public let role: String?

    /// View hierarchy path from the tapped element up to 5 ancestor levels, `">"` separated.
    ///
    /// Example: `"UIButton > UIStackView > UITableViewCell > UITableView > UIView"`.
    /// Useful for identifying where in the view tree the click occurred.
    /// Defaults to empty string if not provided.
    public let elements: String

    /// Whether the clicked element is interactive (has tap handlers or is a clickable control).
    /// Non-interactive elements (plain labels, images without gestures) are excluded from
    /// dead click detection since tapping them is expected to do nothing.
    let isInteractive: Bool

    /// Creates a new ClickEvent.
    ///
    /// Only `x`, `y`, and `elementId` are required. All other parameters have sensible defaults.
    ///
    /// **Minimal usage:**
    /// ```swift
    /// let click = ClickEvent(x: 150, y: 300, elementId: "buy_button")
    /// mixpanel.autocapture.trackClick(click)
    /// ```
    ///
    /// **Full usage:**
    /// ```swift
    /// let click = ClickEvent(
    ///     x: touch.location(in: view.window).x,
    ///     y: touch.location(in: view.window).y,
    ///     elementId: button.accessibilityIdentifier ?? "buy_button",
    ///     tagName: String(describing: type(of: button)),
    ///     accessibleLabel: button.accessibilityLabel,
    ///     role: "button",
    ///     elements: "UIButton > UIStackView > UIView"
    /// )
    /// mixpanel.autocapture.trackClick(click)
    /// ```
    ///
    /// - Parameters:
    ///   - x: Touch X coordinate in window points
    ///   - y: Touch Y coordinate in window points
    ///   - elementId: Stable identifier for the tapped element
    ///   - tagName: Class name of the tapped element (defaults to empty string)
    ///   - accessibleLabel: The element's accessibility label (defaults to nil)
    ///   - role: Semantic role like `"button"`, `"switch"`, `"link"` (defaults to nil)
    ///   - elements: View hierarchy path, `">"` separated (defaults to empty string)
    ///   - isInteractive: Whether the element is interactive (defaults to true)
    public init(x: CGFloat, y: CGFloat, elementId: String,
                tagName: String = "", accessibleLabel: String? = nil,
                role: String? = nil, elements: String = "",
                isInteractive: Bool = true) {
      self.x = x
      self.y = y
      self.elementId = elementId
      self.tagName = tagName
      self.accessibleLabel = accessibleLabel
      self.role = role
      self.elements = elements
      self.isInteractive = isInteractive
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

      if let accessibleLabel = accessibleLabel {
        props["$attr-aria-label"] = accessibleLabel
      }

      if let role = role {
        props["$attr-role"] = role
      }

      return props
    }
  }
#endif
