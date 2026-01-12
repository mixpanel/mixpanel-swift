//
//  MixpanelOptions.swift
//  Mixpanel
//
//  Created by Jared McFarland on 4/15/25.
//  Copyright © 2025 Mixpanel. All rights reserved.
//

public class MixpanelOptions {
  public let token: String
  public let flushInterval: Double
  public let instanceName: String?
  public let trackAutomaticEvents: Bool
  public let optOutTrackingByDefault: Bool
  public let useUniqueDistinctId: Bool
  public let superProperties: Properties?
  public let serverURL: String?
  public let proxyServerConfig: ProxyServerConfig?
  public let useGzipCompression: Bool
  public let featureFlagsEnabled: Bool
  public let featureFlagsContext: [String: Any]

  /// A closure that provides a custom device ID.
  ///
  /// Use this to control device ID generation instead of relying on the SDK's default behavior
  /// (random UUID or IDFV based on `useUniqueDistinctId`).
  ///
  /// **Important: Choose your device ID strategy up front.** This closure is called:
  /// - Once during initialization (if no persisted identity exists)
  /// - On each call to `reset()`
  /// - On each call to `optOutTracking()`
  ///
  /// **Controlling Reset Behavior:**
  /// - Return the **same value** each time = Device ID never changes (persistent identity)
  /// - Return a **different value** each time = Device ID changes on reset (ephemeral identity)
  /// - Return `nil` = Use SDK's default device ID (useful for error handling)
  ///
  /// **Warning:** Adding a `deviceIdProvider` to an existing app that previously used the default
  /// device ID may cause identity discontinuity. The SDK will log a warning if the provider
  /// returns a value different from the persisted anonymous ID.
  ///
  /// **Example - Persistent Device ID:**
  /// ```swift
  /// let options = MixpanelOptions(
  ///     token: "YOUR_TOKEN",
  ///     deviceIdProvider: {
  ///         return MyKeychainHelper.getOrCreatePersistentId()
  ///     }
  /// )
  /// ```
  ///
  /// **Example - Ephemeral Device ID (resets each time):**
  /// ```swift
  /// let options = MixpanelOptions(
  ///     token: "YOUR_TOKEN",
  ///     deviceIdProvider: {
  ///         return UUID().uuidString
  ///     }
  /// )
  /// ```
  ///
  /// **Example - Fallback to SDK default on failure:**
  /// ```swift
  /// let options = MixpanelOptions(
  ///     token: "YOUR_TOKEN",
  ///     deviceIdProvider: {
  ///         guard let id = fetchDeviceIdFromServer() else {
  ///             return nil  // Fall back to SDK default
  ///         }
  ///         return id
  ///     }
  /// )
  /// ```
  public let deviceIdProvider: (() -> String?)?

  public init(
    token: String,
    flushInterval: Double = 60,
    instanceName: String? = nil,
    trackAutomaticEvents: Bool = false,
    optOutTrackingByDefault: Bool = false,
    useUniqueDistinctId: Bool = false,
    superProperties: Properties? = nil,
    serverURL: String? = nil,
    proxyServerConfig: ProxyServerConfig? = nil,
    useGzipCompression: Bool = true,  // NOTE: This is a new default value!
    featureFlagsEnabled: Bool = false,
    featureFlagsContext: [String: Any] = [:],
    deviceIdProvider: (() -> String?)? = nil
  ) {
    self.token = token
    self.flushInterval = flushInterval
    self.instanceName = instanceName
    self.trackAutomaticEvents = trackAutomaticEvents
    self.optOutTrackingByDefault = optOutTrackingByDefault
    self.useUniqueDistinctId = useUniqueDistinctId
    self.superProperties = superProperties
    self.serverURL = serverURL
    self.proxyServerConfig = proxyServerConfig
    self.useGzipCompression = useGzipCompression
    self.featureFlagsEnabled = featureFlagsEnabled
    self.featureFlagsContext = featureFlagsContext
    self.deviceIdProvider = deviceIdProvider
  }
}
