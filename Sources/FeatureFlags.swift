import Foundation

// --- Helper Structures ---

// Represents the data associated with a feature flag
struct FeatureFlagData: Decodable {
    let key: String // Corresponds to 'variant_key' in JS
    let value: Any? // Corresponds to 'variant_value' in JS - Use Any? for flexibility
    
    // Manual decoding to handle Any? for the value
    enum CodingKeys: String, CodingKey {
        case key = "variant_key"
        case value = "variant_value"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        
        // Attempt to decode value flexibly (Bool, String, Int, Double, Array, Dictionary)
        if let boolValue = try? container.decode(Bool.self, forKey: .value) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self, forKey: .value) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .value) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            value = doubleValue
        } else if let arrayValue = try? container.decode([AnyCodable].self, forKey: .value) {
            value = arrayValue.map { $0.value } // Extract underlying values
        } else if let dictValue = try? container.decode([String: AnyCodable].self, forKey: .value) {
            value = dictValue.mapValues { $0.value } // Extract underlying values
        } else if container.contains(.value) && (try? container.decodeNil(forKey: .value)) == true {
            value = nil // Explicitly handle null
        }
        else {
            // Log or handle the case where the type is unexpected or null
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type for variant_value or value is null.")
            throw DecodingError.dataCorrupted(context)
            // Or set value = nil if you prefer to silently ignore unknown types
            // value = nil
        }
    }
    
    // Helper initializer for fallbacks
    init(key: String = "", value: Any?) {
        self.key = key
        self.value = value
    }
}

// Wrapper to help decode 'Any' types within Codable structures
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
        }
        else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type in AnyCodable.")
            throw DecodingError.dataCorrupted(context)
        }
    }
}


// Response structure for the /flags endpoint
struct FlagsResponse: Decodable {
    let flags: [String: FeatureFlagData]? // Dictionary where key is feature name
}


// --- FeatureFlagManager Class ---

class FeatureFlagManager: Network {
    
    private var instanceName: String?
    
    // Internal State
    private var flags: [String: FeatureFlagData]? = nil // Holds the fetched flags
    private var trackedFeatures: Set<String> = Set()
    private var isFetching: Bool = false
    private var fetchCompletionHandlers: [(Bool) -> Void] = [] // To notify callers when fetch completes
    private let accessQueue = DispatchQueue(label: "com.mixpanel.featureflagmanager.queue", attributes: .concurrent) // For thread safety
    
    // Configuration Keys
    private let flagsConfigKey = "flags"
    private let configContextKey = "context"
    private let flagsRoute = "/flags/"
    
    init(serverURL: String, instanceName: String) {
        super.init(serverURL: serverURL)
        self.instanceName = instanceName
        // Initial fetch is triggered by an explicit call or first access usually
        print("FeatureFlagManager initialized.") // Replaces logger.log
    }
    
    required init(serverURL: String) {
        super.init(serverURL: serverURL)
    }
    
    // Public function to start loading flags
    func loadFlags() {
        fetchFlags(completion: nil)
    }
    
    // --- Configuration Access ---
    
    private func getInstance() -> MixpanelInstance? {
        if let instanceName, let instance = Mixpanel.getInstance(name: instanceName) {
            return instance
        } else if let instance = Mixpanel.safeMainInstance() {
            return instance
        }
        return nil
    }
    
    private func getFullConfig() -> MixpanelConfig? {
        getInstance()?.getConfig()
    }
    
    private func getContext() -> InternalProperties {
        return getFullConfig()?.flagsContext ?? [:]
    }
    
    private func isEnabled() -> Bool {
        return getFullConfig()?.flagsEnabled ?? false
    }
    
    // --- Flag State ---
    
    func areFeaturesReady() -> Bool {
        var ready = false
        accessQueue.sync { // Read needs sync access
            ready = self.flags != nil
        }
        if !ready && isEnabled() {
            print("Warning: Feature flags checked before being loaded.") // Replaces logger.log [cite: 21]
        } else if !isEnabled() {
            print("Error: Feature Flags not enabled.") // Replaces logger.error [cite: 11]
        }
        return ready
    }
    
    // --- Fetching Logic ---
    
