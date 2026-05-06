import Foundation
import jsonlogic

// MARK: - AnyCodable

// Wrapper to help decode 'Any' types within Codable structures
// (Keep AnyCodable as defined previously, it holds the necessary decoding logic)
struct AnyCodable: Decodable {
  let value: Any?

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let intValue = try? container.decode(Int.self) {
      value = intValue
    } else if let doubleValue = try? container.decode(Double.self) {
      value = doubleValue
    } else if let stringValue = try? container.decode(String.self) {
      value = stringValue
    } else if let boolValue = try? container.decode(Bool.self) {
      value = boolValue
    } else if let arrayValue = try? container.decode([AnyCodable].self) {
      value = arrayValue.map { $0.value }
    } else if let dictValue = try? container.decode([String: AnyCodable].self) {
      value = dictValue.mapValues { $0.value }
    } else if container.decodeNil() {
      value = nil
    } else {
      let context = DecodingError.Context(
        codingPath: decoder.codingPath, debugDescription: "Unsupported type in AnyCodable.")
      throw DecodingError.dataCorrupted(context)
    }
  }
}

// Represents the variant associated with a feature flag
public struct MixpanelFlagVariant: Decodable {
  public let key: String  // Corresponds to 'variant_key' from API
  public let value: Any?  // Corresponds to 'variant_value' from API
  public let experimentID: String? // Corresponds to 'experiment_id' from API
  public let isExperimentActive: Bool? // Corresponds to 'is_experiment_active' from API
  public let isQATester: Bool? // Corresponds to 'is_qa_tester' from API

  /// Where this variant was sourced from. Always non-nil — every `MixpanelFlagVariant`
  /// carries a definite source. `.fallback` for developer-supplied fallback instances;
  /// `.network` or `.persistence(persistedAt:)` when the SDK serves a variant. For
  /// persisted variants, the timestamp lives on the `.persistence` case so invalid
  /// combinations like "network with a timestamp" are unrepresentable.
  public let source: Source

  /// Identifies where a served variant came from.
  public enum Source {
    /// Variant assigned by the most recent successful `/flags/` network call.
    case network
    /// Variant loaded from the on-disk persistence layer. `persistedAt` is the time the
    /// variant set was originally written to disk.
    case persistence(persistedAt: Date)
    /// Developer-supplied fallback returned because the SDK had no value to serve (flag
    /// not in the loaded set, flags never loaded, fetch failed under NetworkFirst, etc.).
    case fallback
  }

  enum CodingKeys: String, CodingKey {
    case key = "variant_key"
    case value = "variant_value"
    case experimentID = "experiment_id"
    case isExperimentActive = "is_experiment_active"
    case isQATester = "is_qa_tester"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    key = try container.decode(String.self, forKey: .key)

    // Directly decode the 'variant_value' using AnyCodable.
    // If the key is missing, it throws.
    // If the value is null, AnyCodable handles it.
    // If the value is an unsupported type, AnyCodable throws.
    let anyCodableValue = try container.decode(AnyCodable.self, forKey: .value)
    value = anyCodableValue.value  // Extract the underlying Any? value

    // Decode optional fields for tracking
    experimentID = try container.decodeIfPresent(String.self, forKey: .experimentID)
    isExperimentActive = try container.decodeIfPresent(Bool.self, forKey: .isExperimentActive)
    isQATester = try container.decodeIfPresent(Bool.self, forKey: .isQATester)
    // Decoded variants are immediately re-stamped via `withSource` before being placed in
    // `flags`, so the customer never observes `.fallback` here. Defaulting to `.fallback`
    // keeps `source` non-optional without needing a sentinel "unstamped" case.
    source = .fallback
  }

  // Helper initializer with fallbacks, value defaults to key if nil
  public init(key: String = "", value: Any? = nil, isExperimentActive: Bool? = nil, isQATester: Bool? = nil, experimentID: String? = nil) {
    self.key = key
    if let value = value {
      self.value = value
    } else {
      self.value = key
    }
    self.experimentID = experimentID
    self.isExperimentActive = isExperimentActive
    self.isQATester = isQATester
    self.source = .fallback
  }

  /// Internal initializer used when stamping a served variant with its origin.
  internal init(
    key: String,
    value: Any?,
    experimentID: String?,
    isExperimentActive: Bool?,
    isQATester: Bool?,
    source: Source
  ) {
    self.key = key
    self.value = value
    self.experimentID = experimentID
    self.isExperimentActive = isExperimentActive
    self.isQATester = isQATester
    self.source = source
  }

  /// Returns a copy of this variant stamped with the given source. Other fields are preserved.
  internal func withSource(_ source: Source) -> MixpanelFlagVariant {
    return MixpanelFlagVariant(
      key: self.key,
      value: self.value,
      experimentID: self.experimentID,
      isExperimentActive: self.isExperimentActive,
      isQATester: self.isQATester,
      source: source
    )
  }
}

// MARK: - PendingFirstTimeEvent

/// Represents a pending first-time event definition from the flags endpoint
struct PendingFirstTimeEvent: Decodable {
    let flagKey: String
    let flagId: String
    let projectId: Int
    let firstTimeEventHash: String
    let eventName: String
    let propertyFilters: [String: Any]?
    let propertyFiltersJSON: String?
    let pendingVariant: MixpanelFlagVariant

    enum CodingKeys: String, CodingKey {
        case flagKey = "flag_key"
        case flagId = "flag_id"
        case projectId = "project_id"
        case firstTimeEventHash = "first_time_event_hash"
        case eventName = "event_name"
        case propertyFilters = "property_filters"
        case pendingVariant = "pending_variant"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flagKey = try container.decode(String.self, forKey: .flagKey)
        flagId = try container.decode(String.self, forKey: .flagId)
        projectId = try container.decode(Int.self, forKey: .projectId)
        firstTimeEventHash = try container.decode(String.self, forKey: .firstTimeEventHash)
        eventName = try container.decode(String.self, forKey: .eventName)
        pendingVariant = try container.decode(MixpanelFlagVariant.self, forKey: .pendingVariant)

        // Decode propertyFilters using AnyCodable
        if let filtersContainer = try? container.decode([String: AnyCodable].self, forKey: .propertyFilters) {
            let filters = filtersContainer.mapValues { $0.value as Any }
            propertyFilters = filters
            if let jsonData = try? JSONSerialization.data(withJSONObject: filters) {
                propertyFiltersJSON = String(data: jsonData, encoding: .utf8)
            } else {
                propertyFiltersJSON = nil
            }
        } else {
            propertyFilters = nil
            propertyFiltersJSON = nil
        }
    }
}

// Response structure for the /flags endpoint
struct FlagsResponse: Decodable {
  let flags: [String: MixpanelFlagVariant]?  // Dictionary where key is flag name
  let pendingFirstTimeEvents: [PendingFirstTimeEvent]?  // Array of pending first-time event definitions

  enum CodingKeys: String, CodingKey {
    case flags
    case pendingFirstTimeEvents = "pending_first_time_events"
  }
}

// --- FeatureFlagDelegate Protocol ---
public protocol MixpanelFlagDelegate: AnyObject {
  func getOptions() -> MixpanelOptions
  func getDistinctId() -> String
  func getAnonymousId() -> String?
  func track(event: String?, properties: Properties?)
}

/// A protocol defining the public interface for a feature flagging system.
public protocol MixpanelFlags {

  /// The delegate responsible for handling feature flag lifecycle events,
  /// such as tracking. It is declared `weak` to prevent retain cycles.
  var delegate: MixpanelFlagDelegate? { get set }

  // --- Public Methods ---

  /// Initiates the loading or refreshing of flags
  func loadFlags()

  /// Initiates the loading or refreshing of flags with a completion callback.
  /// The completion handler is called with `true` on success and `false` on failure.
  func loadFlags(completion: ((Bool) -> Void)?)

