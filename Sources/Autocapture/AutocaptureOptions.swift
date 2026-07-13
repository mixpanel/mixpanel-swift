//
//  AutocaptureOptions.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

import Foundation
#if os(iOS)
  import UIKit
#endif

// MARK: - Internal Constants

/// Internal configuration constants not exposed in public API
enum AutocaptureDefaults {
  static let maxHierarchyDepth = 5
  static let maxRecursionDepth = 20

  #if os(iOS)
    /// UIKit controls with inherent visual feedback that should be excluded from
    /// dead click detection. These controls always produce a visible UI response
    /// (toggle animation, keyboard, wheel picker, etc.) that may not be captured
    /// by snapshot comparison.
    static let excludedControlTypes: [AnyClass] = [
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
    /// Checked by substring match on the view's class name when walking the hierarchy.
    static let swiftUIExcludedPatterns = [
      "Toggle",       // SwiftUI Toggle (switch)
      "Slider",       // SwiftUI Slider
      "Stepper",      // SwiftUI Stepper
      "TextField",    // SwiftUI TextField
      "TextEditor",   // SwiftUI TextEditor (multiline text)
      "SecureField",  // SwiftUI SecureField (password)
      "Picker",       // SwiftUI Picker
      "DatePicker",   // SwiftUI DatePicker
    ]

    /// Check if a single view is a SwiftUI view (class name contains "Hosting" or "SwiftUI").
    static func isSwiftUIView(_ view: UIView) -> Bool {
      let className = String(describing: type(of: view))
      return className.contains("Hosting") || className.contains("SwiftUI")
    }

    /// Check if a view is interactive (UIControl with targets, has enabled tap gesture recognizer,
    /// or is a SwiftUI view with button accessibility trait).
    static func isInteractive(_ view: UIView) -> Bool {
      // UIKit: UIControl with action targets
      if let control = view as? UIControl, !control.allTargets.isEmpty {
        return true
      }
      // UIKit: explicit tap gesture recognizer
      if let gestures = view.gestureRecognizers {
        for gesture in gestures where gesture.isEnabled {
          if gesture is UITapGestureRecognizer {
            return true
          }
        }
      }
      // Button accessibility trait indicates a clickable element.
      // SwiftUI renders buttons as internal views (e.g., _UIGraphicsView) without
      // UIKit gesture recognizers. The .button trait is set on the hit-test view
      // regardless of framework and reliably signals interactivity.
      // No framework gate needed — plain labels have .staticText, not .button.
      if view.accessibilityTraits.contains(.button) {
        return true
      }
      return false
    }
  #endif
}

// MARK: - Click Options

/// Configuration options for basic click event capture.
public struct ClickOptions {
  /// Whether click capture is enabled. Defaults to `true` when autocapture is enabled.
  public let enabled: Bool

  public init(enabled: Bool = true) {
    self.enabled = enabled
  }
}

// MARK: - Rage Click Options

/// Configuration options for rage click detection.
///
/// Rage clicks are detected when a user taps rapidly multiple times in the same area,
/// indicating frustration with an unresponsive element.
public struct RageClickOptions {
  /// Whether rage click detection is enabled. Defaults to `true`.
  public let enabled: Bool

  /// Number of clicks required to trigger a rage click event.
  /// Defaults to `4` (triggers on the 4th click within the time window).
  public let clickThreshold: Int

  /// Time window in milliseconds for rage click detection.
  /// Clicks must occur within this window to count as a rage click sequence.
  /// Defaults to `1000` (1 second).
  public let timeWindowMs: Int64

  /// Spatial threshold for rage click detection in points (pt).
  /// Clicks must be within this radius of each other to count as part of the same sequence.
  /// Defaults to `44` (matching iOS minimum tap target size).
  public let radius: CGFloat

  public init(
    enabled: Bool = true,
    clickThreshold: Int = 4,
    timeWindowMs: Int64 = 1000,
    radius: CGFloat = 44
  ) {
    self.enabled = enabled
    self.clickThreshold = clickThreshold
    self.timeWindowMs = timeWindowMs
    self.radius = radius
  }
}

// MARK: - Dead Click Options

/// Configuration options for dead click detection.
///
/// Dead clicks are detected when a user taps on an interactive element
/// but no visible UI change occurs, indicating a broken or unresponsive element.
public struct DeadClickOptions {
  /// Whether dead click detection is enabled. Defaults to `true`.
  public let enabled: Bool

  /// Timeout in milliseconds to wait for UI response after a click.
  /// If no UI change is detected within this window, a dead click is recorded.
  /// Defaults to `500` (0.5 seconds).
  public let timeoutMs: Int

  public init(
    enabled: Bool = true,
    timeoutMs: Int = 500
  ) {
    self.enabled = enabled
    self.timeoutMs = timeoutMs
  }
}

// MARK: - Autocapture Options

/// Configuration options for automatic event capture (clicks, rage clicks, dead clicks).
///
/// Autocapture is **disabled by default** and must be explicitly enabled by providing
/// `AutocaptureOptions` during SDK initialization.
///
/// **Example - Enable with defaults:**
/// ```swift
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     autocaptureOptions: AutocaptureOptions()
/// )
/// ```
///
/// **Example - Custom configuration:**
/// ```swift
/// let autocaptureOpts = AutocaptureOptions(
///     clickOptions: ClickOptions(enabled: true),
///     rageClickOptions: RageClickOptions(
///         enabled: true,
///         clickThreshold: 5,        // Require 5 clicks instead of 4
///         timeWindowMs: 800         // Shorter time window
///     ),
///     deadClickOptions: DeadClickOptions(
///         enabled: false            // Disable dead click detection
///     )
/// )
///
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     autocaptureOptions: autocaptureOpts
/// )
/// ```
public struct AutocaptureOptions {
  /// Configuration for basic click capture.
  public let clickOptions: ClickOptions

  /// Configuration for rage click detection.
  public let rageClickOptions: RageClickOptions

  /// Configuration for dead click detection.
  public let deadClickOptions: DeadClickOptions

  /// Returns `true` if any autocapture feature is enabled.
  public var isEnabled: Bool {
    return clickOptions.enabled || rageClickOptions.enabled || deadClickOptions.enabled
  }

  public init(
    clickOptions: ClickOptions = ClickOptions(),
    rageClickOptions: RageClickOptions = RageClickOptions(),
    deadClickOptions: DeadClickOptions = DeadClickOptions()
  ) {
    self.clickOptions = clickOptions
    self.rageClickOptions = rageClickOptions
    self.deadClickOptions = deadClickOptions
  }
}
