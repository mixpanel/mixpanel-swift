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
            propertyFilters = filtersContainer.mapValues { $0.value }
        } else {
            propertyFilters = nil
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

  /// Synchronously checks if the flags  have been successfully loaded
  /// and are available for querying.
  ///
  /// - Returns: `true` if the flags are loaded and ready for use, `false` otherwise.
  func areFlagsReady() -> Bool

  // --- Sync Flag Retrieval ---

  /// Synchronously retrieves the complete `MixpanelFlagVariant` for a given flag name.
  /// If the feature flag is found and flags are ready, its variant is returned.
  /// Otherwise, the provided `fallback` `MixpanelFlagVariant` is returned.
  /// This method will also trigger any necessary tracking logic for the accessed flag.
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
}

// --- FeatureFlagManager Class ---

class FeatureFlagManager: Network, MixpanelFlags {

  weak var delegate: MixpanelFlagDelegate?

  // Thread safety using ReadWriteLock (consistent with Track, People, MixpanelInstance)
  private let flagsLock = ReadWriteLock(label: "com.mixpanel.featureflagmanager")

  // Internal State - Protected by flagsLock
  var flags: [String: MixpanelFlagVariant]? = nil
  var isFetching: Bool = false
  private var trackedFeatures: Set<String> = Set()
  private var fetchCompletionHandlers: [(Bool) -> Void] = []

  // First-time event targeting state
  internal var pendingFirstTimeEvents: [String: PendingFirstTimeEvent] = [:]  // Keyed by "flagKey:firstTimeEventHash"

  /// Stores "flagKey:firstTimeEventHash" keys for activated first-time events.
  /// This set grows throughout the session as events are activated.
  /// It is session-scoped and cleared on app restart.
  internal var activatedFirstTimeEvents: Set<String> = Set()

  // Timing tracking properties
  private var fetchStartTime: Date?
  var timeLastFetched: Date?
  var fetchLatencyMs: Int?

  // Configuration
  private var currentOptions: MixpanelOptions? { delegate?.getOptions() }
  private var flagsRoute = "/flags/"

  // Initializers
  required init(serverURL: String) {
    super.init(serverURL: serverURL)
  }

  public init(serverURL: String, delegate: MixpanelFlagDelegate?) {
    self.delegate = delegate
    super.init(serverURL: serverURL)
  }

  // --- Public Methods ---

