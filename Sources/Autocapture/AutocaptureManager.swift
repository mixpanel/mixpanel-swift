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
    // MARK: - Event Names

    private enum EventName {
      static let click = "$mp_click"
      static let rageClick = "$mp_rage_click"
      static let deadClick = "$mp_dead_click"
    }

    // MARK: - Configuration

    private let options: AutocaptureOptions

    // MARK: - Components

    private let semanticExtractor: SemanticExtractor
    private let rageClickTracker: RageClickTracker?
    private let deadClickDetector: DeadClickDetector?

    // MARK: - Event Callback

    /// Callback to track events via MixpanelInstance.
    /// This is `var` to allow test injection of event capture.
    /// Thread-safe: reads and writes are synchronized via `lock`.
    private var _trackEvent: (String, Properties) -> Void
    var trackEvent: (String, Properties) -> Void {
      get { lock.lock(); defer { lock.unlock() }; return _trackEvent }
      set { lock.lock(); defer { lock.unlock() }; _trackEvent = newValue }
    }

    // MARK: - State

    private var isStarted = false
    private let lock = NSLock()

    // MARK: - Initialization

    /// Create an AutocaptureManager with the given options.
    ///
    /// - Parameters:
    ///   - options: Autocapture configuration options
    ///   - trackEvent: Callback to send events to Mixpanel
    init(
      options: AutocaptureOptions,
      trackEvent: @escaping (String, Properties) -> Void
    ) {
      self.options = options
      self._trackEvent = trackEvent

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
          self?.emitDeadClickEvent(event)
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
      TouchInterceptor.shared.install(manager: self)

      MixpanelLogger.info(message: "AutocaptureManager: started")
    }

    /// Stop autocapture and clean up.
    func stop() {
      lock.lock()
      defer { lock.unlock() }

      guard isStarted else { return }

      isStarted = false

      // Uninstall touch interceptor
      TouchInterceptor.shared.uninstall()

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
        return
      }

      // Extract semantic information
      var clickEvent = semanticExtractor.extractSemantics(from: view, at: point)

      // Check for rage click
      var rageClickResult: RageClickResult?
      if let tracker = rageClickTracker {
        rageClickResult = tracker.trackClick(x: point.x, y: point.y)

        // Update event with rage click info
        if rageClickResult?.isRageClick == true {
          clickEvent = ClickEvent(
            x: clickEvent.x,
            y: clickEvent.y,
            elementId: clickEvent.elementId,
            tagName: clickEvent.tagName,
            ariaLabel: clickEvent.ariaLabel,
            role: clickEvent.role,
            elements: clickEvent.elements,
            isRageClick: true,
            tapCount: rageClickResult?.tapCount ?? 1,
            isInteractive: clickEvent.isInteractive
          )
        }
      }

      // Emit click event
      if options.clickOptions.enabled {
        emitClickEvent(clickEvent)
      }

      // Emit rage click event (independent of regular click)
      if options.rageClickOptions.enabled, rageClickResult?.isRageClick == true {
        emitRageClickEvent(clickEvent)
      }

      // Start dead click monitoring
      if let detector = deadClickDetector, let window = window {
        detector.startMonitoring(event: clickEvent, view: view, in: window)
      }
    }

    // MARK: - Event Emission

    private func emitClickEvent(_ event: ClickEvent) {
      let properties = event.toProperties()
      trackEvent(EventName.click, properties)
      MixpanelLogger.debug(
        message: "AutocaptureManager: emitted \(EventName.click) for \(event.elementId)")
    }

    private func emitRageClickEvent(_ event: ClickEvent) {
      var properties = event.toProperties()
      properties["$tap_count"] = event.tapCount
      trackEvent(EventName.rageClick, properties)
      MixpanelLogger.debug(
        message:
          "AutocaptureManager: emitted \(EventName.rageClick) for \(event.elementId) (count: \(event.tapCount))"
      )
    }

    private func emitDeadClickEvent(_ event: ClickEvent) {
      let properties = event.toProperties()
      trackEvent(EventName.deadClick, properties)
      MixpanelLogger.debug(
        message: "AutocaptureManager: emitted \(EventName.deadClick) for \(event.elementId)")
    }
  }
#endif
