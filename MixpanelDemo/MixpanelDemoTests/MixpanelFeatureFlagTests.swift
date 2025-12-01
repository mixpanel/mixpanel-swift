//
//  MixpanelFeatureFlagTests.swift
//  MixpanelDemo
//
//  Created by Jared McFarland on 4/16/25.
//  Copyright © 2025 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

// MARK: - Mocks and Helpers (Largely Unchanged)

class MockFeatureFlagDelegate: MixpanelFlagDelegate {

  var options: MixpanelOptions
  var distinctId: String
  var anonymousId: String?
  var trackedEvents: [(event: String?, properties: Properties?)] = []
  var trackExpectation: XCTestExpectation?
  var getOptionsCallCount = 0
  var getDistinctIdCallCount = 0
  var getAnonymousIdCallCount = 0

  // Custom track handler to allow overriding behavior
  var customTrackHandler: ((String?, Properties?) -> Void)?

  init(
    options: MixpanelOptions = MixpanelOptions(token: "test", featureFlagsEnabled: true),
    distinctId: String = "test_distinct_id",
    anonymousId: String? = "test_anonymous_id"
  ) {
    self.options = options
    self.distinctId = distinctId
    self.anonymousId = anonymousId
  }

  func getOptions() -> MixpanelOptions {
    getOptionsCallCount += 1
    return options
  }

  func getDistinctId() -> String {
    getDistinctIdCallCount += 1
    return distinctId
  }

  func getAnonymousId() -> String? {
    getAnonymousIdCallCount += 1
    return anonymousId
  }

  func track(event: String?, properties: Properties?) {
    print("MOCK Delegate: Track called - Event: \(event ?? "nil"), Props: \(properties ?? [:])")
    trackedEvents.append((event: event, properties: properties))
    trackExpectation?.fulfill()

    // Call custom handler if set
    customTrackHandler?(event, properties)
  }
}

// AssertEqual helper (Unchanged from previous working version)
func AssertEqual(_ value1: Any?, _ value2: Any?, file: StaticString = #file, line: UInt = #line) {
  // ... (Use the version that fixed the Any?? issues) ...
  switch (value1, value2) {
  case (nil, nil):
    break  // Equal
  case (let v1 as Bool, let v2 as Bool):
    XCTAssertEqual(v1, v2, file: file, line: line)
  case (let v1 as String, let v2 as String):
    XCTAssertEqual(v1, v2, file: file, line: line)
  case (let v1 as Int, let v2 as Int):
    XCTAssertEqual(v1, v2, file: file, line: line)
  case (let v1 as Double, let v2 as Double):
    // Handle potential precision issues if necessary
    XCTAssertEqual(v1, v2, accuracy: 0.00001, file: file, line: line)
  case (let v1 as [Any?], let v2 as [Any?]):
    XCTAssertEqual(v1.count, v2.count, "Array counts differ", file: file, line: line)
    for (index, item1) in v1.enumerated() {
      guard index < v2.count else {
        XCTFail("Index \(index) out of bounds for second array", file: file, line: line)
        return
      }
      AssertEqual(item1, v2[index], file: file, line: line)
    }
  case (let v1 as [String: Any?], let v2 as [String: Any?]):
    XCTAssertEqual(
      v1.count, v2.count, "Dictionary counts differ (\(v1.keys.sorted()) vs \(v2.keys.sorted()))",
      file: file, line: line)
    for (key, item1) in v1 {
      guard v2.keys.contains(key) else {
        XCTFail("Key '\(key)' missing in second dictionary", file: file, line: line)
        continue
      }
      let item2DoubleOptional = v2[key]
      AssertEqual(item1, item2DoubleOptional ?? nil, file: file, line: line)
    }
  default:
    if let n1 = value1 as? NSNumber, let n2 = value2 as? NSNumber {
      XCTAssertEqual(n1, n2, "NSNumber values differ: \(n1) vs \(n2)", file: file, line: line)
    } else {
      XCTFail(
        "Values are not equal or of comparable types: \(String(describing: value1)) vs \(String(describing: value2))",
        file: file, line: line)
    }
  }
}

// MARK: - Mock FeatureFlagManager for Network Isolation

class MockFeatureFlagManager: FeatureFlagManager {
  var shouldSimulateNetworkDelay = false
  var simulatedFetchResult: (success: Bool, flags: [String: MixpanelFlagVariant]?)?
  var fetchRequestCount = 0
  private var fetchStartTime: Date?

  // Request validation properties
  var requestValidationEnabled = false
  var lastRequestMethod: RequestMethod?
  var lastRequestHeaders: [String: String]?
  var lastRequestBody: Data?
  var lastQueryItems: [URLQueryItem]?
  var requestValidationError: String?

  // First-time event recording tracking
  var recordFirstTimeEventCallCount = 0
  var lastRecordedFlagId: String?
  var lastRecordedProjectId: Int?
  var lastRecordedCohortHash: String?

  // Override the now-internal method to prevent real network calls
  override func _performFetchRequest() {
    fetchRequestCount += 1
    print("MockFeatureFlagManager: Intercepted fetch request #\(fetchRequestCount)")

    // Record fetch start time like the real implementation
    let startTime = Date()
    accessQueue.async { [weak self] in
      self?.fetchStartTime = startTime
    }

    // If request validation is enabled, intercept and validate the request construction
    if requestValidationEnabled {
      validateRequestConstruction()
    }

    // Instead of real network call, use simulated result
    if let result = simulatedFetchResult {
      if shouldSimulateNetworkDelay {
        // Simulate network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.completeSimulatedFetch(
            success: result.success, flags: result.flags, startTime: startTime)
        }
      } else {
        // Complete immediately
        self.completeSimulatedFetch(
          success: result.success, flags: result.flags, startTime: startTime)
      }
    } else {
      // No simulation configured - fail immediately
      print("MockFeatureFlagManager: No simulation configured, failing fetch")
      self.accessQueue.async { [weak self] in
        self?._completeFetch(success: false)
      }
    }
  }

  private func validateRequestConstruction() {
    // Clear previous validation error
    requestValidationError = nil

    // Replicate the request construction logic from the real implementation to capture parameters
    guard let delegate = self.delegate else {
      requestValidationError = "Delegate missing"
      return
    }
    let options = delegate.getOptions()

    let distinctId = delegate.getDistinctId()
    let anonymousId = delegate.getAnonymousId()

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
      requestValidationError = "Failed to serialize context"
      return
    }

    guard let authData = "\(options.token):".data(using: .utf8) else {
      requestValidationError = "Failed to create auth data"
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

    // Capture the constructed request parameters for validation
    lastRequestMethod = .get
    lastRequestHeaders = headers
    lastRequestBody = nil  // GET request should have no body
    lastQueryItems = queryItems
  }

  private func completeSimulatedFetch(
    success: Bool, flags: [String: MixpanelFlagVariant]?, startTime: Date
  ) {
    let fetchEndTime = Date()

    if success {
      print("MockFeatureFlagManager: Simulating successful fetch with \(flags?.count ?? 0) flags")
      self.accessQueue.async { [weak self] in
        guard let self = self else { return }

        // Mimic the real implementation's behavior - use mergeFlags like the real impl
        let (mergedFlags, mergedPendingEvents) = self.mergeFlags(
          responseFlags: flags,
          responsePendingEvents: nil
        )
        self.flags = mergedFlags
        self.pendingFirstTimeEvents = mergedPendingEvents

        // Calculate timing metrics like the real implementation
        let latencyMs = Int(fetchEndTime.timeIntervalSince(startTime) * 1000)
        self.fetchLatencyMs = latencyMs
        self.timeLastFetched = fetchEndTime

        print("Flags updated: \(self.flags ?? [:])")
        self._completeFetch(success: true)
      }
    } else {
      print("MockFeatureFlagManager: Simulating failed fetch")
      self.accessQueue.async { [weak self] in
        self?._completeFetch(success: false)
      }
    }
  }

  // Override recordFirstTimeEvent to prevent real network calls and track invocations
  override func recordFirstTimeEvent(flagId: String, projectId: Int, cohortHash: String) {
    recordFirstTimeEventCallCount += 1
    lastRecordedFlagId = flagId
    lastRecordedProjectId = projectId
    lastRecordedCohortHash = cohortHash

    print("MockFeatureFlagManager: Intercepted recordFirstTimeEvent call #\(recordFirstTimeEventCallCount) for flag: \(flagId)")

    // DO NOT call super - prevents actual network calls
  }
}

// MARK: - Refactored FeatureFlagManager Tests

class FeatureFlagManagerTests: XCTestCase {

  var mockDelegate: MockFeatureFlagDelegate!
  var manager: FeatureFlagManager!
  // Sample flag data for simulating fetch results
  let sampleFlags: [String: MixpanelFlagVariant] = [
    "feature_bool_true": MixpanelFlagVariant(key: "v_true", value: true),
    "feature_bool_false": MixpanelFlagVariant(key: "v_false", value: false),
    "feature_string": MixpanelFlagVariant(key: "v_str", value: "test_string"),
    "feature_int": MixpanelFlagVariant(key: "v_int", value: 101),
    "feature_double": MixpanelFlagVariant(key: "v_double", value: 99.9),
    "feature_null": MixpanelFlagVariant(key: "v_null", value: nil),
  ]
  let defaultFallback = MixpanelFlagVariant(value: nil)  // Default fallback for convenience

  override func setUpWithError() throws {
    try super.setUpWithError()
    mockDelegate = MockFeatureFlagDelegate()

    // Use MockFeatureFlagManager to prevent real network calls
    let mockManager = MockFeatureFlagManager(serverURL: "https://test.com", delegate: mockDelegate)

    // Configure default simulation - successful fetch with sample flags
    mockManager.simulatedFetchResult = (success: true, flags: sampleFlags)
    mockManager.shouldSimulateNetworkDelay = true

    manager = mockManager
  }

  override func tearDownWithError() throws {
    mockDelegate = nil
    manager = nil
    try super.tearDownWithError()
  }