  func loadFlags() {
    // Dispatch fetch trigger to allow caller to continue
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?._fetchFlagsIfNeeded(completion: nil)
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
    var flagVariant: MixpanelFlagVariant?
    var tracked = false
    var capturedTimeLastFetched: Date?
    var capturedFetchLatencyMs: Int?

    // Use write lock to perform atomic check-and-set for tracking
    flagsLock.write {
      guard let currentFlags = self.flags else { return }

      if let variant = currentFlags[flagName] {
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
      // If flag wasn't found, flagVariant remains nil
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
    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }

      var flagVariant: MixpanelFlagVariant?
      var needsTrackingCheck = false
      var flagsAreCurrentlyReady = false

      // Read state with lock
      self.flagsLock.read {
        flagsAreCurrentlyReady = (self.flags != nil)
        if flagsAreCurrentlyReady, let currentFlags = self.flags {
          if let variant = currentFlags[flagName] {
            flagVariant = variant
            needsTrackingCheck = !self.trackedFeatures.contains(flagName)
          }
        }
      }

      if flagsAreCurrentlyReady {
        let result = flagVariant ?? fallback
        if flagVariant != nil, needsTrackingCheck {
          // Perform atomic check-and-track
          self._trackFlagIfNeeded(flagName: flagName, variant: result)
        }
        DispatchQueue.main.async { completion(result) }

      } else {
        // --- Flags were NOT ready ---
        // Trigger fetch; fetch completion will handle calling the original completion handler
        MixpanelLogger.debug(message: "Flags not ready, attempting fetch for getFeature call...")
        self._fetchFlagsIfNeeded { success in
          // This completion runs *after* fetch completes (or fails)
          let result: MixpanelFlagVariant
          if success {
            // Fetch succeeded, get the flag SYNCHRONOUSLY
            result = self.getVariantSync(flagName, fallback: fallback)
          } else {
            MixpanelLogger.warn(message: "Failed to fetch flags, returning fallback for \(flagName).")
            result = fallback
          }
          // Call original completion (on main thread)
          DispatchQueue.main.async { completion(result) }
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

  // --- Fetching Logic (Simplified by Serial Queue) ---

  // Internal function to handle fetch logic and state checks
  private func _fetchFlagsIfNeeded(completion: ((Bool) -> Void)?) {
    let optionsSnapshot = self.currentOptions

    guard let options = optionsSnapshot, options.featureFlagsEnabled else {
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
      if !self.isFetching {
        self.isFetching = true
        shouldStartFetch = true
        if let completion = completion {
          self.fetchCompletionHandlers.append(completion)
        }
      } else {
        MixpanelLogger.debug(message: "Fetch already in progress, queueing completion handler.")
        if let completion = completion {
          self.fetchCompletionHandlers.append(completion)
        }
      }
    }

    if shouldStartFetch {
      MixpanelLogger.info(message: "Starting flag fetch (dispatching network request)...")
      // Perform network request on a global queue
      DispatchQueue.global(qos: .utility).async { [weak self] in
        self?._performFetchRequest()
      }
    }
  }

  // Performs the actual network request construction and call
  internal func _performFetchRequest() {
    // Record fetch start time
    let startTime = Date()
    flagsLock.write {
      self.fetchStartTime = startTime
    }

    guard let delegate = self.delegate, let options = self.currentOptions else {
      MixpanelLogger.error(message: "Delegate or options missing for fetch.")
      self._completeFetch(success: false)
      return
    }

    let distinctId = delegate.getDistinctId()
    let anonymousId = delegate.getAnonymousId()
    MixpanelLogger.debug(message: "Fetching flags for distinct ID: \(distinctId)")

    var context = options.featureFlagsContext
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

    let responseParser: (Data) -> FlagsResponse? = { data in
      do { return try JSONDecoder().decode(FlagsResponse.self, from: data) } catch {
        MixpanelLogger.error(message: "Error parsing flags JSON: \(error)")
        return nil
      }
    }
    let resource = Network.buildResource(
      path: flagsRoute, method: .get, queryItems: queryItems, headers: headers,
      parse: responseParser)

    // Make the API request
    Network.apiRequest(
      base: serverURL,
      resource: resource,
      failure: { [weak self] reason, data, response in
        MixpanelLogger.error(message: "Failed to fetch flags. Reason: \(reason)")
        self?._completeFetch(success: false)
      },
      success: { [weak self] (flagsResponse, response) in
        MixpanelLogger.info(message: "Successfully fetched flags.")
        guard let self = self else { return }
        let fetchEndTime = Date()

        // Merge flags and update state with write lock
        let (mergedFlags, mergedPendingEvents) = self.mergeFlags(
          responseFlags: flagsResponse.flags,
          responsePendingEvents: flagsResponse.pendingFirstTimeEvents
        )

        self.flagsLock.write {
          self.flags = mergedFlags
          self.pendingFirstTimeEvents = mergedPendingEvents

          // Calculate timing metrics
          if let startTime = self.fetchStartTime {
            let latencyMs = Int(fetchEndTime.timeIntervalSince(startTime) * 1000)
            self.fetchLatencyMs = latencyMs
          }
          self.timeLastFetched = fetchEndTime

          MixpanelLogger.debug(message: "Flags updated: \(self.flags ?? [:]), Pending events: \(self.pendingFirstTimeEvents.count)")
        }

        self._completeFetch(success: true)
      }
    )
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
  ) -> (flags: [String: MixpanelFlagVariant], pendingEvents: [String: PendingFirstTimeEvent]) {
    var newFlags: [String: MixpanelFlagVariant] = [:]
    var newPendingEvents: [String: PendingFirstTimeEvent] = [:]

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

    return (flags: newFlags, pendingEvents: newPendingEvents)
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

  /// Generic recursive transformation function for nested structures
  private func transformStringsRecursively(
    _ val: Any,
    transformDictKey: (String) -> String = { $0 }
  ) -> Any {
    if let stringValue = val as? String {
      return stringValue.lowercased()
    } else if let arrayValue = val as? [Any] {
      return arrayValue.map { transformStringsRecursively($0, transformDictKey: transformDictKey) }
    } else if let dictValue = val as? [String: Any] {
      var result: [String: Any] = [:]
      for (key, value) in dictValue {
        let newKey = transformDictKey(key)
        result[newKey] = transformStringsRecursively(value, transformDictKey: transformDictKey)
      }
      return result
    } else {
      return val
    }
  }

  /// Lowercase all string keys and values in a nested structure.
  ///
  /// **Important:** This performs case-insensitive matching for both property keys AND values.
  /// String values like "ABC-123" will be lowercased to "abc-123" for comparison.
  /// This is intentional to ensure consistent matching regardless of case in tracked properties.
  private func lowercaseKeysAndValues(_ val: Any) -> Any {
    return transformStringsRecursively(val, transformDictKey: { $0.lowercased() })
  }

  /// Lowercase only leaf node string values in a nested structure (keys unchanged).
  ///
  /// **Important:** Operators and dictionary keys remain unchanged, only string values are lowercased.
  /// This is used for JsonLogic filter expressions to enable case-insensitive value matching
  /// while preserving operator keywords.
  private func lowercaseOnlyLeafNodes(_ val: Any) -> Any {
    return transformStringsRecursively(val)
  }

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
  /// - Note:
  ///   This method is **asynchronous** with respect to the caller. It dispatches its work onto
  ///   the queue and returns immediately, without waiting for first-time event processing to
  ///   complete. As a result, there is a short window during which a subsequent `getVariant` call
  ///   may not yet observe the newly activated variant. Callers should not rely on immediate
  ///   visibility of first-time event activations in the same synchronous call chain.
  internal func checkFirstTimeEvents(eventName: String, properties: [String: Any]) {
    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }

      // Snapshot pending events with lock
      // Note: We don't snapshot activatedFirstTimeEvents because we'll check it
      // atomically later under write lock to avoid TOCTOU race
      var pendingEventsCopy: [String: PendingFirstTimeEvent] = [:]

      self.flagsLock.read {
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
          // Lowercase all keys and values in event properties for case-insensitive matching
          let lowercasedProperties = self.lowercaseKeysAndValues(properties)

          // Lowercase only leaf nodes in JsonLogic filters (keep operators intact)
          let lowercasedFilters = self.lowercaseOnlyLeafNodes(filters)

          // Prepare data for JsonLogic evaluation
          let data = ["properties": lowercasedProperties]

          // Convert to JSON strings for json-logic-swift library
          guard let rulesData = try? JSONSerialization.data(withJSONObject: lowercasedFilters),
                let rulesString = String(data: rulesData, encoding: .utf8),
                let dataJSON = try? JSONSerialization.data(withJSONObject: data),
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
        self.flagsLock.write {
          if !self.activatedFirstTimeEvents.contains(eventKey) {
            // We won the race - activate this event
            self.activatedFirstTimeEvents.insert(eventKey)

            if self.flags == nil {
              self.flags = [:]
            }
            self.flags![flagKey] = pendingEvent.pendingVariant
            shouldActivate = true
          }
        }

        // Only proceed with external calls if we successfully activated
        if shouldActivate {
          MixpanelLogger.info(message: "First-time event matched for flag '\(flagKey)': \(eventName)")

          // Track the feature flag check event with the new variant
          self._trackFlagIfNeeded(flagName: flagKey, variant: pendingEvent.pendingVariant)

          // Record to backend (fire-and-forget)
          self.recordFirstTimeEvent(
            flagId: pendingEvent.flagId,
            projectId: pendingEvent.projectId,
            firstTimeEventHash: pendingEvent.firstTimeEventHash
          )
        }
      }
    }
  }

  /// Records a first-time event activation to the backend
  internal func recordFirstTimeEvent(flagId: String, projectId: Int, firstTimeEventHash: String) {
    guard let delegate = self.delegate else {
      MixpanelLogger.error(message: "Delegate missing for recording first-time event")
      return
    }

    let distinctId = delegate.getDistinctId()
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
      failure: { [weak self] reason, _, _ in
        guard let self = self else { return }
        // Silent failure - cohort sync will catch up
        MixpanelLogger.warn(message: "Failed to record first-time event for flag \(flagId): \(reason)")
      },
      success: { [weak self] _, _ in
        guard let self = self else { return }
        MixpanelLogger.debug(message: "Successfully recorded first-time event for flag \(flagId)")
      }
    )
  }
}
