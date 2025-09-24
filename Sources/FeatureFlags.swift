import Foundation

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

// Response structure for the /flags endpoint
struct FlagsResponse: Decodable {
  let flags: [String: MixpanelFlagVariant]?  // Dictionary where key is flag name
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

  // *** Use a SERIAL queue for automatic state serialization ***
  private static let accessQueueKey = DispatchSpecificKey<Int>()
  let accessQueue: DispatchQueue = {
    let queue = DispatchQueue(label: "com.mixpanel.featureflagmanager.serialqueue")
    queue.setSpecific(key: FeatureFlagManager.accessQueueKey, value: 1)
    return queue
  }()

  // Internal State - Protected by accessQueue
  var flags: [String: MixpanelFlagVariant]? = nil
  var isFetching: Bool = false
  private var trackedFeatures: Set<String> = Set()
  private var fetchCompletionHandlers: [(Bool) -> Void] = []

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
    // Using the serial queue itself for this background task is fine
    accessQueue.async { [weak self] in
      self?._fetchFlagsIfNeeded(completion: nil)
    }
  }

  func areFlagsReady() -> Bool {
    // Simple sync read - serial queue ensures this is safe
    accessQueue.sync { flags != nil }
  }

  // --- Sync Flag Retrieval ---

  func getVariantSync(_ flagName: String, fallback: MixpanelFlagVariant) -> MixpanelFlagVariant {
    var flagVariant: MixpanelFlagVariant?
    var tracked = false
    var capturedTimeLastFetched: Date?
    var capturedFetchLatencyMs: Int?

    // === Serial Queue: Single Sync Block for Read AND Track Update ===
    accessQueue.sync {
      guard let currentFlags = self.flags else { return }

      if let variant = currentFlags[flagName] {
        flagVariant = variant

        // Perform atomic check-and-set for tracking *within the same sync block*
        if !self.trackedFeatures.contains(flagName) {
          self.trackedFeatures.insert(flagName)
          tracked = true
          // Capture timing data while on queue
          capturedTimeLastFetched = self.timeLastFetched
          capturedFetchLatencyMs = self.fetchLatencyMs
        }
      }
      // If flag wasn't found, flagVariant remains nil
    }
    // === End Sync Block ===

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
      print("Info: Flag '\(flagName)' not found or flags not ready. Returning fallback.")
      return fallback
    }
  }

  // --- Async Flag Retrieval ---

  func getVariant(
    _ flagName: String, fallback: MixpanelFlagVariant,
    completion: @escaping (MixpanelFlagVariant) -> Void
  ) {
    accessQueue.async { [weak self] in  // Block A runs serially on accessQueue
      guard let self = self else { return }

      var flagVariant: MixpanelFlagVariant?
      var needsTrackingCheck = false
      var flagsAreCurrentlyReady = false

      // === Access state DIRECTLY within the async block ===
      // No inner sync needed - we are already synchronized by the serial queue
      flagsAreCurrentlyReady = (self.flags != nil)
      if flagsAreCurrentlyReady, let currentFlags = self.flags {
        if let variant = currentFlags[flagName] {
          flagVariant = variant
          // Also safe to access trackedFeatures directly here
          needsTrackingCheck = !self.trackedFeatures.contains(flagName)
        }
      }
      // === State access finished ===

      if flagsAreCurrentlyReady {
        let result = flagVariant ?? fallback
        if flagVariant != nil, needsTrackingCheck {
          // Perform atomic check-and-track. _trackFeatureIfNeeded uses its
          // own sync block, which is safe to call from here (it's not nested).
          self._trackFlagIfNeeded(flagName: flagName, variant: result)
        }
        DispatchQueue.main.async { completion(result) }

      } else {
        // --- Flags were NOT ready ---
        // Trigger fetch; fetch completion will handle calling the original completion handler
        print("Flags not ready, attempting fetch for getFeature call...")
        self._fetchFlagsIfNeeded { success in
          // This completion runs *after* fetch completes (or fails)
          let result: MixpanelFlagVariant
          if success {
            // Fetch succeeded, get the flag SYNCHRONOUSLY
            result = self.getVariantSync(flagName, fallback: fallback)
          } else {
            print("Warning: Failed to fetch flags, returning fallback for \(flagName).")
            result = fallback
          }
          // Call original completion (on main thread)
          DispatchQueue.main.async { completion(result) }
        }

        return  // Exit Block A early, fetch completion handles the callback.

      }
    }  // End accessQueue.async (Block A)
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

    var shouldStartFetch = false
    let optionsSnapshot = self.currentOptions  // Read options directly (safe on accessQueue)

    guard let options = optionsSnapshot, options.featureFlagsEnabled else {
      print("Feature flags are disabled, not fetching.")
      // Dispatch completion to main queue to avoid potential deadlock
      DispatchQueue.main.async {
        completion?(false)
      }
      return  // Exit method
    }

    // Access/Modify isFetching and fetchCompletionHandlers directly (safe on accessQueue)
    if !self.isFetching {
      self.isFetching = true
      shouldStartFetch = true
      if let completion = completion {
        self.fetchCompletionHandlers.append(completion)
      }
    } else {
      print("Fetch already in progress, queueing completion handler.")
      if let completion = completion {
        self.fetchCompletionHandlers.append(completion)
      }
    }
    // State modifications related to starting the fetch are complete

    if shouldStartFetch {
      print("Starting flag fetch (dispatching network request)...")
      // Perform network request OUTSIDE the serial accessQueue context
      // to avoid blocking the queue during network latency.
      // Dispatch the network request initiation to a global queue.
      DispatchQueue.global(qos: .utility).async { [weak self] in
        self?._performFetchRequest()
      }
    }
  }

  // Performs the actual network request construction and call
  internal func _performFetchRequest() {
    // This method runs OUTSIDE the accessQueue

    // Record fetch start time
    let startTime = Date()
    accessQueue.async { [weak self] in
      self?.fetchStartTime = startTime
    }

    guard let delegate = self.delegate, let options = self.currentOptions else {
      print("Error: Delegate or options missing for fetch.")
      self._completeFetch(success: false)
      return
    }

    let distinctId = delegate.getDistinctId()
    let anonymousId = delegate.getAnonymousId()
    print("Fetching flags for distinct ID: \(distinctId)")

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
      print("Error: Failed to serialize context for flags.")
      self._completeFetch(success: false)
      return
    }

    guard let authData = "\(options.token):".data(using: .utf8) else {
      print("Error: Failed to create auth data.")
      self._completeFetch(success: false)
      return
    }
    let base64Auth = authData.base64EncodedString()
    let headers = ["Authorization": "Basic \(base64Auth)"]

    let queryItems = [
      URLQueryItem(name: "context", value: contextString),
      URLQueryItem(name: "token", value: options.token),
      URLQueryItem(name: "mp_lib", value: "swift"),
      URLQueryItem(name: "$lib_version", value: AutomaticProperties.libVersion())
    ]

    let responseParser: (Data) -> FlagsResponse? = { data in
      do { return try JSONDecoder().decode(FlagsResponse.self, from: data) } catch {
        print("Error parsing flags JSON: \(error)")
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
      failure: { [weak self] reason, data, response in  // Completion handlers run on URLSession's queue
        print("Error: Failed to fetch flags. Reason: \(reason)")
        // Update state and call completions via _completeFetch on the serial queue
        self?.accessQueue.async {  // Dispatch completion handling to serial queue
          self?._completeFetch(success: false)
        }
      },
      success: { [weak self] (flagsResponse, response) in  // Completion handlers run on URLSession's queue
        print("Successfully fetched flags.")
        guard let self = self else { return }
        let fetchEndTime = Date()
        // Update state and call completions via _completeFetch on the serial queue
        self.accessQueue.async { [weak self] in
          guard let self = self else { return }
          // already on accessQueue – write directly
          self.flags = flagsResponse.flags ?? [:]

          // Calculate timing metrics
          if let startTime = self.fetchStartTime {
            let latencyMs = Int(fetchEndTime.timeIntervalSince(startTime) * 1000)
            self.fetchLatencyMs = latencyMs
          }
          self.timeLastFetched = fetchEndTime

          print("Flags updated: \(self.flags ?? [:])")
          self._completeFetch(success: true)  // still on accessQueue
        }
      }
    )
  }

  // Centralized fetch completion logic - MUST be called from within accessQueue
  func _completeFetch(success: Bool) {
    self.isFetching = false
    let handlers = self.fetchCompletionHandlers
    self.fetchCompletionHandlers.removeAll()

    DispatchQueue.main.async {
      handlers.forEach { $0(success) }
    }
  }

  // --- Tracking Logic ---

  // Performs the atomic check and triggers delegate call if needed
  private func _trackFlagIfNeeded(flagName: String, variant: MixpanelFlagVariant) {
    var shouldCallDelegate = false
    var capturedTimeLastFetched: Date?
    var capturedFetchLatencyMs: Int?

    // We are already executing on the serial accessQueue, so this is safe.
    if !self.trackedFeatures.contains(flagName) {
      self.trackedFeatures.insert(flagName)
      shouldCallDelegate = true
      // Capture timing data while on queue
      capturedTimeLastFetched = self.timeLastFetched
      capturedFetchLatencyMs = self.fetchLatencyMs
    }

    // Call delegate *outside* this conceptual block if tracking occurred
    // This prevents holding any potential implicit lock during delegate execution
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
      print("Tracked $experiment_started for \(flagName) (dispatched to main)")
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
      print("Error: Flag '\(flagName)' is not Bool")
      return fallbackValue
    }
  }
}