  // --- Simulation Helpers ---
  // These now directly modify state and call the *internal* _completeFetch
  // Requires _completeFetch to be accessible (e.g., internal or @testable import)

  private func simulateFetchSuccess(flags: [String: MixpanelFlagVariant]? = nil) {
    let flagsToSet = flags ?? sampleFlags

    // If using MockFeatureFlagManager, just set the flags directly
    if let mockManager = manager as? MockFeatureFlagManager {
      // For mock, we can directly set the flags without going through fetch
      mockManager.accessQueue.async {
        mockManager.flags = flagsToSet
        mockManager.timeLastFetched = Date()
        mockManager.fetchLatencyMs = 150
        // Don't call _completeFetch - just set the state
      }
      // Give a moment for the async operation to complete
      Thread.sleep(forTimeInterval: 0.01)
    } else {
      // Original implementation for non-mock manager
      let currentTime = Date()
      // Set flags directly *before* calling completeFetch
      manager.accessQueue.sync {
        manager.flags = flagsToSet
        // Set timing properties to simulate a successful fetch
        manager.timeLastFetched = currentTime
        manager.fetchLatencyMs = 150  // Simulate 150ms fetch time
        // Important: Set isFetching = true *before* calling _completeFetch,
        // as _completeFetch assumes a fetch was in progress.
        manager.isFetching = true
      }
      // Call internal completion logic
      manager._completeFetch(success: true)
    }
  }

  private func simulateFetchFailure() {
    // If using MockFeatureFlagManager, just clear the flags
    if let mockManager = manager as? MockFeatureFlagManager {
      mockManager.accessQueue.async {
        mockManager.flags = nil
        // Don't call _completeFetch - just set the state
      }
      // Give a moment for the async operation to complete
      Thread.sleep(forTimeInterval: 0.01)
    } else {
      // Original implementation for non-mock manager
      // Set isFetching = true before calling _completeFetch
      manager.accessQueue.sync {
        manager.isFetching = true
        // Ensure flags are nil or unchanged on failure simulation if desired
        manager.flags = nil  // Or keep existing flags based on desired failure behavior
      }
      // Call internal completion logic
      manager._completeFetch(success: false)
    }
  }

  // MARK: - Test Helpers

  // Expectation & Waiting Helpers

