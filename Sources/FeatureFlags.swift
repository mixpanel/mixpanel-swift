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
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type in AnyCodable.")
            throw DecodingError.dataCorrupted(context)
        }
    }
}


// Represents the data associated with a feature flag
public struct FeatureFlagData: Decodable {
    public let key: String // Corresponds to 'variant_key' from API
    public let value: Any? // Corresponds to 'variant_value' from API

    enum CodingKeys: String, CodingKey {
        case key = "variant_key"
        case value = "variant_value"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)

        // Directly decode the 'variant_value' using AnyCodable.
        // If the key is missing, it throws.
        // If the value is null, AnyCodable handles it.
        // If the value is an unsupported type, AnyCodable throws.
        let anyCodableValue = try container.decode(AnyCodable.self, forKey: .value)
        value = anyCodableValue.value // Extract the underlying Any? value
    }

    // Helper initializer with fallbacks, value defaults to key if nil
    public init(key: String = "", value: Any? = nil) {
        self.key = key
        if let value = value {
            self.value = value
        } else {
             self.value = key
        }
    }
}

// Response structure for the /flags endpoint
struct FlagsResponse: Decodable {
    let flags: [String: FeatureFlagData]? // Dictionary where key is feature name
}

// Feature Flag Config Struct conforming to Decodable
public struct FlagsConfig: Decodable {
    let enabled: Bool
    let context: [String: Any?] // Context for the request (using Any? for flexibility with nil)
    
    // Define the keys corresponding to the JSON structure
    enum CodingKeys: String, CodingKey {
        case enabled
        case context
    }
    
    // Custom initializer required by Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode the 'enabled' boolean directly
        enabled = try container.decode(Bool.self, forKey: .enabled)
        
        // Decode the 'context' dictionary using AnyCodable for values
        // Use decodeIfPresent if the 'context' key might be optional in the JSON
        // If 'context' is guaranteed to exist, use decode().
        let anyCodableContext = try container.decodeIfPresent([String: AnyCodable].self, forKey: .context) ?? [:]
        
        // Map the [String: AnyCodable] dictionary to [String: Any?]
        // by extracting the 'value' from each AnyCodable wrapper.
        context = anyCodableContext.mapValues { $0.value }
    }
    
    // memberwise initializer for non-decoding instantiation
    public init(enabled: Bool = false, context: [String: Any?] = [:]) {
        self.enabled = enabled
        self.context = context
    }
}


// --- FeatureFlagDelegate Protocol ---
public protocol FeatureFlagDelegate: AnyObject {
    func getConfig() -> MixpanelConfig
    func getDistinctId() -> String
    func track(event: String?, properties: Properties?)
}

/// A protocol defining the public interface for a feature flagging system.
public protocol MixpanelFlags {
    
    /// The delegate responsible for handling feature flag lifecycle events,
    /// such as tracking. It is declared `weak` to prevent retain cycles.
    var delegate: FeatureFlagDelegate? { get set }

    // --- Public Methods ---

    /// Initiates the loading or refreshing of flag configurations from a remote source or cache.
    /// This operation should be performed asynchronously to avoid blocking the calling thread.
    /// Implementations should ensure that subsequent calls to retrieve flags
    /// will use the latest data once loaded.
    func loadFlags()

    /// Synchronously checks if the flag configurations have been successfully loaded
    /// and are available for querying.
    ///
    /// - Returns: `true` if the flags are loaded and ready for use, `false` otherwise.
    func areFlagsReady() -> Bool

    // --- Sync Flag Retrieval ---

    /// Synchronously retrieves the complete `FeatureFlagData` for a given feature name.
    /// If the feature flag is found and flags are ready, its data is returned.
    /// Otherwise, the provided `fallback` `FeatureFlagData` is returned.
    /// This method will also trigger any necessary tracking logic for the accessed flag.
    ///
    /// - Parameters:
    ///   - featureName: The unique identifier for the feature flag.
    ///   - fallback: The `FeatureFlagData` to return if the specified flag is not found
    ///               or if the flags are not yet loaded.
    /// - Returns: The `FeatureFlagData` associated with `featureName`, or the `fallback` data.
    func getVariantSync(_ featureName: String, fallback: FeatureFlagData) -> FeatureFlagData

