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
/// let options = MixpanelOptions(token: "YOUR_TOKEN")
/// options.featureFlagOptions = FeatureFlagOptions(enabled: true)
/// let mixpanel = Mixpanel.initialize(options: options)
/// ```
///
/// **Example — Deferred loading (for use with identify):**
/// ```swift
/// let options = MixpanelOptions(token: "YOUR_TOKEN")
/// options.featureFlagOptions = FeatureFlagOptions(enabled: true, prefetchFlags: false)
/// let mixpanel = Mixpanel.initialize(options: options)
///
/// // identify() triggers loadFlags() internally when the distinctId changes
/// mixpanel.identify(distinctId: "user123")
/// ```
///
/// If `identify` may be called with the same persisted distinctId (no change),
/// call `mixpanel.flags.loadFlags()` explicitly to ensure flags are fetched.
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

/// Configuration options for Mixpanel SDK initialization.
///
/// All properties (except `token`) are mutable, enabling flexible configuration:
/// ```swift
/// let options = MixpanelOptions(token: "YOUR_TOKEN")
/// options.flushInterval = 30
/// options.trackAutomaticEvents = true
///
/// // Replace entire configuration structs
/// options.featureFlagOptions = FeatureFlagOptions(enabled: true, prefetchFlags: false)
///
/// let mixpanel = Mixpanel.initialize(options: options)
/// ```
///
/// **Note**: While you can replace entire struct objects (featureFlagOptions,
/// proxyServerConfig, autocaptureOptions), you cannot modify individual properties
/// within those structs as they remain immutable.
///
/// **Thread Safety**: This class is NOT thread-safe. Complete configuration on a
/// single thread before passing to `Mixpanel.initialize()`. Changes made after
/// initialization will NOT affect existing `MixpanelInstance` objects.
///
/// **Token Immutability**: The `token` property cannot be modified after
/// object creation as it identifies the Mixpanel project.
public class MixpanelOptions {
    /// Property keys that ingestion or identity resolution require and that will never be
    /// stripped by ``excludeProperties``, even if a customer lists them. Single source of truth
    /// for both the runtime filter (see `Track.applyExcludeProperties`) and the documentation.
    public static let reservedPropertyKeys: Set<String> = [
        "token", "time", "distinct_id", "$device_id", "$user_id", "$had_persisted_distinct_id",
    ]

    /// Your Mixpanel project token.
    /// This is the unique identifier for your Mixpanel project and cannot be changed after initialization.
    public let token: String

    /// Interval in seconds between automatic data flushes to Mixpanel servers.
    /// Set to a higher value to reduce network requests, or lower for more real-time tracking.
    /// Set to `0` or less to disable automatic flushing (you must call `flush()` manually).
    /// Defaults to `60` seconds.
    public var flushInterval: Double = 60

    /// Unique name for this Mixpanel instance.
    /// Use this when you need to track to multiple Mixpanel projects from the same app.
    /// If not provided, defaults to the project token.
    public var instanceName: String? = nil

    /// Whether to automatically track events like `$app_open` and first app opens.
    /// When enabled, the SDK tracks session start events automatically.
    /// Defaults to `false`.
    ///
    /// **Legacy feature:** Not recommended for new implementations.
    public var trackAutomaticEvents: Bool = false

    /// Whether users should be opted out of tracking by default.
    /// When `true`, no data is sent until the user explicitly opts in via `optInTracking()`.
    /// Defaults to `false`.
    public var optOutTrackingByDefault: Bool = false

    /// Whether to use IDFV (Identifier for Vendor) as the default distinct ID.
    /// When `false`, a random UUID is generated instead.
    ///
    /// **IDFV behavior:** Remains stable across app reinstalls as long as at least one app
    /// from the same vendor stays installed. Resets to a new value if the user uninstalls all
    /// apps from your vendor and later reinstalls.
    ///
    /// Defaults to `false` (uses random UUID).
    public var useUniqueDistinctId: Bool = false

    /// Properties to include with every event tracked by this instance.
    /// These are merged with event-specific properties, with event properties taking precedence.
    /// Useful for setting common properties like user type, subscription details, etc.
    /// Defaults to `nil`.
    public var superProperties: Properties? = nil

    /// Custom server URL for data ingestion.
    ///
    /// Use this for data residency requirements:
    /// - EU: `https://api-eu.mixpanel.com`
    /// - India: `https://api-in.mixpanel.com`
    ///
    /// Defaults to `nil` (uses US servers: `https://api.mixpanel.com`).
    public var serverURL: String? = nil

    /// Configuration for proxying Mixpanel requests through your own server.
    /// Allows you to route analytics data through your infrastructure before reaching Mixpanel.
    ///
    /// **Example:**
    /// ```swift
    /// let proxyConfig = ProxyServerConfig(
    ///     serverUrl: "https://proxy.yourcompany.com",
    ///     delegate: MyProxyDelegate()
    /// )
    /// let options = MixpanelOptions(token: "YOUR_TOKEN")
    /// options.proxyServerConfig = proxyConfig
    /// ```
    ///
    /// Defaults to `nil`
    public var proxyServerConfig: ProxyServerConfig? = nil

