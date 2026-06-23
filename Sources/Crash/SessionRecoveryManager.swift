//
//  SessionRecoveryManager.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
  import UIKit
#endif

/// Coordinates crash detection, recovery, and correlation with MetricKit diagnostics.
///
/// Detection strategy:
/// 1. UserDefaults marker (fast path): Detects unexpected exits immediately on next launch
/// 2. MetricKit diagnostics (enrichment): Classifies crash type with OS-provided diagnostics
///
/// Lifecycle:
/// - Launch/foreground: Arm marker (sessionCompleted = false)
/// - Background: Mark complete (sessionCompleted = true)
/// - Next launch: Check marker → emit $unexpected_exit if incomplete
/// - MetricKit delivery: Correlate → upgrade to $crash if HIGH/MEDIUM confidence
@available(iOS 13.0, *)
class SessionRecoveryManager: NSObject {
  let storage: SessionRecoveryStorage  // Internal for debug access
  private let instanceName: String

  /// Dedicated serial queue for crash recovery operations
  let metricsQueue: DispatchQueue

  /// Reference to MixpanelInstance for event emission
  weak var mixpanelInstance: MixpanelInstance?

  /// Pending unexpected exits awaiting MetricKit corroboration
  var pendingUnexpectedExits: [String: SessionRecoveryRecord] = [:]
  let pendingExitsLock = ReadWriteLock(label: "com.mixpanel.sessionrecovery.pendingexits")

  /// Maximum number of pending unexpected exits to track (crash-loop protection)
  private let maxPendingUnexpectedExits = 10

  /// Maximum retry attempts for processing a recovery record (crash-loop protection)
  private let maxRecoveryRetryCount = 3

  /// Expiration window for pending records (24 hours)
  private let pendingExpirationInterval: TimeInterval = 24 * 60 * 60

  init(instanceName: String) {
    self.instanceName = instanceName
    self.metricsQueue = DispatchQueue(
      label: "com.mixpanel.\(instanceName).metrics",
      qos: .utility,
      autoreleaseFrequency: .workItem
    )
    self.storage = SessionRecoveryStorage(instanceName: instanceName)
  }

  // MARK: - Marker Lifecycle

  /// Arm the crash detection marker on launch or foreground.
  ///
  /// Creates a new SessionRecoveryRecord with sessionCompleted = false.
  /// If a previous incomplete record exists, it's detected as an unexpected exit.
  func armMarker(sessionId: String, replayId: String?, lastFrameTimestamp: TimeInterval?) {
    metricsQueue.async { [weak self] in
      guard let self = self else { return }

      // Check for previous incomplete session (unexpected exit detection)
      if let previousRecord = self.storage.load() {
        if !previousRecord.sessionCompleted {
          MixpanelLogger.info(
            message:
              "Detected unexpected exit: sessionId=\(previousRecord.sessionId), replayId=\(previousRecord.replayId ?? "none")"
          )
          self.handleUnexpectedExit(previousRecord)
        }
      }

      // Create and save new active marker
      let newRecord = SessionRecoveryRecord.createActive(
        sessionId: sessionId,
        replayId: replayId,
        lastFrameTimestamp: lastFrameTimestamp,
        recordingStart: nil,  // Will be set when SR starts recording
        recordingEnd: nil
      )

      self.storage.save(newRecord)
      MixpanelLogger.debug(message: "Armed crash detection marker for session \(sessionId)")
    }
  }

  /// Mark the current session as cleanly completed (on background).
  ///
  /// Sets sessionCompleted = true, indicating the app reached background state successfully.
  func markSessionComplete() {
    metricsQueue.async { [weak self] in
      guard let self = self else { return }

      if var record = self.storage.load() {
        record.markCompleted()
        self.storage.save(record)
        MixpanelLogger.debug(message: "Marked session \(record.sessionId) as complete")
      }
    }
  }

  /// Update the last frame timestamp from Session Replay.
  ///
  /// Called when SR captures a new frame to maintain a tight crash-time anchor.
  func updateLastFrameTimestamp(_ timestamp: TimeInterval?) {
    metricsQueue.async { [weak self] in
      guard let self = self else { return }

      if var record = self.storage.load() {
        record.updateLastFrame(timestamp)
        record.updateLastAlive(Date().timeIntervalSince1970)
        self.storage.save(record)
      }
    }
  }

  /// Update the last alive timestamp (heartbeat).
  ///
  /// Called periodically to maintain a timestamp even when no SR frames are captured.
  func updateLastAliveTimestamp() {
    metricsQueue.async { [weak self] in
      guard let self = self else { return }

      if var record = self.storage.load() {
        record.updateLastAlive(Date().timeIntervalSince1970)
        self.storage.save(record)
      }
    }
  }

  // MARK: - Recovery Processing