  /// Synchronously checks if flag variants are in memory and available for synchronous access.
  ///
  /// - Note: When a persisting `variantLookupPolicy` is configured (`.persistenceUntilNetworkSuccess` or
  ///   `.networkFirst`), this can return `true` before the SDK has spoken to the network this
  ///   session — the returned variants may be stale data from a previous session. Use the
  ///   `source` field on the served `MixpanelFlagVariant` to distinguish: `.network` for
  ///   fresh values, `.persistence(persistedAt:)` for on-disk persisted values (with the
  ///   persistence timestamp).
  ///
  /// - Returns: `true` if flag variants are available in memory (from network or persistence),
  ///            `false` otherwise.
  func areFlagsReady() -> Bool

  // --- Sync Flag Retrieval ---

  /// Synchronously retrieves the complete `MixpanelFlagVariant` for a given flag name.
  /// If the feature flag is found and flags are ready, its variant is returned.
  /// Otherwise, the provided `fallback` `MixpanelFlagVariant` is returned.
  /// This method will also trigger any necessary tracking logic for the accessed flag.
  ///
  /// - Important: This method may block the calling thread until the value can be retrieved.
  ///   It is NOT recommended to call this from the main UI thread.
  ///   If flags are not ready (`areFlagsReady()` is false), this method returns the `fallback`
  ///   value, but it may still block while waiting for queued tracking or activation work to complete.
  ///   If called immediately after track(), variants may not be activated yet due to a
  ///   race condition as track is executed asynchronously. Use `getVariant` instead.
  ///
  /// - Parameters:
  ///   - flagName: The unique identifier for the feature flag.
  ///   - fallback: The `MixpanelFlagVariant` to return if the specified flag is not found
  ///               or if the flags are not yet loaded.
  /// - Returns: The `MixpanelFlagVariant` associated with `flagName`, or the `fallback` variant.
  func getVariantSync(_ flagName: String, fallback: MixpanelFlagVariant) -> MixpanelFlagVariant

  /// Asynchronously retrieves the complete `MixpanelFlagVariant` for a given flag name.
  /// If flags are not ready, an attempt will be made to load them.
  /// The `completion` handler is called with the `MixpanelFlagVariant` for the flag,
  /// or the `fallback` variant if the flag is not found or loading fails.
  /// This method will also trigger any necessary tracking logic for the accessed flag.
  /// The completion handler is typically invoked on the main thread.
  ///
  /// - Parameters:
  ///   - flagName: The unique identifier for the feature flag.
  ///   - fallback: The `MixpanelFlagVariant` to use as a default if the specified flag
  ///               is not found or an error occurs during fetching.
  ///   - completion: A closure that is called with the resulting `MixpanelFlagVariant`.
  ///                 This closure will be executed on the main dispatch queue.
  func getVariant(
    _ flagName: String, fallback: MixpanelFlagVariant,
    completion: @escaping (MixpanelFlagVariant) -> Void)

  /// Synchronously retrieves the underlying value of a feature flag.
  /// This is a convenience method that extracts the `value` property from the `MixpanelFlagVariant`
  /// obtained via `getVariantSync`.
  ///
  /// - Important: This method may block the calling thread until the value can be retrieved.
  ///   It is NOT recommended to call this from the main UI thread.
  ///   If flags are not ready (`areFlagsReady()` is false), this method returns the `fallbackValue`,
  ///   but it may still block while waiting for queued tracking or activation work to complete.
  ///   If called immediately after track(), variants may not be activated yet due to a
  ///   race condition as track is executed asynchronously. Use `getVariantValue` instead.
  ///
  /// - Parameters:
  ///   - flagName: The unique identifier for the feature flag.
  ///   - fallbackValue: The default value to return if the flag is not found,
  ///                    its variant doesn't contain a value, or flags are not ready.
  /// - Returns: The value of the feature flag, or `fallbackValue`. The type is `Any?`.
  func getVariantValueSync(_ flagName: String, fallbackValue: Any?) -> Any?

  /// Asynchronously retrieves the underlying value of a feature flag.
  /// This is a convenience method that extracts the `value` property from the `MixpanelFlagVariant`
  /// obtained via `getVariant`. If flags are not ready, an attempt will be made to load them.
  /// The `completion` handler is called with the flag's value or the `fallbackValue`.
  /// The completion handler is typically invoked on the main thread.
  ///
  /// - Parameters:
  ///   - flagName: The unique identifier for the feature flag.
  ///   - fallbackValue: The default value to use if the flag is not found,
  ///                    fetching fails, or its variant doesn't contain a value.
  ///   - completion: A closure that is called with the resulting value (`Any?`).
  ///                 This closure will be executed on the main dispatch queue.
  func getVariantValue(
    _ flagName: String, fallbackValue: Any?, completion: @escaping (Any?) -> Void)

  /// Synchronously checks if a specific feature flag is considered "enabled".
  /// This typically involves retrieving the flag's value and evaluating it as a boolean.
  /// The exact logic for what constitutes "enabled" (e.g., `true`, non-nil, a specific string)
  /// should be defined by the implementing class.
  ///
  /// - Important: This method may block the calling thread until the value can be retrieved.
  ///   It is NOT recommended to call this from the main UI thread.
  ///   If flags are not ready (`areFlagsReady()` is false), this method returns the `fallbackValue`,
  ///   but it may still block while waiting for queued tracking or activation work to complete.
  ///
  /// - Parameters:
  ///   - flagName: The unique identifier for the feature flag.
  ///   - fallbackValue: The boolean value to return if the flag is not found,
  ///                    cannot be evaluated as a boolean, or flags are not ready. Defaults to `false`.
  /// - Returns: `true` if the flag is considered enabled, `false` otherwise (including if `fallbackValue` is used).
  func isEnabledSync(_ flagName: String, fallbackValue: Bool) -> Bool

  /// Asynchronously checks if a specific feature flag is considered "enabled".
  /// This typically involves retrieving the flag's value and evaluating it as a boolean.
  /// If flags are not ready, an attempt will be made to load them.
  /// The `completion` handler is called with the boolean result.
  /// The completion handler is typically invoked on the main thread.
  ///
  /// - Parameters:
  ///   - flagName: The unique identifier for the feature flag.
  ///   - fallbackValue: The boolean value to use if the flag is not found, fetching fails,
  ///                    or it cannot be evaluated as a boolean. Defaults to `false`.
  ///   - completion: A closure that is called with the boolean result.
  ///                 This closure will be executed on the main dispatch queue.
  func isEnabled(_ flagName: String, fallbackValue: Bool, completion: @escaping (Bool) -> Void)

  // --- Bulk Flag Retrieval ---

  /// Synchronously retrieves all currently fetched feature flag variants.
  /// Returns an empty dictionary if flags have not been loaded yet.
  /// This method does not trigger tracking for any flags.
  ///
  /// - Important: This method may block the calling thread until the value can be retrieved.
  ///   It is NOT recommended to call this from the main UI thread.
  ///   If flags are not ready (`areFlagsReady()` is false), it returns an empty dictionary
  ///   immediately without fetching, but it may still block while waiting for queued tracking
  ///   or activation work to complete.
  ///   If called immediately after track(), variants may not be activated yet due to a
  ///   race condition as track is executed asynchronously. Use `getAllVariants` instead.
  ///
  /// - Returns: A dictionary mapping flag names to their `MixpanelFlagVariant` values,
  ///            or an empty dictionary if flags are not ready.
  func getAllVariantsSync() -> [String: MixpanelFlagVariant]

  /// Asynchronously retrieves all feature flag variants.
  /// If flags are not ready, an attempt will be made to load them.
  /// This method does not trigger tracking for any flags.
  /// The completion handler is typically invoked on the main thread.
  ///
  /// - Parameter completion: A closure that is called with a dictionary mapping flag names
  ///                         to their `MixpanelFlagVariant` values. Returns an empty dictionary
  ///                         if fetching fails.
  func getAllVariants(completion: @escaping ([String: MixpanelFlagVariant]) -> Void)

