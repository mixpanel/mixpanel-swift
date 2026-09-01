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
/// All stored properties are value types (`CGFloat`, `String`, `Bool`), so the event can safely
/// cross threads — it is handed from the main thread, where it is extracted, to the queue that
/// emits it.
///
/// - Warning: **Experimental (beta).** Autocapture may contain issues, and its API and the properties
///   it captures may change in a future release before general availability. Pin your SDK version if
///   you build reports on autocaptured events.
public struct ClickEvent: Sendable {
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
    /// Autocapture resolves this in the following order (see `DefaultElementIdExtractor`), and the
    /// same preferences apply when tracking manually:
    /// - React Native `nativeID` — the JS-side prop, read through the Objective-C runtime
    ///   (skipped for SwiftUI views, which React Native never renders)
    /// - `accessibilityIdentifier` — stable and not user-visible
    /// - `<ClassName>_<hash>` as a last resort, hashed from the element's position in the hierarchy
    ///
    /// `accessibilityLabel` is deliberately not a source: it is localized, so the same element would
    /// report a different identifier per language, and it can carry personal data.
    ///
    /// When constructing a `ClickEvent` yourself, prefer a stable, human-readable string such as
    /// `"buy_button"` or `"settings_cell_notifications"`.
    ///
    /// Avoid dynamic values (e.g., cell index, timestamp) — they prevent meaningful grouping.
    public let elementId: String

    /// The class name or component type of the tapped element.
    ///
    /// Examples: `"UIButton"`, `"UITableViewCell"`, `"Button"` (SwiftUI).
    /// Use `String(describing: type(of: view))` to get the class name.
    /// Set to `nil` if not available.
    public let tagName: String?

    /// The semantic role describing what the element does.
    ///
    /// Autocapture emits one of these exact values, resolved from the view's class and then its
    /// accessibility traits (see `SemanticExtractor`). They are Title Case — match on them
    /// verbatim when building reports on `$attr-role`:
    ///
    /// `"Button"`, `"Link"`, `"Switch"`, `"Slider"`, `"Stepper"`, `"SegmentedControl"`,
    /// `"TextField"`, `"TextArea"`, `"SearchField"`, `"Text"`, `"Image"`, `"List"`, `"Grid"`,
    /// `"ScrollView"`, `"Header"`, `"TabBar"`, `"Adjustable"`.
    ///
    /// Set to `nil` if the element has no specific role. When constructing a `ClickEvent`
    /// yourself, prefer one of the values above so manual and autocaptured events group together.
    public let role: String?

    /// View hierarchy path from the tapped element up to 5 ancestor levels, `">"` separated.
    ///
    /// Example: `"UIButton > UIStackView > UITableViewCell > UITableView > UIView"`.
    /// Useful for identifying where in the view tree the click occurred.
    /// Set to `nil` if not available.
    public let elements: String?

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
    ///   - tagName: Class name of the tapped element (defaults to nil)
    ///   - role: Semantic role like `"button"`, `"switch"`, `"link"` (defaults to nil)
    ///   - elements: View hierarchy path, `">"` separated (defaults to nil)
    ///   - isInteractive: Whether the element is interactive (defaults to true)
    public init(
        x: CGFloat, y: CGFloat, elementId: String,
        tagName: String? = nil,
        role: String? = nil, elements: String? = nil,
        isInteractive: Bool = true
    ) {
        self.x = x
        self.y = y
        self.elementId = elementId
        self.tagName = tagName
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

        if let tagName = tagName {
            props["$el_tag_name"] = tagName
        }

        if let elements = elements {
            props["$elements"] = elements
        }

        if let role = role {
            props["$attr-role"] = role
        }

        return props
    }
}
#endif
