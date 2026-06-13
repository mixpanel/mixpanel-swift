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
  /// 1. Capturing a baseline UI snapshot shortly after the click (150ms default)
  /// 2. Waiting for the timeout period (500ms default)
  /// 3. Comparing the final state to the baseline
  /// 4. If no change detected, emitting a dead click event
  final class DeadClickDetector {
    // MARK: - Configuration

    private let timeoutMs: Int
    private let baselineDelayMs: Int

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
      let view: UIView
      let baselineSnapshot: UISnapshot?
      let startTime: Date
    }

    // MARK: - Excluded Controls

    /// Controls that should be excluded from dead click detection because
    /// they have inherent visual feedback or side effects not detected by UI snapshots.
    private static let excludedControlTypes: [AnyClass] = [
      UISwitch.self,
      UITextField.self,
      UITextView.self,
      UIStepper.self,
      UISegmentedControl.self,
      UIDatePicker.self,
      UIPickerView.self,
    ]

    // MARK: - Initialization

    init(options: DeadClickOptions) {
      self.timeoutMs = options.timeoutMs
      self.baselineDelayMs = options.baselineDelayMs
    }

    // MARK: - Public API

    /// Check if a view should be excluded from dead click monitoring.
    ///
    /// Returns true for controls that have inherent feedback (keyboard, state changes)
    /// that may not be detected by UI snapshot comparison.
    func shouldExclude(view: UIView) -> Bool {
      for controlType in Self.excludedControlTypes {
        if view.isKind(of: controlType) {
          return true
        }
      }
      return false
    }

    /// Check if a view has tap/interaction handlers attached.
    ///
    /// Only views with actual handlers should be monitored for dead clicks,
    /// as tapping a non-interactive view is expected to do nothing.
    func hasInteractionHandlers(view: UIView) -> Bool {
      // Check for tap gesture recognizers on the view itself
      if let gestures = view.gestureRecognizers {
        for gesture in gestures where gesture.isEnabled {
          if gesture is UITapGestureRecognizer {
            return true
          }
        }
      }

      // Check if UIControl has targets (buttons, etc.)
      if let control = view as? UIControl {
        if !control.allTargets.isEmpty {
          return true
        }
      }

      // Check ancestors for gesture recognizers that might handle this tap
      var ancestor = view.superview
      var depth = 0
      let maxDepth = 5

      while let current = ancestor, depth < maxDepth {
        if let gestures = current.gestureRecognizers {
          for gesture in gestures where gesture.isEnabled {
            if gesture is UITapGestureRecognizer {
              return true
            }
          }
        }

        // Check if ancestor is a UIControl with targets
        if let control = current as? UIControl, !control.allTargets.isEmpty {
          return true
        }

        ancestor = current.superview
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
      // Skip excluded elements
      guard !shouldExclude(view: view) else {
        MixpanelLogger.debug(
          message: "DeadClickDetector: excluded element \(event.elementId)")
        return
      }

      // Only monitor elements with interaction handlers
      guard hasInteractionHandlers(view: view) else {
        MixpanelLogger.debug(
          message: "DeadClickDetector: no handlers on \(event.elementId)")
        return
      }

      lock.lock()
      currentWindow = window
      pendingCheck = PendingCheck(
        event: event,
        view: view,
        baselineSnapshot: nil,
        startTime: Date()
      )
      lock.unlock()

      // Schedule baseline capture
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(baselineDelayMs)) {
        [weak self] in
        self?.captureBaseline()
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

    private func captureBaseline() {
      lock.lock()
      guard var check = pendingCheck, let window = currentWindow else {
        lock.unlock()
        return
      }

      let baseline = captureSnapshot(window: window)
      check = PendingCheck(
        event: check.event,
        view: check.view,
        baselineSnapshot: baseline,
        startTime: check.startTime
      )
      pendingCheck = check
      lock.unlock()

      // Schedule final check
      let remainingDelay = timeoutMs - baselineDelayMs
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(remainingDelay)) {
        [weak self] in
        self?.performFinalCheck()
      }
    }

    private func performFinalCheck() {
      lock.lock()
      guard let check = pendingCheck,
        let baseline = check.baselineSnapshot,
        let window = currentWindow
      else {
        pendingCheck = nil
        lock.unlock()
        return
      }
      pendingCheck = nil
      lock.unlock()

      let current = captureSnapshot(window: window)

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
      var contentHash = 0

      // Count visible windows (handles alerts, sheets, etc.)
      let windowCount =
        UIApplication.shared.windows.filter { $0.isKeyWindow || !$0.isHidden }.count

      // Walk view hierarchy
      func processView(_ view: UIView) {
        guard !view.isHidden, view.alpha > 0 else { return }

        viewCount += 1

        // Hash content for change detection
        var hasher = Hasher()
        hasher.combine(String(describing: type(of: view)))

        if let label = view as? UILabel {
          hasher.combine(label.text)
        }
        if let button = view as? UIButton {
          hasher.combine(button.currentTitle)
        }
        if let switchView = view as? UISwitch {
          hasher.combine(switchView.isOn)
        }
        if let control = view as? UIControl {
          hasher.combine(control.isEnabled)
        }

        hasher.combine(view.isHidden)
        hasher.combine(view.alpha > 0)

        contentHash ^= hasher.finalize()

        for subview in view.subviews {
          processView(subview)
        }
      }

      if let rootView = window.rootViewController?.view {
        processView(rootView)
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