  /// Handle an unexpected exit detected on launch.
  ///
  /// Emits $unexpected_exit event and adds to pending exits for MetricKit correlation.
  private func handleUnexpectedExit(_ record: SessionRecoveryRecord) {
    // Crash-loop protection: check retry count
    if record.recoveryRetryCount >= maxRecoveryRetryCount {
      MixpanelLogger.warn(
        message:
          "Quarantining recovery record after \(record.recoveryRetryCount) failed attempts: \(record.sessionId)"
      )
      storage.delete()
      return
    }

    // Crash-loop protection: check pending exits limit
    pendingExitsLock.read {
      if pendingUnexpectedExits.count >= maxPendingUnexpectedExits {
        MixpanelLogger.warn(
          message:
            "Max pending unexpected exits reached (\(maxPendingUnexpectedExits)), dropping oldest"
        )
        // Will be handled by adding new one
      }
    }

    // Emit $unexpected_exit event
      if ((record.replayId) != nil) {
          emitUnexpectedExitEvent(record)
      }

    // Add to pending exits for MetricKit correlation
    pendingExitsLock.write {
      // Evict oldest if at limit
      if pendingUnexpectedExits.count >= maxPendingUnexpectedExits,
        let oldestKey = pendingUnexpectedExits.keys.sorted(by: {
          pendingUnexpectedExits[$0]!.startTimestamp < pendingUnexpectedExits[$1]!.startTimestamp
        }).first
      {
        pendingUnexpectedExits.removeValue(forKey: oldestKey)
      }

      pendingUnexpectedExits[record.sessionId] = record
    }

    // Clean up the marker (processed)
    storage.delete()
  }

  /// Emit $unexpected_exit event.
  fileprivate func emitUnexpectedExitEvent(_ record: SessionRecoveryRecord) {
    guard let instance = mixpanelInstance else {
      MixpanelLogger.warn(message: "Cannot emit event: MixpanelInstance not set")
      return
    }

    var properties: Properties = [
      "$session_id": record.sessionId,
      "$crash_timestamp": record.lastFrameTimestamp ?? record.lastAliveTimestamp,
      "$exit_type": "unexpected",
    ]

    if let replayId = record.replayId {
      properties["$replay_id"] = replayId
    }

    instance.track(event: "$unexpected_exit", properties: properties)
    MixpanelLogger.info(
      message:
        "Emitted $unexpected_exit event for session \(record.sessionId), replayId=\(record.replayId ?? "none")"
    )
  }

  /// Emit $crash event (MetricKit-corroborated).
  func emitCrashEvent(
    _ record: SessionRecoveryRecord, crashInfo: CrashInfo, confidence: CorrelationConfidence
  ) {
    guard let instance = mixpanelInstance else {
      MixpanelLogger.warn(message: "Cannot emit event: MixpanelInstance not set")
      return
    }

    var properties: Properties = [
      "$session_id": record.sessionId,
      "$crash_timestamp": record.lastFrameTimestamp ?? record.lastAliveTimestamp,
      "$app_version": record.appVersion,
      "$app_build_number": record.buildNumber,
      "$os_version": record.osVersion,
      "$device_model": record.deviceModel,
      "$exit_type": "crash",
      "$crash_type": crashInfo.type,
      "$correlation_confidence": confidence.rawValue,
    ]

    if let replayId = record.replayId {
      properties["$replay_id"] = replayId
    }

    if let exceptionType = crashInfo.exceptionType {
      properties["$exception_type"] = exceptionType
    }

    if let signal = crashInfo.signal {
      properties["$signal"] = signal
    }

    // Generate stable event ID for idempotency
    let eventId =
      "\(record.sessionId)_\(crashInfo.timeWindowStart)_\(crashInfo.timeWindowEnd)".data(
        using: .utf8)?.base64EncodedString() ?? ""
    properties["$event_id"] = eventId

    instance.track(event: "$crash", properties: properties)
    MixpanelLogger.info(
      message:
        "Emitted $crash event for session \(record.sessionId), confidence=\(confidence.rawValue)"
    )
  }

  // MARK: - Cleanup

  /// Clean up expired pending records.
  func cleanupExpiredPendingRecords() {
    metricsQueue.async { [weak self] in
      guard let self = self else { return }

      let now = Date().timeIntervalSince1970

      self.pendingExitsLock.write {
        let expiredKeys = self.pendingUnexpectedExits.filter { _, record in
          now - record.startTimestamp > self.pendingExpirationInterval
        }.map { $0.key }

        for key in expiredKeys {
          MixpanelLogger.debug(
            message: "Removing expired pending record: \(key)")
          self.pendingUnexpectedExits.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
          MixpanelLogger.info(message: "Cleaned up \(expiredKeys.count) expired pending records")
        }
      }
    }
  }
}

// MARK: - Supporting Types

/// Confidence level for MetricKit correlation
enum CorrelationConfidence: String {
  case high = "HIGH"
  case medium = "MEDIUM"
  case low = "LOW"
}

/// Crash information from MetricKit
struct CrashInfo {
  let type: String
  let signal: String?
  let exceptionType: String?
  let timeWindowStart: TimeInterval
  let timeWindowEnd: TimeInterval
}
