//
//  MixpanelOptions.swift
//  Mixpanel
//
//  Created by Jared McFarland on 4/15/25.
//  Copyright © 2025 Mixpanel. All rights reserved.
//

import Foundation

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

  /// Strategy used to resolve flag variants relative to the on-disk persistence layer and
  /// the network. Defaults to `.networkOnly` — variant lookups always wait for the network
  /// call, matching behavior prior to the introduction of variant persistence.
  ///
  /// Persistence behavior is derived directly from this policy:
  /// - `.networkOnly` — no persistence. The on-disk blob is also wiped at init if present
  ///   (so toggling from a persisting policy back to `.networkOnly` cleans up after itself).
  /// - `.persistenceUntilNetworkSuccess(persistenceTtl:)` / `.networkFirst(persistenceTtl:)` — successful
  ///   fetches write to disk; persisted variants are read on init.
  public let variantLookupPolicy: VariantLookupPolicy

  public init(
    enabled: Bool = false,
    context: [String: Any] = [:],
    prefetchFlags: Bool = true,
    variantLookupPolicy: VariantLookupPolicy = .networkOnly
  ) {
    self.enabled = enabled
    self.context = context
    self.prefetchFlags = prefetchFlags
    self.variantLookupPolicy = variantLookupPolicy
  }
}

/// Strategy for resolving feature flag variants relative to the on-disk persistence layer
/// and the network.
///
/// - `networkOnly`: Never read or write persisted variants. Variant lookups always wait for
///   the network call. Default; matches behavior prior to variant persistence. If a persisted
///   blob exists from a previous session that used a persisting policy, it's wiped on init.
/// - `persistenceUntilNetworkSuccess(persistenceTtl:)`: Serve persisted variants immediately
///   when available, refresh from the network in the background. Persisted entries older
///   than `persistenceTtl` are ignored on read but NOT deleted (the next successful fetch
///   overwrites them).
/// - `networkFirst(persistenceTtl:)`: Prefer fresh values from the network, but fall back to
///   persisted variants when the network call fails. Same TTL semantics as
///   `persistenceUntilNetworkSuccess`.
///
/// **TTL handling** — non-positive `persistenceTtl` on a persisting policy is a
/// misconfiguration. At SDK init the requested policy is run through `effective(_:)`, which
/// collapses any persisting policy with `persistenceTtl <= 0` to `.networkOnly` (with a
/// warning logged). Persistence-with-no-useful-TTL would write to disk on every fetch but
/// never serve anything from disk, so the SDK substitutes the meaningful interpretation. The
/// factories themselves don't sanitize — they preserve exactly what the developer asked for
/// so callers can introspect.
///
/// Convenience zero-argument forms `persistenceUntilNetworkSuccess()` / `networkFirst()` use
/// `defaultTTL` (24 hours) — equivalent to passing
/// `persistenceTtl: VariantLookupPolicy.defaultTTL`.
public enum VariantLookupPolicy {
  case networkOnly
  case persistenceUntilNetworkSuccess(persistenceTtl: TimeInterval)
  case networkFirst(persistenceTtl: TimeInterval)

  /// Default time-to-live for persisted variants when no TTL is specified: 24 hours.
  public static let defaultTTL: TimeInterval = 24 * 60 * 60

  /// Convenience constructor — equivalent to
  /// `.persistenceUntilNetworkSuccess(persistenceTtl: VariantLookupPolicy.defaultTTL)`.
  public static func persistenceUntilNetworkSuccess() -> VariantLookupPolicy {
    return .persistenceUntilNetworkSuccess(persistenceTtl: defaultTTL)
  }

  /// Convenience constructor — equivalent to
  /// `.networkFirst(persistenceTtl: VariantLookupPolicy.defaultTTL)`.
  public static func networkFirst() -> VariantLookupPolicy {
    return .networkFirst(persistenceTtl: defaultTTL)
  }

  /// Resolves the policy the SDK should actually use given what the developer configured.
  /// Substitutes `.networkOnly` when the requested policy is a persisting one with non-
  /// positive `persistenceTtl`, since "persist on every fetch but the TTL makes nothing ever
  /// serve" does no useful work — the developer almost certainly meant "no persistence." Logs
  /// a warning when the substitution happens.
  ///
  /// Called once at FeatureFlagManager init; downstream code can treat the returned policy
  /// as canonical.
  internal static func effective(_ requested: VariantLookupPolicy) -> VariantLookupPolicy {
    let persistenceTtl: TimeInterval
    switch requested {
      case .networkOnly:
        return requested
      case .persistenceUntilNetworkSuccess(let t), .networkFirst(let t):
        persistenceTtl = t
    }
    if persistenceTtl <= 0 {
      MixpanelLogger.warn(
        message:
          "Non-positive persistenceTtl (\(persistenceTtl)s) on \(requested); falling back to networkOnly since persistence with no meaningful TTL does no useful work."
      )
      return .networkOnly
    }
    return requested
  }
}

public class MixpanelOptions {
  /// Property keys that ingestion or identity resolution require and that will never be
  /// stripped by ``excludeProperties``, even if a customer lists them. Single source of truth
  /// for both the runtime filter (see `Track.applyExcludeProperties`) and the documentation.
  public static let reservedPropertyKeys: Set<String> = [
    "token", "time", "distinct_id", "$device_id", "$user_id", "$had_persisted_distinct_id",
  ]

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

  /// Property keys that will be stripped from outgoing event and People payloads before they
  /// are persisted and sent to Mixpanel. Defaults to empty (no filtering, zero per-payload
  /// overhead).
  ///
  /// Use this to reduce payload size or to suppress properties the project has no interest in.
  /// Matching is **exact and case-sensitive**.
  ///
  /// Keys in ``MixpanelOptions/reservedPropertyKeys`` are never stripped, even if listed —
  /// they are required for ingestion and identity resolution.
  ///
  /// **Scope:**
  /// - **Events** — applied at the persistence chokepoint, covering super properties, caller
  ///   properties, and SDK auto-properties uniformly.
  /// - **People `$set` and `$set_once`** — applied after the SDK merges
  ///   `AutomaticProperties.peopleProperties` (the auto-injected `$ios_*` device keys) so
  ///   those auto-injected keys are subject to the same exclude set as event auto-properties.
  ///
  /// **Not in scope:**
  /// - Other People operators (`$add`, `$append`, `$union`, `$unset`, `$merge`, `$remove`,
  ///   `$delete`) are pass-through. Their property keys are operands rather than a bag to
  ///   mutate, and filtering inside them would silently change semantics (e.g. dropping a
  ///   name from an `$unset` list).
  /// - **Group updates** never merge auto-properties, so there is nothing the filter would
  ///   contribute that the caller couldn't omit themselves.
  /// - **`$mp_metadata`** is a sibling of `properties` in the event envelope and is
  ///   structurally outside the filter's scope by design.
  ///
  /// **Recommended: do not strip `mp_lib` or `$lib_version`.** Mixpanel does not need them
  /// for ingestion or identity resolution, so stripping them is permitted — but they are how
  /// Mixpanel identifies which SDK (and which version) produced an event. Removing them
  /// limits reporting accuracy (e.g. per-platform breakdowns) and makes it harder for support
  /// to debug issues on your project. If either key is included here, the SDK logs a warning
  /// at instance creation time.
  public let excludeProperties: Set<String>
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
    featureFlagOptions: FeatureFlagOptions? = nil,
    excludeProperties: Set<String> = []
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
    self.excludeProperties = excludeProperties

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