  /// Replaces the current custom flag evaluation context entirely and triggers a flag re-fetch.
  ///
  /// In-memory variants and the on-disk persistence layer are intentionally NOT cleared — the
  /// persistence layer is keyed on distinctId only, so it remains valid for this user across
  /// context changes. The next successful fetch under the new context will overwrite the
  /// persistence layer with fresh values.
  ///
  /// - Parameters:
  ///   - context: The new context dictionary to use for flag evaluation.
  ///   - completion: A closure called when the fetch under the new context completes (success
  ///     or failure). Always invoked exactly once.
  func setContext(_ context: [String: Any], completion: @escaping () -> Void)
}

// --- FeatureFlagManager Class ---

class FeatureFlagManager: MixpanelFlags {

  weak var delegate: MixpanelFlagDelegate? {
    didSet {
      if let context = delegate?.getOptions().featureFlagOptions.context, !context.isEmpty {
        flagsLock.write {
          if self.flagContext.isEmpty {
            self.flagContext = context
          }
        }
      }
    }
  }

    var serverURL: String!
  // Thread safety using ReadWriteLock (consistent with Track, People, MixpanelInstance)
  internal let flagsLock = ReadWriteLock(label: "com.mixpanel.featureflagmanager")

  // Internal State - Protected by flagsLock
  var flags: [String: MixpanelFlagVariant]? = nil
  var isFetching: Bool = false
  private var trackedFeatures: Set<String> = Set()
  private var fetchCompletionHandlers: [(Bool) -> Void] = []

  /// True when `flags` was populated from the on-disk persistence layer and we have not yet
  /// seen the initial network response for the current user/context. Only set for
  /// `.networkFirst` — `.persistenceUntilNetworkSuccess` serves persisted values immediately. Async lookups
  /// gate on this to honor the NetworkFirst spec ("await on network call, only serve persisted
  /// values if it fails") while still letting sync lookups + areFlagsReady() see the persisted
  /// values.
  internal var awaitingInitialNetworkResponse: Bool = false

  /// `persistedAt` from the persisted blob currently sitting in `flags`. Lifetime matches
  /// the persistence-derived state (`flags` + `pendingFirstTimeEvents`):
  ///   - Set in `_loadPersistedVariants` when we read the blob from disk
  ///   - Cleared in the network-fetch success closure (the in-memory blob is fully
  ///     `.network`-stamped after a refresh, so the persisted timestamp no longer applies)
  ///   - Cleared in `reset()` along with the rest of the per-user state
  ///
  /// Stored separately from the `.persistence(persistedAt:)` variant case so we can answer
  /// "is the loaded blob past TTL?" even when `flags` is empty (the previous session may
  /// have persisted an empty response).
  ///
  /// `internal` so tests that inject `.persistence` variants directly can match the
  /// production invariant.
  internal var loadedBlobPersistedAt: Date?

  /// Per-instance name used as the UserDefaults key prefix for the on-disk persistence layer.
  /// Captured from the delegate at init so we can persist/clear without holding a delegate
  /// reference during async work.
  private let instanceName: String

  // First-time event targeting state
  internal var pendingFirstTimeEvents: [String: PendingFirstTimeEvent] = [:]  // Keyed by "flagKey:firstTimeEventHash"

  /// O(1) lookup set of event names that have pending first-time events.
  /// Maintained in parallel with `pendingFirstTimeEvents` to avoid iterating
  /// the full dictionary on every tracked event.
  internal var pendingFirstTimeEventNames: Set<String> = Set()

  /// Stores "flagKey:firstTimeEventHash" keys for activated first-time events.
  /// This set grows throughout the session as events are activated.
  /// It is session-scoped and cleared on app restart.
  internal var activatedFirstTimeEvents: Set<String> = Set()

  // Flag evaluation context (protected by flagsLock)
  private var flagContext: [String: Any]

  // Timing tracking properties
  private var fetchStartTime: Date?
  var timeLastFetched: Date?
  var fetchLatencyMs: Int?

  /// Bumped on `reset()` so in-flight fetches dispatched pre-reset don't poison post-reset state.
  /// Captured at the start of `_performFetchRequest` and re-checked before applying results.
  private var fetchGeneration: Int = 0

  // Configuration
  private var currentOptions: MixpanelOptions? { delegate?.getOptions() }
  private var flagsRoute = "/flags/"

  // Queue for synchronizing flag operations with tracking. `internal` rather than `private`
  // so tests can post barrier tasks to wait for queued work (persistence load on init, etc.).
  internal var trackingQueue: DispatchQueue

  // Initializers
    internal init(
      serverURL: String,
      trackingQueue: DispatchQueue,
      instanceName: String,
      delegate: MixpanelFlagDelegate? = nil
    ) {
        self.serverURL = serverURL
        self.trackingQueue = trackingQueue
        self.instanceName = instanceName
        self.delegate = delegate
        self.flagContext = delegate?.getOptions().featureFlagOptions.context ?? [:]

        // Dispatch the init-time persistence work on the tracking queue so UserDefaults I/O
        // doesn't block the caller (typically the main thread during MixpanelInstance
        // construction). Persisting policies load the persistence layer; `.networkOnly` wipes
        // any stale blob left over from a previous session that used a persisting policy.
        if let options = delegate?.getOptions(), options.featureFlagOptions.enabled {
            switch options.featureFlagOptions.variantLookupPolicy {
            case .persistenceUntilNetworkSuccess, .networkFirst:
                trackingQueue.async { [weak self] in
                    self?._loadPersistedVariants()
                }
            case .networkOnly:
                trackingQueue.async { [weak self] in
                    guard let self = self else { return }
                    MixpanelPersistence.deleteFlagsPersistence(instanceName: self.instanceName)
                }
            }
        }
    }

  // --- Public Methods ---

  func loadFlags() {
    loadFlags(completion: nil)
  }

  func loadFlags(completion: ((Bool) -> Void)?) {
    // Dispatch fetch trigger to allow caller to continue
      trackingQueue.async { [weak self] in
      self?._fetchFlagsIfNeeded(completion: completion)
    }
  }

  /// Clears all in-memory feature flag state (in-memory variants, tracked-flag set, fetch
  /// timing, first-time event state) AND wipes the on-disk persistence blob. Intended for
  /// identity-change paths: `MixpanelInstance.reset()`, `identify` when distinctId actually
  /// changes, and `optOutTracking`. `setContext` deliberately does NOT call this — context
  /// changes don't invalidate the persisted blob (it is keyed on distinctId only).
  ///
  /// Posts to the tracking queue so the mutation is serialized with reads and fetches. Any
  /// in-flight fetch dispatched before this call is discarded when it completes (via the
  /// generation check in `_performFetchRequest`'s success/failure closures). Pending
  /// fetch-completion handlers are invoked with `false` so callers don't hang.
  func reset() {
    trackingQueue.async { [weak self] in
      guard let self = self else { return }

      var orphanedHandlers: [(Bool) -> Void] = []
      self.flagsLock.write {
        self.fetchGeneration &+= 1
        self.flags = nil
        self.loadedBlobPersistedAt = nil
        self.trackedFeatures.removeAll()
        self.pendingFirstTimeEvents.removeAll()
        self.pendingFirstTimeEventNames.removeAll()
        self.activatedFirstTimeEvents.removeAll()
        self.fetchStartTime = nil
        self.timeLastFetched = nil
        self.fetchLatencyMs = nil
        self.awaitingInitialNetworkResponse = false
        orphanedHandlers = self.fetchCompletionHandlers
        self.fetchCompletionHandlers.removeAll()
        self.isFetching = false
      }

      // Wipe the on-disk persistence blob so a freshly-identified user can't be served the
      // prior user's variants. `MixpanelInstance.reset()` also wipes via
      // deleteMPUserDefaultsData, so this is defensive (idempotent) but keeps the manager
      // self-contained.
      MixpanelPersistence.deleteFlagsPersistence(instanceName: self.instanceName)

      DispatchQueue.main.async {
        orphanedHandlers.forEach { $0(false) }
      }
    }
  }