    /// Whether to compress network request payloads using gzip.
    /// Compression reduces bandwidth usage but adds minimal CPU overhead.
    /// Defaults to `true`.
    public var useGzipCompression: Bool = true

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
    public var excludeProperties: Set<String> = []
    
    @available(*, deprecated, message: "Use featureFlagOptions.enabled instead")
    public var featureFlagsEnabled: Bool { return featureFlagOptions.enabled }

    @available(*, deprecated, message: "Use featureFlagOptions.context instead")
    public var featureFlagsContext: [String: Any] { return featureFlagOptions.context }

    /// Grouped configuration for feature flags behavior.
    ///
    /// When provided to the initializer, this takes precedence over the
    /// `featureFlagsEnabled` and `featureFlagsContext` parameters.
    public var featureFlagOptions: FeatureFlagOptions = FeatureFlagOptions()

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
    /// let options = MixpanelOptions(token: "YOUR_TOKEN")
    /// options.deviceIdProvider = { cachedDeviceId }  // Return cached value
    /// let mixpanel = Mixpanel.initialize(options: options)
    /// ```
    ///
    /// **Example - Ephemeral Device ID (resets each time):**
    /// ```swift
    /// let options = MixpanelOptions(token: "YOUR_TOKEN")
    /// options.deviceIdProvider = {
    ///     return UUID().uuidString
    /// }
    /// let mixpanel = Mixpanel.initialize(options: options)
    /// ```
    public var deviceIdProvider: (() -> String?)? = nil

    /// Configuration for automatic event capture (clicks, rage clicks, dead clicks).
    ///
    /// Autocapture is **disabled by default**. Provide an `AutocaptureOptions` instance
    /// to enable automatic capture of user interactions.
    ///
    /// **Example — Enable autocapture with defaults:**
    /// ```swift
    /// let options = MixpanelOptions(
    ///     token: "YOUR_TOKEN",
    ///     autocaptureOptions: AutocaptureOptions()
    /// )
    /// ```
    ///
    /// **Note:** Autocapture is only available on iOS.
    #if os(iOS)
    public var autocaptureOptions: AutocaptureOptions? = nil
    #endif

    /// Initializer requiring only a token.
    /// All other properties use their default values and can be configured after initialization.
    ///
    /// **Example:**
    /// ```swift
    /// let options = MixpanelOptions(token: "YOUR_TOKEN")
    /// options.flushInterval = 30
    /// options.trackAutomaticEvents = true
    /// let mixpanel = Mixpanel.initialize(options: options)
    /// ```
    ///
    /// - parameter token: Your Mixpanel project token
    public init(token: String) {
        self.token = token
    }

    /// Backward compatible convenience initializer with fixed set of configuration parameters.
    ///
    /// **Recommended:** Use `init(token:)` instead and set properties after initialization
    /// for a cleaner, more flexible API:
    /// ```swift
    /// let options = MixpanelOptions(token: "YOUR_TOKEN")
    /// options.flushInterval = 30
    /// options.serverURL = "https://api-eu.mixpanel.com"
    /// ```
    ///
    /// This initializer is maintained for backward compatibility but may be deprecated in a future release.
    public convenience init(
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
        featureFlagOptions: FeatureFlagOptions? = nil,
        excludeProperties: Set<String> = [],
    ) {
        self.init(token: token)
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

// MARK: - Internal Copy Support

extension MixpanelOptions {
    /// Creates a deep copy of this MixpanelOptions instance.
    ///
    /// The SDK uses this internally to create an immutable snapshot of the configuration
    /// at initialization time. This ensures that changes to the original options object
    /// after `Mixpanel.initialize()` do not affect the running SDK instance.
    ///
    /// All properties are copied:
    /// - Value types (String, Bool, Double, etc.) are copied by value
    /// - Struct types (FeatureFlagOptions, AutocaptureOptions, etc.) are copied by value
    /// - Closure references (deviceIdProvider) are preserved
    /// - Weak references (proxyServerConfig.delegate) point to the same delegate instance
    internal func copy() -> MixpanelOptions {
        let copy = MixpanelOptions(token: self.token)
        copy.flushInterval = self.flushInterval
        copy.instanceName = self.instanceName
        copy.trackAutomaticEvents = self.trackAutomaticEvents
        copy.optOutTrackingByDefault = self.optOutTrackingByDefault
        copy.useUniqueDistinctId = self.useUniqueDistinctId
        copy.superProperties = self.superProperties
        copy.serverURL = self.serverURL
        copy.proxyServerConfig = self.proxyServerConfig
        copy.useGzipCompression = self.useGzipCompression
        copy.featureFlagOptions = self.featureFlagOptions
        copy.deviceIdProvider = self.deviceIdProvider
        copy.excludeProperties = self.excludeProperties
        #if os(iOS)
        copy.autocaptureOptions = self.autocaptureOptions
        #endif
        return copy
    }
}
