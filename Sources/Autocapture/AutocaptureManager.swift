//
//  AutocaptureManager.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import UIKit

  /// Main coordinator for autocapture functionality.
  ///
  /// Manages lifecycle, coordinates components, and dispatches events to Mixpanel.
  final class AutocaptureManager {
    // MARK: - Configuration

    private let options: AutocaptureOptions

    // MARK: - Components

    private let semanticExtractor: SemanticExtractor
    private let rageClickTracker: RageClickTracker?
    private let deadClickDetector: DeadClickDetector?
    private let touchInterceptor = TouchInterceptor()

    // MARK: - Autocapture Reference

    /// Reference to the Autocapture instance for event tracking.
    /// Weak to avoid retain cycles with MixpanelInstance.
    private weak var autocapture: Autocapture?

    // MARK: - State

    private var isStarted = false
    private let lock = NSLock()

    // MARK: - Initialization

    /// Create an AutocaptureManager with the given options.
    ///
    /// - Parameters:
    ///   - options: Autocapture configuration options
    ///   - autocapture: The Autocapture instance for event tracking
    init(
      options: AutocaptureOptions,
      autocapture: Autocapture
    ) {
      self.options = options
      self.autocapture = autocapture

      // Initialize components
      self.semanticExtractor = SemanticExtractor()

      // Initialize rage click tracker if enabled
      if options.rageClickOptions.enabled {
        self.rageClickTracker = RageClickTracker(options: options.rageClickOptions)
      } else {
        self.rageClickTracker = nil
      }

      // Initialize dead click detector if enabled
      if options.deadClickOptions.enabled {
        self.deadClickDetector = DeadClickDetector(options: options.deadClickOptions)
        self.deadClickDetector?.onDeadClick = { [weak self] event in
          self?.autocapture?.trackDeadClick(event)
          MixpanelLogger.debug(
            message: "AutocaptureManager: emitted $mp_dead_click for \(event.elementId)")
        }
      } else {
        self.deadClickDetector = nil
      }

      MixpanelLogger.info(
        message:
          "AutocaptureManager: initialized (click=\(options.clickOptions.enabled), rage=\(options.rageClickOptions.enabled), dead=\(options.deadClickOptions.enabled))"
      )
    }

    // MARK: - Lifecycle

    /// Start autocapture by installing the touch interceptor.
    func start() {
      lock.lock()
      defer { lock.unlock() }

      guard !isStarted else {
        MixpanelLogger.debug(message: "AutocaptureManager: already started")
        return
      }

      isStarted = true

      // Install touch interceptor
      touchInterceptor.install(manager: self)

      MixpanelLogger.info(message: "AutocaptureManager: started")
    }

    /// Stop autocapture and clean up.
    func stop() {
      lock.lock()
      defer { lock.unlock() }

      guard isStarted else { return }

      isStarted = false

      // Uninstall touch interceptor
      touchInterceptor.uninstall()

      // Reset components
      rageClickTracker?.reset()
      deadClickDetector?.cancelPendingCheck()

      MixpanelLogger.info(message: "AutocaptureManager: stopped")
    }

    /// Signals that a UI change occurred.
    ///
    /// Call this when a UI change happens that the dead click detector cannot observe,
    /// such as navigation in React Native or other framework-driven UI changes.
    /// This cancels any pending dead click detection to prevent false positives.
    func signalUIChange() {
      deadClickDetector?.cancelPendingCheck()
      rageClickTracker?.reset()
      MixpanelLogger.debug(message: "AutocaptureManager: UI change signaled, cancelled pending detections")
    }

    // MARK: - Touch Handling

    /// Handle a touch event from the interceptor.
    ///
    /// Called by TouchInterceptor when a touch ends.
    func handleTouch(at point: CGPoint, view: UIView?, window: UIWindow?) {
      do {
        try processTouch(at: point, view: view, window: window)
      } catch {
        MixpanelLogger.error(message: "AutocaptureManager: error processing touch: \(error)")
        // Never rethrow - silently fail and let the app continue
      }
    }

    private func processTouch(at point: CGPoint, view: UIView?, window: UIWindow?) throws {
      guard let view = view else {
        MixpanelLogger.debug(message: "AutocaptureManager: no view for touch at \(point)")
        return
      }

      // Extract semantic information
      let clickEvent = semanticExtractor.extractSemantics(from: view, at: point)

      // Check for rage click
      let rageClickResult = rageClickTracker?.trackClick(x: point.x, y: point.y)

      // Emit click event
      if options.clickOptions.enabled {
        autocapture?.trackClick(clickEvent)
        MixpanelLogger.debug(
          message: "AutocaptureManager: emitted $mp_click for \(clickEvent.elementId)")
      }

      // Emit rage click event (independent of regular click)
      if options.rageClickOptions.enabled, rageClickResult?.isRageClick == true {
        autocapture?.trackRageClick(clickEvent)
        MixpanelLogger.debug(
          message: "AutocaptureManager: emitted $mp_rage_click for \(clickEvent.elementId)")
      }

      // Start dead click monitoring
      if let detector = deadClickDetector, let window = window {
        detector.startMonitoring(event: clickEvent, view: view, in: window)
      }
    }

  }
#endif