  private func waitBriefly(timeout: TimeInterval = 0.5, file: StaticString = #file, line: UInt = #line) {
    let expectation = XCTestExpectation(description: "Brief wait")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expectation.fulfill() }
    wait(for: [expectation], timeout: timeout)
  }

  private func waitForAsyncOperation<T>(
    timeout: TimeInterval = 2.0,
    description: String,
    operation: (@escaping (T) -> Void) -> Void,
    validation: (T) -> Void
  ) {
    let expectation = XCTestExpectation(description: description)
    var result: T?

    operation { value in
      result = value
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: timeout)

    if let result = result {
      validation(result)
    } else {
      XCTFail("Operation did not complete in time")
    }
  }

  // Tracking Helpers

  private func expectTracking(
    expectedCount: Int = 1,
    description: String = "Track called",
    timeout: TimeInterval = 1.0,
    operation: () -> Void
  ) {
    mockDelegate.trackedEvents.removeAll()
    mockDelegate.trackExpectation = XCTestExpectation(description: description)
    mockDelegate.trackExpectation?.expectedFulfillmentCount = expectedCount

    operation()

    wait(for: [mockDelegate.trackExpectation!], timeout: timeout)
    XCTAssertEqual(mockDelegate.trackedEvents.count, expectedCount)
  }

  private func verifyTrackingProperties(
    _ properties: [String: Any?],
    experimentName: String,
    variantName: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    AssertEqual(properties["Experiment name"] ?? nil, experimentName, file: file, line: line)
    AssertEqual(properties["Variant name"] ?? nil, variantName, file: file, line: line)
    AssertEqual(properties["$experiment_type"] ?? nil, "feature_flag", file: file, line: line)
  }

  private func verifyTimingProperties(
    _ properties: [String: Any?],
    expectedLatency: Int? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTAssertTrue(properties.keys.contains("timeLastFetched"), "Should include timeLastFetched", file: file, line: line)
    XCTAssertTrue(properties.keys.contains("fetchLatencyMs"), "Should include fetchLatencyMs", file: file, line: line)

    if let expected = expectedLatency,
       let actual = properties["fetchLatencyMs"] as? Int {
      XCTAssertEqual(actual, expected, file: file, line: line)
    }
  }

  // Event Verification Helper

  private func verifyTrackedEvent(
    at index: Int = 0,
    expectedEvent: String = "$experiment_started",
    experimentName: String,
    variantName: String,
    checkTimingProperties: Bool = false,
    expectedLatency: Int? = nil,
    additionalChecks: ((Properties) -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    guard index < mockDelegate.trackedEvents.count else {
      XCTFail("No tracked event at index \(index)", file: file, line: line)
      return
    }

    let tracked = mockDelegate.trackedEvents[index]
    XCTAssertEqual(tracked.event, expectedEvent, file: file, line: line)
    XCTAssertNotNil(tracked.properties, file: file, line: line)

    guard let props = tracked.properties else { return }

    verifyTrackingProperties(props, experimentName: experimentName,
                            variantName: variantName, file: file, line: line)

    if checkTimingProperties {
      verifyTimingProperties(props, expectedLatency: expectedLatency,
                           file: file, line: line)
    }

    additionalChecks?(props)
  }

  // Async Operation Helper

  @discardableResult
  private func getVariantAsync(
    _ flagName: String,
    fallback: MixpanelFlagVariant? = nil,
    timeout: TimeInterval = 2.0,
    description: String? = nil,
    verifyMainThread: Bool = true,
    file: StaticString = #file,
    line: UInt = #line
  ) -> MixpanelFlagVariant? {
    let expectation = XCTestExpectation(
      description: description ?? "Get variant async for \(flagName)"
    )
    var receivedData: MixpanelFlagVariant?

    manager.getVariant(flagName, fallback: fallback ?? defaultFallback) { data in
      if verifyMainThread {
        XCTAssertTrue(Thread.isMainThread,
                     "Completion should be on main thread",
                     file: file, line: line)
      }
      receivedData = data
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: timeout)
    return receivedData
  }

  // Fetch Setup Helpers

  private func setupReadyFlags(flags: [String: MixpanelFlagVariant]? = nil) {
    simulateFetchSuccess(flags: flags)
    waitBriefly()
  }

  private func setupReadyFlagsAndVerify(flags: [String: MixpanelFlagVariant]? = nil) {
    setupReadyFlags(flags: flags)
    XCTAssertTrue(manager.areFlagsReady(), "Flags should be ready after setup")
  }

  // JSON Parsing Helpers

  private func decodeJSON<T: Decodable>(
    _ jsonString: String,
    as type: T.Type,
    file: StaticString = #file,
    line: UInt = #line
  ) -> T? {
    guard let data = jsonString.data(using: .utf8) else {
      XCTFail("Failed to convert JSON string to data", file: file, line: line)
      return nil
    }

    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      XCTFail("Failed to decode JSON: \(error)", file: file, line: line)
      return nil
    }
  }

  private func assertJSONDecodes<T: Decodable>(
    _ jsonString: String,
    as type: T.Type,
    file: StaticString = #file,
    line: UInt = #line,
    validation: (T) -> Void
  ) {
    if let result = decodeJSON(jsonString, as: type, file: file, line: line) {
      validation(result)
    }
  }

  // Mock Configuration Helpers

  private var mockManager: MockFeatureFlagManager? {
    return manager as? MockFeatureFlagManager
  }

  private func configureMockFetch(
    success: Bool,
    flags: [String: MixpanelFlagVariant]? = nil,
    withDelay: Bool = true
  ) {
    guard let mock = mockManager else {
      XCTFail("Manager is not a MockFeatureFlagManager")
      return
    }
    mock.simulatedFetchResult = (success: success, flags: flags ?? sampleFlags)
    mock.shouldSimulateNetworkDelay = withDelay
  }

  private func resetMockToSuccess() {
    configureMockFetch(success: true, flags: sampleFlags, withDelay: true)
  }

  // Context Verification Helper

  private func verifyRequestContext(
    expectedDistinctId: String,
    expectedDeviceId: String? = nil,
    additionalChecks: (([String: Any]) -> Void)? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    guard let mockMgr = mockManager,
          let queryItems = mockMgr.lastQueryItems else {
      XCTFail("No query items captured", file: file, line: line)
      return
    }

    let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

    guard let contextString = queryDict["context"],
          let contextData = contextString?.data(using: .utf8),
          let context = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] else {
      XCTFail("Failed to parse context", file: file, line: line)
      return
    }

    XCTAssertEqual(context["distinct_id"] as? String, expectedDistinctId, file: file, line: line)

    if let expectedDeviceId = expectedDeviceId {
      XCTAssertEqual(context["device_id"] as? String, expectedDeviceId, file: file, line: line)
    } else {
      XCTAssertNil(context["device_id"], file: file, line: line)
    }

    additionalChecks?(context)
  }

  // Variant Creation Helpers

  private func createExperimentVariant(
    key: String,
    value: Any?,
    experimentID: String = "test-exp-id",
    isActive: Bool = true,
    isQATester: Bool = false
  ) -> MixpanelFlagVariant {
    return MixpanelFlagVariant(
      key: key,
      value: value,
      isExperimentActive: isActive,
      isQATester: isQATester,
      experimentID: experimentID
    )
  }

  private func createControlVariant(key: String = "control", value: Any? = false) -> MixpanelFlagVariant {
    return MixpanelFlagVariant(key: key, value: value)
  }

  // First-Time Event Helper

  private func setupAndTriggerFirstTimeEvent(
    flagKey: String,
    eventName: String,
    eventProperties: [String: Any] = [:],
    filters: [String: Any]? = nil,
    pendingVariant: MixpanelFlagVariant,
    initialVariant: MixpanelFlagVariant? = nil,
    cohortHash: String = "hash123",
    validation: ((MockFeatureFlagManager) -> Void)? = nil
  ) {
    guard let mockMgr = mockManager else {
      XCTFail("Manager is not a MockFeatureFlagManager")
      return
    }

    let pendingEvent = createPendingEvent(
      flagKey: flagKey,
      eventName: eventName,
      filters: filters,
      pendingVariant: pendingVariant
    )

    let cohortKey = "\(flagKey):\(cohortHash)"

    mockMgr.accessQueue.sync {
      let initial = initialVariant ?? createControlVariant()
      mockMgr.flags = [flagKey: initial]
      mockMgr.pendingFirstTimeEvents = [cohortKey: pendingEvent]
    }

    mockMgr.checkFirstTimeEvents(eventName: eventName, properties: eventProperties)
    waitBriefly(timeout: 1.0)

    mockMgr.accessQueue.sync {
      validation?(mockMgr)
    }
  }

  // Manager State Helpers

  private func resetManagerFlags(_ flags: [String: MixpanelFlagVariant]? = nil) {
    mockManager?.accessQueue.sync {
      mockManager?.flags = flags
    }
    Thread.sleep(forTimeInterval: 0.01)
  }

  private func clearManagerFlags() {
    resetManagerFlags(nil)
  }

  private func setManagerFlags(_ flags: [String: MixpanelFlagVariant]) {
    resetManagerFlags(flags)
  }

  // --- State and Configuration Tests ---

  func testAreFeaturesReady_InitialState() {
    XCTAssertFalse(manager.areFlagsReady(), "Features should not be ready initially")
  }

  func testAreFeaturesReady_AfterSuccessfulFetchSimulation() {
    setupReadyFlagsAndVerify()
  }

  func testAreFeaturesReady_AfterFailedFetchSimulation() {
    simulateFetchFailure()
    waitBriefly()
    XCTAssertFalse(
      manager.areFlagsReady(), "Features should not be ready after failed fetch simulation")
  }

  // --- Load Flags Tests ---

  func testLoadFlags_WhenDisabledInConfig() {
    mockDelegate.options = MixpanelOptions(token: "test", featureFlagsEnabled: false)  // Explicitly disable
    manager.loadFlags()  // Call public API

    waitBriefly()

    XCTAssertFalse(manager.areFlagsReady(), "Flags should not become ready if disabled")
    // We can't easily check if _fetchFlagsIfNeeded was *not* called without more testability hooks
  }

  // Note: Testing that loadFlags *starts* a fetch is harder now without exposing internal state.
  // We test the outcome via the async getFeature tests below.

  // --- Sync Flag Retrieval Tests ---

  func testGetVariantSync_FlagsReady_ExistingFlag() {
    setupReadyFlags()
    let flagVariant = manager.getVariantSync("feature_string", fallback: defaultFallback)
    AssertEqual(flagVariant.key, "v_str")
    AssertEqual(flagVariant.value, "test_string")
    // Tracking check happens later
  }

  func testGetVariantSync_FlagsReady_MissingFlag_UsesFallback() {
    setupReadyFlags()
    let fallback = MixpanelFlagVariant(key: "fb_key", value: "fb_value")
    let flagVariant = manager.getVariantSync("missing_feature", fallback: fallback)
    AssertEqual(flagVariant.key, fallback.key)
    AssertEqual(flagVariant.value, fallback.value)
    XCTAssertEqual(mockDelegate.trackedEvents.count, 0, "Should not track for fallback")
  }

  func testGetVariantSync_FlagsNotReady_UsesFallback() {
    XCTAssertFalse(manager.areFlagsReady())  // Precondition
    let fallback = MixpanelFlagVariant(key: "fb_key", value: 999)
    let flagVariant = manager.getVariantSync("feature_bool_true", fallback: fallback)
    AssertEqual(flagVariant.key, fallback.key)
    AssertEqual(flagVariant.value, fallback.value)
    XCTAssertEqual(mockDelegate.trackedEvents.count, 0, "Should not track if flags not ready")
  }

  func testGetVariantValueSync_FlagsReady() {
    setupReadyFlags()
    let value = manager.getVariantValueSync("feature_int", fallbackValue: -1)
    AssertEqual(value, 101)
  }

  func testGetVariantValueSync_FlagsReady_MissingFlag() {
    setupReadyFlags()
    let value = manager.getVariantValueSync("missing_feature", fallbackValue: "default")
    AssertEqual(value, "default")
  }

  func testGetVariantValueSync_FlagsNotReady() {
    XCTAssertFalse(manager.areFlagsReady())
    let value = manager.getVariantValueSync("feature_int", fallbackValue: -1)
    AssertEqual(value, -1)
  }

  func testIsFlagEnabledSync_FlagsReady_True() {
    setupReadyFlags()
    XCTAssertTrue(manager.isEnabledSync("feature_bool_true"))
  }

  func testIsFlagEnabledSync_FlagsReady_False() {
    setupReadyFlags()
    XCTAssertFalse(manager.isEnabledSync("feature_bool_false"))
  }

  func testIsFlagEnabledSync_FlagsReady_MissingFlag_UsesFallback() {
    setupReadyFlags()
    XCTAssertTrue(manager.isEnabledSync("missing", fallbackValue: true))
    XCTAssertFalse(manager.isEnabledSync("missing", fallbackValue: false))
  }

  func testIsFlagEnabledSync_FlagsReady_NonBoolValue_UsesFallback() {
    setupReadyFlags()
    XCTAssertTrue(manager.isEnabledSync("feature_string", fallbackValue: true))  // String value
    XCTAssertFalse(manager.isEnabledSync("feature_int", fallbackValue: false))  // Int value
    XCTAssertTrue(manager.isEnabledSync("feature_null", fallbackValue: true))  // Null value
  }

  func testIsFlagEnabledSync_FlagsNotReady_UsesFallback() {
    XCTAssertFalse(manager.areFlagsReady())
    XCTAssertTrue(manager.isEnabledSync("feature_bool_true", fallbackValue: true))
    XCTAssertFalse(manager.isEnabledSync("feature_bool_true", fallbackValue: false))
  }

  // --- Async Flag Retrieval Tests ---

  func testGetVariant_Async_FlagsReady_ExistingFlag_XCTWaiter() {
    setupReadyFlags()
    let receivedData = getVariantAsync("feature_double")
    XCTAssertNotNil(receivedData, "Received data should be non-nil after successful wait")
    AssertEqual(receivedData?.key, "v_double")
    AssertEqual(receivedData?.value, 99.9)
  }

  func testGetVariant_Async_FlagsReady_MissingFlag_UsesFallback() {
    setupReadyFlags()
    let fallback = MixpanelFlagVariant(key: "fb_async", value: -1)
    let receivedData = getVariantAsync("missing_feature", fallback: fallback)
    XCTAssertNotNil(receivedData)
    AssertEqual(receivedData?.key, fallback.key)
    AssertEqual(receivedData?.value, fallback.value)
    XCTAssertEqual(mockDelegate.trackedEvents.count, 0, "Should not track fallback")
  }

  // Test fetch triggering and completion via getFeature when not ready
  func testGetVariant_Async_FlagsNotReady_FetchSuccess() {
    XCTAssertFalse(manager.areFlagsReady())

    // Setup tracking expectation *before* calling getFeature
    mockDelegate.trackExpectation = XCTestExpectation(description: "Tracking call for fetch success")

    let receivedData = getVariantAsync("feature_int", timeout: 3.0)

    // Wait for tracking to complete
    wait(for: [mockDelegate.trackExpectation!], timeout: 3.0)

    XCTAssertNotNil(receivedData)
    AssertEqual(receivedData?.key, "v_int")
    AssertEqual(receivedData?.value, 101)
    XCTAssertTrue(manager.areFlagsReady(), "Flags should be ready after successful fetch")
    XCTAssertEqual(mockDelegate.trackedEvents.count, 1, "Tracking event should have been recorded")
  }

  func testGetVariant_Async_FlagsNotReady_FetchFailure() {
    // Configure mock to simulate failure for this test
    configureMockFetch(success: false, flags: nil)

    XCTAssertFalse(manager.areFlagsReady())
    let fallback = MixpanelFlagVariant(key: "fb_fail", value: "failed_fetch")
    let receivedData = getVariantAsync("feature_string", fallback: fallback, timeout: 3.0)

    XCTAssertNotNil(receivedData)
    AssertEqual(receivedData?.key, fallback.key)  // Should receive fallback
    AssertEqual(receivedData?.value, fallback.value)
    XCTAssertFalse(manager.areFlagsReady(), "Flags should still not be ready after failed fetch")
    XCTAssertEqual(
      mockDelegate.trackedEvents.count, 0, "Should not track on fetch failure/fallback")

    // Reset mock configuration back to success for other tests
    resetMockToSuccess()
  }

  // --- Tracking Tests ---

  func testTracking_CalledOncePerFeature() {
    simulateFetchSuccess()  // Flags ready

    mockDelegate.trackExpectation = XCTestExpectation(
      description: "Track called once for feature_bool_true")
    mockDelegate.trackExpectation?.expectedFulfillmentCount = 1  // Expect exactly one call

    // Call sync methods multiple times
    _ = manager.getVariantSync("feature_bool_true", fallback: defaultFallback)
    _ = manager.getVariantValueSync("feature_bool_true", fallbackValue: nil)
    _ = manager.isEnabledSync("feature_bool_true")

    // Call async method
    let asyncExpectation = XCTestExpectation(
      description: "Async getFeature completes for tracking test")
    manager.getVariant("feature_bool_true", fallback: defaultFallback) { _ in
      asyncExpectation.fulfill()
    }

    // Wait for async call AND the track expectation
    wait(for: [asyncExpectation, mockDelegate.trackExpectation!], timeout: 2.0)

    // Verify track delegate method was called exactly once
    let trueEvents = mockDelegate.trackedEvents.filter {
      $0.properties?["Experiment name"] as? String == "feature_bool_true"
    }
    XCTAssertEqual(trueEvents.count, 1, "Track should only be called once for the same feature")

    // --- Call for a *different* feature ---
    mockDelegate.trackExpectation = XCTestExpectation(
      description: "Track called for feature_string")
    _ = manager.getVariantSync("feature_string", fallback: defaultFallback)
    wait(for: [mockDelegate.trackExpectation!], timeout: 1.0)

    let stringEvents = mockDelegate.trackedEvents.filter {
      $0.properties?["Experiment name"] as? String == "feature_string"
    }
    XCTAssertEqual(stringEvents.count, 1, "Track should be called again for a different feature")

    // Verify total calls
    XCTAssertEqual(mockDelegate.trackedEvents.count, 2, "Total track calls should be 2")
  }

  func testTracking_SendsCorrectProperties() {
    setupReadyFlags()
    expectTracking {
      _ = manager.getVariantSync("feature_int", fallback: defaultFallback)
    }
    verifyTrackedEvent(experimentName: "feature_int", variantName: "v_int", checkTimingProperties: true)
  }

  func testTracking_IncludesTimingProperties() {
    setupReadyFlags()
    expectTracking {
      _ = manager.getVariantSync("feature_string", fallback: defaultFallback)
    }
    verifyTrackedEvent(experimentName: "feature_string", variantName: "v_str", checkTimingProperties: true, expectedLatency: 150)
  }

  func testTracking_DoesNotTrackForFallback_Sync() {
    setupReadyFlags()
    _ = manager.getVariantSync("missing_feature", fallback: MixpanelFlagVariant(key: "fb", value: "v"))
    waitBriefly()
    XCTAssertEqual(
      mockDelegate.trackedEvents.count, 0,
      "Track should not be called when a fallback is used (sync)")
  }

  func testTracking_DoesNotTrackForFallback_Async() {
    setupReadyFlags()
    getVariantAsync("missing_feature", fallback: MixpanelFlagVariant(key: "fb", value: "v"))
    XCTAssertEqual(
      mockDelegate.trackedEvents.count, 0,
      "Track should not be called when a fallback is used (async)")
  }

  // --- Concurrency Tests ---

  // Test concurrent fetch attempts (via getFeature when not ready)
  func testConcurrentGetFeature_WhenNotReady_OnlyOneFetch() {
    XCTAssertFalse(manager.areFlagsReady())

    let numConcurrentCalls = 5
    var expectations: [XCTestExpectation] = []
    var completionResults: [MixpanelFlagVariant?] = Array(repeating: nil, count: numConcurrentCalls)

    // Use a more descriptive fallback to help with debugging
    let testFallback = MixpanelFlagVariant(key: "fallback_key", value: "fallback_value")

    // Expect tracking only ONCE for the actual feature if fetch succeeds
    mockDelegate.trackExpectation = XCTestExpectation(description: "Track call (should be once)")
    mockDelegate.trackExpectation?.expectedFulfillmentCount = 1

    print("Starting \(numConcurrentCalls) concurrent getFeature calls...")

    for i in 0..<numConcurrentCalls {
      let exp = XCTestExpectation(description: "Async getFeature \(i) completes")
      expectations.append(exp)
      DispatchQueue.global().async {  // Simulate calls from different threads
        self.manager.getVariant("feature_bool_true", fallback: testFallback) { data in
          print("Completion handler \(i) called with data: \(String(describing: data))")
          completionResults[i] = data
          exp.fulfill()
        }
      }
    }
    print("Concurrent calls dispatched.")

    // MockFeatureFlagManager will automatically handle the fetch simulation
    // No need for manual simulateFetchSuccess() - the mock handles it

    // Wait for all getFeature completions AND the single tracking call
    wait(for: expectations + [mockDelegate.trackExpectation!], timeout: 10.0)  // Much longer timeout for CI

    // Verify all completions received the correct data
    for i in 0..<numConcurrentCalls {
      XCTAssertNotNil(completionResults[i], "Completion \(i) did not receive data")
      // Check if we got the actual flag data, not the fallback
      if completionResults[i]?.key == testFallback.key {
        XCTFail("Completion \(i) received fallback instead of actual flag data")
      }
      AssertEqual(completionResults[i]?.key, "v_true")
      AssertEqual(completionResults[i]?.value, true)
    }

    // Verify flags are ready and tracking occurred only once
    XCTAssertTrue(manager.areFlagsReady())
    let trackEvents = mockDelegate.trackedEvents.filter {
      $0.properties?["Experiment name"] as? String == "feature_bool_true"
    }
    XCTAssertEqual(
      trackEvents.count, 1, "Tracking should have occurred exactly once despite concurrent calls")

    // Verify only one network fetch was triggered
    if let mockManager = manager as? MockFeatureFlagManager {
      XCTAssertEqual(
        mockManager.fetchRequestCount, 1,
        "Should have made exactly one fetch request despite concurrent calls")
    }
  }

  // --- Response Parser Tests ---

  func testResponseParserFunction() {
    // Test the response parser functionality by simulating various JSON responses
    // We'll create test data and parse it directly using JSONDecoder

    // Helper function to parse JSON data like the actual implementation does
    let parseResponse: (Data) -> FlagsResponse? = { data in
      do {
        return try JSONDecoder().decode(FlagsResponse.self, from: data)
      } catch {
        print("Error parsing flags JSON: \(error)")
        return nil
      }
    }

    // Create various test data scenarios
    let validJSON = """
      {
          "flags": {
              "test_flag": {
                  "variant_key": "test_variant",
                  "variant_value": "test_value"
              }
          }
      }
      """.data(using: .utf8)!

    let emptyFlagsJSON = """
      {
          "flags": {}
      }
      """.data(using: .utf8)!

    let nullFlagsJSON = """
      {
          "flags": null
      }
      """.data(using: .utf8)!

    let malformedJSON = "not json".data(using: .utf8)!

    // Test valid JSON with flags
    let validResult = parseResponse(validJSON)
    XCTAssertNotNil(validResult, "Parser should handle valid JSON")
    XCTAssertNotNil(validResult?.flags, "Flags should be non-nil")
    XCTAssertEqual(validResult?.flags?.count, 1, "Should have one flag")
    XCTAssertEqual(validResult?.flags?["test_flag"]?.key, "test_variant")
    XCTAssertEqual(validResult?.flags?["test_flag"]?.value as? String, "test_value")

    // Test empty flags object
    let emptyResult = parseResponse(emptyFlagsJSON)
    XCTAssertNotNil(emptyResult, "Parser should handle empty flags object")
    XCTAssertNotNil(emptyResult?.flags, "Flags should be non-nil")
    XCTAssertEqual(emptyResult?.flags?.count, 0, "Flags should be empty")

    // Test null flags field
    let nullResult = parseResponse(nullFlagsJSON)
    XCTAssertNotNil(nullResult, "Parser should handle null flags")
    XCTAssertNil(nullResult?.flags, "Flags should be nil when null in JSON")

    // Test malformed JSON
    let malformedResult = parseResponse(malformedJSON)
    XCTAssertNil(malformedResult, "Parser should return nil for malformed JSON")

    // Test with multiple flags
    let multipleFlagsJSON = """
      {
          "flags": {
              "feature_a": {
                  "variant_key": "variant_a",
                  "variant_value": true
              },
              "feature_b": {
                  "variant_key": "variant_b",
                  "variant_value": 42
              },
              "feature_c": {
                  "variant_key": "variant_c",
                  "variant_value": null
              }
          }
      }
      """.data(using: .utf8)!

    let multiResult = parseResponse(multipleFlagsJSON)
    XCTAssertNotNil(multiResult, "Parser should handle multiple flags")
    XCTAssertEqual(multiResult?.flags?.count, 3, "Should have three flags")
    XCTAssertEqual(multiResult?.flags?["feature_a"]?.value as? Bool, true)
    XCTAssertEqual(multiResult?.flags?["feature_b"]?.value as? Int, 42)
    XCTAssertNil(multiResult?.flags?["feature_c"]?.value, "Null value should be preserved")

    // Test with missing required fields
    let missingFieldJSON = """
      {
          "not_flags": {}
      }
      """.data(using: .utf8)!

    let missingFieldResult = parseResponse(missingFieldJSON)
    XCTAssertNotNil(missingFieldResult, "Parser should handle missing flags field")
    XCTAssertNil(missingFieldResult?.flags, "Flags should be nil when field is missing")

    let optionalExperimentPropertiesJSON = """
      {
          "flags": {
              "active_experiment_flag": {
                  "variant_key": "A",
                  "variant_value": "A",
                  "experiment_id": "447db52b-ec4a-4186-8d89-f9ba7bc7d7dd",
                  "is_experiment_active": true,
                  "is_qa_tester": false
              },
              "experiment_flag_for_qa_user": {
                  "variant_key": "B",
                  "variant_value": "B",
                  "experiment_id": "447db52b-ec4a-4186-8d89-f9ba7bc7d7dd",
                  "is_experiment_active": false,
                  "is_qa_tester": true
              },
              "flag_with_no_optionals": {
                  "variant_key": "C",
                  "variant_value": "C"
              }
          }
      }
      """.data(using: .utf8)!

    let experimentResult = parseResponse(optionalExperimentPropertiesJSON)
    XCTAssertNotNil(experimentResult)
    XCTAssertEqual(experimentResult?.flags?.count, 3)

    let activeFlag = experimentResult?.flags?["active_experiment_flag"]
    XCTAssertEqual(activeFlag?.key, "A")
    XCTAssertEqual(activeFlag?.value as? String, "A")
    XCTAssertEqual(activeFlag?.experimentID, "447db52b-ec4a-4186-8d89-f9ba7bc7d7dd")
    XCTAssertEqual(activeFlag?.isExperimentActive, true)
    XCTAssertEqual(activeFlag?.isQATester, false)

    let qaFlag = experimentResult?.flags?["experiment_flag_for_qa_user"]
    XCTAssertEqual(qaFlag?.key, "B")
    XCTAssertEqual(qaFlag?.value as? String, "B")
    XCTAssertEqual(qaFlag?.experimentID, "447db52b-ec4a-4186-8d89-f9ba7bc7d7dd")
    XCTAssertEqual(qaFlag?.isExperimentActive, false)
    XCTAssertEqual(qaFlag?.isQATester, true)

    let minimalFlag = experimentResult?.flags?["flag_with_no_optionals"]
    XCTAssertEqual(minimalFlag?.key, "C")
    XCTAssertEqual(minimalFlag?.value as? String, "C")
    XCTAssertNil(minimalFlag?.experimentID)
    XCTAssertNil(minimalFlag?.isExperimentActive)
    XCTAssertNil(minimalFlag?.isQATester)
  }

  // --- Delegate Error Handling Tests ---

  func testDelegateNilHandling() {
    // Set up with flags ready, but then remove delegate
    simulateFetchSuccess()
    manager.delegate = nil

    // Test all operations with nil delegate

    // Synchronous operations
    let syncData = manager.getVariantSync("feature_bool_true", fallback: defaultFallback)
    XCTAssertEqual(syncData.key, "v_true")
    XCTAssertEqual(syncData.value as? Bool, true)

    // Async operations
    let expectation = XCTestExpectation(description: "Async with nil delegate")
    manager.getVariant("feature_int", fallback: defaultFallback) { data in
      XCTAssertEqual(data.key, "v_int")
      XCTAssertEqual(data.value as? Int, 101)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    // No tracking calls should succeed, but operations should still work
    // This is "success" as the code doesn't crash when delegate is nil
  }

  func testFetchWithNoDelegate() {
    // Create manager with no delegate
    let noDelegate = FeatureFlagManager(serverURL: "https://test.com", delegate: nil)

    // Try to load flags
    noDelegate.loadFlags()

    // Verify no crash; attempt a flag fetch after a short delay
    let expectation = XCTestExpectation(description: "Check after attempted fetch")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      XCTAssertFalse(noDelegate.areFlagsReady(), "Flags should not be ready without delegate")
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)
  }

  func testDelegateConfigDisabledHandling() {
    // Set delegate options to disabled
    mockDelegate.options = MixpanelOptions(token: "test", featureFlagsEnabled: false)

    // Try to load flags
    manager.loadFlags()

    // Verify no fetch is triggered
    let expectation = XCTestExpectation(description: "Check disabled options behavior")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      XCTAssertFalse(
        self.manager.areFlagsReady(), "Flags should not be ready when options disabled")
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)
  }

  // --- AnyCodable Edge Cases ---

  func testAnyCodableWithComplexTypes() {
    // Use reflection to test AnyCodable directly

    // Test with nested array
    let nestedArrayJSON = """
      {
          "variant_key": "complex_array",
          "variant_value": [1, "string", true, [2, 3], {"key": "value"}]
      }
      """.data(using: .utf8)!

    do {
      let decoder = JSONDecoder()
      let flagData = try decoder.decode(MixpanelFlagVariant.self, from: nestedArrayJSON)

      XCTAssertEqual(flagData.key, "complex_array")
      XCTAssertNotNil(flagData.value, "Value should not be nil")

      // Verify array structure
      guard let array = flagData.value as? [Any?] else {
        XCTFail("Value should be an array")
        return
      }

      XCTAssertEqual(array.count, 5, "Array should have 5 elements")
      XCTAssertEqual(array[0] as? Int, 1)
      XCTAssertEqual(array[1] as? String, "string")
      XCTAssertEqual(array[2] as? Bool, true)

      // Nested array check
      guard let nestedArray = array[3] as? [Any?] else {
        XCTFail("Element 3 should be an array")
        return
      }
      XCTAssertEqual(nestedArray.count, 2)
      XCTAssertEqual(nestedArray[0] as? Int, 2)
      XCTAssertEqual(nestedArray[1] as? Int, 3)

      // Nested dictionary check
      guard let nestedDict = array[4] as? [String: Any?] else {
        XCTFail("Element 4 should be a dictionary")
        return
      }
      XCTAssertEqual(nestedDict.count, 1)
      XCTAssertEqual(nestedDict["key"] as? String, "value")

    } catch {
      XCTFail("Failed to decode nested array JSON: \(error)")
    }

    // Test with deeply nested object
    let nestedObjectJSON = """
      {
          "variant_key": "complex_object",
          "variant_value": {
              "str": "value",
              "num": 42,
              "bool": true,
              "null": null,
              "array": [1, 2],
              "nested": {
                  "deeper": {
                      "deepest": "bottom"
                  }
              }
          }
      }
      """.data(using: .utf8)!

    do {
      let decoder = JSONDecoder()
      let flagData = try decoder.decode(MixpanelFlagVariant.self, from: nestedObjectJSON)

      XCTAssertEqual(flagData.key, "complex_object")
      XCTAssertNotNil(flagData.value, "Value should not be nil")

      // Verify dictionary structure
      guard let dict = flagData.value as? [String: Any?] else {
        XCTFail("Value should be a dictionary")
        return
      }

      XCTAssertEqual(dict.count, 6, "Dictionary should have 6 keys")
      XCTAssertEqual(dict["str"] as? String, "value")
      XCTAssertEqual(dict["num"] as? Int, 42)
      XCTAssertEqual(dict["bool"] as? Bool, true)
      XCTAssertTrue(dict.keys.contains("null"), "Key 'null' should exist")
      if let nullEntry = dict["null"] {
        // Key exists with a value of nil (as wanted)
        XCTAssertNil(nullEntry, "Value for null key should be nil")
      } else {
        // Key doesn't exist (which would be wrong)
        XCTFail("'null' key should exist in dictionary")
      }

      // Check nested array
      guard let array = dict["array"] as? [Any?] else {
        XCTFail("Array key should contain an array")
        return
      }
      XCTAssertEqual(array.count, 2)

      // Check deeply nested structure
      guard let nested = dict["nested"] as? [String: Any?] else {
        XCTFail("Nested key should contain dictionary")
        return
      }

      guard let deeper = nested["deeper"] as? [String: Any?] else {
        XCTFail("Deeper key should contain dictionary")
        return
      }

      XCTAssertEqual(deeper["deepest"] as? String, "bottom")

    } catch {
      XCTFail("Failed to decode nested object JSON: \(error)")
    }
  }

  func testAnyCodableWithInvalidTypes() {
    // Test case where variant_value has an unsupported type
    // Note: This is harder to test directly since JSON doesn't have many "invalid" types
    // We can test error handling by constructing invalid JSON manually

    let unsupportedTypeJSON = """
      {
          "variant_key": "invalid_type",
          "variant_value": "infinity"
      }
      """.data(using: .utf8)!

    // This is a valid test since the string will decode properly
    do {
      let decoder = JSONDecoder()
      let flagData = try decoder.decode(MixpanelFlagVariant.self, from: unsupportedTypeJSON)
      XCTAssertEqual(flagData.key, "invalid_type")
      XCTAssertEqual(flagData.value as? String, "infinity")
    } catch {
      XCTFail("Should not fail with simple string value: \(error)")
    }

    // Test handling of missing variant_value
    let missingValueJSON = """
      {
          "variant_key": "missing_value"
      }
      """.data(using: .utf8)!

    do {
      let decoder = JSONDecoder()
      let _ = try decoder.decode(MixpanelFlagVariant.self, from: missingValueJSON)
      XCTFail("Decoding should fail with missing variant_value")
    } catch {
      // This is expected to fail, so the test passes
      XCTAssertTrue(error is DecodingError, "Error should be a DecodingError")
    }
  }

  func testFeatureFlagContextIncludesDeviceId() {
    // Test that device_id is included in the feature flags context
    let testAnonymousId = "test_device_id_12345"
    let testDistinctId = "test_distinct_id_67890"

    let mockDelegate = MockFeatureFlagDelegate(
      options: MixpanelOptions(token: "test", featureFlagsEnabled: true),
      distinctId: testDistinctId,
      anonymousId: testAnonymousId
    )

    let manager = FeatureFlagManager(serverURL: "https://test.com", delegate: mockDelegate)

    // Verify the delegate methods return expected values
    XCTAssertEqual(mockDelegate.getDistinctId(), testDistinctId)
    XCTAssertEqual(mockDelegate.getAnonymousId(), testAnonymousId)

    // Verify call counts
    XCTAssertEqual(mockDelegate.getDistinctIdCallCount, 1)
    XCTAssertEqual(mockDelegate.getAnonymousIdCallCount, 1)
  }

  func testFeatureFlagContextWithNilAnonymousId() {
    // Test that device_id is not included when anonymous ID is nil
    let testDistinctId = "test_distinct_id_67890"

    let mockDelegate = MockFeatureFlagDelegate(
      options: MixpanelOptions(token: "test", featureFlagsEnabled: true),
      distinctId: testDistinctId,
      anonymousId: nil
    )

    let manager = FeatureFlagManager(serverURL: "https://test.com", delegate: mockDelegate)

    // Verify the delegate methods return expected values
    XCTAssertEqual(mockDelegate.getDistinctId(), testDistinctId)
    XCTAssertNil(mockDelegate.getAnonymousId())

    // Verify call counts
    XCTAssertEqual(mockDelegate.getDistinctIdCallCount, 1)
    XCTAssertEqual(mockDelegate.getAnonymousIdCallCount, 1)
  }

  func testAccessQueueKeyFunctionality() {
    // Test that _performTrackingDelegateCall correctly determines if it's on the accessQueue
    simulateFetchSuccess()

    // First scenario: Call from accessQueue (should read timing properties directly)
    let syncExpectation = XCTestExpectation(description: "Sync tracking completes")

    // Reset tracked events
    mockDelegate.trackedEvents.removeAll()
    mockDelegate.trackExpectation = syncExpectation

    // Call getVariantSync which should trigger tracking from within the accessQueue
    _ = manager.getVariantSync("feature_double", fallback: defaultFallback)

    wait(for: [syncExpectation], timeout: 1.0)

    // Verify tracking occurred with timing properties
    XCTAssertEqual(mockDelegate.trackedEvents.count, 1, "Should have tracked once")
    let syncTrackedEvent = mockDelegate.trackedEvents[0]
    XCTAssertEqual(syncTrackedEvent.event, "$experiment_started")

    // Verify timing properties are present
    let syncProps = syncTrackedEvent.properties!
    XCTAssertNotNil(syncProps["timeLastFetched"], "Should have timeLastFetched")
    XCTAssertNotNil(syncProps["fetchLatencyMs"], "Should have fetchLatencyMs")
    XCTAssertEqual(syncProps["fetchLatencyMs"] as? Int, 150, "Should have expected latency")

    // Second scenario: Call from outside accessQueue (should sync to read properties)
    let asyncExpectation = XCTestExpectation(description: "Async tracking completes")

    // Reset tracked events and set up new tracking expectation
    mockDelegate.trackedEvents.removeAll()
    mockDelegate.trackExpectation = asyncExpectation

    // Use async getVariant which may trigger tracking from different queue contexts
    manager.getVariant("feature_null", fallback: defaultFallback) { _ in
      // This completion runs on main queue
    }

    wait(for: [asyncExpectation], timeout: 1.0)

    // Verify tracking occurred with timing properties
    XCTAssertEqual(mockDelegate.trackedEvents.count, 1, "Should have tracked once")
    let asyncTrackedEvent = mockDelegate.trackedEvents[0]
    XCTAssertEqual(asyncTrackedEvent.event, "$experiment_started")

    // Verify timing properties are present (should be the same regardless of queue)
    let asyncProps = asyncTrackedEvent.properties!
    XCTAssertNotNil(asyncProps["timeLastFetched"], "Should have timeLastFetched")
    XCTAssertNotNil(asyncProps["fetchLatencyMs"], "Should have fetchLatencyMs")
    XCTAssertEqual(asyncProps["fetchLatencyMs"] as? Int, 150, "Should have expected latency")
  }

  func testTrackingFromDifferentQueueContexts() {
    // Test that tracking works correctly when called from various queue contexts
    simulateFetchSuccess()

    let testQueue = DispatchQueue(label: "test.queue")
    let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

    // Track expectations for multiple calls
    let expectationCount = 3
    var expectations: [XCTestExpectation] = []
    for i in 0..<expectationCount {
      expectations.append(XCTestExpectation(description: "Track call \(i)"))
    }

    mockDelegate.trackedEvents.removeAll()
    var trackIndex = 0

    // Set custom track handler to fulfill expectations in order
    mockDelegate.customTrackHandler = { event, properties in
      if trackIndex < expectations.count {
        expectations[trackIndex].fulfill()
        trackIndex += 1
      }
    }

    // Test 1: From custom serial queue
    testQueue.async {
      _ = self.manager.getVariantSync("feature_bool_true", fallback: self.defaultFallback)
    }

    // Test 2: From concurrent queue
    concurrentQueue.async {
      _ = self.manager.getVariantSync("feature_bool_false", fallback: self.defaultFallback)
    }

    // Test 3: From main queue
    DispatchQueue.main.async {
      _ = self.manager.getVariantSync("feature_string", fallback: self.defaultFallback)
    }

    // Wait for all tracking to complete
    wait(for: expectations, timeout: 2.0)

    // Verify all tracking calls included timing properties
    XCTAssertEqual(mockDelegate.trackedEvents.count, expectationCount)

    for (index, event) in mockDelegate.trackedEvents.enumerated() {
      XCTAssertEqual(
        event.event, "$experiment_started", "Event \(index) should be $experiment_started")
      let props = event.properties!
      XCTAssertNotNil(props["timeLastFetched"], "Event \(index) should have timeLastFetched")
      XCTAssertNotNil(props["fetchLatencyMs"], "Event \(index) should have fetchLatencyMs")
      XCTAssertEqual(
        props["fetchLatencyMs"] as? Int, 150, "Event \(index) should have expected latency")
    }
  }

  func testTrackingIncludesOptionalProperties() {
    // Set up flags with experiment properties
    let flagsWithExperiment: [String: MixpanelFlagVariant] = [
      "experiment_flag": MixpanelFlagVariant(key: "variant_a", value: true, isExperimentActive: true, isQATester: false, experimentID: "exp_123")
    ]
    simulateFetchSuccess(flags: flagsWithExperiment)

    mockDelegate.trackExpectation = XCTestExpectation(description: "Track with experiment properties")
    _ = manager.getVariantSync("experiment_flag", fallback: defaultFallback)
    wait(for: [mockDelegate.trackExpectation!], timeout: 1.0)

    let props = mockDelegate.trackedEvents[0].properties!
    XCTAssertEqual(props["$experiment_id"] as? String, "exp_123")
    XCTAssertEqual(props["$is_experiment_active"] as? Bool, true)
    XCTAssertEqual(props["$is_qa_tester"] as? Bool, false)
  }

  // MARK: - Timing Properties Sanity Tests

  func testTimingPropertiesSanity() {
    // 1. Test Initial State - Properties should be nil before any fetch
    XCTAssertNil(manager.timeLastFetched, "timeLastFetched should be nil initially")
    XCTAssertNil(manager.fetchLatencyMs, "fetchLatencyMs should be nil initially")

    // 2. Test Accurate Timing Calculation with Real Delay
    if let mockManager = manager as? MockFeatureFlagManager {
      // Configure mock to simulate a realistic network delay
      let expectedDelayMs = 250  // 250ms simulated network delay
      mockManager.shouldSimulateNetworkDelay = true

      // Create a custom expectation to measure actual time
      let fetchExpectation = XCTestExpectation(description: "Fetch completes with timing")
      let fetchStartTime = Date()

      // Trigger async fetch
      manager.getVariant("feature_bool_true", fallback: defaultFallback) { _ in
        fetchExpectation.fulfill()
      }

      wait(for: [fetchExpectation], timeout: 2.0)

      // Verify timing properties are set and reasonable
      XCTAssertNotNil(
        manager.timeLastFetched, "timeLastFetched should be set after successful fetch")
      XCTAssertNotNil(manager.fetchLatencyMs, "fetchLatencyMs should be set after successful fetch")

      // 3. Test Reasonable Bounds
      if let latencyMs = manager.fetchLatencyMs {
        XCTAssertGreaterThan(latencyMs, 0, "fetchLatencyMs should be positive")
        XCTAssertLessThan(latencyMs, 30000, "fetchLatencyMs should be less than 30 seconds")

        // Verify latency is in reasonable range for our simulated delay
        // Allow some tolerance for execution overhead
        let actualElapsedMs = Int(Date().timeIntervalSince(fetchStartTime) * 1000)
        let tolerance = 500  // 500ms tolerance for CI/slow systems
        XCTAssertLessThanOrEqual(
          abs(latencyMs - actualElapsedMs), tolerance,
          "fetchLatencyMs (\(latencyMs)ms) should be close to actual elapsed time (\(actualElapsedMs)ms)"
        )
      }

      if let timeLastFetched = manager.timeLastFetched {
        let timestamp = Int(timeLastFetched.timeIntervalSince1970)
        let year2020Timestamp = 1_577_836_800  // Jan 1, 2020
        let year2100Timestamp = 4_102_444_800  // Jan 1, 2100

        XCTAssertGreaterThan(
          timestamp, year2020Timestamp, "timeLastFetched should be after year 2020")
        XCTAssertLessThan(
          timestamp, year2100Timestamp, "timeLastFetched should be before year 2100")

        // Verify timestamp is not in the future
        XCTAssertLessThanOrEqual(
          timeLastFetched.timeIntervalSinceNow, 1.0,
          "timeLastFetched should not be in the future (allowing 1s tolerance)"
        )
      }
    }

    // 4. Test Update on Subsequent Fetches
    if let mockManager = manager as? MockFeatureFlagManager {
      // Store first fetch values
      let firstFetchTime = manager.timeLastFetched
      let firstLatency = manager.fetchLatencyMs

      // Wait a bit to ensure time difference
      Thread.sleep(forTimeInterval: 0.1)

      // Reset flags to trigger new fetch
      mockManager.accessQueue.sync {
        mockManager.flags = nil
      }

      // Configure different delay for second fetch
      mockManager.shouldSimulateNetworkDelay = true
      mockManager.simulatedFetchResult = (success: true, flags: sampleFlags)

      let secondFetchExpectation = XCTestExpectation(description: "Second fetch completes")

      manager.getVariant("feature_string", fallback: defaultFallback) { _ in
        secondFetchExpectation.fulfill()
      }

      wait(for: [secondFetchExpectation], timeout: 2.0)

      // Verify timing properties updated
      XCTAssertNotNil(manager.timeLastFetched, "timeLastFetched should be set after second fetch")
      XCTAssertNotNil(manager.fetchLatencyMs, "fetchLatencyMs should be set after second fetch")

      if let firstTime = firstFetchTime, let secondTime = manager.timeLastFetched {
        XCTAssertGreaterThan(
          secondTime.timeIntervalSince1970, firstTime.timeIntervalSince1970,
          "Second fetch time should be later than first fetch time"
        )
      }

      // Latency might be similar but should be independently calculated
      XCTAssertNotNil(
        manager.fetchLatencyMs, "fetchLatencyMs should still be set after second fetch")
    }

    // 5. Test Failed Fetch Behavior
    if let mockManager = manager as? MockFeatureFlagManager {
      // Store current valid timing values
      let validTimeLastFetched = manager.timeLastFetched
      let validFetchLatency = manager.fetchLatencyMs

      // Reset flags and configure for failure
      mockManager.accessQueue.sync {
        mockManager.flags = nil
      }
      mockManager.simulatedFetchResult = (success: false, flags: nil)

      let failedFetchExpectation = XCTestExpectation(description: "Failed fetch completes")

      manager.getVariant("feature_int", fallback: defaultFallback) { variant in
        // Should get fallback on failure
        XCTAssertEqual(
          variant.key, self.defaultFallback.key, "Should receive fallback on fetch failure")
        failedFetchExpectation.fulfill()
      }

      wait(for: [failedFetchExpectation], timeout: 2.0)

      // Verify timing properties aren't corrupted by failed fetch
      // They should either remain unchanged or be cleared, but not set to invalid values
      if manager.timeLastFetched != nil {
        // If still set, should be the previous valid value
        XCTAssertEqual(
          manager.timeLastFetched?.timeIntervalSince1970,
          validTimeLastFetched?.timeIntervalSince1970,
          "timeLastFetched should not be updated on failed fetch"
        )
      }

      if manager.fetchLatencyMs != nil {
        // If still set, should be the previous valid value
        XCTAssertEqual(
          manager.fetchLatencyMs, validFetchLatency,
          "fetchLatencyMs should not be updated on failed fetch"
        )
      }

      // Reset to success for cleanup
      mockManager.simulatedFetchResult = (success: true, flags: sampleFlags)
    }

    // 6. Test Consistency Between Timing Properties
    if let mockManager = manager as? MockFeatureFlagManager {
      // Ensure we have a successful fetch
      mockManager.accessQueue.sync {
        mockManager.flags = nil
      }

      let consistencyExpectation = XCTestExpectation(description: "Fetch for consistency check")

      manager.getVariant("feature_double", fallback: defaultFallback) { _ in
        consistencyExpectation.fulfill()
      }

      wait(for: [consistencyExpectation], timeout: 2.0)

      // Both should be set or both should be nil
      if manager.fetchLatencyMs != nil {
        XCTAssertNotNil(
          manager.timeLastFetched,
          "If fetchLatencyMs is set, timeLastFetched should also be set"
        )
      }

      if manager.timeLastFetched != nil {
        XCTAssertNotNil(
          manager.fetchLatencyMs,
          "If timeLastFetched is set, fetchLatencyMs should also be set"
        )
      }
    }

    // 7. Test Timing Properties in Tracking Events
    // Reset tracked events to test fresh tracking
    mockDelegate.trackedEvents.removeAll()

    // Use a unique flag name that hasn't been tracked yet to ensure fresh tracking
    let uniqueFlagName = "test_timing_flag_\(UUID().uuidString.prefix(8))"

    // Create a test flag for this unique name
    if let mockManager = manager as? MockFeatureFlagManager {
      var testFlags = sampleFlags
      testFlags[uniqueFlagName] = MixpanelFlagVariant(key: "timing_test", value: true)
      mockManager.accessQueue.sync {
        mockManager.flags = testFlags
      }
    }

    let trackingExpectation = XCTestExpectation(description: "Tracking includes timing properties")
    mockDelegate.trackExpectation = trackingExpectation

    // Trigger tracking by accessing the unique flag
    _ = manager.getVariantSync(uniqueFlagName, fallback: defaultFallback)

    wait(for: [trackingExpectation], timeout: 1.0)

    XCTAssertEqual(mockDelegate.trackedEvents.count, 1, "Should have tracked one event")
    let trackedEvent = mockDelegate.trackedEvents[0]
    let props = trackedEvent.properties!

    // Verify timing properties are included in tracking
    if manager.timeLastFetched != nil {
      XCTAssertNotNil(props["timeLastFetched"], "Tracking should include timeLastFetched")
      if let trackedTimestamp = props["timeLastFetched"] as? Int {
        let expectedTimestamp = Int(manager.timeLastFetched!.timeIntervalSince1970)
        XCTAssertEqual(
          trackedTimestamp, expectedTimestamp,
          "Tracked timeLastFetched should match manager's value"
        )
      }
    }

    if manager.fetchLatencyMs != nil {
      XCTAssertNotNil(props["fetchLatencyMs"], "Tracking should include fetchLatencyMs")
      if let trackedLatency = props["fetchLatencyMs"] as? Int {
        XCTAssertEqual(
          trackedLatency, manager.fetchLatencyMs!,
          "Tracked fetchLatencyMs should match manager's value"
        )
      }
    }
  }

  func testGETRequestFormat() {
    // Use a fresh MockFeatureFlagManager with request validation enabled
    let mockManager = MockFeatureFlagManager(serverURL: "https://api.mixpanel.com", delegate: mockDelegate)
    mockManager.requestValidationEnabled = true
    mockManager.simulatedFetchResult = (success: true, flags: sampleFlags)

    // Trigger a request
    mockManager.loadFlags()

    // Wait for request to be processed
    let expectation = XCTestExpectation(description: "Request validation completes")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
    wait(for: [expectation], timeout: 1.0)

    // Verify no validation errors
    XCTAssertNil(mockManager.requestValidationError, "Request validation should not have errors: \(mockManager.requestValidationError ?? "")")

    // Verify GET method
    XCTAssertEqual(mockManager.lastRequestMethod, .get, "Should use GET method")

    // Verify headers
    XCTAssertNotNil(mockManager.lastRequestHeaders, "Headers should be captured")
    if let headers = mockManager.lastRequestHeaders {
      XCTAssertTrue(headers.keys.contains("Authorization"), "Should include Authorization header")
      XCTAssertTrue(headers["Authorization"]?.starts(with: "Basic ") == true, "Should use Basic auth")
      XCTAssertFalse(headers.keys.contains("Content-Type"), "Should not include Content-Type header for GET")
    }

    // Verify no request body
    XCTAssertNil(mockManager.lastRequestBody, "GET request should not have a body")

    // Verify query parameters
    XCTAssertNotNil(mockManager.lastQueryItems, "Query items should be captured")
    if let queryItems = mockManager.lastQueryItems {
      let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

      // Check required parameters
      XCTAssertNotNil(queryDict["context"], "Should include context parameter")
      XCTAssertEqual(queryDict["token"], "test", "Should include token parameter")
      XCTAssertEqual(queryDict["mp_lib"], "swift", "Should include mp_lib parameter")
      XCTAssertEqual(queryDict["$lib_version"], AutomaticProperties.libVersion(), "Should include $lib_version parameter")

      // Verify context JSON structure
      if let contextString = queryDict["context"],
        let contextData = contextString?.data(using: .utf8),
        let context = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] {
        XCTAssertEqual(context["distinct_id"] as? String, "test_distinct_id", "Context should include distinct_id")
        XCTAssertEqual(context["device_id"] as? String, "test_anonymous_id", "Context should include device_id")
      } else {
        XCTFail("Context should be valid JSON")
      }
    }
  }

  func testGETRequestWithCustomContext() {
    // Set up custom context
    let customOptions = MixpanelOptions(token: "custom-token", featureFlagsEnabled: true, featureFlagsContext: [
      "user_id": "test-user-123",
      "group_id": "test-group-456"
    ])

    let customDelegate = MockFeatureFlagDelegate(
      options: customOptions,
      distinctId: "custom-distinct-id",
      anonymousId: "custom-device-id"
    )

    let mockManager = MockFeatureFlagManager(serverURL: "https://api.mixpanel.com", delegate: customDelegate)
    mockManager.requestValidationEnabled = true
    mockManager.simulatedFetchResult = (success: true, flags: sampleFlags)

    // Trigger a request
    mockManager.loadFlags()

    // Wait for request to be processed
    let expectation = XCTestExpectation(description: "Custom context request validation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
    wait(for: [expectation], timeout: 1.0)

    // Verify no validation errors
    XCTAssertNil(mockManager.requestValidationError, "Request validation should not have errors")

    // Verify query parameters with custom context
    XCTAssertNotNil(mockManager.lastQueryItems, "Query items should be captured")
    if let queryItems = mockManager.lastQueryItems {
      let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
      XCTAssertEqual(queryDict["token"], "custom-token", "Should include custom token")
      // Verify context includes both standard and custom fields
      if let contextString = queryDict["context"],
        let contextData = contextString?.data(using: .utf8),
        let context = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] {

        XCTAssertEqual(context["distinct_id"] as? String, "custom-distinct-id", "Context should include distinct_id")
        XCTAssertEqual(context["device_id"] as? String, "custom-device-id", "Context should include device_id")
        XCTAssertEqual(context["user_id"] as? String, "test-user-123", "Context should include custom user_id")
        XCTAssertEqual(context["group_id"] as? String, "test-group-456", "Context should include custom group_id")
      } else {
        XCTFail("Context should be valid JSON with custom fields")
      }
    }
  }

  func testGETRequestWithNilAnonymousId() {
    // Set up with nil anonymous ID
    let nilAnonymousDelegate = MockFeatureFlagDelegate(
      options: MixpanelOptions(token: "test-token", featureFlagsEnabled: true),
      distinctId: "test-distinct-id",
      anonymousId: nil
    )

    let mockManager = MockFeatureFlagManager(serverURL: "https://api.mixpanel.com", delegate: nilAnonymousDelegate)
    mockManager.requestValidationEnabled = true
    mockManager.simulatedFetchResult = (success: true, flags: sampleFlags)

    // Trigger a request
    mockManager.loadFlags()

    // Wait for request to be processed
    let expectation = XCTestExpectation(description: "Nil anonymous ID request validation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
    wait(for: [expectation], timeout: 1.0)

    // Verify no validation errors
    XCTAssertNil(mockManager.requestValidationError, "Request validation should not have errors with nil anonymous ID")

    // Verify context excludes device_id when anonymous ID is nil
    if let queryItems = mockManager.lastQueryItems {
      let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

        if let contextString = queryDict["context"],
          let contextData = contextString?.data(using: .utf8),
          let context = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] {

          XCTAssertEqual(context["distinct_id"] as? String, "test-distinct-id", "Context should include distinct_id")
          XCTAssertNil(context["device_id"], "Context should not include device_id when anonymous ID is nil")

          // Should only contain distinct_id (no additional context configured)
          XCTAssertEqual(context.keys.count, 1, "Context should only contain distinct_id when no device_id or additional context")
      } else {
        XCTFail("Context should be valid JSON")
      }
    }
  }

  // MARK: - First-Time Event Targeting Tests

  // MARK: Response Parsing Tests

  func testParsePendingFirstTimeEvents() {
    let json = """
    {
      "flags": {
        "test-flag": {
          "variant_key": "control",
          "variant_value": false
        }
      },
      "pending_first_time_events": [
        {
          "flag_key": "test-flag",
          "flag_id": "flag-123",
          "project_id": 3,
          "cohort_hash": "abc123",
          "event_name": "Purchase Complete",
          "property_filters": {
            ">": [{"var": "properties.amount"}, 100]
          },
          "pending_variant": {
            "variant_key": "treatment",
            "variant_value": true,
            "experiment_id": "exp-456",
            "is_experiment_active": true
          }
        }
      ]
    }
    """.data(using: .utf8)!

    do {
      let response = try JSONDecoder().decode(FlagsResponse.self, from: json)
      XCTAssertNotNil(response.flags)
      XCTAssertNotNil(response.pendingFirstTimeEvents)
      XCTAssertEqual(response.pendingFirstTimeEvents?.count, 1)

      let pendingEvent = response.pendingFirstTimeEvents![0]
      XCTAssertEqual(pendingEvent.flagKey, "test-flag")
      XCTAssertEqual(pendingEvent.flagId, "flag-123")
      XCTAssertEqual(pendingEvent.projectId, 3)
      XCTAssertEqual(pendingEvent.cohortHash, "abc123")
      XCTAssertEqual(pendingEvent.eventName, "Purchase Complete")
      XCTAssertNotNil(pendingEvent.propertyFilters)
      XCTAssertEqual(pendingEvent.pendingVariant.key, "treatment")
      XCTAssertEqual(pendingEvent.pendingVariant.value as? Bool, true)
    } catch {
      XCTFail("Failed to parse response: \(error)")
    }
  }

  func testParseEmptyPendingFirstTimeEvents() {
    let json = """
    {
      "flags": {},
      "pending_first_time_events": []
    }
    """.data(using: .utf8)!

    do {
      let response = try JSONDecoder().decode(FlagsResponse.self, from: json)
      XCTAssertNotNil(response.pendingFirstTimeEvents)
      XCTAssertEqual(response.pendingFirstTimeEvents?.count, 0)
    } catch {
      XCTFail("Failed to parse response: \(error)")
    }
  }

  // MARK: First-Time Event Matching Tests

  func testFirstTimeEventMatching_ExactNameMatch() {
    let pendingVariant = createExperimentVariant(key: "activated", value: true, experimentID: "exp-123")
    let initialVariant = createControlVariant(value: false)

    setupAndTriggerFirstTimeEvent(
      flagKey: "welcome-modal",
      eventName: "Dashboard Viewed",
      pendingVariant: pendingVariant,
      initialVariant: initialVariant
    ) { mockMgr in
      let flag = mockMgr.flags?["welcome-modal"]
      XCTAssertEqual(flag?.key, "activated")
      XCTAssertEqual(flag?.value as? Bool, true)
      XCTAssertTrue(mockMgr.activatedFirstTimeEvents.contains("welcome-modal:hash123"))
    }
  }

  func testFirstTimeEventMatching_WithPropertyFilters() {
    let pendingVariant = createExperimentVariant(key: "premium", value: ["discount": 20], experimentID: "exp-456")
    let initialVariant = createControlVariant(value: nil)
    let filters: [String: Any] = [">": [["var": "properties.amount"], 100]]

    setupAndTriggerFirstTimeEvent(
      flagKey: "premium-welcome",
      eventName: "Purchase Complete",
      eventProperties: ["amount": 150],
      filters: filters,
      pendingVariant: pendingVariant,
      initialVariant: initialVariant,
      cohortHash: "hash456"
    ) { mockMgr in
      let flag = mockMgr.flags?["premium-welcome"]
      XCTAssertEqual(flag?.key, "premium")
      XCTAssertTrue(mockMgr.activatedFirstTimeEvents.contains("premium-welcome:hash456"))
    }
  }

  func testFirstTimeEventMatching_PropertyFilterNoMatch() {
    let pendingVariant = MixpanelFlagVariant(key: "premium", value: true)
    let initialVariant = createControlVariant(value: false)
    let filters: [String: Any] = [">": [["var": "properties.amount"], 100]]

    // Trigger event with amount < 100 (should NOT match)
    setupAndTriggerFirstTimeEvent(
      flagKey: "premium-welcome",
      eventName: "Purchase Complete",
      eventProperties: ["amount": 50],
      filters: filters,
      pendingVariant: pendingVariant,
      initialVariant: initialVariant,
      cohortHash: "hash456"
    ) { mockMgr in
      let flag = mockMgr.flags?["premium-welcome"]
      XCTAssertEqual(flag?.key, "control")
      XCTAssertFalse(mockMgr.activatedFirstTimeEvents.contains("premium-welcome:hash456"))
    }
  }

  func testFirstTimeEventMatching_CaseInsensitiveProperties() {
    let pendingVariant = MixpanelFlagVariant(key: "matched", value: true)
    let initialVariant = createControlVariant(value: false)
    let filters: [String: Any] = ["==": [["var": "properties.plan"], "PREMIUM"]]

    // Trigger event with lowercase plan (should match due to case-insensitive comparison)
    setupAndTriggerFirstTimeEvent(
      flagKey: "case-test",
      eventName: "Test Event",
      eventProperties: ["plan": "premium"],
      filters: filters,
      pendingVariant: pendingVariant,
      initialVariant: initialVariant,
      cohortHash: "hash789"
    ) { mockMgr in
      let flag = mockMgr.flags?["case-test"]
      XCTAssertEqual(flag?.key, "matched")
    }
  }

  // MARK: Activation State Tests

  func testFirstTimeEventActivatesOnlyOnce() {
    if let mockManager = manager as? MockFeatureFlagManager {
      let pendingVariant = MixpanelFlagVariant(key: "activated", value: true)

      let pendingEvent = createPendingEvent(
        flagKey: "once-only",
        eventName: "Test Event",
        filters: nil,
        pendingVariant: pendingVariant
      )

      mockManager.accessQueue.sync {
        mockManager.flags = ["once-only": MixpanelFlagVariant(key: "control", value: false)]
        mockManager.pendingFirstTimeEvents = ["once-only:hash999": pendingEvent]
        // Reset tracking state
        mockManager.recordFirstTimeEventCallCount = 0
      }

      // Trigger event multiple times
      mockManager.checkFirstTimeEvents(eventName: "Test Event", properties: [:])
      mockManager.checkFirstTimeEvents(eventName: "Test Event", properties: [:])
      mockManager.checkFirstTimeEvents(eventName: "Test Event", properties: [:])

      let expectation = XCTestExpectation(description: "Event processing completes")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
      wait(for: [expectation], timeout: 1.0)

      // Verify activation occurred and is tracked
      mockManager.accessQueue.sync {
        XCTAssertTrue(mockManager.activatedFirstTimeEvents.contains("once-only:hash999"))

        // Verify recordFirstTimeEvent was called exactly once
        XCTAssertEqual(mockManager.recordFirstTimeEventCallCount, 1,
          "recordFirstTimeEvent should be called exactly once, not \(mockManager.recordFirstTimeEventCallCount) times")

        // Verify the correct parameters were recorded
        XCTAssertEqual(mockManager.lastRecordedFlagId, "test-flag-id")
        XCTAssertEqual(mockManager.lastRecordedProjectId, 1)
        XCTAssertEqual(mockManager.lastRecordedCohortHash, "hash123")
      }
    }
  }

  // MARK: Flag Refresh Edge Cases

  func testFlagRefresh_PreservesActivatedVariants() {
    if let mockManager = manager as? MockFeatureFlagManager {
      // Set up initial state with activated variant
      mockManager.accessQueue.sync {
        mockManager.flags = ["test-flag": MixpanelFlagVariant(key: "activated", value: true)]
        mockManager.activatedFirstTimeEvents.insert("test-flag:hash123")
      }

      // Simulate fetch response with different variant for same flag
      let newFlags = ["test-flag": MixpanelFlagVariant(key: "control", value: false)]
      mockManager.simulatedFetchResult = (success: true, flags: newFlags)

      // Trigger fetch
      mockManager.loadFlags()

      let expectation = XCTestExpectation(description: "Fetch completes")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
      wait(for: [expectation], timeout: 1.0)

      // Verify activated variant was preserved
      mockManager.accessQueue.sync {
        let flag = mockManager.flags?["test-flag"]
        XCTAssertEqual(flag?.key, "activated", "Activated variant should be preserved")
        XCTAssertEqual(flag?.value as? Bool, true)
      }
    }
  }

  func testFlagRefresh_KeepsOrphanedActivatedFlags() {
    if let mockManager = manager as? MockFeatureFlagManager {
      // Set up initial state with activated variant
      mockManager.accessQueue.sync {
        mockManager.flags = ["orphaned-flag": MixpanelFlagVariant(key: "activated", value: true)]
        mockManager.activatedFirstTimeEvents.insert("orphaned-flag:hash123")
      }

      // Simulate fetch response WITHOUT the orphaned flag
      let newFlags = ["other-flag": MixpanelFlagVariant(key: "control", value: false)]
      mockManager.simulatedFetchResult = (success: true, flags: newFlags)

      // Trigger fetch
      mockManager.loadFlags()

      let expectation = XCTestExpectation(description: "Fetch completes")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
      wait(for: [expectation], timeout: 1.0)

      // Verify orphaned flag was kept
      mockManager.accessQueue.sync {
        let flag = mockManager.flags?["orphaned-flag"]
        XCTAssertNotNil(flag, "Orphaned activated flag should be kept")
        XCTAssertEqual(flag?.key, "activated")
      }
    }
  }

  // MARK: Helper Methods

  private func createPendingEvent(
    flagKey: String,
    eventName: String,
    filters: [String: Any]?,
    pendingVariant: MixpanelFlagVariant
  ) -> PendingFirstTimeEvent {
    let json: [String: Any] = [
      "flag_key": flagKey,
      "flag_id": "test-flag-id",
      "project_id": 1,
      "cohort_hash": "hash123",
      "event_name": eventName,
      "property_filters": filters as Any,
      "pending_variant": [
        "variant_key": pendingVariant.key,
        "variant_value": pendingVariant.value as Any,
        "experiment_id": pendingVariant.experimentID as Any,
        "is_experiment_active": pendingVariant.isExperimentActive as Any,
        "is_qa_tester": pendingVariant.isQATester as Any
      ]
    ]

    let data = try! JSONSerialization.data(withJSONObject: json)
    return try! JSONDecoder().decode(PendingFirstTimeEvent.self, from: data)
  }

}  // End Test Class
