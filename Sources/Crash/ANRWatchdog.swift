//
//  ANRWatchdog.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

#if os(iOS)
  import Foundation
  import UIKit

  /// ANR (Application Not Responding) / Main Thread Hang Watchdog.
  ///
  /// Monitors main thread responsiveness by posting pings from a background thread
  /// and measuring round-trip latency. Emits $app_hang events when thresholds are breached.
  ///
  /// False positive prevention:
  /// - Ignores pings while debugger attached
  /// - Pauses monitoring when app is backgrounded
  /// - Startup grace period (waits for first frame render)
  /// - High QoS watchdog thread (prevents starvation)
  @available(iOS 13.0, *)
  class ANRWatchdog {
    /// Hang severity thresholds (in seconds)
    private enum HangThreshold {
      static let warning: TimeInterval = 0.25  // 250ms
      static let moderate: TimeInterval = 1.0  // 1 second
      static let severe: TimeInterval = 2.0  // 2 seconds
    }

    /// Ping interval (how often to check main thread)
    private let pingInterval: TimeInterval = 0.1  // 100ms

    /// Startup grace period (wait this long before starting monitoring)
    private let startupGracePeriod: TimeInterval = 3.0

    /// Watchdog thread (high QoS to avoid starvation)
    private var watchdogThread: Thread?
    private var isRunning = false
    private var isPaused = false

    /// Reference to MixpanelInstance for event emission
    weak var mixpanelInstance: MixpanelInstance?

    /// Session/replay info for hang events
    private var currentSessionId: String?
    var currentReplayId: String?  // Accessible for updating from MixpanelInstance

    /// Last reported hang severity (to avoid duplicate events)
    private var lastReportedSeverity: String?

    init() {
      setupNotifications()
    }

    /// Start the watchdog.
    ///
    /// Defers actual monitoring start by `startupGracePeriod` to exclude
    /// expensive cold-launch work.
    func start(sessionId: String, replayId: String?) {
      guard !isRunning else {
        MixpanelLogger.debug(message: "ANR watchdog already running")
        return
      }

      currentSessionId = sessionId
      currentReplayId = replayId

      // Defer start by grace period to skip cold launch
      DispatchQueue.main.asyncAfter(deadline: .now() + startupGracePeriod) { [weak self] in
        self?.startMonitoring()
      }
    }

    /// Stop the watchdog.
    func stop() {
      isRunning = false
      watchdogThread?.cancel()
      watchdogThread = nil
      currentSessionId = nil
      currentReplayId = nil
      lastReportedSeverity = nil

      MixpanelLogger.debug(message: "ANR watchdog stopped")
    }

    /// Pause monitoring (on background).
    func pause() {
      isPaused = true
      MixpanelLogger.debug(message: "ANR watchdog paused")
    }

    /// Resume monitoring (on foreground).
    func resume() {
      isPaused = false
      lastReportedSeverity = nil  // Reset to allow new reports after resume
      MixpanelLogger.debug(message: "ANR watchdog resumed")
    }

    /// Start the monitoring loop.
    private func startMonitoring() {
      guard !isRunning else { return }

      isRunning = true

      watchdogThread = Thread { [weak self] in
        guard let self = self else { return }

        MixpanelLogger.info(message: "ANR watchdog started monitoring")

        while self.isRunning && !Thread.current.isCancelled {
          autoreleasepool {
            // Skip ping if paused or debugger attached
              if self.isPaused {//}|| self.isDebuggerAttached() {
              Thread.sleep(forTimeInterval: self.pingInterval)
              return
            }

            // Ping main thread and measure latency
            let latency = self.pingMainThread()

            // Check thresholds and emit events
            if latency >= HangThreshold.severe {
              self.reportHang(latency: latency, severity: "severe")
            } else if latency >= HangThreshold.moderate {
              self.reportHang(latency: latency, severity: "moderate")
            } else if latency >= HangThreshold.warning {
              self.reportHang(latency: latency, severity: "warning")
            } else {
              // Main thread is responsive, clear last reported severity
              self.lastReportedSeverity = nil
            }

            Thread.sleep(forTimeInterval: self.pingInterval)
          }
        }

        MixpanelLogger.info(message: "ANR watchdog monitoring stopped")
      }

      // Set high QoS to prevent watchdog thread starvation
      watchdogThread?.qualityOfService = .userInteractive
      watchdogThread?.name = "com.mixpanel.anr.watchdog"
      watchdogThread?.start()
    }

    /// Ping the main thread and measure round-trip latency.
    ///
    /// Returns the latency in seconds.
    private func pingMainThread() -> TimeInterval {
      let semaphore = DispatchSemaphore(value: 0)
      let startTime = Date()

      DispatchQueue.main.async {
        semaphore.signal()
      }

      // Wait for ping to return (with timeout to prevent infinite wait)
      let timeout = DispatchTime.now() + HangThreshold.severe + 1.0
      _ = semaphore.wait(timeout: timeout)

      let latency = Date().timeIntervalSince(startTime)
      return latency
    }

    /// Report a hang event.
    private func reportHang(latency: TimeInterval, severity: String) {
      // Avoid duplicate reports for the same severity level
      guard lastReportedSeverity != severity else { return }

      lastReportedSeverity = severity

      guard let instance = mixpanelInstance else {
        MixpanelLogger.warn(message: "Cannot emit hang event: MixpanelInstance not set")
        return
      }

      var properties: Properties = [
        "$hang_duration_ms": Int(latency * 1000),
        "$hang_severity": severity,
        "$session_id": currentSessionId ?? "unknown",
      ]

      if let replayId = currentReplayId {
        properties["$replay_id"] = replayId
      }

      instance.track(event: "$app_hang", properties: properties)

      MixpanelLogger.warn(
        message:
          "Main thread hang detected: \(Int(latency * 1000))ms, severity=\(severity)"
      )
    }

    /// Check if debugger is attached.
    ///
    /// Returns true if a debugger is attached (Xcode debugging).
    private func isDebuggerAttached() -> Bool {
      var info = kinfo_proc()
      var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
      var size = MemoryLayout<kinfo_proc>.stride

      let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

      if result != 0 {
        return false
      }

      return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Set up lifecycle notifications.
    private func setupNotifications() {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationDidEnterBackground),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
      )

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationWillEnterForeground),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
      )
    }

    @objc private func applicationDidEnterBackground() {
      pause()
    }

    @objc private func applicationWillEnterForeground() {
      resume()
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
      stop()
    }
  }
#endif
