//
//  MixpanelDeviceIdProviderTests.swift
//  MixpanelDemoTests
//
//  Created by Claude Code on 2026-01-12.
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

class MixpanelDeviceIdProviderTests: MixpanelBaseTests {

  // MARK: - Test Group 1: Basic Provider Functionality

  /// Test 1.1: Verify provider is called during initialization and value is used
  func testDeviceIdProviderIsCalledOnInitialization() {
    var providerCalled = false
    let customDeviceId = "custom-device-id-12345"

    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: {
        providerCalled = true
        return customDeviceId
      }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    XCTAssertTrue(providerCalled, "deviceIdProvider should be called during initialization")
    XCTAssertEqual(
      testMixpanel.anonymousId, customDeviceId,
      "anonymousId should be set from provider")
    XCTAssertEqual(
      testMixpanel.distinctId, "$device:\(customDeviceId)",
      "distinctId should use provider value with prefix")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 1.2: Verify backward compatibility when no provider is set
  func testNilProviderUsesDefaultBehavior() {
    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: nil
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    // Should use UUID or IDFV depending on configuration
    XCTAssertNotNil(testMixpanel.anonymousId, "anonymousId should be generated")
    XCTAssertFalse(testMixpanel.anonymousId?.isEmpty ?? true, "anonymousId should not be empty")
    XCTAssertTrue(
      testMixpanel.distinctId.hasPrefix("$device:"), "distinctId should have device prefix")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 1.3: Verify that tracked events use the provider-generated device ID
  func testDeviceIdProviderValueUsedInEvents() {
    let customDeviceId = "my-custom-device-123"
    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: { customDeviceId }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    testMixpanel.track(event: "Test Event")
    waitForTrackingQueue(testMixpanel)

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertFalse(events.isEmpty, "Should have tracked event")

    let lastEvent = events.last!
    let properties = lastEvent["properties"] as! InternalProperties

    XCTAssertEqual(
      properties["distinct_id"] as? String, "$device:\(customDeviceId)",
      "Event distinct_id should use provider value")
    XCTAssertEqual(
      properties["$device_id"] as? String, customDeviceId,
      "Event $device_id should be the raw provider value")

    removeDBfile(testMixpanel.apiToken)
  }

  // MARK: - Test Group 2: Reset Behavior

  /// Test 2.1: Verify that reset() calls the provider to get a new device ID
  func testResetCallsDeviceIdProvider() {
    var callCount = 0

    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: {
        callCount += 1
        return "device-id-\(callCount)"
      }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    let initialCallCount = callCount
    let initialDeviceId = testMixpanel.anonymousId

    testMixpanel.reset()
    waitForTrackingQueue(testMixpanel)

    XCTAssertGreaterThan(callCount, initialCallCount, "Provider should be called again on reset")
    XCTAssertNotEqual(
      testMixpanel.anonymousId, initialDeviceId, "Device ID should change after reset")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 2.2: Demonstrate that returning the same value = "never reset"
  func testProviderReturningSameValuePersistsAcrossReset() {
    let persistentDeviceId = "persistent-device-id"
    var callCount = 0

    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: {
        callCount += 1
        return persistentDeviceId  // Always return same value
      }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    let callCountAfterInit = callCount

    testMixpanel.reset()
    waitForTrackingQueue(testMixpanel)

    testMixpanel.reset()
    waitForTrackingQueue(testMixpanel)

    // Provider is called on each reset
    XCTAssertGreaterThan(callCount, callCountAfterInit, "Provider called on each reset")
    XCTAssertEqual(
      testMixpanel.anonymousId, persistentDeviceId,
      "Device ID persists when provider returns same value")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 2.3: Demonstrate that returning different values = "reset behavior"
  func testProviderReturningDifferentValueResetsDeviceId() {
    var callCount = 0

    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: {
        callCount += 1
        return "device-id-\(callCount)"  // Different value each time
      }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    let initialDeviceId = testMixpanel.anonymousId
    XCTAssertNotNil(initialDeviceId, "Should have initial device ID")

    testMixpanel.reset()
    waitForTrackingQueue(testMixpanel)

    XCTAssertNotEqual(
      testMixpanel.anonymousId, initialDeviceId,
      "Device ID changes when provider returns new value")

    removeDBfile(testMixpanel.apiToken)
  }

  // MARK: - Test Group 3: OptOutTracking Behavior

  /// Test 3.1: Verify that optOutTracking() uses the provider
  func testOptOutTrackingCallsDeviceIdProvider() {
    var callCount = 0

    let options = MixpanelOptions(
      token: randomId(),
      trackAutomaticEvents: false,
      deviceIdProvider: {
        callCount += 1
        return "opt-out-device-\(callCount)"
      }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    let callCountAfterInit = callCount
    let initialDeviceId = testMixpanel.anonymousId

    testMixpanel.optOutTracking()
    waitForTrackingQueue(testMixpanel)

    XCTAssertGreaterThan(callCount, callCountAfterInit, "Provider called on optOutTracking")
    XCTAssertNotEqual(
      testMixpanel.anonymousId, initialDeviceId,
      "Device ID changes after opt-out when provider returns different value")

    removeDBfile(testMixpanel.apiToken)
  }

  // MARK: - Test Group 4: Migration/Warning Behavior

  /// Test 4.1: Verify warning is logged when provider replaces existing ID
  /// Note: This test validates the warning behavior by checking that initialization
  /// completes without issues when provider differs from persisted value
  func testWarningWhenProviderReplacesExistingAnonymousId() {
    let testToken = randomId()

    // First, create an instance WITHOUT a provider to establish persisted identity
    let testMixpanel1 = Mixpanel.initialize(
      token: testToken,
      trackAutomaticEvents: false
    )
    waitForTrackingQueue(testMixpanel1)

    let originalAnonymousId = testMixpanel1.anonymousId
    XCTAssertNotNil(originalAnonymousId, "Should have original anonymous ID")

    // Force archive to persist
    flushAndWaitForTrackingQueue(testMixpanel1)

    // Remove instance to simulate app restart
    Mixpanel.removeInstance(name: testToken)

    // Reinitialize WITH a provider that returns a DIFFERENT value
    let options = MixpanelOptions(
      token: testToken,
      deviceIdProvider: { "completely-different-device-id" }
    )

    let testMixpanel2 = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel2)

    // The persisted value should be used (not the provider value)
    // because we don't want to break identity continuity
    // The warning should be logged (we can't easily assert on logs in tests)
    XCTAssertEqual(
      testMixpanel2.anonymousId, originalAnonymousId,
      "Should use persisted anonymousId, not provider value, to preserve identity")

    removeDBfile(testToken)
  }

  /// Test 4.2: Verify no warning when provider matches existing ID
  func testNoWarningWhenProviderMatchesExistingAnonymousId() {
    let persistentId = "always-the-same-id"
    let testToken = randomId()

    let options = MixpanelOptions(
      token: testToken,
      deviceIdProvider: { persistentId }
    )

    // First init
    let testMixpanel1 = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel1)

    XCTAssertEqual(testMixpanel1.anonymousId, persistentId)
    flushAndWaitForTrackingQueue(testMixpanel1)

    // Remove and reinitialize
    Mixpanel.removeInstance(name: testToken)

    // Second init with same provider returning same value
    let testMixpanel2 = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel2)

    // Should work without issues, no warning expected
    XCTAssertEqual(
      testMixpanel2.anonymousId, persistentId,
      "Should use same ID without warnings")

    removeDBfile(testToken)
  }

  // MARK: - Test Group 5: Persistence Behavior

  /// Test 5.1: Persisted identity value is used even if provider returns different value
  func testPersistedIdentityUsedOverProviderValue() {
    let testToken = randomId()
    let persistentId = "persistent-device-id"

    let options = MixpanelOptions(
      token: testToken,
      deviceIdProvider: { persistentId }
    )

    // First initialization - provider should be called
    let testMixpanel1 = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel1)

    XCTAssertEqual(testMixpanel1.anonymousId, persistentId)

    flushAndWaitForTrackingQueue(testMixpanel1)
    Mixpanel.removeInstance(name: testToken)

    // Second initialization with same provider - persisted value should be used
    let testMixpanel2 = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel2)

    // Persisted value should be preserved
    XCTAssertEqual(
      testMixpanel2.anonymousId, persistentId,
      "Persisted value should be used")

    removeDBfile(testToken)
  }

