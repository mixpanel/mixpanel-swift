//
//  TouchInterceptor.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import ObjectiveC
  import UIKit

  /// Intercepts touch events using a global gesture recognizer approach.
  ///
  /// This captures touches on ALL windows by adding a gesture recognizer that
  /// observes but never claims touch events.
  final class TouchInterceptor: NSObject, UIGestureRecognizerDelegate {
    // MARK: - Singleton

    static let shared = TouchInterceptor()

    // MARK: - State

    private var isInstalled = false
    private weak var manager: AutocaptureManager?
    private let lock = NSLock()
    private var observedWindows = NSHashTable<UIWindow>.weakObjects()

    // MARK: - Initialization

    private override init() {
      super.init()
      // Observe for new windows
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowDidBecomeVisible(_:)),
        name: UIWindow.didBecomeVisibleNotification,
        object: nil
      )
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Install the touch interceptor.
    ///
    /// - Parameter manager: The AutocaptureManager to delegate touch events to
    func install(manager: AutocaptureManager) {
      MixpanelLogger.debug(message: "TouchInterceptor: install() called, isInstalled=\(isInstalled)")

      // Ensure installation happens on main thread
      if !Thread.isMainThread {
        MixpanelLogger.debug(message: "TouchInterceptor: dispatching to main thread")
        DispatchQueue.main.async { [weak self] in
          self?.performInstall(manager: manager)
        }
        return
      }

      performInstall(manager: manager)
    }

    private func performInstall(manager: AutocaptureManager) {
      lock.lock()
      defer { lock.unlock() }

      guard !isInstalled else {
        self.manager = manager
        MixpanelLogger.debug(message: "TouchInterceptor: already installed, updated manager reference")
        return
      }

      self.manager = manager
      isInstalled = true

      // Add gesture recognizer to all existing windows
      // Use selector-based approach to avoid app extension issues
      let sharedSelector = NSSelectorFromString("sharedApplication")
      guard UIApplication.responds(to: sharedSelector),
            let application = UIApplication.perform(sharedSelector)?.takeUnretainedValue() as? UIApplication
      else {
        MixpanelLogger.info(message: "TouchInterceptor: not running in app context, skipping window observation")
        return
      }

      for window in application.windows {
        addGestureRecognizer(to: window)
      }

      // Also check connected scenes for windows (iOS 13+)
      if #available(iOS 13.0, *) {
        for scene in application.connectedScenes {
          if let windowScene = scene as? UIWindowScene {
            for window in windowScene.windows {
              addGestureRecognizer(to: window)
            }
          }
        }
      }

      MixpanelLogger.info(message: "TouchInterceptor: installed successfully, observing \(observedWindows.count) windows")
    }

    /// Uninstall the touch interceptor.
    func uninstall() {
      lock.lock()
      defer { lock.unlock() }
      manager = nil
      for window in observedWindows.allObjects {
        window.gestureRecognizers?.removeAll { $0 is TouchObservingGestureRecognizer }
      }
      observedWindows.removeAllObjects()
      isInstalled = false
      MixpanelLogger.info(message: "TouchInterceptor: uninstalled")
    }

    // MARK: - Window Observation

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
      guard let window = notification.object as? UIWindow else { return }
      MixpanelLogger.debug(message: "TouchInterceptor: window became visible")
      DispatchQueue.main.async { [weak self] in
        self?.addGestureRecognizer(to: window)
      }
    }

    private func addGestureRecognizer(to window: UIWindow) {
      guard !observedWindows.contains(window) else { return }

      // Add only our custom observing recognizer (not duplicate tap recognizer)
      let observingRecognizer = TouchObservingGestureRecognizer(target: self, action: #selector(handleTouchGesture(_:)))
      observingRecognizer.delegate = self
      observingRecognizer.cancelsTouchesInView = false
      observingRecognizer.delaysTouchesEnded = false
      observingRecognizer.delaysTouchesBegan = false

      window.addGestureRecognizer(observingRecognizer)
      observedWindows.add(window)

      MixpanelLogger.debug(message: "TouchInterceptor: added gesture recognizer to window")
    }

    // MARK: - Gesture Handling

    /// Required by UIGestureRecognizer(target:action:) — never called because
    /// TouchObservingGestureRecognizer handles touches via touchesBegan/touchesEnded
    /// overrides and always transitions to .failed state.
    @objc private func handleTouchGesture(_ gesture: TouchObservingGestureRecognizer) {
    }

    /// Called by the gesture recognizer when a touch ends
    func processTouchEnded(at location: CGPoint, view: UIView?, window: UIWindow) {
      MixpanelLogger.debug(message: "TouchInterceptor: touch ended at \(location)")

      guard let manager = manager else {
        MixpanelLogger.debug(message: "TouchInterceptor: manager is nil")
        return
      }

      manager.handleTouch(at: location, view: view, window: window)
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      return true  // Allow all other gesture recognizers to work
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldReceive touch: UITouch
    ) -> Bool {
      return true  // Receive all touches
    }
  }

  // MARK: - Custom Gesture Recognizer

  /// A gesture recognizer that observes touches without claiming them.
  private class TouchObservingGestureRecognizer: UIGestureRecognizer {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
      // Don't change state - we're just observing
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
      // Don't change state - we're just observing
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
      // Only process single-finger taps to avoid duplicate events from multi-touch
      guard touches.count == 1, let touch = touches.first else {
        state = .failed
        return
      }

      guard let window = self.view as? UIWindow else {
        state = .failed
        return
      }

      let location = touch.location(in: window)
      let view = touch.view

      TouchInterceptor.shared.processTouchEnded(at: location, view: view, window: window)

      // Transition to failed state to let the gesture system continue
      // We're observing only, not claiming the touch
      state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
      state = .cancelled
    }

    override func reset() {
      super.reset()
      // Reset state for next touch sequence
      state = .possible
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false  // Never prevent other gesture recognizers
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false  // Cannot be prevented by other gesture recognizers
    }

    override func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false  // Don't require others to fail
    }

    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false  // Don't need to fail for others
    }
  }
#endif