    private func fetchFlags(completion: ((Bool) -> Void)?) {
        guard isEnabled() else { // [cite: 12]
            print("Feature flags are disabled, not fetching.")
            completion?(false)
            return
        }
        
        let shouldFetch = accessQueue.sync(flags: .barrier) { // Write access needs barrier
            if self.isFetching {
                // Queue completion if already fetching
                if let completion = completion {
                    self.fetchCompletionHandlers.append(completion)
                }
                return false // Don't start another fetch
            }
            // Mark as fetching and add the first completion handler
            self.isFetching = true
            if let completion = completion {
                self.fetchCompletionHandlers.append(completion)
            }
            return true // Start fetch
        }
        
        guard shouldFetch else { return }
        
        if let instance = getInstance() {
            let distinctId = instance.distinctId
            print("Fetching flags for distinct ID: \(distinctId)") // Replaces logger.log [cite: 13]
            
            // Prepare request context [cite: 14]
            var context = getContext()
            context["distinct_id"] = distinctId
            
            let requestBodyDict = ["context": context]
            
            guard let requestBodyData = try? JSONSerialization.data(withJSONObject: requestBodyDict, options: []) else {
                print("Error: Failed to serialize request body for flags.")
                completeFetch(success: false)
                return
            }
            
            // Basic Auth Header
            guard let authData = "\(instance.apiToken):".data(using: .utf8) else {
                print("Error: Failed to create auth data.")
                completeFetch(success: false)
                return
            }
            let base64Auth = authData.base64EncodedString()
            let headers = [
                "Authorization": "Basic \(base64Auth)",
                "Content-Type": "application/json" // Assuming JSON, though JS used octet-stream [cite: 15] adjust if needed
            ]
            
            // Define the response parser
            let responseParser: (Data) -> FlagsResponse? = { data in
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(FlagsResponse.self, from: data)
                    return response
                } catch {
                    print("Error: Failed to parse flags response JSON: \(error)") // Replaces logger.error [cite: 18]
                    return nil
                }
            }
            
            // Build the resource [cite: 51]
            let resource = Network.buildResource(path: flagsRoute, // e.g., "/flags"
                                                 method: .post,
                                                 requestBody: requestBodyData,
                                                 headers: headers,
                                                 parse: responseParser) // [cite: 52]
            
            // Make the API request [cite: 42]
            Network.apiRequest(base: serverURL, // e.g., "https://api.mixpanel.com" [cite: 36]
                               resource: resource,
                               failure: { reason, data, response in
                print("Error: Failed to fetch flags. Reason: \(reason)") // Replaces logger.error [cite: 18]
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Error response body: \(responseString)")
                }
                self.completeFetch(success: false)
            },
                               success: { [weak self] (flagsResponse, response) in // [cite: 16]
                print("Successfully fetched flags.")
                self?.accessQueue.sync(flags: .barrier) { // Write needs barrier
                    self?.flags = flagsResponse.flags ?? [:] // Store fetched flags [cite: 17]
                }
                self?.completeFetch(success: true)
            })
        }
    }
    
    private func completeFetch(success: Bool) {
        accessQueue.sync(flags: .barrier) { // Write needs barrier
            let handlers = self.fetchCompletionHandlers
            self.fetchCompletionHandlers.removeAll()
            self.isFetching = false
            // Notify all queued handlers
            DispatchQueue.main.async { // Call handlers on main thread
                handlers.forEach { $0(success) }
            }
        }
    }
    
    
    // --- Getting Feature Flags (Async) ---
    
    // Use completion handler pattern similar to Network class
    func getFeature(_ featureName: String, fallback: FeatureFlagData = FeatureFlagData(value: nil), completion: @escaping (FeatureFlagData) -> Void) {
        accessQueue.async { // Read can be concurrent
            if self.flags != nil {
                // Flags already loaded, return sync result immediately on main thread
                let result = self._getFeatureSync(featureName, fallback: fallback)
                DispatchQueue.main.async { completion(result) }
            } else {
                // Flags not loaded, trigger fetch and call completion when done
                DispatchQueue.main.async { // Ensure fetchFlags is called from a consistent thread if needed, or manage internally
                    self.fetchFlags { [weak self] success in
                        guard let self = self else {
                            completion(fallback)
                            return
                        }
                        if success {
                            let result = self._getFeatureSync(featureName, fallback: fallback) // Called within fetch completion, safe to access flags
                            completion(result)
                        } else {
                            print("Warning: Failed to fetch flags, returning fallback for \(featureName).")
                            completion(fallback)
                        }
                    }
                }
            }
        }
    }
    
    
    func getFeatureData(_ featureName: String, fallbackValue: Any? = nil, completion: @escaping (Any?) -> Void) {
        getFeature(featureName, fallback: FeatureFlagData(value: fallbackValue)) { featureData in
            completion(featureData.value)
        }
    }
    
    func isFeatureEnabled(_ featureName: String, fallbackValue: Bool = false, completion: @escaping (Bool) -> Void) {
        // Fetch the data first, then evaluate if it's true/false
        getFeatureData(featureName, fallbackValue: fallbackValue) { [weak self] dataValue in
            guard let self = self else {
                completion(fallbackValue)
                return
            }
            // Use the sync logic for evaluation after data is retrieved
            completion(self._isFeatureEnabledSync(featureName: featureName, dataValue: dataValue, fallbackValue: fallbackValue))
        }
    }
    
    
    // --- Getting Feature Flags (Sync) ---
    
    // Private helper to avoid queue logic repetition, assumes flags are loaded or called from within completion
    private func _getFeatureSync(_ featureName: String, fallback: FeatureFlagData) -> FeatureFlagData {
        // Assumes called within accessQueue.sync or after flags are confirmed non-nil
        guard let currentFlags = self.flags else {
            // This path should ideally not be hit if areFeaturesReady is checked, but good for safety
            print("Warning: getFeatureSync called before flags loaded for \(featureName).") // [cite: 21]
            return fallback
        }
        
        guard let feature = currentFlags[featureName] else {
            print("Info: No flag found for '\(featureName)', returning fallback.") // [cite: 23]
            return fallback
        }
        
        // Track experiment exposure [cite: 24]
        trackFeatureCheck(featureName: featureName, feature: feature)
        return feature
    }
    
    // Public sync methods require careful usage - check areFeaturesReady() first!
    func getFeatureSync(_ featureName: String, fallback: FeatureFlagData = FeatureFlagData(value: nil)) -> FeatureFlagData {
        guard areFeaturesReady() else {
            print("Warning: Flags not ready for getFeatureSync call for \(featureName). Returning fallback.") // [cite: 21]
            return fallback
        }
        // Access flags safely using the queue
        var result: FeatureFlagData!
        accessQueue.sync { // Read needs sync access
            // We know flags is not nil here due to areFeaturesReady check
            result = self._getFeatureSync(featureName, fallback: fallback)
        }
        return result
    }
    
    
    func getFeatureDataSync(_ featureName: String, fallbackValue: Any? = nil) -> Any? {
        return getFeatureSync(featureName, fallback: FeatureFlagData(value: fallbackValue)).value
    }
    
    
    // Private helper for boolean evaluation
    private func _isFeatureEnabledSync(featureName: String, dataValue: Any?, fallbackValue: Bool) -> Bool {
        guard let val = dataValue else {
            print("Info: Feature flag '\(featureName)' value is nil; returning fallback: \(fallbackValue)")
            return fallbackValue
        }
        
        if let boolVal = val as? Bool {
            return boolVal // [cite: 28]
        } else {
            // Log error if value is not a boolean [cite: 28]
            print("Error: Feature flag '\(featureName)' value: \(val) is not a boolean; returning fallback: \(fallbackValue)")
            return fallbackValue // [cite: 29]
        }
    }
    
    func isFeatureEnabledSync(_ featureName: String, fallbackValue: Bool = false) -> Bool { // [cite: 27]
        let dataValue = getFeatureDataSync(featureName, fallbackValue: fallbackValue)
        return _isFeatureEnabledSync(featureName: featureName, dataValue: dataValue, fallbackValue: fallbackValue)
    }
    
    
    // --- Tracking ---
    
    private func trackFeatureCheck(featureName: String, feature: FeatureFlagData) {
        accessQueue.sync(flags: .barrier) { // Write needs barrier
            guard !self.trackedFeatures.contains(featureName) else { // [cite: 30]
                return
            }
            self.trackedFeatures.insert(featureName) // [cite: 31]
        }
        
        // Call the tracking function provided during initialization
        let properties: Properties = [
            "Experiment name": featureName,
            "Variant name": feature.key,
            "$experiment_type": "feature_flag"
        ]
        if let instance = getInstance() {
            instance.track(event: "$experiment_started", properties: properties)
            print("Tracked $experiment_started for \(featureName)")
        }
    }
}