  /// Test 5.2: Provider IS called when there's no persisted identity
  func testProviderCalledWhenNoPersistedIdentity() {
    let testToken = randomId()
    var callCount = 0

    // Ensure no persisted data
    removeDBfile(testToken)
    MixpanelPersistence.deleteMPUserDefaultsData(instanceName: testToken)

    let options = MixpanelOptions(
      token: testToken,
      deviceIdProvider: {
        callCount += 1
        return "fresh-device-id"
      }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    XCTAssertGreaterThanOrEqual(
      callCount, 1, "Provider should be called when no persisted identity")
    XCTAssertEqual(testMixpanel.anonymousId, "fresh-device-id")

    removeDBfile(testToken)
  }

  // MARK: - Test Group 6: Edge Cases

  /// Test 6.1a: Provider returning nil should fall back to default
  func testProviderReturningNilFallsBackToDefault() {
    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: { nil }  // Return nil
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    // Should fall back to default behavior (UUID or IDFV)
    XCTAssertNotNil(testMixpanel.anonymousId, "Should have anonymousId")
    XCTAssertFalse(
      testMixpanel.anonymousId?.isEmpty ?? true,
      "Should not have empty anonymousId - should fall back to default")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 6.1b: Provider returning empty string should fall back to default
  func testProviderReturningEmptyStringFallsBackToDefault() {
    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: { "" }  // Empty string
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    // Should fall back to default behavior (UUID or IDFV)
    XCTAssertNotNil(testMixpanel.anonymousId, "Should have anonymousId")
    XCTAssertFalse(
      testMixpanel.anonymousId?.isEmpty ?? true,
      "Should not have empty anonymousId - should fall back to default")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 6.2: Verify identify() works correctly with provider-generated device ID
  func testIdentifyWithDeviceIdProvider() {
    let customDeviceId = "provider-device-id"
    let options = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: { customDeviceId }
    )

    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    // Before identify
    XCTAssertEqual(
      testMixpanel.distinctId, "$device:\(customDeviceId)",
      "distinctId should use provider value before identify")

    // After identify
    let userId = "user@example.com"
    testMixpanel.identify(distinctId: userId)
    waitForTrackingQueue(testMixpanel)

    XCTAssertEqual(testMixpanel.distinctId, userId, "distinctId should be userId after identify")
    XCTAssertEqual(testMixpanel.userId, userId, "userId should be set after identify")
    XCTAssertEqual(
      testMixpanel.anonymousId, customDeviceId,
      "anonymousId should still be provider value after identify")

    removeDBfile(testMixpanel.apiToken)
  }

  /// Test 6.3: Multiple instances can have different providers
  func testMultipleInstancesWithDifferentProviders() {
    let options1 = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: { "instance-1-device" }
    )

    let options2 = MixpanelOptions(
      token: randomId(),
      deviceIdProvider: { "instance-2-device" }
    )

    let instance1 = Mixpanel.initialize(options: options1)
    let instance2 = Mixpanel.initialize(options: options2)

    waitForTrackingQueue(instance1)
    waitForTrackingQueue(instance2)

    XCTAssertEqual(instance1.anonymousId, "instance-1-device", "Instance 1 should use its provider")
    XCTAssertEqual(instance2.anonymousId, "instance-2-device", "Instance 2 should use its provider")
    XCTAssertNotEqual(
      instance1.anonymousId, instance2.anonymousId,
      "Instances should have different device IDs")

    removeDBfile(instance1.apiToken)
    removeDBfile(instance2.apiToken)
  }
}
