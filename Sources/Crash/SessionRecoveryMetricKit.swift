//
//  SessionRecoveryMetricKit.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

#if os(iOS)
  import Foundation
  import UIKit
  import MetricKit

  /// MetricKit integration for SessionRecoveryManager.
  ///
  /// Receives crash and hang diagnostics from MetricKit (iOS 14+) and correlates them
  /// with pending unexpected exits to upgrade $unexpected_exit to $crash events.
  @available(iOS 14.0, *)
  extension SessionRecoveryManager: MXMetricManagerSubscriber {

    /// Register with MetricKit to receive diagnostics.
    ///
    /// Should be called early in app lifecycle to ensure live delivery isn't missed.
    func registerMetricKitSubscriber() {
      MXMetricManager.shared.add(self)
      MixpanelLogger.info(message: "Registered MetricKit subscriber for crash diagnostics")
    }

    /// Unregister from MetricKit.
    func unregisterMetricKitSubscriber() {
      MXMetricManager.shared.remove(self)
      MixpanelLogger.info(message: "Unregistered MetricKit subscriber")
    }

    /// Receive diagnostic payloads from MetricKit.
    ///
    /// Called by MetricKit when diagnostics are available (timing controlled by OS).
    /// May contain multiple crash/hang diagnostics, potentially from multiple sessions.
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
      metricsQueue.async { [weak self] in
        guard let self = self else { return }

        MixpanelLogger.info(message: "Received \(payloads.count) MetricKit diagnostic payload(s)")

        for payload in payloads {
          self.processMetricKitPayload(payload)
        }
      }
    }

    /// Process a single MetricKit diagnostic payload.
    private func processMetricKitPayload(_ payload: MXDiagnosticPayload) {
      let timeWindow = (
        start: payload.timeStampBegin.timeIntervalSince1970,
        end: payload.timeStampEnd.timeIntervalSince1970
      )

      MixpanelLogger.debug(
        message:
          "Processing MetricKit payload: time window \(timeWindow.start) to \(timeWindow.end)"
      )

      // Process crash diagnostics
      if let crashDiagnostics = payload.crashDiagnostics {
        for crash in crashDiagnostics {
          processCrashDiagnostic(crash, timeWindow: timeWindow, payload: payload)
        }
      }

      // Process hang diagnostics
      if let hangDiagnostics = payload.hangDiagnostics {
        for hang in hangDiagnostics {
          processHangDiagnostic(hang, timeWindow: timeWindow, payload: payload)
        }
      }
    }

    /// Process a crash diagnostic and correlate with pending sessions.
    private func processCrashDiagnostic(
      _ crash: MXCrashDiagnostic,
      timeWindow: (start: TimeInterval, end: TimeInterval),
      payload: MXDiagnosticPayload
    ) {
      // Extract signal and exception type as strings
      let signalString = crash.signal?.stringValue
      let exceptionTypeString = crash.exceptionType?.stringValue ?? crash.exceptionCode?.stringValue

      let crashInfo = CrashInfo(
        type: "crash",
        signal: signalString,
        exceptionType: exceptionTypeString,
        timeWindowStart: timeWindow.start,
        timeWindowEnd: timeWindow.end
      )

      MixpanelLogger.debug(
        message:
          "Crash diagnostic: signal=\(signalString ?? "unknown"), exception=\(exceptionTypeString ?? "unknown")"
      )

      // Correlate with pending sessions
      // Note: MXDiagnosticPayload doesn't have applicationVersion directly
      // We'll use the version from our stored records for correlation
      if let (record, confidence) = correlateCrashWithPendingSessions(
        crashInfo: crashInfo,
        appVersion: nil,  // Will match any version
        osVersion: getOSVersion()
      ) {
        MixpanelLogger.info(
          message:
            "Correlated crash with session \(record.sessionId), confidence=\(confidence.rawValue)"
        )

        // Only upgrade to $crash for HIGH/MEDIUM confidence
        if confidence == .high || confidence == .medium {
          emitCrashEvent(record, crashInfo: crashInfo, confidence: confidence)

          // Remove from pending exits
          pendingExitsLock.write {
            pendingUnexpectedExits.removeValue(forKey: record.sessionId)
          }
        } else {
          MixpanelLogger.debug(
            message:
              "LOW confidence match for session \(record.sessionId), keeping as $unexpected_exit"
          )
        }
      } else {
        MixpanelLogger.debug(
          message:
            "No matching pending session for crash in window \(timeWindow.start) to \(timeWindow.end)"
        )
      }
    }

    /// Process a hang diagnostic.
    private func processHangDiagnostic(
      _ hang: MXHangDiagnostic,
      timeWindow: (start: TimeInterval, end: TimeInterval),
      payload: MXDiagnosticPayload
    ) {
      let hangInfo = CrashInfo(
        type: "hang",
        signal: nil,
        exceptionType: nil,
        timeWindowStart: timeWindow.start,
        timeWindowEnd: timeWindow.end
      )

      MixpanelLogger.debug(
        message: "Hang diagnostic in window \(timeWindow.start) to \(timeWindow.end)"
      )

      // Correlate with pending sessions (similar to crash)
      if let (record, confidence) = correlateCrashWithPendingSessions(
        crashInfo: hangInfo,
        appVersion: nil,  // Will match any version
        osVersion: getOSVersion()
      ) {
        MixpanelLogger.info(
          message:
            "Correlated hang with session \(record.sessionId), confidence=\(confidence.rawValue)"
        )

        if confidence == .high || confidence == .medium {
//          emitCrashEvent(record, crashInfo: hangInfo, confidence: confidence)

//          pendingExitsLock.write {
//            pendingUnexpectedExits.removeValue(forKey: record.sessionId)
//          }
        }
      }
    }

    /// Correlate a crash/hang with pending unexpected exits.
    ///
    /// Returns the best-matching record and confidence level, or nil if no match.
    private func correlateCrashWithPendingSessions(
      crashInfo: CrashInfo,
      appVersion: String?,
      osVersion: String
    ) -> (SessionRecoveryRecord, CorrelationConfidence)? {

      var candidates: [(record: SessionRecoveryRecord, confidence: CorrelationConfidence)] = []

      pendingExitsLock.read {
        for (_, record) in pendingUnexpectedExits {
          // Check if record's lastAliveTimestamp falls within crash time window
          let timestamp = record.lastAliveTimestamp
          let inWindow =
            timestamp >= crashInfo.timeWindowStart && timestamp <= crashInfo.timeWindowEnd

          if !inWindow {
            continue
          }

          // Check metadata match (if appVersion provided)
          let versionMatch = appVersion == nil || record.appVersion == appVersion
          let osMatch = record.osVersion.hasPrefix(osVersion.prefix(3))  // Match major.minor version
          let metadataMatch = versionMatch && osMatch

          if metadataMatch {
            // HIGH confidence: within window + metadata match + only match
            candidates.append((record: record, confidence: .high))
          } else {
            // MEDIUM confidence: within window but metadata mismatch
            candidates.append((record: record, confidence: .medium))
          }
        }
      }

      // If exactly one HIGH confidence match, return it
      let highConfidenceCandidates = candidates.filter { $0.confidence == .high }
      if highConfidenceCandidates.count == 1 {
        return highConfidenceCandidates.first
      }

      // If multiple candidates, downgrade to MEDIUM if all were HIGH
      if highConfidenceCandidates.count > 1 {
        // Return the one closest to the end of the window (crashes typically happen at session end)
        let best = highConfidenceCandidates.max { a, b in
          abs(a.record.lastAliveTimestamp - crashInfo.timeWindowEnd)
            > abs(b.record.lastAliveTimestamp - crashInfo.timeWindowEnd)
        }
        return (best!.record, .medium)
      }

      // If only MEDIUM confidence candidates, return the closest one
      if !candidates.isEmpty {
        let best = candidates.max { a, b in
          abs(a.record.lastAliveTimestamp - crashInfo.timeWindowEnd)
            > abs(b.record.lastAliveTimestamp - crashInfo.timeWindowEnd)
        }
        return best
      }

      return nil
    }

    /// Get OS version string for correlation.
    private func getOSVersion() -> String {
      #if os(iOS)
        return UIDevice.current.systemVersion
      #else
        return ProcessInfo.processInfo.operatingSystemVersionString
      #endif
    }
  }
#endif