  func setContext(_ context: [String: Any], completion: @escaping () -> Void) {
    flagsLock.write {
      self.flagContext = context
    }
    trackingQueue.async { [weak self] in
      self?._fetchFlagsIfNeeded { _ in
        completion()
      }
    }
  }

  func areFlagsReady() -> Bool {
    var result: Bool = false
    flagsLock.read {
      result = (flags != nil)
    }
    return result
  }

  // --- Sync Flag Retrieval ---

  func getVariantSync(_ flagName: String, fallback: MixpanelFlagVariant) -> MixpanelFlagVariant {
    if Thread.isMainThread {
      MixpanelLogger.warn(
        message: "It is NOT recommended to call this method from the main thread as it might block the calling thread until the value can be retrieved. Consider using async getVariant() instead."
      )
    }
      return _getVariantSyncImpl(flagName, fallback: fallback)
  }

  private func _getVariantSyncImpl(_ flagName: String, fallback: MixpanelFlagVariant) -> MixpanelFlagVariant {
    var flagVariant: MixpanelFlagVariant?
    var tracked = false
    var capturedTimeLastFetched: Date?
    var capturedFetchLatencyMs: Int?

    // Use write lock to perform atomic check-and-set for tracking
    flagsLock.write {
      guard let currentFlags = self.flags else { return }

      // Treat expired persisted variants as not-present — return the developer fallback and
      // skip tracking, since the customer effectively didn't receive a value. The blob
      // stays on disk; the next successful fetch overwrites it.
      if let variant = currentFlags[flagName], !self.isVariantExpired(variant) {
        flagVariant = variant

        // Perform atomic check-and-set for tracking
        if !self.trackedFeatures.contains(flagName) {
          self.trackedFeatures.insert(flagName)
          tracked = true
          // Capture timing data while in lock
          capturedTimeLastFetched = self.timeLastFetched
          capturedFetchLatencyMs = self.fetchLatencyMs
        }
      }
      // If flag wasn't found OR was expired, flagVariant remains nil
    }

    // Now, process the results outside the lock

    if let foundVariant = flagVariant {
      // If tracking was done *in this call*, call the delegate with timing data
      if tracked {
        self._performTrackingDelegateCall(
          flagName: flagName,
          variant: foundVariant,
          timeLastFetched: capturedTimeLastFetched,
          fetchLatencyMs: capturedFetchLatencyMs
        )
      }
      return foundVariant
    } else {
      MixpanelLogger.info(message: "Flag '\(flagName)' not found or flags not ready. Returning fallback.")
      return fallback
    }
  }

  // --- Async Flag Retrieval ---

  func getVariant(
    _ flagName: String, fallback: MixpanelFlagVariant,
    completion: @escaping (MixpanelFlagVariant) -> Void
  ) {
      trackingQueue.async { [weak self] in
      guard let self = self else { return }

      var flagVariant: MixpanelFlagVariant?
      var needsTrackingCheck = false
      var canServeImmediately = false

      // Read state with lock. Serve immediately when flags are populated, we're not in the
      // NetworkFirst-init window (waiting for the first network response after a persistence
      // hit), AND the loaded blob isn't past TTL. The blob-staleness check is what makes the
      // async path fall through to a fetch when persisted values have aged out mid-session —
      // the inline TTL check below would otherwise silently serve the developer fallback
      // without refreshing.
      self.flagsLock.read {
        guard let currentFlags = self.flags,
              !self.awaitingInitialNetworkResponse,
              !self.loadedFlagsAreStale() else { return }
        canServeImmediately = true
        if let variant = currentFlags[flagName], !self.isVariantExpired(variant) {
          flagVariant = variant
          needsTrackingCheck = !self.trackedFeatures.contains(flagName)
        }
      }

      if canServeImmediately {
        let result = flagVariant ?? fallback
        if flagVariant != nil, needsTrackingCheck {
          // Perform atomic check-and-track
          self._trackFlagIfNeeded(flagName: flagName, variant: result)
        }
        DispatchQueue.main.async { completion(result) }

      } else {
        // Flags not yet servable. Either nothing in memory, or NetworkFirst awaiting the
        // initial network response. Trigger a fetch and serve from `flags` afterward.
        // On failure, `flags` is left untouched: NetworkFirst with a persistence hit still
        // has persisted values (Source.persistence); everything else stays nil and we serve
        // the fallback.
        MixpanelLogger.debug(message: "Flags not yet servable, attempting fetch for getVariant '\(flagName)'...")
        self._fetchFlagsIfNeeded { _ in
          // Hop back to the tracking queue so we can read flags + run the tracking check
          // atomically. Whether the fetch succeeded or not, _getVariantSyncImpl returns the
          // variant from `flags` if present (persisted or network) else the fallback.
          self.trackingQueue.async {
            let result = self._getVariantSyncImpl(flagName, fallback: fallback)
            DispatchQueue.main.async { completion(result) }
          }
        }
      }
    }
  }

  func getVariantValueSync(_ flagName: String, fallbackValue: Any?) -> Any? {
    return getVariantSync(flagName, fallback: MixpanelFlagVariant(value: fallbackValue)).value
  }

  func getVariantValue(
    _ flagName: String, fallbackValue: Any?, completion: @escaping (Any?) -> Void
  ) {
    getVariant(flagName, fallback: MixpanelFlagVariant(value: fallbackValue)) { flagVariant in
      completion(flagVariant.value)
    }
  }

  func isEnabledSync(_ flagName: String, fallbackValue: Bool = false) -> Bool {
    let variantValue = getVariantValueSync(flagName, fallbackValue: fallbackValue)
    return self._evaluateBooleanFlag(
      flagName: flagName, variantValue: variantValue, fallbackValue: fallbackValue)
  }

  func isEnabled(
    _ flagName: String, fallbackValue: Bool = false, completion: @escaping (Bool) -> Void
  ) {
    getVariantValue(flagName, fallbackValue: fallbackValue) { [weak self] variantValue in
      guard let self = self else {
        completion(fallbackValue)
        return
      }
      let result = self._evaluateBooleanFlag(
        flagName: flagName, variantValue: variantValue, fallbackValue: fallbackValue)
      completion(result)
    }
  }

  // --- Bulk Flag Retrieval ---

    func getAllVariantsSync() -> [String: MixpanelFlagVariant] {
        if Thread.isMainThread {
            MixpanelLogger.warn(
                message: "It is NOT recommended to call this method from the main thread as it might block the calling thread until the value can be retrieved. Consider using async getAllVariants() instead."
            )
        }
        return _getAllVariantsSyncImpl()
    }

  private func _getAllVariantsSyncImpl() -> [String: MixpanelFlagVariant] {
    var result: [String: MixpanelFlagVariant] = [:]
    flagsLock.read {
      // Filter out expired persisted variants — same rule as getVariantSync. Keep `.network`
      // and unexpired `.persistence(persistedAt:)` entries.
      if let currentFlags = self.flags {
        result = currentFlags.filter { _, variant in !self.isVariantExpired(variant) }
      }
    }
    return result
  }

  func getAllVariants(completion: @escaping ([String: MixpanelFlagVariant]) -> Void) {
      trackingQueue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { completion([:]) }
        return
      }

