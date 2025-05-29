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
  var trackedEvents: [(event: String?, properties: Properties?)] = []
  var trackExpectation: XCTestExpectation?
  var getOptionsCallCount = 0
  var getDistinctIdCallCount = 0

  init(
    options: MixpanelOptions = MixpanelOptions(token: "test", featureFlagsEnabled: true),
    distinctId: String = "test_distinct_id"
  ) {
    self.options = options
    self.distinctId = distinctId
  }

  func getOptions() -> MixpanelOptions {
    getOptionsCallCount += 1
    return options
  }

  func getDistinctId() -> String {
    getDistinctIdCallCount += 1
    return distinctId
  }

  func track(event: String?, properties: Properties?) {
    print("MOCK Delegate: Track called - Event: \(event ?? "nil"), Props: \(properties ?? [:])")
    trackedEvents.append((event: event, properties: properties))
    trackExpectation?.fulfill()
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
    // Ensure manager is initialized with the delegate
    manager = FeatureFlagManager(serverURL: "https://test.com", delegate: mockDelegate)
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
    // Set flags directly *before* calling completeFetch
    manager.accessQueue.sync {
      manager.flags = flagsToSet
      // Important: Set isFetching = true *before* calling _completeFetch,
      // as _completeFetch assumes a fetch was in progress.
      manager.isFetching = true
    }
    // Call internal completion logic
    manager._completeFetch(success: true)
  }

  private func simulateFetchFailure() {
    // Set isFetching = true before calling _completeFetch
    manager.accessQueue.sync {
      manager.isFetching = true
      // Ensure flags are nil or unchanged on failure simulation if desired
      manager.flags = nil  // Or keep existing flags based on desired failure behavior
    }
    // Call internal completion logic
    manager._completeFetch(success: false)
  }

  // --- State and Configuration Tests ---

  func testAreFeaturesReady_InitialState() {
    XCTAssertFalse(manager.areFlagsReady(), "Features should not be ready initially")
  }

  func testAreFeaturesReady_AfterSuccessfulFetchSimulation() {
    simulateFetchSuccess()
    // Need to wait briefly for the main queue dispatch in _completeFetch to potentially run
    let expectation = XCTestExpectation(description: "Wait for potential completion dispatch")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expectation.fulfill() }
    wait(for: [expectation], timeout: 0.5)
    XCTAssertTrue(
      manager.areFlagsReady(), "Features should be ready after successful fetch simulation")
  }

  func testAreFeaturesReady_AfterFailedFetchSimulation() {
    simulateFetchFailure()
    // Need to wait briefly for the main queue dispatch in _completeFetch to potentially run
    let expectation = XCTestExpectation(description: "Wait for potential completion dispatch")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expectation.fulfill() }
    wait(for: [expectation], timeout: 0.5)
    XCTAssertFalse(
      manager.areFlagsReady(), "Features should not be ready after failed fetch simulation")
  }

  // --- Load Flags Tests ---

  func testLoadFlags_WhenDisabledInConfig() {
    mockDelegate.options = MixpanelOptions(token: "test", featureFlagsEnabled: false)  // Explicitly disable
    manager.loadFlags()  // Call public API

    // Wait to ensure no async fetch operations started changing state
    let expectation = XCTestExpectation(description: "Wait briefly")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expectation.fulfill() }
    wait(for: [expectation], timeout: 0.5)

    XCTAssertFalse(manager.areFlagsReady(), "Flags should not become ready if disabled")
    // We can't easily check if _fetchFlagsIfNeeded was *not* called without more testability hooks
  }

  // Note: Testing that loadFlags *starts* a fetch is harder now without exposing internal state.
  // We test the outcome via the async getFeature tests below.

  // --- Sync Flag Retrieval Tests ---

  func testGetVariantSync_FlagsReady_ExistingFlag() {
    simulateFetchSuccess()  // Flags loaded
    let flagVariant = manager.getVariantSync("feature_string", fallback: defaultFallback)
    AssertEqual(flagVariant.key, "v_str")
    AssertEqual(flagVariant.value, "test_string")
    // Tracking check happens later
  }

  func testGetVariantSync_FlagsReady_MissingFlag_UsesFallback() {
    simulateFetchSuccess()
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
    simulateFetchSuccess()
    let value = manager.getVariantValueSync("feature_int", fallbackValue: -1)
    AssertEqual(value, 101)
  }

  func testGetVariantValueSync_FlagsReady_MissingFlag() {
    simulateFetchSuccess()
    let value = manager.getVariantValueSync("missing_feature", fallbackValue: "default")
    AssertEqual(value, "default")
  }

  func testGetVariantValueSync_FlagsNotReady() {
    XCTAssertFalse(manager.areFlagsReady())
    let value = manager.getVariantValueSync("feature_int", fallbackValue: -1)
    AssertEqual(value, -1)
  }

  func testIsFlagEnabledSync_FlagsReady_True() {
    simulateFetchSuccess()
    XCTAssertTrue(manager.isEnabledSync("feature_bool_true"))
  }

  func testIsFlagEnabledSync_FlagsReady_False() {
    simulateFetchSuccess()
    XCTAssertFalse(manager.isEnabledSync("feature_bool_false"))
  }

  func testIsFlagEnabledSync_FlagsReady_MissingFlag_UsesFallback() {
    simulateFetchSuccess()
    XCTAssertTrue(manager.isEnabledSync("missing", fallbackValue: true))
    XCTAssertFalse(manager.isEnabledSync("missing", fallbackValue: false))
  }

  func testIsFlagEnabledSync_FlagsReady_NonBoolValue_UsesFallback() {
    simulateFetchSuccess()
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
    // Arrange
    simulateFetchSuccess()  // Ensure flags are ready
    let expectation = XCTestExpectation(description: "Async getFeature ready - XCTWaiter Wait")
    var receivedData: MixpanelFlagVariant?
    var assertionError: String?

    // Act
    manager.getVariant("feature_double", fallback: defaultFallback) { data in
      // This completion should run on the main thread
      if !Thread.isMainThread {
        assertionError = "Completion not on main thread (\(Thread.current))"
      }
      receivedData = data
      // Perform crucial checks inside completion
      if receivedData == nil { assertionError = (assertionError ?? "") + "; Received data was nil" }
      if receivedData?.key != "v_double" {
        assertionError = (assertionError ?? "") + "; Received key mismatch"
      }
      // Add other essential checks if needed
      expectation.fulfill()
    }

    // Assert - Wait using an explicit XCTWaiter instance
    let waiter = XCTWaiter()
    let result = waiter.wait(for: [expectation], timeout: 2.0)  // Increased timeout

    // Check waiter result and any errors captured in completion
    if result != .completed {
      XCTFail(
        "XCTWaiter timed out waiting for expectation. Error captured: \(assertionError ?? "None")")
    } else if let error = assertionError {
      XCTFail("Assertions failed within completion block: \(error)")
    }

    // Final check on data after wait
    // These might be redundant if checked thoroughly in completion, but good final check
    XCTAssertNotNil(receivedData, "Received data should be non-nil after successful wait")
    AssertEqual(receivedData?.key, "v_double")
    AssertEqual(receivedData?.value, 99.9)
  }

  func testGetVariant_Async_FlagsReady_MissingFlag_UsesFallback() {
    simulateFetchSuccess()  // Flags loaded
    let expectation = XCTestExpectation(
      description: "Async getFeature (Flags Ready, Missing) completes")
    let fallback = MixpanelFlagVariant(key: "fb_async", value: -1)
    var receivedData: MixpanelFlagVariant?

    manager.getVariant("missing_feature", fallback: fallback) { data in
      XCTAssertTrue(Thread.isMainThread, "Completion should be on main thread")
      receivedData = data
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)

    XCTAssertNotNil(receivedData)
    AssertEqual(receivedData?.key, fallback.key)
    AssertEqual(receivedData?.value, fallback.value)
    // Check delegate tracking after wait (should not have tracked)
    XCTAssertEqual(mockDelegate.trackedEvents.count, 0, "Should not track fallback")
  }

  // Test fetch triggering and completion via getFeature when not ready
  func testGetVariant_Async_FlagsNotReady_FetchSuccess() {
    XCTAssertFalse(manager.areFlagsReady())
    let expectation = XCTestExpectation(
      description: "Async getFeature (Flags Not Ready) triggers fetch and succeeds")
    var receivedData: MixpanelFlagVariant?

    // Setup tracking expectation *before* calling getFeature
    mockDelegate.trackExpectation = XCTestExpectation(
      description: "Tracking call for fetch success")

    // Call getFeature - this should trigger the fetch logic internally
    manager.getVariant("feature_int", fallback: defaultFallback) { data in
      XCTAssertTrue(Thread.isMainThread, "Completion should be on main thread")
      receivedData = data
      expectation.fulfill()  // Fulfill main expectation
    }

    // Crucially, simulate the fetch success *after* getFeature was called.
    // Add a slight delay to mimic network latency and allow fetch logic to start.
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
      print("Simulating fetch success...")
      self.simulateFetchSuccess()  // This sets flags and calls _completeFetch
    }

    // Wait for BOTH the getFeature completion AND the tracking expectation
    wait(for: [expectation, mockDelegate.trackExpectation!], timeout: 3.0)  // Increased timeout

    XCTAssertNotNil(receivedData)
    AssertEqual(receivedData?.key, "v_int")  // Check correct flag data received
    AssertEqual(receivedData?.value, 101)
    XCTAssertTrue(manager.areFlagsReady(), "Flags should be ready after successful fetch")
    XCTAssertEqual(mockDelegate.trackedEvents.count, 1, "Tracking event should have been recorded")
  }

  func testGetVariant_Async_FlagsNotReady_FetchFailure() {
    XCTAssertFalse(manager.areFlagsReady())
    let expectation = XCTestExpectation(
      description: "Async getFeature (Flags Not Ready) triggers fetch and fails")
    let fallback = MixpanelFlagVariant(key: "fb_fail", value: "failed_fetch")
    var receivedData: MixpanelFlagVariant?

    // Call getFeature
    manager.getVariant("feature_string", fallback: fallback) { data in
      XCTAssertTrue(Thread.isMainThread, "Completion should be on main thread")
      receivedData = data
      expectation.fulfill()
    }

    // Simulate fetch failure after a delay
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
      print("Simulating fetch failure...")
      self.simulateFetchFailure()  // This calls _completeFetch(success: false)
    }

    wait(for: [expectation], timeout: 3.0)

    XCTAssertNotNil(receivedData)
    AssertEqual(receivedData?.key, fallback.key)  // Should receive fallback
    AssertEqual(receivedData?.value, fallback.value)
    XCTAssertFalse(manager.areFlagsReady(), "Flags should still not be ready after failed fetch")
    XCTAssertEqual(
      mockDelegate.trackedEvents.count, 0, "Should not track on fetch failure/fallback")
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
    simulateFetchSuccess()
    mockDelegate.trackExpectation = XCTestExpectation(
      description: "Track called for properties check")

    _ = manager.getVariantSync("feature_int", fallback: defaultFallback)  // Trigger tracking

    wait(for: [mockDelegate.trackExpectation!], timeout: 1.0)

    XCTAssertEqual(mockDelegate.trackedEvents.count, 1)
    let tracked = mockDelegate.trackedEvents[0]
    XCTAssertEqual(tracked.event, "$experiment_started")
    XCTAssertNotNil(tracked.properties)

    let props = tracked.properties!
    AssertEqual(props["Experiment name"] ?? nil, "feature_int")
    AssertEqual(props["Variant name"] ?? nil, "v_int")
    AssertEqual(props["$experiment_type"] ?? nil, "feature_flag")
  }

  func testTracking_DoesNotTrackForFallback_Sync() {
    simulateFetchSuccess()  // Flags ready
    _ = manager.getVariantSync(
      "missing_feature", fallback: MixpanelFlagVariant(key: "fb", value: "v"))  // Request missing flag
    // Wait briefly to ensure no unexpected tracking call
    let expectation = XCTestExpectation(description: "Wait briefly for no track")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expectation.fulfill() }
    wait(for: [expectation], timeout: 0.5)
    XCTAssertEqual(
      mockDelegate.trackedEvents.count, 0,
      "Track should not be called when a fallback is used (sync)")
  }

  func testTracking_DoesNotTrackForFallback_Async() {
    simulateFetchSuccess()  // Flags ready
    let expectation = XCTestExpectation(description: "Async getFeature (Fallback) completes")

    manager.getVariant("missing_feature", fallback: MixpanelFlagVariant(key: "fb", value: "v")) {
      _ in
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
    // Check delegate tracking after wait
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

    // Expect tracking only ONCE for the actual feature if fetch succeeds
    mockDelegate.trackExpectation = XCTestExpectation(description: "Track call (should be once)")
    mockDelegate.trackExpectation?.expectedFulfillmentCount = 1

    print("Starting \(numConcurrentCalls) concurrent getFeature calls...")
    for i in 0..<numConcurrentCalls {
      let exp = XCTestExpectation(description: "Async getFeature \(i) completes")
      expectations.append(exp)
      DispatchQueue.global().async {  // Simulate calls from different threads
        self.manager.getVariant("feature_bool_true", fallback: self.defaultFallback) { data in
          print("Completion handler \(i) called.")
          completionResults[i] = data
          exp.fulfill()
        }
      }
    }
    print("Concurrent calls dispatched.")

    // Simulate fetch success after a delay
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {  // Longer delay
      print("Simulating fetch success for concurrent test...")
      // Simulate fetch success - important this only happens *once* conceptually
      self.simulateFetchSuccess()
      print("Fetch simulation complete.")
    }

    // Wait for all getFeature completions AND the single tracking call
    wait(for: expectations + [mockDelegate.trackExpectation!], timeout: 5.0)  // Longer timeout

    // Verify all completions received the correct data
    for i in 0..<numConcurrentCalls {
      XCTAssertNotNil(completionResults[i], "Completion \(i) did not receive data")
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

}  // End Test Class
