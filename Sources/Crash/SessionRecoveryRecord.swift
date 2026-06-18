//
//  SessionRecoveryRecord.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
  import UIKit
#elseif os(macOS)
  import Cocoa
#elseif canImport(WatchKit)
  import WatchKit
#endif

/// Record stored in UserDefaults to detect unexpected app exits (crashes, force-quits, OS kills).
///
/// Written on launch/foreground (sessionCompleted = false), marked complete on background.
/// On next launch, sessionCompleted == false indicates an unexpected exit.
struct SessionRecoveryRecord: Codable {
  /// Schema version for forward compatibility (allows handling old records after app updates)
  let schemaVersion: Int

  /// Core session identifiers
  let sessionId: String
  let replayId: String?

  /// App metadata (used for MetricKit correlation)
  let appVersion: String
  let buildNumber: String

  /// Device/OS metadata (used for MetricKit correlation)
  let osVersion: String
  let deviceModel: String

  /// Timestamps
  let startTimestamp: TimeInterval
  let recordingStart: TimeInterval?
  let recordingEnd: TimeInterval?
  var lastFrameTimestamp: TimeInterval?
  var lastAliveTimestamp: TimeInterval

  /// Session lifecycle flag
  var sessionCompleted: Bool

  /// Crash-loop protection
  var recoveryRetryCount: Int

  /// Current schema version
  static let currentSchemaVersion = 1

  /// Create a new recovery record for the active session
  static func createActive(
    sessionId: String,
    replayId: String?,
    lastFrameTimestamp: TimeInterval?,
    recordingStart: TimeInterval?,
    recordingEnd: TimeInterval?
  ) -> SessionRecoveryRecord {
    let now = Date().timeIntervalSince1970

    return SessionRecoveryRecord(
      schemaVersion: currentSchemaVersion,
      sessionId: sessionId,
      replayId: replayId,
      appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
      buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
      osVersion: Self.getOSVersion(),
      deviceModel: Self.getDeviceModel(),
      startTimestamp: now,
      recordingStart: recordingStart,
      recordingEnd: recordingEnd,
      lastFrameTimestamp: lastFrameTimestamp,
      lastAliveTimestamp: now,
      sessionCompleted: false,
      recoveryRetryCount: 0
    )
  }

  /// Get OS version string
  private static func getOSVersion() -> String {
    #if os(iOS) || os(tvOS) || os(visionOS)
      #if targetEnvironment(macCatalyst)
        return ProcessInfo.processInfo.operatingSystemVersionString
      #else
        return UIDevice.current.systemVersion
      #endif
    #elseif os(macOS)
      return ProcessInfo.processInfo.operatingSystemVersionString
    #elseif os(watchOS)
      return WKInterfaceDevice.current().systemVersion
    #else
      return "unknown"
    #endif
  }

  /// Get device model identifier
  private static func getDeviceModel() -> String {
    #if os(iOS) || os(tvOS) || os(visionOS)
      var systemInfo = utsname()
      uname(&systemInfo)
      let machineMirror = Mirror(reflecting: systemInfo.machine)
      let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
      return identifier
    #elseif os(macOS)
      var systemInfo = utsname()
      uname(&systemInfo)
      let machineMirror = Mirror(reflecting: systemInfo.machine)
      let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
      return identifier
    #else
      return "unknown"
    #endif
  }

  /// Update the last alive timestamp (heartbeat)
  mutating func updateLastAlive(_ timestamp: TimeInterval) {
    self.lastAliveTimestamp = timestamp
  }

  /// Update the last frame timestamp from Session Replay
  mutating func updateLastFrame(_ timestamp: TimeInterval?) {
    self.lastFrameTimestamp = timestamp
  }

  /// Mark session as cleanly completed
  mutating func markCompleted() {
    self.sessionCompleted = true
  }

  /// Increment retry count for crash-loop protection
  mutating func incrementRetryCount() {
    self.recoveryRetryCount += 1
  }
}

/// Storage layer for SessionRecoveryRecord using UserDefaults
class SessionRecoveryStorage {
  private let userDefaults: UserDefaults
  private let storageKey: String

  /// Initialize with instance-specific storage key
  init(instanceName: String) {
    // Use same suite name as MixpanelPersistence for consistency
    self.userDefaults = UserDefaults(suiteName: "Mixpanel") ?? UserDefaults.standard
    self.storageKey = "mp_session_recovery_\(instanceName)"
  }

  /// Save recovery record to UserDefaults
  func save(_ record: SessionRecoveryRecord) {
    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(record)
      userDefaults.set(data, forKey: storageKey)
    } catch {
      MixpanelLogger.warn(message: "Failed to save SessionRecoveryRecord: \(error)")
    }
  }

  /// Load recovery record from UserDefaults
  func load() -> SessionRecoveryRecord? {
    guard let data = userDefaults.data(forKey: storageKey) else {
      return nil
    }

    do {
      let decoder = JSONDecoder()
      let record = try decoder.decode(SessionRecoveryRecord.self, from: data)
      return record
    } catch {
      MixpanelLogger.warn(message: "Failed to decode SessionRecoveryRecord: \(error)")
      return nil
    }
  }

  /// Delete recovery record from UserDefaults
  func delete() {
    userDefaults.removeObject(forKey: storageKey)
  }

  /// Check if a recovery record exists
  func exists() -> Bool {
    return userDefaults.data(forKey: storageKey) != nil
  }
}
