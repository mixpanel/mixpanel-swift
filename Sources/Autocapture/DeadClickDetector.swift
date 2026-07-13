//
//  DeadClickDetector.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import UIKit

  /// Detects clicks on interactive elements that produce no visible UI response.
  ///
  /// Dead clicks indicate broken or unresponsive UI elements. Detection works by:
  /// 1. Capturing a baseline UI snapshot synchronously at click time
  /// 2. Waiting for the timeout period (500ms default)
  /// 3. Comparing the final state to the baseline
  /// 4. If no change detected, emitting a dead click event
  final class DeadClickDetector {
    // MARK: - Configuration

    private let timeoutMs: Int

    // MARK: - Callback

    /// Called when a dead click is detected
    var onDeadClick: ((ClickEvent) -> Void)?

    // MARK: - State

    private var pendingCheck: PendingCheck?
    private weak var currentWindow: UIWindow?
    private let lock = NSLock()

    // MARK: - Types

    private struct UISnapshot {
      let viewCount: Int
      let contentHash: Int
      let windowCount: Int
    }

    private struct PendingCheck {
      let event: ClickEvent
      let baselineSnapshot: UISnapshot
      let startTime: Date
    }

    // MARK: - Initialization

    init(options: DeadClickOptions) {
      self.timeoutMs = options.timeoutMs
    }

    // MARK: - Public API

    /// Check if a view should be excluded from dead click monitoring.
    ///
    /// Returns true for controls that have inherent feedback (keyboard, state changes)
    /// that may not be detected by UI snapshot comparison.
    ///
    /// This method walks up the view hierarchy to catch cases where the touch hits
    /// a subview of an excluded control (e.g., the thumb of a UISwitch).
    func shouldExclude(view: UIView) -> Bool {
      var currentView: UIView? = view
      var depth = 0
      let maxDepth = 10

      while let v = currentView, depth < maxDepth {
        // Check UIKit control types
        for controlType in AutocaptureDefaults.excludedControlTypes {
          if v.isKind(of: controlType) {
            return true
          }
        }

        // Check SwiftUI patterns by class name
        let className = String(describing: type(of: v))
        for pattern in AutocaptureDefaults.swiftUIExcludedPatterns {
          if className.contains(pattern) {
            return true
          }
        }

        // Also check accessibility traits for adjustable (sliders, steppers)
        if v.accessibilityTraits.contains(.adjustable) {
          return true
        }

        currentView = v.superview
        depth += 1
      }

      return false
    }

    /// Start monitoring for dead click after a tap.
    ///
    /// - Parameters:
    ///   - event: The click event to monitor
    ///   - view: The view that was tapped
    ///   - window: The window containing the view
    func startMonitoring(event: ClickEvent, view: UIView, in window: UIWindow) {
      // Only monitor interactive elements — tapping a non-interactive view
      // (plain label, image without gesture) is expected to do nothing.
      guard event.isInteractive else {
        MixpanelLogger.debug(
          message: "DeadClickDetector: non-interactive element \(event.elementId)")
        return
      }

      // Skip excluded elements (controls with inherent feedback like toggles, text fields)
      guard !shouldExclude(view: view) else {
        MixpanelLogger.debug(
          message: "DeadClickDetector: excluded element \(event.elementId)")
        return
      }

      // Capture baseline synchronously at click time — before the click handler
      // has a chance to update the UI. This prevents fast UI responses (e.g.,
      // showing a UIAlertController) from being absorbed into the baseline,
      // which would cause false positive dead clicks.
      let baseline = captureSnapshot(window: window)

      lock.lock()
      currentWindow = window
      pendingCheck = PendingCheck(
        event: event,
        baselineSnapshot: baseline,
        startTime: Date()
      )
      lock.unlock()

      // Schedule final check at full timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
        [weak self] in
        self?.performFinalCheck()
      }
    }

    /// Cancel any pending dead click check.
    ///
    /// Call this when the user navigates away or the app backgrounds.
    func cancelPendingCheck() {
      lock.lock()
      pendingCheck = nil
      lock.unlock()
    }

    // MARK: - Private

    private func performFinalCheck() {
      lock.lock()
      guard let check = pendingCheck, let window = currentWindow else {
        pendingCheck = nil
        lock.unlock()
        return
      }
      pendingCheck = nil
      lock.unlock()

      let current = captureSnapshot(window: window)
      let baseline = check.baselineSnapshot

      // Compare snapshots
      let hasChanges = hasUIChanges(baseline: baseline, current: current)

      if !hasChanges {
        // Dead click detected
        MixpanelLogger.debug(message: "DeadClickDetector: dead click on \(check.event.elementId)")
        onDeadClick?(check.event)
      }
    }

    // MARK: - Snapshot

    private func captureSnapshot(window: UIWindow) -> UISnapshot {
      var viewCount = 0
      var contentHash = 17

      // Count visible windows (handles alerts, sheets, etc.)
      // Use windowScene.windows for iOS 13+, fallback to just counting this window
      let windowCount: Int
      if #available(iOS 13.0, *) {
        if let scene = window.windowScene {
          windowCount = scene.windows.filter { $0.isKeyWindow || !$0.isHidden }.count
        } else {
          windowCount = 1
        }
      } else {
        windowCount = 1  // Fallback for older iOS
      }

      // Walk view hierarchy
      func processView(_ view: UIView, depth: Int = 0) {
        guard !view.isHidden, view.alpha > 0, depth < AutocaptureDefaults.maxRecursionDepth else { return }

        viewCount += 1

        // Position and size
        let frame = view.frame
        contentHash = 31 &* contentHash &+ Int(frame.origin.x)
        contentHash = 31 &* contentHash &+ Int(frame.origin.y)
        contentHash = 31 &* contentHash &+ Int(frame.size.width)
        contentHash = 31 &* contentHash &+ Int(frame.size.height)

        // Class name
        contentHash = 31 &* contentHash &+ String(describing: type(of: view)).hashValue

        // Text content
        if let label = view as? UILabel {
          contentHash = 31 &* contentHash &+ (label.text?.hashValue ?? 0)
        }
        if let button = view as? UIButton {
          contentHash = 31 &* contentHash &+ (button.currentTitle?.hashValue ?? 0)
        }

        // Control state
        if let switchView = view as? UISwitch {
          contentHash = 31 &* contentHash &+ switchView.isOn.hashValue
        }
        if let control = view as? UIControl {
          contentHash = 31 &* contentHash &+ control.isEnabled.hashValue
        }

        for subview in view.subviews {
          processView(subview, depth: depth + 1)
        }
      }

      // Walk the window's entire view hierarchy — not just rootViewController.view.
      // Presented view controllers (alerts, action sheets, popovers) are added as
      // direct subviews of the window via _UITransitionView, not as children of the
      // root view controller's view. Walking from the window catches all of them.
      for subview in window.subviews {
        processView(subview)
      }

      return UISnapshot(
        viewCount: viewCount,
        contentHash: contentHash,
        windowCount: windowCount
      )
    }

    private func hasUIChanges(baseline: UISnapshot, current: UISnapshot) -> Bool {
      // Check view count change
      if baseline.viewCount != current.viewCount {
        return true
      }

      // Check content hash change
      if baseline.contentHash != current.contentHash {
        return true
      }

      // Check window count change (new alerts, sheets, etc.)
      if baseline.windowCount != current.windowCount {
        return true
      }

      return false
    }
  }
#endif