      var canServeImmediately = false
      self.flagsLock.read {
        canServeImmediately = (self.flags != nil)
          && !self.awaitingInitialNetworkResponse
          && !self.loadedFlagsAreStale()
      }
      if canServeImmediately {
        // Use the sync impl so the expired-filter is applied consistently.
        let result = self._getAllVariantsSyncImpl()
        DispatchQueue.main.async { completion(result) }
      } else {
        // Either nothing in memory yet, NetworkFirst awaiting the initial network response,
        // or the loaded persisted blob is past TTL. Trigger a fetch and serve from `flags`
        // afterward — on success it has the fresh values, on NetworkFirst failure the
        // persisted values stayed in place (still served, _getAllVariantsSyncImpl filters
        // any expired entries).
        MixpanelLogger.debug(message: "Flags not yet servable, attempting fetch for getAllVariants...")
        self._fetchFlagsIfNeeded { _ in
          DispatchQueue.main.async { completion(self._getAllVariantsSyncImpl()) }
        }
      }
    }
  }

  // --- Fetching Logic (Simplified by Serial Queue) ---

  // Internal function to handle fetch logic and state checks
  private func _fetchFlagsIfNeeded(completion: ((Bool) -> Void)?) {
    let optionsSnapshot = self.currentOptions

    guard let options = optionsSnapshot, options.featureFlagOptions.enabled else {
      MixpanelLogger.debug(message: "Feature flags are disabled, not fetching.")
      // Dispatch completion to main queue to avoid potential deadlock
      DispatchQueue.main.async {
        completion?(false)
      }
      return  // Exit method
    }

    var shouldStartFetch = false

    // Access/Modify isFetching and fetchCompletionHandlers with write lock
    flagsLock.write {
      if let completion = completion {
        self.fetchCompletionHandlers.append(completion)
      }
      if !self.isFetching {
        self.isFetching = true
        shouldStartFetch = true
      } else {
        MixpanelLogger.debug(message: "Fetch already in progress, queueing completion handler.")
      }
    }

    if shouldStartFetch {
      MixpanelLogger.info(message: "Starting flag fetch...")
      // Already on a background queue (callers dispatch before calling this method)
      self._performFetchRequest()
    }
  }

  // Performs the actual network request construction and call
  internal func _performFetchRequest() {
    // Record fetch start time and snapshot the current generation. The snapshot is checked
    // in the success/failure closures so a fetch that was dispatched before reset() does not
    // overwrite the freshly cleared state.
    let startTime = Date()
    var generation = 0
    flagsLock.write {
      self.fetchStartTime = startTime
      generation = self.fetchGeneration
    }

    guard let delegate = self.delegate, let options = self.currentOptions else {
      MixpanelLogger.error(message: "Delegate or options missing for fetch.")
      self._completeFetch(success: false)
      return
    }

    let distinctId = delegate.getDistinctId()
    let anonymousId = delegate.getAnonymousId()
    MixpanelLogger.debug(message: "Fetching flags for distinct ID: \(distinctId)")

    var context: [String: Any] = [:]
    flagsLock.read {
      context = self.flagContext
    }
    context["distinct_id"] = distinctId
    if let anonymousId = anonymousId {
      context["device_id"] = anonymousId
    }

    guard
      let contextData = try? JSONSerialization.data(
        withJSONObject: context, options: []),
      let contextString = String(data: contextData, encoding: .utf8)
    else {
      MixpanelLogger.error(message: "Failed to serialize context for flags.")
      self._completeFetch(success: false)
      return
    }

    guard let headers = createAuthHeaders(token: options.token) else {
      MixpanelLogger.error(message: "Failed to create auth headers.")
      self._completeFetch(success: false)
      return
    }

    let queryItems = [
      URLQueryItem(name: "context", value: contextString),
      URLQueryItem(name: "token", value: options.token),
      URLQueryItem(name: "mp_lib", value: "swift"),
      URLQueryItem(name: "$lib_version", value: AutomaticProperties.libVersion())
    ]

    // Capture the raw response bytes via a reference holder so we can persist the wire
    // format unchanged. Storing raw JSON (rather than re-encoding the parsed variants)
    // keeps the parser as the single source of truth and carries `pending_first_time_events`
    // through to subsequent loads for free.
    let rawHolder = RawDataHolder()
    let responseParser: (Data) -> FlagsResponse? = { data in
      rawHolder.data = data
      do { return try JSONDecoder().decode(FlagsResponse.self, from: data) } catch {
        MixpanelLogger.error(message: "Error parsing flags JSON: \(error)")
        return nil
      }
    }
    let resource = Network.buildResource(
      path: flagsRoute, method: .get, queryItems: queryItems, headers: headers,
      parse: responseParser)

    // Capture the distinctId at dispatch time. Using this (rather than re-reading delegate
    // state at write time) ensures the persisted blob is keyed to the user we actually
    // fetched for, even if identify() raced ahead.
    let distinctIdAtDispatch = distinctId

    // Make the API request
    Network.apiRequest(
      base: serverURL,
      resource: resource,
      failure: { [weak self] reason, data, response in
        MixpanelLogger.error(message: "Failed to fetch flags. Reason: \(reason)")
        guard let self = self else { return }
        if self.isStaleFetch(generation: generation) {
          MixpanelLogger.debug(
            message: "Discarding flag fetch failure from stale generation \(generation).")
          return
        }
        // Whether or not we have persisted values, we've definitively failed to get a
        // network response. NetworkFirst async lookups can stop awaiting and serve from
        // `flags` (persisted values stay in place since we don't touch them on failure).
        self.flagsLock.write {
          self.awaitingInitialNetworkResponse = false
        }
        self._completeFetch(success: false)
      },
      success: { [weak self] (flagsResponse, response) in
        MixpanelLogger.info(message: "Successfully fetched flags.  \(flagsResponse)")
        guard let self = self else { return }
        if self.isStaleFetch(generation: generation) {
          MixpanelLogger.debug(
            message: "Discarding flag fetch result from stale generation \(generation).")
          return
        }
        let fetchEndTime = Date()

        // Merge flags and update state with write lock
        let (mergedFlags, mergedPendingEvents, mergedPendingEventNames) = self.mergeFlags(
          responseFlags: flagsResponse.flags,
          responsePendingEvents: flagsResponse.pendingFirstTimeEvents
        )

        // Stamp every variant with .network before publishing. mergeFlags may have preserved
        // some prior-flag entries (activated first-time events) — those came from a prior
        // network response too, so .network is correct for them as well.
        let stampedFlags = mergedFlags.mapValues { $0.withSource(.network) }

        // Snapshot the persistence-policy decision OUTSIDE the lock to avoid calling into
        // the delegate (`getOptions()`) while holding the write lock — keeps the lock
        // surface narrow and avoids potential deadlocks if a future delegate impl ever takes
        // a lock of its own.
        let shouldPersist = self.shouldPersistVariants()

        // Single critical section: gate the in-memory write AND the on-disk persistence
        // write on the same generation check. Without this, a reset() between the lock
        // release and the disk write could leak prior-user variants onto disk under the
        // prior-user distinctId (the next session's distinctId check would catch it, but
        // the disk write is wasted I/O and confusing in logs).
        var didApplyResults = false
        self.flagsLock.write {
          // Re-check generation under the lock in case reset() raced between the check above
          // and the write. If stale, drop the result without touching state or completing.
          guard generation == self.fetchGeneration else { return }
          self.flags = stampedFlags
          self.loadedBlobPersistedAt = nil
          self.pendingFirstTimeEvents = mergedPendingEvents
          self.pendingFirstTimeEventNames = mergedPendingEventNames
          // Network response received — async lookups can stop awaiting (NetworkFirst) and
          // serve from the freshly-populated `flags`.
          self.awaitingInitialNetworkResponse = false

          // Calculate timing metrics
          if let startTime = self.fetchStartTime {
            let latencyMs = Int(fetchEndTime.timeIntervalSince(startTime) * 1000)
            self.fetchLatencyMs = latencyMs
          }
          self.timeLastFetched = fetchEndTime

          MixpanelLogger.debug(message: "Flags updated: \(self.flags ?? [:]), Pending events: \(self.pendingFirstTimeEvents.count)")
          didApplyResults = true
        }

        // Persist the raw response so future sessions / failed fetches can fall back. Writes
        // are gated by the lookup policy via `shouldPersist` (true for `.persistenceUntilNetworkSuccess`
        // and `.networkFirst`, false for `.networkOnly`). Skipped when `didApplyResults` is
        // false because that means the generation check failed (reset raced ahead) and we
        // shouldn't overwrite the persisted blob with prior-user data. UserDefaults I/O is
        // kept outside the lock since it can block.
        if didApplyResults,
           shouldPersist,
           let rawData = rawHolder.data,
           let rawString = String(data: rawData, encoding: .utf8) {
          let blob = FlagsPersistenceBlob(
            persistedAt: fetchEndTime,
            distinctId: distinctIdAtDispatch,
            response: rawString
          )
          MixpanelPersistence.saveFlagsPersistence(blob, instanceName: self.instanceName)
        }

        self._completeFetch(success: true)
      }
    )
  }

  /// Internal reference-type holder so the response-parser closure can hand the raw response
  /// bytes back to the success closure for persistence. Class (not struct) so the captured
  /// reference shares state across closure invocations.
  private final class RawDataHolder {
    var data: Data?
  }

  // MARK: - Persistence Helpers

  /// Loads the on-disk persistence blob, validates distinctId + TTL, parses, stamps every
  /// variant with `.persistence(persistedAt:)`, and writes into `flags`. Both
  /// `.persistenceUntilNetworkSuccess` and `.networkFirst` populate `flags` directly so sync lookups and
  /// `areFlagsReady()` reflect persisted values. The difference between policies is enforced
  /// at async-lookup time via `awaitingInitialNetworkResponse`: `.networkFirst` sets it true
  /// so async lookups await the network call before serving.
  ///
  /// Runs on the tracking queue (called from init).
  internal func _loadPersistedVariants() {
    guard let blob = MixpanelPersistence.loadFlagsPersistence(instanceName: self.instanceName) else {
      return
    }

    // distinctId check — refuse to serve another user's variants under this user's identity.
    // Wipe the stale blob so it doesn't sit on disk for someone who no longer uses this device.
    // This is a parallel of the active "distinctId changes" paths (identify/reset/optOut)
    // applied to the cross-session case where the change happened while the app was killed.
    let delegate = self.delegate
    let currentDistinctId = delegate?.getDistinctId() ?? ""
    if blob.distinctId != currentDistinctId {
      MixpanelLogger.debug(message: "Persisted flags belong to a different distinct_id; clearing.")
      MixpanelPersistence.deleteFlagsPersistence(instanceName: self.instanceName)
      return
    }

    // TTL check — discard expired entries. TTL of 0 means "always expired"; negative TTLs
    // are coerced to default by `persistenceTtlSeconds()`.
    if let ttl = self.persistenceTtlSeconds(),
       Date().timeIntervalSince(blob.persistedAt) > ttl {
      MixpanelLogger.debug(message: "Persisted flags expired; ignoring.")
      return
    }

    // Parse the raw response. The persistence layer self-heals structural failures (bad
    // JSON envelope) on read, but a structurally-valid blob with an unparseable `response`
    // string would stick on disk and fail every cold-start. Wipe it here too so the next
    // successful fetch gets a clean slate.
    guard let responseData = blob.response.data(using: .utf8),
          let parsed = try? JSONDecoder().decode(FlagsResponse.self, from: responseData) else {
      MixpanelLogger.warn(message: "Failed to parse persisted flags response; clearing.")
      MixpanelPersistence.deleteFlagsPersistence(instanceName: self.instanceName)
      return
    }

    let parsedFlags = parsed.flags ?? [:]
    let stamped = parsedFlags.mapValues { $0.withSource(.persistence(persistedAt: blob.persistedAt)) }

    // Build pending-event lookups so first-time event matching keeps working from
    // persistence.
    var pendingEvents: [String: PendingFirstTimeEvent] = [:]
    var pendingEventNames: Set<String> = []
    if let events = parsed.pendingFirstTimeEvents {
      for event in events {
        let key = self.getPendingEventKey(event.flagKey, event.firstTimeEventHash)
        pendingEvents[key] = event
        pendingEventNames.insert(event.eventName)
      }
    }

    // Snapshot the policy OUTSIDE the lock — `currentLookupPolicy()` calls into the delegate,
    // and we don't want to hold a delegate call inside our write lock (a future delegate impl
    // taking its own lock could deadlock). Compute here, branch on it inside the lock.
    let isNetworkFirst: Bool
    if case .networkFirst = self.currentLookupPolicy() {
      isNetworkFirst = true
    } else {
      isNetworkFirst = false
    }

    flagsLock.write {
      // Defer to network values if a fetch already raced ahead of us between init and now.
      guard self.flags == nil else { return }
      self.flags = stamped
      self.loadedBlobPersistedAt = blob.persistedAt
      self.pendingFirstTimeEvents = pendingEvents
      self.pendingFirstTimeEventNames = pendingEventNames
      // For .networkFirst, async lookups must wait for the initial network response. The
      // fetch success/failure path will clear this flag.
      if isNetworkFirst {
        self.awaitingInitialNetworkResponse = true
      }
      MixpanelLogger.debug(message: "Loaded \(stamped.count) persisted variants into memory.")
    }
  }

  /// Returns the configured TTL in seconds, or `nil` for `.networkOnly` (no expiry check).
  /// Negative TTLs are invalid and coerced to `VariantLookupPolicy.defaultTTL` with a warning
  /// (matches the JS SDK). TTL of `0` is valid and means "always expired."
  private func persistenceTtlSeconds() -> TimeInterval? {
    switch self.currentLookupPolicy() {
    case .networkOnly:
      return nil
    case .persistenceUntilNetworkSuccess(let ttl), .networkFirst(let ttl):
      if ttl < 0 {
        MixpanelLogger.warn(
          message: "Negative TTL (\(ttl)) is invalid; using default \(VariantLookupPolicy.defaultTTL)s")
        return VariantLookupPolicy.defaultTTL
      }
      return ttl
    }
  }

  private func currentLookupPolicy() -> VariantLookupPolicy {
    return self.delegate?.getOptions().featureFlagOptions.variantLookupPolicy ?? .networkOnly
  }

  /// Whether successful fetches should be persisted to disk. Derived from the lookup policy:
  /// `.persistenceUntilNetworkSuccess` and `.networkFirst` write to disk; `.networkOnly` doesn't.
  private func shouldPersistVariants() -> Bool {
    switch self.currentLookupPolicy() {
    case .networkOnly:
      return false
    case .persistenceUntilNetworkSuccess, .networkFirst:
      return true
    }
  }

  /// Returns true if the loaded persisted blob is past TTL. Uses `loadedBlobPersistedAt`
  /// rather than inspecting variant sources so the check works uniformly whether the blob
  /// has flags in it or is empty (a previous session may have persisted a no-flags
  /// response — we still want TTL to govern when to refresh).
  ///
  /// Returns false when no persisted blob is in memory or under `.networkOnly`.
  ///
  /// Caller must hold `flagsLock`.
  private func loadedFlagsAreStale() -> Bool {
    guard let persistedAt = self.loadedBlobPersistedAt,
          let ttl = self.persistenceTtlSeconds() else { return false }
    return Date().timeIntervalSince(persistedAt) > ttl
  }

  /// Returns true if the variant was loaded from the persistence layer and has aged past
  /// the configured TTL. `.network` and `.fallback` variants are never expired — including
  /// activated first-time-event variants, which are deliberately stamped `.network` to
  /// survive blob expiration.
  ///
  /// Get-paths use this to skip stale persisted values mid-session — once a variant's TTL
  /// elapses while loaded in memory, subsequent `getVariant` calls return the developer
  /// fallback instead of the stale value. The on-disk blob is intentionally NOT deleted
  /// (per the "don't clear if TTL has expired on getVariant" rule); the next successful
  /// network fetch overwrites it.
  private func isVariantExpired(_ variant: MixpanelFlagVariant) -> Bool {
    guard case .persistence(let persistedAt) = variant.source else { return false }
    guard let ttl = self.persistenceTtlSeconds() else { return false }
    return Date().timeIntervalSince(persistedAt) > ttl
  }

  /// Returns true if the captured `generation` no longer matches the current generation,
  /// meaning the fetch was started before a `reset()` and its result should be discarded.
  private func isStaleFetch(generation: Int) -> Bool {
    var current = 0
    flagsLock.read {
      current = self.fetchGeneration
    }
    return current != generation
  }

  // Centralized fetch completion logic
  func _completeFetch(success: Bool) {
    var handlers: [(Bool) -> Void] = []

    flagsLock.write {
      self.isFetching = false
      handlers = self.fetchCompletionHandlers
      self.fetchCompletionHandlers.removeAll()
    }

    DispatchQueue.main.async {
      handlers.forEach { $0(success) }
    }
  }

  // --- Flag Merging Helper ---
  func mergeFlags(
    responseFlags: [String: MixpanelFlagVariant]?,
    responsePendingEvents: [PendingFirstTimeEvent]?
  ) -> (flags: [String: MixpanelFlagVariant], pendingEvents: [String: PendingFirstTimeEvent], pendingEventNames: Set<String>) {
    var newFlags: [String: MixpanelFlagVariant] = [:]
    var newPendingEvents: [String: PendingFirstTimeEvent] = [:]
    var newPendingEventNames: Set<String> = Set()

    var currentFlags: [String: MixpanelFlagVariant]?
    var activatedEvents: Set<String> = []

    // Read current state with lock
    flagsLock.read {
      currentFlags = self.flags
      activatedEvents = self.activatedFirstTimeEvents
    }

    // Process flags from response
    if let responseFlags = responseFlags {
      for (flagKey, variant) in responseFlags {
        // Check if any event for this flag was activated
        let hasActivatedEvent = activatedEvents.contains { eventKey in
          eventKey.hasPrefix("\(flagKey):")
        }

        if hasActivatedEvent, let currentFlag = currentFlags?[flagKey] {
          // Preserve activated variant
          newFlags[flagKey] = currentFlag
        } else {
          // Use server's current variant
          newFlags[flagKey] = variant
        }
      }
    }

    // Process pending first-time events from response
    if let responsePendingEvents = responsePendingEvents {
      for pendingEvent in responsePendingEvents {
        let eventKey = self.getPendingEventKey(pendingEvent.flagKey, pendingEvent.firstTimeEventHash)

        // Skip if already activated
        if activatedEvents.contains(eventKey) {
          continue
        }

        newPendingEvents[eventKey] = pendingEvent
        newPendingEventNames.insert(pendingEvent.eventName)
      }
    }

    // Preserve orphaned activated flags
    for eventKey in activatedEvents {
      guard let flagKey = self.getFlagKeyFromPendingEventKey(eventKey) else {
        MixpanelLogger.warn(message: "Failed to parse flag key from event key: \(eventKey)")
        continue
      }
      if newFlags[flagKey] == nil, let orphanedFlag = currentFlags?[flagKey] {
        newFlags[flagKey] = orphanedFlag
      }
    }

    return (flags: newFlags, pendingEvents: newPendingEvents, pendingEventNames: newPendingEventNames)
  }

  // --- Tracking Logic ---

  // Performs the atomic check and triggers delegate call if needed
  private func _trackFlagIfNeeded(flagName: String, variant: MixpanelFlagVariant) {
    var shouldCallDelegate = false
    var capturedTimeLastFetched: Date?
    var capturedFetchLatencyMs: Int?

    // Use write lock for atomic check-and-set
    flagsLock.write {
      if !self.trackedFeatures.contains(flagName) {
        self.trackedFeatures.insert(flagName)
        shouldCallDelegate = true
        // Capture timing data while in lock
        capturedTimeLastFetched = self.timeLastFetched
        capturedFetchLatencyMs = self.fetchLatencyMs
      }
    }

    // Call delegate outside the lock if tracking occurred
    if shouldCallDelegate {
      self._performTrackingDelegateCall(
        flagName: flagName,
        variant: variant,
        timeLastFetched: capturedTimeLastFetched,
        fetchLatencyMs: capturedFetchLatencyMs
      )
    }
  }

  // Helper to call the delegate with timing data passed as parameters
  private func _performTrackingDelegateCall(
    flagName: String,
    variant: MixpanelFlagVariant,
    timeLastFetched: Date? = nil,
    fetchLatencyMs: Int? = nil
  ) {
    guard let delegate = self.delegate else { return }

    var properties: Properties = [
      "Experiment name": flagName,
      "Variant name": variant.key,
      "$experiment_type": "feature_flag",
    ]

    // Add timing properties if provided
    if let timeLastFetched = timeLastFetched {
      properties["timeLastFetched"] = Int(timeLastFetched.timeIntervalSince1970)
    }
    if let fetchLatencyMs = fetchLatencyMs {
      properties["fetchLatencyMs"] = fetchLatencyMs
    }

    if let experimentID = variant.experimentID {
      properties["$experiment_id"] = experimentID
    }
    if let isExperimentActive = variant.isExperimentActive {
      properties["$is_experiment_active"] = isExperimentActive
    }
    if let isQATester = variant.isQATester {
      properties["$is_qa_tester"] = isQATester
    }

    // Source tracking properties. `$variant_source` is sent for every served variant
    // (`.network` or `.persistence`) to match the JS SDK. `$persisted_at_in_ms` and
    // `$ttl_in_ms` are persistence-only — the timestamp is the raw epoch millis the blob
    // was written, sent without any delta calculation so the server can derive what it
    // needs. Tracking only fires for served variants, so `.fallback` won't appear here.
    switch variant.source {
    case .network:
      properties["$variant_source"] = "network"
    case .persistence(let persistedAt):
      properties["$variant_source"] = "persistence"
      properties["$persisted_at_in_ms"] = Int(persistedAt.timeIntervalSince1970 * 1000)
      if let ttl = self.persistenceTtlSeconds() {
        properties["$ttl_in_ms"] = Int(ttl * 1000)
      }
    case .fallback:
      break
    }

    // Dispatch delegate call asynchronously to main thread for safety
    DispatchQueue.main.async {
      delegate.track(event: "$experiment_started", properties: properties)
      MixpanelLogger.debug(message: "Tracked $experiment_started for \(flagName) (dispatched to main)")
    }
  }

  // --- Boolean Evaluation Helper ---
  private func _evaluateBooleanFlag(flagName: String, variantValue: Any?, fallbackValue: Bool)
    -> Bool
  {
    guard let val = variantValue else { return fallbackValue }
    if let boolVal = val as? Bool {
      return boolVal
    } else {
      MixpanelLogger.error(message: "Flag '\(flagName)' is not Bool")
      return fallbackValue
    }
  }

  // --- Auth Header Helper ---
  private func createAuthHeaders(token: String, includeContentType: Bool = false) -> [String: String]? {
    guard let authData = "\(token):".data(using: .utf8) else {
      return nil
    }

    var headers = ["Authorization": "Basic \(authData.base64EncodedString())"]

    if includeContentType {
      headers["Content-Type"] = "application/json"
    }

    return headers
  }

  // MARK: - First-Time Event Helpers

  /// Generate a unique key for a pending first-time event
  private func getPendingEventKey(_ flagKey: String, _ firstTimeEventHash: String) -> String {
    return "\(flagKey):\(firstTimeEventHash)"
  }

  /// Extract the flag key from a pending event key
  private func getFlagKeyFromPendingEventKey(_ eventKey: String) -> String? {
    return eventKey.split(separator: ":", maxSplits: 1).first.map { String($0) }
  }

  // MARK: - First-Time Event Checking

    /// Checks if a tracked event matches any pending first-time events and activates the corresponding variant.
    ///
    ///- Note:
    ///   This method **must** be called from the `trackingQueue`.
    ///   Executing this sequentially on the background serial queue ensures that
    ///   any subsequent `getVariant` calls (which also wait for or read from this state)
    ///   will receive the newly activated variant, effectively eliminating the race
    ///   condition between tracking and flag evaluation.
    internal func checkFirstTimeEvents(eventName: String, properties: [String: Any]) {
        // O(1) check: skip iteration if no pending event matches this event name
        var hasPendingEvent = false
        flagsLock.read {
            hasPendingEvent = self.pendingFirstTimeEventNames.contains(eventName)
        }
        guard hasPendingEvent else { return }
        
        // Snapshot pending events with lock
        // Note: We don't snapshot activatedFirstTimeEvents because we'll check it
        // atomically later under write lock to avoid TOCTOU race
        var pendingEventsCopy: [String: PendingFirstTimeEvent] = [:]
        
        flagsLock.read {
            pendingEventsCopy = self.pendingFirstTimeEvents
        }
        
        // Iterate through all pending first-time events
        for (eventKey, pendingEvent) in pendingEventsCopy {
            // Check exact event name match (case-sensitive)
            if eventName != pendingEvent.eventName {
                continue
            }
            
            // Evaluate property filters using json-logic-swift library
            if let filters = pendingEvent.propertyFilters, !filters.isEmpty {
                // Convert to JSON strings for json-logic-swift library
                guard let rulesString = pendingEvent.propertyFiltersJSON,
                      let dataJSON = try? JSONSerialization.data(withJSONObject: properties),
                      let dataString = String(data: dataJSON, encoding: .utf8) else {
                    MixpanelLogger.warn(message: "Failed to serialize JsonLogic filters for event '\(eventKey)' matching '\(eventName)'")
                    continue
                }
                
                // Evaluate the filter
                do {
                    let result: Bool = try applyRule(rulesString, to: dataString)
                    if !result {
                        MixpanelLogger.debug(message: "JsonLogic filter evaluated to false for event '\(eventKey)'")
                        continue
                    }
                } catch {
                    MixpanelLogger.error(message: "JsonLogic evaluation error for event '\(eventKey)': \(error)")
                    continue
                }
            }
            
            // Event matched! Try to activate the variant atomically
            let flagKey = pendingEvent.flagKey
            var shouldActivate = false
            
            // Atomic check-and-set: Ensure only one thread activates this event.
            // This prevents duplicate recordFirstTimeEvent calls and flag variant changes
            // when multiple threads concurrently process the same event.
            flagsLock.write {
                if !activatedFirstTimeEvents.contains(eventKey) {
                    // We won the race - activate this event
                    activatedFirstTimeEvents.insert(eventKey)

                    if flags == nil {
                        flags = [:]
                    }
                    // Stamp NETWORK source — the activated variant came from the prior /flags/
                    // response. Activations are deliberately not written to disk; the
                    // persistence layer stays a passive snapshot of the wire response so it
                    // can be re-loaded verbatim.
                    flags![flagKey] = pendingEvent.pendingVariant.withSource(.network)
                    shouldActivate = true
                }
            }
            
            // Only proceed with external calls if we successfully activated
            if shouldActivate {
                MixpanelLogger.info(message: "First-time event matched for flag '\(flagKey)': \(eventName)")
                
                // Track the feature flag check event with the new variant
                self._trackFlagIfNeeded(flagName: flagKey, variant: pendingEvent.pendingVariant)
                
                guard let delegate = self.delegate else {
                    MixpanelLogger.error(message: "Delegate missing for recording first-time event")
                    return
                }
                
                let distinctId = delegate.getDistinctId()
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    // Record to backend (fire-and-forget)
                    self?.recordFirstTimeEvent(
                        flagId: pendingEvent.flagId,
                        projectId: pendingEvent.projectId,
                        firstTimeEventHash: pendingEvent.firstTimeEventHash,
                        distinctId: distinctId
                    )
                }
            }
        }
    }

  /// Records a first-time event activation to the backend
  internal func recordFirstTimeEvent(flagId: String, projectId: Int, firstTimeEventHash: String, distinctId: String) {
    let url = "/flags/\(flagId)/first-time-events"

    let queryItems = [
      URLQueryItem(name: "mp_lib", value: "swift"),
      URLQueryItem(name: "$lib_version", value: AutomaticProperties.libVersion())
    ]

    let payload: [String: Any] = [
      "distinct_id": distinctId,
      "project_id": projectId,
      "first_time_event_hash": firstTimeEventHash
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
          let options = currentOptions else {
      MixpanelLogger.error(message: "Failed to prepare first-time event recording request")
      return
    }

    guard let headers = createAuthHeaders(token: options.token, includeContentType: true) else {
      MixpanelLogger.error(message: "Failed to create auth headers for first-time event recording")
      return
    }

    let responseParser: (Data) -> Bool? = { _ in true }
    let resource = Network.buildResource(
      path: url,
      method: .post,
      requestBody: jsonData,
      queryItems: queryItems,
      headers: headers,
      parse: responseParser
    )

    MixpanelLogger.debug(message: "Recording first-time event for flag: \(flagId)")

    // Fire-and-forget POST request
    Network.apiRequest(
      base: serverURL,
      resource: resource,
      failure: { reason, _, _ in
        // Silent failure - cohort sync will catch up
        MixpanelLogger.warn(message: "Failed to record first-time event for flag \(flagId): \(reason)")
      },
      success: { _, _ in
        MixpanelLogger.debug(message: "Successfully recorded first-time event for flag \(flagId)")
      }
    )
  }
}