// --- Example Usage Placeholder (Requires Mixpanel instance setup) ---
/*
 // Assuming you have a Mixpanel instance and Network setup:
 let mixpanelInstance = Mixpanel.initialize(token: "YOUR_TOKEN", launchOptions: nil, flushInterval: 60)
 let network = Network(serverURL: mixpanelInstance.serverURL) // Or however Network gets initialized
 
 let featureFlagManager = FeatureFlagManager(
 getConfigFunc: { key in mixpanelInstance.configuration.get(key) }, // Adapt based on actual config access
 getDistinctIdFunc: { mixpanelInstance.distinctId },
 trackFunc: { eventName, properties in mixpanelInstance.track(event: eventName, properties: properties) },
 network: network
 )
 
 // Load flags initially (e.g., during app startup)
 featureFlagManager.loadFlags()
 
 // Later, check a flag (async)
 featureFlagManager.isFeatureEnabled("new_checkout_flow", fallbackValue: false) { isEnabled in
 if isEnabled {
 print("New checkout flow is enabled!")
 // Show new UI
 } else {
 print("New checkout flow is disabled.")
 // Show old UI
 }
 }
 
 // Or check synchronously *after* confirming flags are loaded
 if featureFlagManager.areFeaturesReady() {
 let buttonColorData = featureFlagManager.getFeatureDataSync("button_color", fallbackValue: "blue")
 if let buttonColor = buttonColorData as? String {
 print("Button color variant: \(buttonColor)")
 // Apply button color
 }
 
 let shouldUseNewAPI = featureFlagManager.isFeatureEnabledSync("use_new_api", fallbackValue: false)
 print("Should use new API (sync): \(shouldUseNewAPI)")
 
 } else {
 print("Flags not ready yet for sync access.")
 // Use default behavior or wait
 }
 */