    /// Asynchronously retrieves the complete `FeatureFlagData` for a given feature name.
    /// If flags are not ready, an attempt will be made to load them.
    /// The `completion` handler is called with the `FeatureFlagData` for the feature,
    /// or the `fallback` data if the flag is not found or loading fails.
    /// This method will also trigger any necessary tracking logic for the accessed flag.
    /// The completion handler is typically invoked on the main thread.
    ///
    /// - Parameters:
    ///   - featureName: The unique identifier for the feature flag.
    ///   - fallback: The `FeatureFlagData` to use as a default if the specified flag
    ///               is not found or an error occurs during fetching.
    ///   - completion: A closure that is called with the resulting `FeatureFlagData`.
    ///                 This closure will be executed on the main dispatch queue.
    func getVariant(_ featureName: String, fallback: FeatureFlagData, completion: @escaping (FeatureFlagData) -> Void)

    /// Synchronously retrieves the underlying value of a feature flag.
    /// This is a convenience method that extracts the `value` property from the `FeatureFlagData`
    /// obtained via `getVariantSync`.
    ///
    /// - Parameters:
    ///   - featureName: The unique identifier for the feature flag.
    ///   - fallbackValue: The default value to return if the flag is not found,
    ///                    its data doesn't contain a value, or flags are not ready.
    /// - Returns: The value of the feature flag, or `fallbackValue`. The type is `Any?`.
    func getVariantValueSync(_ featureName: String, fallbackValue: Any?) -> Any?

    /// Asynchronously retrieves the underlying value of a feature flag.
    /// This is a convenience method that extracts the `value` property from the `FeatureFlagData`
    /// obtained via `getVariant`. If flags are not ready, an attempt will be made to load them.
    /// The `completion` handler is called with the flag's value or the `fallbackValue`.
    /// The completion handler is typically invoked on the main thread.
    ///
    /// - Parameters:
    ///   - featureName: The unique identifier for the feature flag.
    ///   - fallbackValue: The default value to use if the flag is not found,
    ///                    fetching fails, or its data doesn't contain a value.
    ///   - completion: A closure that is called with the resulting value (`Any?`).
    ///                 This closure will be executed on the main dispatch queue.
    func getVariantValue(_ featureName: String, fallbackValue: Any?, completion: @escaping (Any?) -> Void)

    /// Synchronously checks if a specific feature flag is considered "enabled".
    /// This typically involves retrieving the flag's value and evaluating it as a boolean.
    /// The exact logic for what constitutes "enabled" (e.g., `true`, non-nil, a specific string)
    /// should be defined by the implementing class.
    ///
    /// - Parameters:
    ///   - featureName: The unique identifier for the feature flag.
    ///   - fallbackValue: The boolean value to return if the flag is not found,
    ///                    cannot be evaluated as a boolean, or flags are not ready. Defaults to `false`.
    /// - Returns: `true` if the flag is considered enabled, `false` otherwise (including if `fallbackValue` is used).
    func isFlagEnabledSync(_ featureName: String, fallbackValue: Bool) -> Bool

    /// Asynchronously checks if a specific feature flag is considered "enabled".
    /// This typically involves retrieving the flag's value and evaluating it as a boolean.
    /// If flags are not ready, an attempt will be made to load them.
    /// The `completion` handler is called with the boolean result.
    /// The completion handler is typically invoked on the main thread.
    ///
    /// - Parameters:
    ///   - featureName: The unique identifier for the feature flag.
    ///   - fallbackValue: The boolean value to use if the flag is not found, fetching fails,
    ///                    or it cannot be evaluated as a boolean. Defaults to `false`.
    ///   - completion: A closure that is called with the boolean result.
    ///                 This closure will be executed on the main dispatch queue.
    func isFlagEnabled(_ featureName: String, fallbackValue: Bool, completion: @escaping (Bool) -> Void)
}


// --- FeatureFlagManager Class ---

class FeatureFlagManager: Network, MixpanelFlags {
    
    weak var delegate: FeatureFlagDelegate?
    
    // *** Use a SERIAL queue for automatic state serialization ***
    let accessQueue = DispatchQueue(label: "com.mixpanel.featureflagmanager.serialqueue")
    
    // Internal State - Protected by accessQueue
    var flags: [String: FeatureFlagData]? = nil
    var isFetching: Bool = false
    private var trackedFeatures: Set<String> = Set()
    private var fetchCompletionHandlers: [(Bool) -> Void] = []
    
    // Configuration
    private var currentConfig: MixpanelConfig? { delegate?.getConfig() }
    private var flagsRoute = "/flags/"
    
    // Initializers
    required init(serverURL: String) {
        super.init(serverURL: serverURL)
    }
    