// MARK: - DEBUG Extensions for MixpanelDemo

#if DEBUG
extension PendingFirstTimeEvent {
    init(flagKey: String, flagId: String, projectId: Int,
         firstTimeEventHash: String, eventName: String,
         propertyFilters: [String: Any]?, pendingVariant: MixpanelFlagVariant) {
        self.flagKey = flagKey
        self.flagId = flagId
        self.projectId = projectId
        self.firstTimeEventHash = firstTimeEventHash
        self.eventName = eventName
        self.propertyFilters = propertyFilters
        if let filters = propertyFilters, let jsonData = try? JSONSerialization.data(withJSONObject: filters) {
            self.propertyFiltersJSON = String(data: jsonData, encoding: .utf8)
        } else {
            self.propertyFiltersJSON = nil
        }
        self.pendingVariant = pendingVariant
    }
}

extension FeatureFlagManager {
    internal func injectMockFirstTimeEvents(_ mockEvents: [PendingFirstTimeEvent],
                                           _ mockFlags: [String: MixpanelFlagVariant]) {
        flagsLock.write {
            self.activatedFirstTimeEvents.removeAll()
            self.flags = mockFlags
            self.pendingFirstTimeEvents.removeAll()
            self.pendingFirstTimeEventNames.removeAll()
            for event in mockEvents {
                let key = getPendingEventKey(event.flagKey, event.firstTimeEventHash)
                self.pendingFirstTimeEvents[key] = event
                self.pendingFirstTimeEventNames.insert(event.eventName)
            }
        }
    }

    internal func resetFirstTimeEventsForDemo() {
        flagsLock.write {
            self.activatedFirstTimeEvents.removeAll()
            for (_, event) in self.pendingFirstTimeEvents {
                self.flags?[event.flagKey] = event.pendingVariant
            }
        }
    }

    internal func getPendingEventsForDebug() -> [(eventKey: String, event: PendingFirstTimeEvent)] {
        var result: [(eventKey: String, event: PendingFirstTimeEvent)] = []
        flagsLock.read {
            result = self.pendingFirstTimeEvents.map { (eventKey: $0.key, event: $0.value) }
        }
        return result.sorted { $0.eventKey < $1.eventKey }
    }

    internal func getActivatedEventsForDebug() -> [String] {
        var result: [String] = []
        flagsLock.read {
            result = Array(self.activatedFirstTimeEvents)
        }
        return result.sorted()
    }

    internal func getFlagsForDebug() -> [String: MixpanelFlagVariant] {
        var result: [String: MixpanelFlagVariant] = [:]
        flagsLock.read {
            result = self.flags ?? [:]
        }
        return result
    }
}
#endif
