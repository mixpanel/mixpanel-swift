//
//  SessionRecoveryDebug.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//
//  ⚠️ DEBUG ONLY - This file contains testing utilities and should be removed in production builds
//

#if DEBUG && os(iOS)
  import Foundation

  /// Debug utilities for crash detection testing.
  ///
  /// These methods are only available in DEBUG builds and should be removed before production release.
  @available(iOS 13.0, *)
  extension MixpanelInstance {

    /**
       Get debug information about crash detection state.

       Useful for verifying crash detection setup and troubleshooting issues.

       - returns: A formatted string with current marker state, pending exits, and watchdog status

       ⚠️ DEBUG ONLY - Remove this file before production release
       */
    public func debugCrashDetection() -> String {
      var report = "=== Crash Detection Debug ===\n\n"

      // Check current marker
      if let record = sessionRecoveryManager.storage.load() {
        report += "Current Marker:\n"
        report += "  sessionId: \(record.sessionId)\n"
        report += "  sessionCompleted: \(record.sessionCompleted)\n"
        report += "  replayId: \(record.replayId ?? "none")\n"
        report += "  lastAliveTimestamp: \(formatTimestamp(record.lastAliveTimestamp))\n"
        if let lastFrame = record.lastFrameTimestamp {
          report += "  lastFrameTimestamp: \(formatTimestamp(lastFrame))\n"
        }
        report += "  appVersion: \(record.appVersion)\n"
        report += "  buildNumber: \(record.buildNumber)\n"
        report += "  osVersion: \(record.osVersion)\n"
        report += "  retryCount: \(record.recoveryRetryCount)\n"
      } else {
        report += "Current Marker: None\n"
      }

      // Check pending exits
      var pendingCount = 0
      var pendingList: [(String, SessionRecoveryRecord)] = []
      sessionRecoveryManager.pendingExitsLock.read {
        pendingCount = sessionRecoveryManager.pendingUnexpectedExits.count
        pendingList = Array(sessionRecoveryManager.pendingUnexpectedExits)
      }

      report += "\nPending Unexpected Exits: \(pendingCount)\n"
      for (id, record) in pendingList {
        report += "  - \(id)\n"
        report += "    sessionId: \(record.sessionId)\n"
        report += "    timestamp: \(formatTimestamp(record.startTimestamp))\n"
        report += "    replayId: \(record.replayId ?? "none")\n"
      }

      // Check ANR watchdog
      report += "\nANR Watchdog:\n"
      report += "  currentReplayId: \(anrWatchdog.currentReplayId ?? "none")\n"

      // Check metrics queue
      report += "\nMetrics Queue:\n"
      report += "  label: \(sessionRecoveryManager.metricsQueue.label)\n"

      report += "\n=== End Debug Report ===\n"

      return report
    }

    /**
       Clear all crash detection state for testing purposes.

       This removes the current marker and all pending unexpected exits.
       Use this to reset crash detection state between tests.

       ⚠️ DEBUG ONLY - This will cause loss of crash detection data.
       Remove this file before production release.
       */
    public func debugResetCrashDetection() {
      sessionRecoveryManager.storage.delete()
      sessionRecoveryManager.pendingExitsLock.write {
        sessionRecoveryManager.pendingUnexpectedExits.removeAll()
      }
      MixpanelLogger.info(message: "🔄 DEBUG: Crash detection state cleared")
    }

    /**
       Force trigger an unexpected exit detection (for testing).

       This simulates an incomplete session marker as if the app crashed.
       Use this to test crash detection without actually crashing the app.

       ⚠️ DEBUG ONLY - Remove this file before production release.
       */
    public func debugSimulateCrash() {
      // Create an incomplete marker
      let record = SessionRecoveryRecord.createActive(
        sessionId: sessionMetadata.sessionID,
        replayId: nil,
        lastFrameTimestamp: nil,
        recordingStart: nil,
        recordingEnd: nil
      )
      sessionRecoveryManager.storage.save(record)
      MixpanelLogger.info(
        message: "🧪 DEBUG: Simulated crash - marker saved as incomplete. Restart app to detect."
      )
    }

    // MARK: - Private Helpers

    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
      let date = Date(timeIntervalSince1970: timestamp)
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      return formatter.string(from: date)
    }
  }

#endif
