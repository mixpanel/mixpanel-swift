//
//  MixpanelOptions.swift
//  Mixpanel
//
//  Created by Jared McFarland on 4/15/25.
//  Copyright © 2025 Mixpanel. All rights reserved.
//

/// Configuration options for feature flags behavior.
///
/// Use this to control how and when feature flags are loaded by the SDK.
///
/// **Example — Default behavior (auto-loads flags on first foreground):**
/// ```swift
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     flagsOptions: FlagOptions(enabled: true)
/// )
/// ```
///
/// **Example — Deferred loading (for use with identify):**
/// ```swift
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     flagsOptions: FlagOptions(enabled: true, loadOnFirstForeground: false)
/// )
/// let mp = Mixpanel.initialize(options: options)
/// // identify() triggers loadFlags() internally when the distinctId changes
/// mp.identify(distinctId: "user123")
/// ```
///
/// If `identify` may be called with the same persisted distinctId (no change),
/// call `mp.flags.loadFlags()` explicitly to ensure flags are fetched.
public struct FlagOptions {
  /// Whether feature flags are enabled. Defaults to `false`.
  public let enabled: Bool

  /// Custom context dictionary sent with flag fetch requests.
  public let context: [String: Any]

  /// Whether the SDK should automatically load flags when the app first enters
  /// the foreground (i.e., during initialization). Defaults to `true`.
  ///
  /// Set to `false` if you need to call `identify` before the first flag fetch,
  /// then manually trigger loading via `flags.loadFlags()`.
  public let loadOnFirstForeground: Bool

  public init(
    enabled: Bool = false,
    context: [String: Any] = [:],
    loadOnFirstForeground: Bool = true
  ) {
    self.enabled = enabled
    self.context = context
    self.loadOnFirstForeground = loadOnFirstForeground
  }
}

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
  @available(*, deprecated, message: "Use flagsOptions.enabled instead")
  public var featureFlagsEnabled: Bool { return flagsOptions.enabled }

  @available(*, deprecated, message: "Use flagsOptions.context instead")
  public var featureFlagsContext: [String: Any] { return flagsOptions.context }

  /// Grouped configuration for feature flags behavior.
  ///
  /// When provided to the initializer, this takes precedence over the
  /// `featureFlagsEnabled` and `featureFlagsContext` parameters.
  public let flagsOptions: FlagOptions

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
  /// **Thread Safety:** This closure is called synchronously while holding internal locks.
  /// Keep implementations fast and non-blocking. For Keychain or network-fetched IDs,
  /// retrieve and cache the value at app launch, then return the cached value from the provider.
  ///
  /// **Warning:** Adding a `deviceIdProvider` to an existing app that previously used the default
  /// device ID may cause identity discontinuity. The SDK will log a warning if the provider
  /// returns a value different from the persisted anonymous ID.
  ///
  /// **Example - Persistent Device ID (cached at launch):**
  /// ```swift
  /// // Cache the device ID at app launch (before Mixpanel init)
  /// let cachedDeviceId = MyKeychainHelper.getOrCreatePersistentId()
  ///
  /// let options = MixpanelOptions(
  ///     token: "YOUR_TOKEN",
  ///     deviceIdProvider: { cachedDeviceId }  // Return cached value
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
    deviceIdProvider: (() -> String?)? = nil,
    flagsOptions: FlagOptions? = nil
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
    self.deviceIdProvider = deviceIdProvider

    // When flagsOptions is explicitly provided, it takes precedence
    if let flagsOptions = flagsOptions {
      self.flagsOptions = flagsOptions
    } else {
      self.flagsOptions = FlagOptions(
        enabled: featureFlagsEnabled,
        context: featureFlagsContext
      )
    }
  }
}