    public init(serverURL: String, delegate: FeatureFlagDelegate?) {
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
    
    func getVariantSync(_ featureName: String, fallback: FeatureFlagData) -> FeatureFlagData {
        var featureData: FeatureFlagData?
        var tracked = false
        // === Serial Queue: Single Sync Block for Read AND Track Update ===
        accessQueue.sync {
            guard let currentFlags = self.flags else { return }
            
            if let feature = currentFlags[featureName] {
                featureData = feature
                
                // Perform atomic check-and-set for tracking *within the same sync block*
                if !self.trackedFeatures.contains(featureName) {
                    self.trackedFeatures.insert(featureName)
                    tracked = true
                }
            }
            // If feature wasn't found, featureData remains nil
        }
        // === End Sync Block ===
        
        // Now, process the results outside the lock
        
        if let foundFeature = featureData {
            // If tracking was done *in this call*, call the delegate
            if tracked {
                self._performTrackingDelegateCall(featureName: featureName, feature: foundFeature)
            }
            return foundFeature
        } else {
            print("Info: Flag '\(featureName)' not found or flags not ready. Returning fallback.")
            return fallback
        }
    }
    
    // --- Async Flag Retrieval ---
    
    func getVariant(_ featureName: String, fallback: FeatureFlagData, completion: @escaping (FeatureFlagData) -> Void) {
        accessQueue.async { [weak self] in // Block A runs serially on accessQueue
            guard let self = self else { return }
            
            var featureData: FeatureFlagData?
            var needsTrackingCheck = false
            var flagsAreCurrentlyReady = false
            
            // === Access state DIRECTLY within the async block ===
            // No inner sync needed - we are already synchronized by the serial queue
            flagsAreCurrentlyReady = (self.flags != nil)
            if flagsAreCurrentlyReady, let currentFlags = self.flags {
                if let feature = currentFlags[featureName] {
                    featureData = feature
                    // Also safe to access trackedFeatures directly here
                    needsTrackingCheck = !self.trackedFeatures.contains(featureName)
                }
            }
            // === State access finished ===
            
            if flagsAreCurrentlyReady {
                let result = featureData ?? fallback
                if featureData != nil, needsTrackingCheck {
                    // Perform atomic check-and-track. _trackFeatureIfNeeded uses its
                    // own sync block, which is safe to call from here (it's not nested).
                    self._trackFeatureIfNeeded(featureName: featureName, feature: result)
                }
                DispatchQueue.main.async { completion(result) }
                
            } else {
                // --- Flags were NOT ready ---
                // Trigger fetch; fetch completion will handle calling the original completion handler
                print("Flags not ready, attempting fetch for getFeature call...")
                self._fetchFlagsIfNeeded { success in
                    // This completion runs *after* fetch completes (or fails)
                    let result: FeatureFlagData
                    if success {
                        // Fetch succeeded, get the feature SYNCHRONOUSLY
                        result = self.getVariantSync(featureName, fallback: fallback)
                    } else {
                        print("Warning: Failed to fetch flags, returning fallback for \(featureName).")
                        result = fallback
                    }
                    // Call original completion (on main thread)
                    DispatchQueue.main.async { completion(result) }
                }

                return // Exit Block A early, fetch completion handles the callback.
                
            }
        } // End accessQueue.async (Block A)
    }
    
    func getVariantValueSync(_ featureName: String, fallbackValue: Any?) -> Any? {
        return getVariantSync(featureName, fallback: FeatureFlagData(value: fallbackValue)).value
    }
    
    func getVariantValue(_ featureName: String, fallbackValue: Any?, completion: @escaping (Any?) -> Void) {
        getVariant(featureName, fallback: FeatureFlagData(value: fallbackValue)) { featureData in
            completion(featureData.value)
        }
    }
    
    func isFlagEnabledSync(_ featureName: String, fallbackValue: Bool = false) -> Bool {
        let dataValue = getVariantValueSync(featureName, fallbackValue: fallbackValue)
        return self._evaluateBooleanFlag(featureName: featureName, dataValue: dataValue, fallbackValue: fallbackValue)
    }
    
    func isFlagEnabled(_ featureName: String, fallbackValue: Bool = false, completion: @escaping (Bool) -> Void) {
        getVariantValue(featureName, fallbackValue: fallbackValue) { [weak self] dataValue in
            guard let self = self else {
                completion(fallbackValue)
                return
            }
            let result = self._evaluateBooleanFlag(featureName: featureName, dataValue: dataValue, fallbackValue: fallbackValue)
            completion(result)
        }
    }
    
    // --- Fetching Logic (Simplified by Serial Queue) ---
    
    // Internal function to handle fetch logic and state checks
    private func _fetchFlagsIfNeeded(completion: ((Bool) -> Void)?) {
        
        var shouldStartFetch = false
        let configSnapshot = self.currentConfig // Read config directly (safe on accessQueue)
        

        guard let config = configSnapshot, config.flagsConfig.enabled else {
            print("Feature flags are disabled, not fetching.")
            // Call completion immediately since we know the result and are on the queue.
            completion?(false)
            return // Exit method
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
    private func _performFetchRequest() {
        // This method runs OUTSIDE the accessQueue
        
        guard let delegate = self.delegate, let config = self.currentConfig else {
            print("Error: Delegate or config missing for fetch.")
            self._completeFetch(success: false)
            return
        }
        
        let distinctId = delegate.getDistinctId()
        print("Fetching flags for distinct ID: \(distinctId)")
        
        var context = config.flagsConfig.context
        context["distinct_id"] = distinctId
        let requestBodyDict = ["context": context]
        
        guard let requestBodyData = try? JSONSerialization.data(withJSONObject: requestBodyDict, options: []) else {
            print("Error: Failed to serialize request body for flags.")
            self._completeFetch(success: false); return
        }
        guard let authData = "\(config.token):".data(using: .utf8) else {
            print("Error: Failed to create auth data."); self._completeFetch(success: false); return
        }
        let base64Auth = authData.base64EncodedString()
        let headers = ["Authorization": "Basic \(base64Auth)", "Content-Type": "application/json"]
        let responseParser: (Data) -> FlagsResponse? = { data in
            do { return try JSONDecoder().decode(FlagsResponse.self, from: data) }
            catch { print("Error parsing flags JSON: \(error)"); return nil }
        }
        let resource = Network.buildResource(path: flagsRoute, method: .post, requestBody: requestBodyData, headers: headers, parse: responseParser)
        
        // Make the API request
        Network.apiRequest(
            base: serverURL,
            resource: resource,
            failure: { [weak self] reason, data, response in // Completion handlers run on URLSession's queue
                print("Error: Failed to fetch flags. Reason: \(reason)")
                // Update state and call completions via _completeFetch on the serial queue
                self?.accessQueue.async { // Dispatch completion handling to serial queue
                    self?._completeFetch(success: false)
                }
            },
            success: { [weak self] (flagsResponse, response) in // Completion handlers run on URLSession's queue
                print("Successfully fetched flags.")
                guard let self = self else { return }
                // Update state and call completions via _completeFetch on the serial queue
                self.accessQueue.async { [weak self] in
                    guard let self = self else { return }
                    // already on accessQueue – write directly
                    self.flags = flagsResponse.flags ?? [:]
                    print("Flags updated: \(self.flags ?? [:])")
                    self._completeFetch(success: true)   // still on accessQueue
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
    private func _trackFeatureIfNeeded(featureName: String, feature: FeatureFlagData) {
        var shouldCallDelegate = false
        
        // We are already executing on the serial accessQueue, so this is safe.
        if !self.trackedFeatures.contains(featureName) {
            self.trackedFeatures.insert(featureName)
            shouldCallDelegate = true
        }
        
        // Call delegate *outside* this conceptual block if tracking occurred
        // This prevents holding any potential implicit lock during delegate execution
        if shouldCallDelegate {
            self._performTrackingDelegateCall(featureName: featureName, feature: feature)
        }
    }
    
    // Helper to just call the delegate (no locking)
    private func _performTrackingDelegateCall(featureName: String, feature: FeatureFlagData) {
        guard let delegate = self.delegate else { return }
        let properties: Properties = [
            "Experiment name": featureName, "Variant name": feature.key, "$experiment_type": "feature_flag"
        ]
        // Dispatch delegate call asynchronously to main thread for safety
        DispatchQueue.main.async {
            delegate.track(event: "$experiment_started", properties: properties)
            print("Tracked $experiment_started for \(featureName) (dispatched to main)")
        }
    }
    
    // --- Boolean Evaluation Helper ---
    private func _evaluateBooleanFlag(featureName: String, dataValue: Any?, fallbackValue: Bool) -> Bool {
        guard let val = dataValue else { return fallbackValue }
        if let boolVal = val as? Bool { return boolVal }
        else { print("Error: Flag '\(featureName)' is not Bool"); return fallbackValue }
    }
}
