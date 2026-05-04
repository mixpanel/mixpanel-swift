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
/// **Example — Default behavior (prefetches flags during initialization):**
/// ```swift
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     featureFlagOptions: FeatureFlagOptions(enabled: true)
/// )
/// ```
///
/// **Example — Deferred loading (for use with identify):**
/// ```swift
/// let options = MixpanelOptions(
///     token: "YOUR_TOKEN",
///     featureFlagOptions: FeatureFlagOptions(enabled: true, prefetchFlags: false)
/// )
/// let mp = Mixpanel.initialize(options: options)
/// // identify() triggers loadFlags() internally when the distinctId changes
/// mp.identify(distinctId: "user123")
/// ```
///
/// If `identify` may be called with the same persisted distinctId (no change),
/// call `mp.flags.loadFlags()` explicitly to ensure flags are fetched.
public struct FeatureFlagOptions {
  /// Whether feature flags are enabled. Defaults to `false`.
  public let enabled: Bool

  /// Custom context dictionary sent with flag fetch requests.
  public let context: [String: Any]

  /// Whether the SDK should prefetch feature flags during initialization.
  /// Defaults to `true`.
  ///
  /// Set to `false` if you need to call `identify` before the first flag fetch,
  /// then manually trigger loading via `flags.loadFlags()`.
  public let prefetchFlags: Bool

  public init(
    enabled: Bool = false,
    context: [String: Any] = [:],
    prefetchFlags: Bool = true
  ) {
    self.enabled = enabled
    self.context = context
    self.prefetchFlags = prefetchFlags
  }
}

public class MixpanelOptions {
  /// Your Mixpanel project token.
  public let token: String

  /// Interval in seconds between automatic flush operations. Defaults to `60`.
  /// Set to `0` to disable automatic flushing (requires manual calls to `flush()`).
  public let flushInterval: Double

  /// Unique name for this Mixpanel instance. Defaults to the project token.
  /// Use this when you need multiple instances with the same token.
  public let instanceName: String?

  /// Whether to automatically track common mobile events. Defaults to `false`.
  /// When enabled, tracks events like app launch, session start, etc.
  public let trackAutomaticEvents: Bool

  /// Whether users are opted out of tracking by default. Defaults to `false`.
  /// Useful for GDPR compliance where explicit opt-in is required.
  public let optOutTrackingByDefault: Bool

  /// Whether to use the device's vendor identifier (IDFV) as the default distinct ID.
  /// Defaults to `false` (uses random UUID instead).
  /// IDFV persists across app reinstalls but changes if all apps from the same vendor are uninstalled.
  public let useUniqueDistinctId: Bool

  /// Super properties to register during initialization.
  /// These are automatically included with every event tracked.
  public let superProperties: Properties?

  /// Custom server URL for Mixpanel API requests. Defaults to `https://api.mixpanel.com`.
  /// Use this for EU or IN data residency (`https://api-eu.mixpanel.com`, `https://api-in.mixpanel.com`).
  public let serverURL: String?

  /// Proxy server configuration including custom headers and query parameters.
  /// If `serverURL` is not provided, the proxy's `serverUrl` will be used.
  /// If both `serverURL` and `proxyServerConfig` are provided, `serverURL` takes precedence.
  public let proxyServerConfig: ProxyServerConfig?

  /// Whether to use gzip compression for network requests. Defaults to `true`.
  /// Reduces bandwidth usage but adds slight CPU overhead for compression.
  public let useGzipCompression: Bool
  @available(*, deprecated, message: "Use featureFlagOptions.enabled instead")
  public var featureFlagsEnabled: Bool { return featureFlagOptions.enabled }

  @available(*, deprecated, message: "Use featureFlagOptions.context instead")
  public var featureFlagsContext: [String: Any] { return featureFlagOptions.context }

  /// Grouped configuration for feature flags behavior.
  ///
  /// When provided to the initializer, this takes precedence over the
  /// `featureFlagsEnabled` and `featureFlagsContext` parameters.
  public let featureFlagOptions: FeatureFlagOptions

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

  /// Creates a new Mixpanel configuration with the specified options.
  ///
  /// - Parameters:
  ///   - token: Your Mixpanel project token (required).
  ///   - flushInterval: Seconds between automatic flushes. Set to `0` to disable. Defaults to `60`.
  ///   - instanceName: Unique identifier for this instance. Defaults to the token.
  ///   - trackAutomaticEvents: Enable automatic event tracking (app launch, sessions, etc.). Defaults to `false`.
  ///   - optOutTrackingByDefault: Start with tracking disabled (GDPR compliance). Defaults to `false`.
  ///   - useUniqueDistinctId: Use device IDFV instead of random UUID. Defaults to `false`.
  ///   - superProperties: Properties automatically added to all events. Defaults to `nil`.
  ///   - serverURL: Custom API endpoint (EU: `https://api-eu.mixpanel.com`, IN: `https://api-in.mixpanel.com`). Defaults to `nil` (uses US endpoint).
  ///   - proxyServerConfig: Proxy configuration with headers/query params. `serverURL` takes precedence if both provided. Defaults to `nil`.
  ///   - useGzipCompression: Enable gzip compression for network requests. Defaults to `true`.
  ///   - featureFlagsEnabled: (Deprecated) Use `featureFlagOptions.enabled` instead. Defaults to `false`.
  ///   - featureFlagsContext: (Deprecated) Use `featureFlagOptions.context` instead. Defaults to `[:]`.
  ///   - deviceIdProvider: Custom device ID provider closure. Defaults to `nil`.
  ///   - featureFlagOptions: Feature flag configuration. Takes precedence over deprecated params. Defaults to `nil`.
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
    useGzipCompression: Bool = true,
    featureFlagsEnabled: Bool = false,
    featureFlagsContext: [String: Any] = [:],
    deviceIdProvider: (() -> String?)? = nil,
    featureFlagOptions: FeatureFlagOptions? = nil
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

    // When featureFlagOptions is explicitly provided, it takes precedence
    if let featureFlagOptions = featureFlagOptions {
      self.featureFlagOptions = featureFlagOptions
    } else {
      self.featureFlagOptions = FeatureFlagOptions(
        enabled: featureFlagsEnabled,
        context: featureFlagsContext
      )
    }
  }
}
