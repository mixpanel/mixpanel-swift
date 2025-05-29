//
//  MixpanelDemoTests.swift
//  MixpanelDemoTests
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel
@testable import MixpanelDemo

private let devicePrefix = "$device:"
class MixpanelDemoTests: MixpanelBaseTests {

  func test5XXResponse() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.serverURL = kFakeServerUrl
    testMixpanel.track(event: "Fake Event")
    flushAndWaitForTrackingQueue(testMixpanel)
    // Failure count should be 3
    let waitTime =
      testMixpanel.flushInstance.flushRequest.networkRequestsAllowedAfterTime
      - Date().timeIntervalSince1970
    print("Delta wait time is \(waitTime)")
    XCTAssert(waitTime >= 110, "Network backoff time is less than 2 minutes.")
    XCTAssert(
      testMixpanel.flushInstance.flushRequest.networkConsecutiveFailures == 2,
      "Network failures did not equal 2")

    XCTAssert(
      eventQueue(token: testMixpanel.apiToken).count == 2,
      "Removed an event from the queue that was not sent")
    removeDBfile(testMixpanel.apiToken)
  }

  func testFlushEvents() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    for i in 0..<50 {
      testMixpanel.track(event: "event \(i)")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).isEmpty,
      "events should have been flushed")

    for i in 0..<60 {
      testMixpanel.track(event: "event \(i)")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).isEmpty,
      "events should have been flushed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testFlushProperties() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    XCTAssertTrue(testMixpanel.flushBatchSize == 50, "the default flush batch size is set to 50")
    XCTAssertTrue(testMixpanel.flushInterval == 60, "flush interval is set correctly")
    testMixpanel.flushBatchSize = 10
    XCTAssertTrue(testMixpanel.flushBatchSize == 10, "flush batch size is set correctly")
    testMixpanel.flushBatchSize = 60
    XCTAssertTrue(testMixpanel.flushBatchSize == 50, "flush batch size is max at 50")
    testMixpanel.flushInterval = 30
    XCTAssertTrue(testMixpanel.flushInterval == 30, "flush interval is set correctly")
  }

  func testFlushPeople() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    for i in 0..<50 {
      testMixpanel.people.set(property: "p1", to: "\(i)")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      peopleQueue(token: testMixpanel.apiToken).isEmpty, "people should have been flushed")
    for i in 0..<60 {
      testMixpanel.people.set(property: "p1", to: "\(i)")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      peopleQueue(token: testMixpanel.apiToken).isEmpty, "people should have been flushed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testFlushGroups() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    let groupKey = "test_key"
    let groupValue = "test_value"
    for i in 0..<50 {
      testMixpanel.getGroup(groupKey: groupKey, groupID: groupValue).set(property: "p1", to: "\(i)")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      groupQueue(token: testMixpanel.apiToken).isEmpty, "groups should have been flushed")
    for i in 0..<60 {
      testMixpanel.getGroup(groupKey: groupKey, groupID: groupValue).set(property: "p1", to: "\(i)")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      peopleQueue(token: testMixpanel.apiToken).isEmpty, "groups should have been flushed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testFlushNetworkFailure() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.serverURL = kFakeServerUrl
    for i in 0..<50 {
      testMixpanel.track(event: "event \(UInt(i))")
    }
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 51, "51 events should be queued up")
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 51,
      "events should still be in the queue if flush fails")
    removeDBfile(testMixpanel.apiToken)
  }

  func testFlushQueueContainsCorruptedEvent() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.trackingQueue.async {
      testMixpanel.mixpanelPersistence.saveEntity(
        ["event": "bad event1", "properties": ["BadProp": Double.nan]], type: .events)
      testMixpanel.mixpanelPersistence.saveEntity(
        ["event": "bad event2", "properties": ["BadProp": Float.nan]], type: .events)
      testMixpanel.mixpanelPersistence.saveEntity(
        ["event": "bad event3", "properties": ["BadProp": Double.infinity]], type: .events)
      testMixpanel.mixpanelPersistence.saveEntity(
        ["event": "bad event4", "properties": ["BadProp": Float.infinity]], type: .events)
    }

    for i in 0..<10 {
      testMixpanel.track(event: "event \(UInt(i))")
    }
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 0, "good events should still be flushed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testAddEventContainsInvalidJsonObjectDoubleNaN() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    XCTExpectAssert("unsupported property type was allowed") {
      testMixpanel.track(event: "bad event", properties: ["BadProp": Double.nan])
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testAddEventContainsInvalidJsonObjectFloatNaN() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    XCTExpectAssert("unsupported property type was allowed") {
      testMixpanel.track(event: "bad event", properties: ["BadProp": Float.nan])
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testAddEventContainsInvalidJsonObjectDoubleInfinity() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    XCTExpectAssert("unsupported property type was allowed") {
      testMixpanel.track(event: "bad event", properties: ["BadProp": Double.infinity])
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testAddEventContainsInvalidJsonObjectFloatInfinity() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    XCTExpectAssert("unsupported property type was allowed") {
      testMixpanel.track(event: "bad event", properties: ["BadProp": Float.infinity])
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testAddingEventsAfterFlush() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    for i in 0..<10 {
      testMixpanel.track(event: "event \(UInt(i))")
    }
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 11, "11 events should be queued up")
    flushAndWaitForTrackingQueue(testMixpanel)
    for i in 0..<5 {
      testMixpanel.track(event: "event \(UInt(i))")
    }
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 5, "5 more events should be queued up")
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).isEmpty, "events should have been flushed")
    removeDBfile(testMixpanel.apiToken)
  }

  // Mock implementation of MixpanelFlags to track loadFlags calls
  class MockMixpanelFlags: MixpanelFlags {
    var delegate: MixpanelFlagDelegate?
    var loadFlagsCallCount = 0

    func loadFlags() {
      loadFlagsCallCount += 1
    }

    func areFlagsReady() -> Bool {
      return true
    }

    func getVariantSync(_ flagName: String, fallback: MixpanelFlagVariant) -> MixpanelFlagVariant {
      return fallback
    }

    func getVariant(
      _ flagName: String, fallback: MixpanelFlagVariant,
      completion: @escaping (MixpanelFlagVariant) -> Void
    ) {
      completion(fallback)
    }

    func getVariantValueSync(_ flagName: String, fallbackValue: Any?) -> Any? {
      return fallbackValue
    }

    func getVariantValue(
      _ flagName: String, fallbackValue: Any?, completion: @escaping (Any?) -> Void
    ) {
      completion(fallbackValue)
    }

    func isEnabledSync(_ flagName: String, fallbackValue: Bool) -> Bool {
      return fallbackValue
    }

    func isEnabled(_ flagName: String, fallbackValue: Bool, completion: @escaping (Bool) -> Void) {
      completion(fallbackValue)
    }
  }

  func testIdentify() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)

    // Inject our mock flags object
    let mockFlags = MockMixpanelFlags()
    testMixpanel.flags = mockFlags

    for _ in 0..<2 {
      // run this twice to test reset works correctly wrt to distinct ids
      let distinctId: String = "d1"
      // try this for ODIN and nil
      #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(
          testMixpanel.distinctId,
          devicePrefix + testMixpanel.defaultDeviceId(),
          "mixpanel identify failed to set default distinct id")
        XCTAssertEqual(
          testMixpanel.anonymousId,
          testMixpanel.defaultDeviceId(),
          "mixpanel failed to set default anonymous id")
      #endif
      XCTAssertNil(
        testMixpanel.people.distinctId,
        "mixpanel people distinct id should default to nil")
      XCTAssertNil(
        testMixpanel.people.distinctId,
        "mixpanel user id should default to nil")
      testMixpanel.track(event: "e1")
      waitForTrackingQueue(testMixpanel)
      let eventsQueue = eventQueue(token: testMixpanel.apiToken)
      XCTAssertTrue(
        eventsQueue.count == 2 || eventsQueue.count == 1,  // first app open should not be tracked for the second run,
        "events should be sent right away with default distinct id")
      #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(
          (eventsQueue.last?["properties"] as? InternalProperties)?["distinct_id"] as? String,
          devicePrefix + mixpanel.defaultDeviceId(),
          "events should use default distinct id if none set")
      #endif
      XCTAssertEqual(
        (eventsQueue.last?["properties"] as? InternalProperties)?["$lib_version"] as? String,
        AutomaticProperties.libVersion(),
        "events should has lib version in internal properties")
      testMixpanel.people.set(property: "p1", to: "a")
      waitForTrackingQueue(testMixpanel)
      var peopleQueue_value = peopleQueue(token: testMixpanel.apiToken)
      var unidentifiedQueue = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)
      XCTAssertTrue(
        peopleQueue_value.isEmpty,
        "people records should go to unidentified queue before identify:")
      XCTAssertTrue(
        unidentifiedQueue.count == 2 || eventsQueue.count == 1,  // first app open should not be tracked for the second run,
        "unidentified people records not queued")
      XCTAssertEqual(
        unidentifiedQueue.last?["$token"] as? String,
        testMixpanel.apiToken,
        "incorrect project token in people record")
      // Record the loadFlags call count before identify
      let loadFlagsCallCountBefore = mockFlags.loadFlagsCallCount

      testMixpanel.identify(distinctId: distinctId)
      waitForTrackingQueue(testMixpanel)

      // Assert that loadFlags was called when distinctId changed
      XCTAssertEqual(
        mockFlags.loadFlagsCallCount, loadFlagsCallCountBefore + 1,
        "loadFlags should be called when distinctId changes during identify")

      let anonymousId = testMixpanel.anonymousId
      peopleQueue_value = peopleQueue(token: testMixpanel.apiToken)
      unidentifiedQueue = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)
      XCTAssertEqual(
        peopleQueue_value.last?["$distinct_id"] as? String,
        distinctId, "distinct id not set properly on unidentified people record")
      XCTAssertEqual(
        testMixpanel.distinctId, distinctId,
        "mixpanel identify failed to set distinct id")
      XCTAssertEqual(
        testMixpanel.userId, distinctId,
        "mixpanel identify failed to set user id")
      XCTAssertEqual(
        testMixpanel.anonymousId, anonymousId,
        "mixpanel identify shouldn't change anonymousId")
      XCTAssertEqual(
        testMixpanel.people.distinctId, distinctId,
        "mixpanel identify failed to set people distinct id")
      XCTAssertTrue(
        unidentifiedQueue.isEmpty,
        "identify: should move records from unidentified queue")
      XCTAssertTrue(
        peopleQueue_value.count > 0,
        "identify: should move records to main people queue")
      XCTAssertEqual(
        peopleQueue_value.last?["$token"] as? String,
        testMixpanel.apiToken, "incorrect project token in people record")
      let p: InternalProperties = peopleQueue_value.last?["$set"] as! InternalProperties
      XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
      assertDefaultPeopleProperties(p)
      peopleQueue_value = peopleQueue(token: testMixpanel.apiToken)

      testMixpanel.people.set(property: "p1", to: "a")
      waitForTrackingQueue(testMixpanel)

      peopleQueue_value = peopleQueue(token: testMixpanel.apiToken)
      unidentifiedQueue = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)
      XCTAssertEqual(
        peopleQueue_value.last?["$distinct_id"] as? String,
        distinctId, "distinct id not set properly on unidentified people record")
      XCTAssertTrue(
        unidentifiedQueue.isEmpty,
        "once idenitfy: is called, unidentified queue should be skipped")
      XCTAssertTrue(
        peopleQueue_value.count > 0,
        "once identify: is called, records should go straight to main queue")
      testMixpanel.track(event: "e2")
      waitForTrackingQueue(testMixpanel)
      let newDistinctId =
        (eventQueue(token: testMixpanel.apiToken).last?["properties"] as? InternalProperties)?[
          "distinct_id"] as? String
      XCTAssertEqual(
        newDistinctId, distinctId,
        "events should use new distinct id after identify:")

      // Test that calling identify with the same distinctId does NOT trigger loadFlags
      let loadFlagsCountBeforeSameId = mockFlags.loadFlagsCallCount
      testMixpanel.identify(distinctId: distinctId)  // Same distinctId
      waitForTrackingQueue(testMixpanel)
      XCTAssertEqual(
        mockFlags.loadFlagsCallCount, loadFlagsCountBeforeSameId,
        "loadFlags should NOT be called when distinctId doesn't change")

      testMixpanel.reset()
      waitForTrackingQueue(testMixpanel)
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testIdentifyTrack() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let distinctIdBeforeIdentify: String? = testMixpanel.distinctId
    let distinctId = "testIdentifyTrack"

    testMixpanel.identify(distinctId: distinctId)
    waitForTrackingQueue(testMixpanel)
    let e: InternalProperties = eventQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(e["event"] as? String, "$identify", "incorrect event name")
    let p: InternalProperties = e["properties"] as! InternalProperties
    XCTAssertEqual(p["distinct_id"] as? String, distinctId, "wrong distinct_id")
    XCTAssertEqual(
      p["$anon_distinct_id"] as? String, distinctIdBeforeIdentify, "wrong $anon_distinct_id")
    removeDBfile(testMixpanel.apiToken)
  }

  func testIdentifyResetTrack() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let originalDistinctId: String? = testMixpanel.distinctId
    let distinctId = "testIdentifyTrack"
    testMixpanel.reset()
    waitForTrackingQueue(testMixpanel)

    for i in 1...3 {
      let prevDistinctId: String? = testMixpanel.distinctId
      let newDistinctId = distinctId + String(i)
      testMixpanel.identify(distinctId: newDistinctId)
      waitForTrackingQueue(testMixpanel)

      let e: InternalProperties = eventQueue(token: testMixpanel.apiToken).last!
      XCTAssertEqual(e["event"] as? String, "$identify", "incorrect event name")
      let p: InternalProperties = e["properties"] as! InternalProperties
      XCTAssertEqual(p["distinct_id"] as? String, newDistinctId, "wrong distinct_id")
      XCTAssertEqual(p["$anon_distinct_id"] as? String, prevDistinctId, "wrong $anon_distinct_id")
      XCTAssertNotEqual(
        prevDistinctId, originalDistinctId, "After reset, UUID will be used - never the same")
      #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(
          prevDistinctId, originalDistinctId, "After reset, IFV will be used - always the same")
      #endif
      testMixpanel.reset()
      waitForTrackingQueue(testMixpanel)
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testCreateAlias() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.people.set(properties: ["p1": "a"])
    waitForTrackingQueue(testMixpanel)
    var unidentifiedQueue = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)
    // the user profile update has been queued up in unidentifiedQueue until identify is called
    XCTAssertTrue(!unidentifiedQueue.isEmpty)

    let distinctId = testMixpanel.distinctId
    let alias: String = "a1"
    testMixpanel.createAlias(alias, distinctId: testMixpanel.distinctId)
    waitForTrackingQueue(testMixpanel)

    let mixpanelIdentity = MixpanelPersistence.loadIdentity(instanceName: testMixpanel.apiToken)
    XCTAssertTrue(
      distinctId == mixpanelIdentity.distinctID && distinctId == mixpanelIdentity.peopleDistinctID
        && distinctId == mixpanelIdentity.userId && alias == mixpanelIdentity.alias)
    removeDBfile(testMixpanel.apiToken)
    unidentifiedQueue = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)
    // unidentifiedQueue has been flushed
    XCTAssertTrue(unidentifiedQueue.isEmpty)

    let testMixpanel2 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel2.people.set(properties: ["p1": "a"])
    waitForTrackingQueue(testMixpanel2)

    let distinctId2 = testMixpanel2.distinctId
    testMixpanel2.createAlias(alias, distinctId: testMixpanel.distinctId, andIdentify: false)
    waitForTrackingQueue(testMixpanel2)

    let unidentifiedQueue2 = unIdentifiedPeopleQueue(token: testMixpanel2.apiToken)
    // The user profile updates should still be held in unidentifiedQueue cause no identify is called
    XCTAssertTrue(!unidentifiedQueue2.isEmpty)
    let mixpanelIdentity2 = MixpanelPersistence.loadIdentity(instanceName: testMixpanel2.apiToken)
    XCTAssertTrue(
      distinctId2 == mixpanelIdentity2.distinctID && nil == mixpanelIdentity2.peopleDistinctID
        && nil == mixpanelIdentity2.userId && alias == mixpanelIdentity2.alias)
    removeDBfile(testMixpanel2.apiToken)
  }

  func testPersistentIdentity() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let distinctId: String = "d1"
    let alias: String = "a1"
    testMixpanel.identify(distinctId: distinctId)
    waitForTrackingQueue(testMixpanel)
    testMixpanel.createAlias(alias, distinctId: testMixpanel.distinctId)
    waitForTrackingQueue(testMixpanel)
    var mixpanelIdentity = MixpanelPersistence.loadIdentity(instanceName: testMixpanel.apiToken)
    XCTAssertTrue(
      distinctId == mixpanelIdentity.distinctID && distinctId == mixpanelIdentity.peopleDistinctID
        && distinctId == mixpanelIdentity.userId && alias == mixpanelIdentity.alias)
    testMixpanel.archive()
    waitForTrackingQueue(testMixpanel)
    testMixpanel.unarchive()
    waitForTrackingQueue(testMixpanel)
    mixpanelIdentity = MixpanelPersistence.loadIdentity(instanceName: testMixpanel.apiToken)
    XCTAssertTrue(
      testMixpanel.distinctId == mixpanelIdentity.distinctID
        && testMixpanel.people.distinctId == mixpanelIdentity.peopleDistinctID
        && testMixpanel.anonymousId == mixpanelIdentity.anonymousId
        && testMixpanel.userId == mixpanelIdentity.userId
        && testMixpanel.alias == mixpanelIdentity.alias)
    MixpanelPersistence.deleteMPUserDefaultsData(instanceName: testMixpanel.apiToken)
    waitForTrackingQueue(testMixpanel)
    mixpanelIdentity = MixpanelPersistence.loadIdentity(instanceName: testMixpanel.apiToken)
    XCTAssertTrue(
      "" == mixpanelIdentity.distinctID && nil == mixpanelIdentity.peopleDistinctID
        && nil == mixpanelIdentity.anonymousId && nil == mixpanelIdentity.userId
        && nil == mixpanelIdentity.alias)
    removeDBfile(testMixpanel.apiToken)
  }

  func testUseUniqueDistinctId() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let testMixpanel2 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    XCTAssertNotEqual(
      testMixpanel.distinctId, testMixpanel2.distinctId,
      "by default, distinctId should not be unique to the device")

    let testMixpanel3 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60, useUniqueDistinctId: false)
    let testMixpanel4 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60, useUniqueDistinctId: false)
    XCTAssertNotEqual(
      testMixpanel3.distinctId, testMixpanel4.distinctId,
      "distinctId should not be unique to the device if useUniqueDistinctId is set to false")

    let testMixpanel5 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60, useUniqueDistinctId: true)
    let testMixpanel6 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60, useUniqueDistinctId: true)
    XCTAssertEqual(
      testMixpanel5.distinctId, testMixpanel6.distinctId,
      "distinctId should be unique to the device if useUniqueDistinctId is set to true")
  }

  func testHadPersistedDistinctId() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    XCTAssertNotNil(testMixpanel.distinctId)
    let distinctId = testMixpanel.distinctId
    let testMixpanel2 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    XCTAssertEqual(
      testMixpanel2.distinctId, distinctId,
      "mixpanel anonymous distinct id should not be changed for each init")

    let userId: String = "u1"
    testMixpanel.identify(distinctId: userId)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(devicePrefix + testMixpanel.anonymousId!, distinctId)
    XCTAssertEqual(testMixpanel.userId, userId)
    XCTAssertEqual(testMixpanel.distinctId, userId)
    XCTAssertTrue(testMixpanel.hadPersistedDistinctId!)
    removeDBfile(testMixpanel.apiToken)
  }

  func testTrackWithDefaultProperties() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.track(event: "Something Happened")
    waitForTrackingQueue(testMixpanel)
    let e: InternalProperties = eventQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(e["event"] as? String, "Something Happened", "incorrect event name")
    let p: InternalProperties = e["properties"] as! InternalProperties
    XCTAssertNotNil(p["$app_build_number"], "$app_build_number not set")
    XCTAssertNotNil(p["$app_version_string"], "$app_version_string not set")
    XCTAssertNotNil(p["$lib_version"], "$lib_version not set")
    XCTAssertNotNil(p["$model"], "$model not set")
    XCTAssertNotNil(p["$os"], "$os not set")
    XCTAssertNotNil(p["$os_version"], "$os_version not set")
    XCTAssertNotNil(p["$screen_height"], "$screen_height not set")
    XCTAssertNotNil(p["$screen_width"], "$screen_width not set")
    XCTAssertNotNil(p["distinct_id"], "distinct_id not set")
    XCTAssertNotNil(p["time"], "time not set")
    XCTAssertEqual(p["$manufacturer"] as? String, "Apple", "incorrect $manufacturer")
    XCTAssertEqual(p["mp_lib"] as? String, "swift", "incorrect mp_lib")
    XCTAssertEqual(p["token"] as? String, testMixpanel.apiToken, "incorrect token")
    removeDBfile(testMixpanel.apiToken)
  }

  func testTrackWithCustomProperties() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let now = Date()
    let p: Properties = [
      "string": "yello",
      "number": 3,
      "date": now,
      "$app_version": "override",
    ]
    testMixpanel.track(event: "Something Happened", properties: p)
    waitForTrackingQueue(testMixpanel)
    let props: InternalProperties =
      eventQueue(token: testMixpanel.apiToken).last?["properties"] as! InternalProperties
    XCTAssertEqual(props["string"] as? String, "yello")
    XCTAssertEqual(props["number"] as? Int, 3)
    let dateValue = props["date"] as! String
    compareDate(dateString: dateValue, dateDate: now)
    XCTAssertEqual(
      props["$app_version"] as? String, "override",
      "reserved property override failed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testTrackWithOptionalProperties() {
    let optNil: Double? = nil
    let optDouble: Double? = 1.0
    let optArray: [Double?] = [nil, 1.0, 2.0]
    let optDict: [String: Double?] = ["nil": nil, "double": 1.0]
    let nested: [String: Any] = ["list": optArray, "dict": optDict]
    let p: Properties = [
      "nil": optNil,
      "double": optDouble,
      "list": optArray,
      "dict": optDict,
      "nested": nested,
    ]
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.track(event: "Optional Test", properties: p)
    waitForTrackingQueue(testMixpanel)
    let props: InternalProperties =
      eventQueue(token: testMixpanel.apiToken).last?["properties"] as! InternalProperties
    XCTAssertNil(props["nil"] as? Double)
    XCTAssertEqual(props["double"] as? Double, 1.0)
    XCTAssertEqual(props["list"] as? Array, [1.0, 2.0])
    XCTAssertEqual(props["dict"] as? Dictionary, ["nil": nil, "double": 1.0])
    let nestedProp = props["nested"] as? [String: Any]
    XCTAssertEqual(nestedProp?["dict"] as? Dictionary, ["nil": nil, "double": 1.0])
    XCTAssertEqual(nestedProp?["list"] as? Array, [1.0, 2.0])
    removeDBfile(testMixpanel.apiToken)
  }

  func testTrackWithCustomDistinctIdAndToken() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = ["token": "t1", "distinct_id": "d1"]
    testMixpanel.track(event: "e1", properties: p)
    waitForTrackingQueue(testMixpanel)
    let trackToken =
      (eventQueue(token: testMixpanel.apiToken).last?["properties"] as? InternalProperties)?[
        "token"] as? String
    let trackDistinctId =
      (eventQueue(token: testMixpanel.apiToken).last?["properties"] as? InternalProperties)?[
        "distinct_id"] as? String
    XCTAssertEqual(trackToken, "t1", "user-defined distinct id not used in track.")
    XCTAssertEqual(trackDistinctId, "d1", "user-defined distinct id not used in track.")
    removeDBfile(testMixpanel.apiToken)
  }

  func testTrackWithGroups() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    testMixpanel.trackWithGroups(
      event: "Something Happened", properties: [groupKey: "some other value", "p1": "value"],
      groups: [groupKey: groupID])
    waitForTrackingQueue(testMixpanel)
    let e: InternalProperties = eventQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(e["event"] as? String, "Something Happened", "incorrect event name")
    let p: InternalProperties = e["properties"] as! InternalProperties
    XCTAssertNotNil(p["$app_build_number"], "$app_build_number not set")
    XCTAssertNotNil(p["$app_version_string"], "$app_version_string not set")
    XCTAssertNotNil(p["$lib_version"], "$lib_version not set")
    XCTAssertNotNil(p["$model"], "$model not set")
    XCTAssertNotNil(p["$os"], "$os not set")
    XCTAssertNotNil(p["$os_version"], "$os_version not set")
    XCTAssertNotNil(p["$screen_height"], "$screen_height not set")
    XCTAssertNotNil(p["$screen_width"], "$screen_width not set")
    XCTAssertNotNil(p["distinct_id"], "distinct_id not set")
    XCTAssertNotNil(p["time"], "time not set")
    XCTAssertEqual(p["$manufacturer"] as? String, "Apple", "incorrect $manufacturer")
    XCTAssertEqual(p["mp_lib"] as? String, "swift", "incorrect mp_lib")
    XCTAssertEqual(p["token"] as? String, testMixpanel.apiToken, "incorrect token")
    XCTAssertEqual(p[groupKey] as? String, groupID, "incorrect group id")
    XCTAssertEqual(p["p1"] as? String, "value", "incorrect group value")
    removeDBfile(testMixpanel.apiToken)
  }

  func testRegisterSuperProperties() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    var p: Properties = ["p1": "a", "p2": 3, "p3": Date()]
    testMixpanel.registerSuperProperties(p)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
      NSDictionary(dictionary: p),
      "register super properties failed")
    p = ["p1": "b"]
    testMixpanel.registerSuperProperties(p)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()["p1"] as? String, "b",
      "register super properties failed to overwrite existing value")
    p = ["p4": "a"]
    testMixpanel.registerSuperPropertiesOnce(p)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()["p4"] as? String, "a",
      "register super properties once failed first time")
    p = ["p4": "b"]
    testMixpanel.registerSuperPropertiesOnce(p)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()["p4"] as? String, "a",
      "register super properties once failed second time")
    p = ["p4": "c"]
    testMixpanel.registerSuperPropertiesOnce(p, defaultValue: "d")
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()["p4"] as? String, "a",
      "register super properties once with default value failed when no match")
    testMixpanel.registerSuperPropertiesOnce(p, defaultValue: "a")
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()["p4"] as? String, "c",
      "register super properties once with default value failed when match")
    testMixpanel.unregisterSuperProperty("a")
    waitForTrackingQueue(testMixpanel)
    XCTAssertNil(
      testMixpanel.currentSuperProperties()["a"],
      "unregister super property failed")
    // unregister non-existent super property should not throw
    testMixpanel.unregisterSuperProperty("a")
    testMixpanel.clearSuperProperties()
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      testMixpanel.currentSuperProperties().isEmpty,
      "clear super properties failed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testSettingSuperPropertiesWhenInit() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60,
      superProperties: ["mp_lib": "flutter"])
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()["mp_lib"] as? String, "flutter",
      "register super properties in init failed")
    testMixpanel.track(event: "e1")
    waitForTrackingQueue(testMixpanel)
    let e = eventQueue(token: testMixpanel.apiToken).last!
    let p = e["properties"] as! InternalProperties
    XCTAssertNotNil(p["mp_lib"], "flutter")
  }

  func testInvalidPropertiesTrack() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = ["data": [Data()]]
    XCTExpectAssert("property type should not be allowed") {
      testMixpanel.track(event: "e1", properties: p)
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testInvalidSuperProperties() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = ["data": [Data()]]
    XCTExpectAssert("property type should not be allowed") {
      testMixpanel.registerSuperProperties(p)
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testInvalidSuperProperties2() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = ["data": [Data()]]
    XCTExpectAssert("property type should not be allowed") {
      testMixpanel.registerSuperPropertiesOnce(p)
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testInvalidSuperProperties3() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = ["data": [Data()]]
    XCTExpectAssert("property type should not be allowed") {
      testMixpanel.registerSuperPropertiesOnce(p, defaultValue: "v")
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testValidPropertiesTrack() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = allPropertyTypes()
    testMixpanel.track(event: "e1", properties: p)
    removeDBfile(testMixpanel.apiToken)
  }

  func testValidSuperProperties() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    let p: Properties = allPropertyTypes()
    testMixpanel.registerSuperProperties(p)
    testMixpanel.registerSuperPropertiesOnce(p)
    testMixpanel.registerSuperPropertiesOnce(p, defaultValue: "v")
    removeDBfile(testMixpanel.apiToken)
  }

  func testReset() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    testMixpanel.track(event: "e1")
    waitForTrackingQueue(testMixpanel)
    let p: Properties = ["p1": "a"]
    testMixpanel.registerSuperProperties(p)
    testMixpanel.people.set(properties: p)
    testMixpanel.archive()
    testMixpanel.reset()
    waitForTrackingQueue(testMixpanel)

    #if MIXPANEL_UNIQUE_DISTINCT_ID
      XCTAssertEqual(
        testMixpanel.distinctId,
        devicePrefix + testMixpanel.defaultDeviceId(),
        "distinct id failed to reset")
    #endif
    XCTAssertNil(testMixpanel.people.distinctId, "people distinct id failed to reset")
    XCTAssertTrue(
      testMixpanel.currentSuperProperties().isEmpty,
      "super properties failed to reset")
    XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).isEmpty, "events queue failed to reset")
    XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).isEmpty, "people queue failed to reset")
    let testMixpanel2 = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    waitForTrackingQueue(testMixpanel2)
    #if MIXPANEL_UNIQUE_DISTINCT_ID
      XCTAssertEqual(
        testMixpanel2.distinctId, devicePrefix + testMixpanel2.defaultDeviceId(),
        "distinct id failed to reset after archive")
    #endif
    XCTAssertNil(
      testMixpanel2.people.distinctId,
      "people distinct id failed to reset after archive")
    XCTAssertTrue(
      testMixpanel2.currentSuperProperties().isEmpty,
      "super properties failed to reset after archive")
    XCTAssertTrue(
      eventQueue(token: testMixpanel2.apiToken).count == 1,
      "events queue failed to reset after archive")
    XCTAssertTrue(
      peopleQueue(token: testMixpanel2.apiToken).isEmpty,
      "people queue failed to reset after archive")
    removeDBfile(testMixpanel.apiToken)
    removeDBfile(testMixpanel2.apiToken)
  }

  func testArchiveNSNumberBoolIntProperty() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.serverURL = kFakeServerUrl
    let aBoolNumber: Bool = true
    let aBoolNSNumber = NSNumber(value: aBoolNumber)

    let aIntNumber: Int = 1
    let aIntNSNumber = NSNumber(value: aIntNumber)

    testMixpanel.track(event: "e1", properties: ["p1": aBoolNSNumber, "p2": aIntNSNumber])
    testMixpanel.archive()
    waitForTrackingQueue(testMixpanel)

    let testMixpanel2 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel2.serverURL = kFakeServerUrl
    waitForTrackingQueue(testMixpanel2)

    let properties: [String: Any] =
      eventQueue(token: testMixpanel2.apiToken)[1]["properties"] as! [String: Any]

    XCTAssertTrue(
      isBoolNumber(num: properties["p1"]! as! NSNumber),
      "The bool value should be unarchived as bool")
    XCTAssertFalse(
      isBoolNumber(num: properties["p2"]! as! NSNumber),
      "The int value should not be unarchived as bool")
    removeDBfile(testToken)
  }

  private func isBoolNumber(num: NSNumber) -> Bool {
    let boolID = CFBooleanGetTypeID()  // the type ID of CFBoolean
    let numID = CFGetTypeID(num)  // the type ID of num
    return numID == boolID
  }

  func testArchive() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.serverURL = kFakeServerUrl
    #if MIXPANEL_UNIQUE_DISTINCT_ID
      XCTAssertEqual(
        testMixpanel.distinctId, devicePrefix + testMixpanel.defaultDeviceId(),
        "default distinct id archive failed")
    #endif
    XCTAssertTrue(
      testMixpanel.currentSuperProperties().isEmpty,
      "default super properties archive failed")
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).isEmpty, "default events queue archive failed")
    XCTAssertNil(testMixpanel.people.distinctId, "default people distinct id archive failed")
    XCTAssertTrue(
      peopleQueue(token: testMixpanel.apiToken).isEmpty, "default people queue archive failed")
    let p: Properties = ["p1": "a"]
    testMixpanel.identify(distinctId: "d1")
    waitForTrackingQueue(testMixpanel)
    testMixpanel.registerSuperProperties(p)
    testMixpanel.track(event: "e1")
    testMixpanel.track(event: "e2")
    testMixpanel.track(event: "e3")
    testMixpanel.track(event: "e4")
    testMixpanel.track(event: "e5")
    testMixpanel.track(event: "e6")
    testMixpanel.track(event: "e7")
    testMixpanel.track(event: "e8")
    testMixpanel.track(event: "e9")
    testMixpanel.people.set(properties: p)
    waitForTrackingQueue(testMixpanel)
    testMixpanel.timedEvents["e2"] = 5
    testMixpanel.archive()
    let testMixpanel2 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel2.serverURL = kFakeServerUrl
    waitForTrackingQueue(testMixpanel2)
    XCTAssertEqual(testMixpanel2.distinctId, "d1", "custom distinct archive failed")
    XCTAssertTrue(
      testMixpanel2.currentSuperProperties().count == 1,
      "custom super properties archive failed")
    let eventQueueValue = eventQueue(token: testMixpanel2.apiToken)

    XCTAssertEqual(
      eventQueueValue[1]["event"] as? String, "e1",
      "event was not successfully archived/unarchived")
    XCTAssertEqual(
      eventQueueValue[2]["event"] as? String, "e2",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[3]["event"] as? String, "e3",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[4]["event"] as? String, "e4",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[5]["event"] as? String, "e5",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[6]["event"] as? String, "e6",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[7]["event"] as? String, "e7",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[8]["event"] as? String, "e8",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      eventQueueValue[9]["event"] as? String, "e9",
      "event was not successfully archived/unarchived or order is incorrect")
    XCTAssertEqual(
      testMixpanel2.people.distinctId, "d1",
      "custom people distinct id archive failed")
    XCTAssertTrue(
      peopleQueue(token: testMixpanel2.apiToken).count >= 1, "pending people queue archive failed")
    XCTAssertEqual(
      testMixpanel2.timedEvents["e2"] as? Int, 5,
      "timedEvents archive failed")
    let testMixpanel3 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel3.serverURL = kFakeServerUrl
    XCTAssertEqual(testMixpanel3.distinctId, "d1", "expecting d1 as distinct id as initialised")
    XCTAssertTrue(
      testMixpanel3.currentSuperProperties().count == 1,
      "default super properties expected to have 1 item")
    XCTAssertNotNil(eventQueue(token: testMixpanel3.apiToken), "default events queue is nil")
    XCTAssertTrue(
      eventQueue(token: testMixpanel3.apiToken).count == 10,
      "default events queue expecting 10 items ($identify call added)")
    XCTAssertNotNil(
      testMixpanel3.people.distinctId,
      "default people distinct id from no file failed")
    XCTAssertNotNil(
      peopleQueue(token: testMixpanel3.apiToken), "default people queue from no file is nil")
    XCTAssertTrue(
      peopleQueue(token: testMixpanel3.apiToken).count >= 1, "default people queue expecting 1 item"
    )
    XCTAssertTrue(testMixpanel3.timedEvents.count == 1, "timedEvents expecting 1 item")
    removeDBfile(testToken)
  }

  func testMixpanelDelegate() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.delegate = self
    testMixpanel.identify(distinctId: "d1")
    testMixpanel.track(event: "e1")
    testMixpanel.people.set(property: "p1", to: "a")
    waitForTrackingQueue(testMixpanel)
    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 3, "delegate should have stopped flush")
    XCTAssertTrue(
      peopleQueue(token: testMixpanel.apiToken).count == 2, "delegate should have stopped flush")
    removeDBfile(testMixpanel.apiToken)
  }

  func testEventTiming() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.track(event: "Something Happened")
    waitForTrackingQueue(testMixpanel)
    var e: InternalProperties = eventQueue(token: testMixpanel.apiToken).last!
    var p = e["properties"] as! InternalProperties
    XCTAssertNil(p["$duration"], "New events should not be timed.")
    testMixpanel.time(event: "400 Meters")
    testMixpanel.track(event: "500 Meters")
    waitForTrackingQueue(testMixpanel)
    e = eventQueue(token: testMixpanel.apiToken).last!
    p = e["properties"] as! InternalProperties
    XCTAssertNil(p["$duration"], "The exact same event name is required for timing.")
    testMixpanel.track(event: "400 Meters")
    waitForTrackingQueue(testMixpanel)
    e = eventQueue(token: testMixpanel.apiToken).last!
    p = e["properties"] as! InternalProperties
    XCTAssertNotNil(p["$duration"], "This event should be timed.")
    testMixpanel.track(event: "400 Meters")
    waitForTrackingQueue(testMixpanel)
    e = eventQueue(token: testMixpanel.apiToken).last!
    p = e["properties"] as! InternalProperties
    XCTAssertNil(
      p["$duration"],
      "Tracking the same event should require a second call to timeEvent.")
    testMixpanel.time(event: "Time Event A")
    testMixpanel.time(event: "Time Event B")
    testMixpanel.time(event: "Time Event C")
    waitForTrackingQueue(testMixpanel)
    var testTimedEvents = MixpanelPersistence.loadTimedEvents(instanceName: testMixpanel.apiToken)
    XCTAssertTrue(
      testTimedEvents.count == 3, "Each call to time() should add an event to timedEvents")
    XCTAssertNotNil(testTimedEvents["Time Event A"], "Keys in timedEvents should be event names")
    testMixpanel.clearTimedEvent(event: "Time Event A")
    waitForTrackingQueue(testMixpanel)
    testTimedEvents = MixpanelPersistence.loadTimedEvents(instanceName: testMixpanel.apiToken)
    XCTAssertNil(testTimedEvents["Time Event A"], "clearTimedEvent should remove key/value pair")
    XCTAssertTrue(
      testTimedEvents.count == 2, "clearTimedEvent shoud remove only one key/value pair")
    testMixpanel.clearTimedEvents()
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      MixpanelPersistence.loadTimedEvents(instanceName: testMixpanel.apiToken).count == 0,
      "clearTimedEvents should remove all key/value pairs")
    removeDBfile(testMixpanel.apiToken)
  }

  func testReadWriteLock() {
    var array = [Int]()
    let lock = ReadWriteLock(label: "test")
    let queue = DispatchQueue(label: "concurrent", qos: .utility, attributes: .concurrent)
    for _ in 0..<10 {
      queue.async {
        lock.write {
          for i in 0..<100 {
            array.append(i)
          }
        }
      }

      queue.async {
        lock.read {
          XCTAssertTrue(array.count % 100 == 0, "supposed to happen after write")
        }
      }
    }
  }

  func testSetGroup() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    let groupKey = "test_key"
    let groupValue = "test_value"
    testMixpanel.setGroup(groupKey: groupKey, groupIDs: [groupValue])
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(testMixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
    let q = peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
    XCTAssertEqual(q[groupKey] as? [String], [groupValue], "group value people property not queued")
    assertDefaultPeopleProperties(q)
    removeDBfile(testMixpanel.apiToken)
  }

  func testAddGroup() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    let groupKey = "test_key"
    let groupValue = "test_value"

    testMixpanel.addGroup(groupKey: groupKey, groupID: groupValue)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(testMixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
    waitForTrackingQueue(testMixpanel)
    let q = peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
    XCTAssertEqual(q[groupKey] as? [String], [groupValue], "addGroup people update not queued")
    assertDefaultPeopleProperties(q)
    testMixpanel.addGroup(groupKey: groupKey, groupID: groupValue)

    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(testMixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
    waitForTrackingQueue(testMixpanel)
    let q2 = peopleQueue(token: testMixpanel.apiToken).last!["$union"] as! InternalProperties
    XCTAssertEqual(q2[groupKey] as? [String], [groupValue], "addGroup people update not queued")

    let newVal = "new_group"
    testMixpanel.addGroup(groupKey: groupKey, groupID: newVal)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue, newVal])
    waitForTrackingQueue(testMixpanel)
    waitForTrackingQueue(testMixpanel)
    let q3 = peopleQueue(token: testMixpanel.apiToken).last!["$union"] as! InternalProperties
    XCTAssertEqual(q3[groupKey] as? [String], [newVal], "addGroup people update not queued")
    removeDBfile(testMixpanel.apiToken)
  }

  func testRemoveGroup() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.identify(distinctId: "d1")
    let groupKey = "test_key"
    let groupValue = "test_value"
    let newVal = "new_group"

    testMixpanel.setGroup(groupKey: groupKey, groupIDs: [groupValue, newVal])
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(
      testMixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue, newVal])

    testMixpanel.removeGroup(groupKey: groupKey, groupID: groupValue)
    waitForTrackingQueue(testMixpanel)
    XCTAssertEqual(testMixpanel.currentSuperProperties()[groupKey] as? [String], [newVal])
    waitForTrackingQueue(testMixpanel)
    let q2 = peopleQueue(token: testMixpanel.apiToken).last!["$remove"] as! InternalProperties
    XCTAssertEqual(q2[groupKey] as? String, groupValue, "removeGroup people update not queued")

    testMixpanel.removeGroup(groupKey: groupKey, groupID: groupValue)
    waitForTrackingQueue(testMixpanel)
    XCTAssertNil(testMixpanel.currentSuperProperties()[groupKey])
    waitForTrackingQueue(testMixpanel)
    let q3 = peopleQueue(token: testMixpanel.apiToken).last!["$unset"] as! [String]
    XCTAssertEqual(q3, [groupKey], "removeGroup people update not queued")
    removeDBfile(testMixpanel.apiToken)
  }

  func testMultipleInstancesWithSameToken() {
    let testToken = randomId()
    let concurentQueue = DispatchQueue(label: "multithread", attributes: .concurrent)

    var testMixpanel: MixpanelInstance?
    for _ in 1...10 {
      concurentQueue.async {
        testMixpanel = Mixpanel.initialize(
          token: testToken, trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel?.loggingEnabled = true
        testMixpanel?.track(event: "test")
      }
    }

    var testMixpanel2: MixpanelInstance?
    for _ in 1...10 {
      concurentQueue.async {
        testMixpanel2 = Mixpanel.initialize(
          token: testToken, trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel2?.loggingEnabled = true
        testMixpanel2?.track(event: "test")
      }
    }
    sleep(5)
    testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel2 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    XCTAssertTrue(
      testMixpanel === testMixpanel2,
      "instance with same token should be reused and no sqlite db locked error should be populated")
  }

  func testMultipleInstancesWithSameTokenButDifferentInstanceNameShouldNotCrash() {
    let testToken = randomId()
    let concurentQueue = DispatchQueue(label: "multithread", attributes: .concurrent)

    for i in 1...10 {
      concurentQueue.async {
        let testMixpanel = Mixpanel.initialize(
          token: testToken, trackAutomaticEvents: true, flushInterval: 60,
          instanceName: "instance\(i)")
        testMixpanel.loggingEnabled = true
        testMixpanel.track(event: "test")
      }
    }

    sleep(5)
    XCTAssertTrue(true, "no sqlite db locked error should be populated")
    for j in 1...10 {
      removeDBfile("instance\(j)")
    }
  }

  func testMultipleInstancesWithSameTokenButDifferentInstanceName() {
    let testToken = randomId()
    let instanceName1 = randomId()
    let instanceName2 = randomId()
    let instance1 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60, instanceName: instanceName1)
    let instance2 = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60, instanceName: instanceName2)

    XCTAssertNotEqual(instance1.distinctId, instance2.distinctId)
    instance1.identify(distinctId: "user1")
    instance1.track(event: "test")
    waitForTrackingQueue(instance1)
    waitForTrackingQueue(instance2)

    XCTAssertEqual(instance1.distinctId, "user1")
    XCTAssertEqual(instance1.userId, "user1")
    let events = eventQueue(token: instanceName1)
    let properties = events.last?["properties"] as? InternalProperties
    XCTAssertEqual(properties?["distinct_id"] as? String, "user1")

    instance1.people.set(property: "p1", to: "a")
    waitForTrackingQueue(instance1)
    waitForTrackingQueue(instance2)

    let peopleQueue_value = peopleQueue(token: instanceName1)
    let setValue = peopleQueue_value.last!["$set"] as! InternalProperties
    XCTAssertEqual(setValue["p1"] as? String, "a", "custom people property not queued")

    XCTAssertEqual(
      peopleQueue_value.last?["$distinct_id"] as? String,
      "user1", "distinct id not set properly on the people record")

    instance2.identify(distinctId: "user2")
    instance2.track(event: "test2")
    waitForTrackingQueue(instance1)
    waitForTrackingQueue(instance2)
    XCTAssertEqual(instance2.distinctId, "user2")
    XCTAssertEqual(instance2.userId, "user2")
    let events2 = eventQueue(token: instanceName2)
    let properties2 = events2.last?["properties"] as? InternalProperties
    // event property should have the current distinct id
    XCTAssertEqual(properties2?["distinct_id"] as? String, "user2")

    instance2.people.set(property: "p2", to: "b")
    waitForTrackingQueue(instance1)
    waitForTrackingQueue(instance2)

    let peopleQueue2_value = peopleQueue(token: instanceName2)
    XCTAssertEqual(
      peopleQueue2_value.last?["$distinct_id"] as? String,
      "user2", "distinct id not set properly on the people record")

    let setValue2 = peopleQueue2_value.last!["$set"] as! InternalProperties
    XCTAssertEqual(setValue2["p2"] as? String, "b", "custom people property not queued")

    removeDBfile(instanceName1)
    removeDBfile(instanceName2)
  }

  func testReadWriteMultiThreadShouldNotCrash() {
    let concurentQueue = DispatchQueue(label: "multithread", attributes: .concurrent)
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)

    for n in 1...10 {
      concurentQueue.async {
        testMixpanel.track(event: "event\(n)")
      }
      concurentQueue.async {
        testMixpanel.flush()
      }
      concurentQueue.async {
        testMixpanel.archive()
      }
      concurentQueue.async {
        testMixpanel.reset()
      }
      concurentQueue.async {
        testMixpanel.createAlias("aaa11", distinctId: testMixpanel.distinctId)
        testMixpanel.identify(distinctId: "test")
      }
      concurentQueue.async {
        testMixpanel.registerSuperProperties(["Plan": "Mega"])
      }
      concurentQueue.async {
        let _ = testMixpanel.currentSuperProperties()
      }
      concurentQueue.async {
        testMixpanel.people.set(property: "aaa", to: "SwiftSDK Cocoapods")
        testMixpanel.getGroup(groupKey: "test", groupID: 123).set(properties: ["test": 123])
        testMixpanel.removeGroup(groupKey: "test", groupID: 123)
      }
      concurentQueue.async {
        testMixpanel.track(event: "test")
        testMixpanel.time(event: "test")
        testMixpanel.clearTimedEvents()
      }
    }
    removeDBfile(testMixpanel.apiToken)
  }

  func testMPDB() {
    // we test with this crazy string because the "token" here can be the instanceName
    // which can be any string the user likes, MPDB should strip the non-alphanumeric characters to prevent SQL errors
    let mpdb = MPDB.init(token: "Re@lly  Bad.T0ken+\(randomId())--*🤪/0️⃣\\_? ")
    mpdb.open()

    let numRows = 50
    let halfRows = numRows / 2
    let eventName = "Test Event"

    for pType in PersistenceType.allCases {
      let emptyArray: [InternalProperties] = mpdb.readRows(pType, numRows: numRows)
      XCTAssertTrue(emptyArray.isEmpty, "Table should be empty")
      for i in 0...numRows - 1 {
        let eventObj: InternalProperties = ["event": eventName, "properties": ["index": i]]
        let eventData = JSONHandler.serializeJSONObject(eventObj)!
        mpdb.insertRow(pType, data: eventData)
      }
      let dataArray: [InternalProperties] = mpdb.readRows(pType, numRows: halfRows)
      XCTAssertEqual(dataArray.count, halfRows, "Should have read only half of the rows")
      var ids: [Int32] = []
      for (n, entity) in dataArray.enumerated() {
        guard let id = entity["id"] as? Int32 else {
          continue
        }
        ids.append(id)
        XCTAssertEqual(entity["event"] as! String, eventName, "Event name should be unchanged")
        // index should be oldest events, 0 - 24
        XCTAssertEqual(
          entity["properties"] as! [String: Int], ["index": n], "Should read oldest events first")
      }

      mpdb.deleteRows(pType, ids: ids)
      let dataArray2: [InternalProperties] = mpdb.readRows(pType, numRows: numRows)
      // even though we requested numRows, there should only be halfRows left
      XCTAssertEqual(dataArray2.count, halfRows, "Should have deleted half the rows")
      for (n, entity) in dataArray2.enumerated() {
        XCTAssertEqual(entity["event"] as! String, eventName, "Event name should be unchanged")
        // old events (0-24) should have been deleted so index should be recent events 25-49
        XCTAssertEqual(
          entity["properties"] as! [String: Int], ["index": n + halfRows],
          "Should have deleted oldest events first")
      }
    }

    mpdb.close()
    removeDBfile(mpdb.apiToken)
  }

  func testMigration() {
    let token = "testToken"
    // clean up
    removeDBfile(token)
    // copy the legacy archived file for the migration test
    let legacyFiles = [
      "mixpanel-testToken-events", "mixpanel-testToken-properties", "mixpanel-testToken-groups",
      "mixpanel-testToken-people", "mixpanel-testToken-optOutStatus",
    ]
    prepareForMigrationFiles(legacyFiles)
    // initialize mixpanel will do the migration automatically if found legacy archive files.
    let testMixpanel = Mixpanel.initialize(
      token: token, trackAutomaticEvents: true, flushInterval: 60)
    let fileManager = FileManager.default
    let libraryUrls = fileManager.urls(
      for: .libraryDirectory,
      in: .userDomainMask)
    XCTAssertFalse(
      fileManager.fileExists(
        atPath: (libraryUrls.first?.appendingPathComponent("mixpanel-testToken-events"))!.path),
      "after migration, the legacy archive files should be removed")
    XCTAssertFalse(
      fileManager.fileExists(
        atPath: (libraryUrls.first?.appendingPathComponent("mixpanel-testToken-properties"))!.path),
      "after migration, the legacy archive files should be removed")
    XCTAssertFalse(
      fileManager.fileExists(
        atPath: (libraryUrls.first?.appendingPathComponent("mixpanel-testToken-groups"))!.path),
      "after migration, the legacy archive files should be removed")
    XCTAssertFalse(
      fileManager.fileExists(
        atPath: (libraryUrls.first?.appendingPathComponent("mixpanel-testToken-people"))!.path),
      "after migration, the legacy archive files should be removed")

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(events.count, 306)

    XCTAssertEqual(events[0]["event"] as? String, "$identify")
    XCTAssertEqual(events[1]["event"] as? String, "Logged in")
    XCTAssertEqual(events[2]["event"] as? String, "$ae_first_open")
    XCTAssertEqual(events[3]["event"] as? String, "Tracked event 1")
    let properties = events.last?["properties"] as? InternalProperties
    XCTAssertEqual(properties?["Cool Property"] as? [Int], [12345, 301])
    XCTAssertEqual(properties?["Super Property 2"] as? String, "p2")

    let people = peopleQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(people.count, 6)
    XCTAssertEqual(people[0]["$distinct_id"] as? String, "demo_user")
    XCTAssertEqual(people[0]["$token"] as? String, "testToken")
    let appendProperties = people[5]["$append"] as! InternalProperties
    XCTAssertEqual(appendProperties["d"] as? String, "goodbye")

    let group = groupQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(group.count, 2)
    XCTAssertEqual(group[0]["$group_key"] as? String, "Cool Property")
    let setProperties = group[0]["$set"] as! InternalProperties
    XCTAssertEqual(setProperties["g"] as? String, "yo")
    let setProperties2 = group[1]["$set"] as! InternalProperties
    XCTAssertEqual(setProperties2["a"] as? Int, 1)
    XCTAssertTrue(MixpanelPersistence.loadOptOutStatusFlag(instanceName: token)!)

    //timedEvents
    let testTimedEvents = MixpanelPersistence.loadTimedEvents(instanceName: token)
    XCTAssertEqual(testTimedEvents.count, 3)
    XCTAssertNotNil(testTimedEvents["Time Event A"])
    XCTAssertNotNil(testTimedEvents["Time Event B"])
    XCTAssertNotNil(testTimedEvents["Time Event C"])
    let identity = MixpanelPersistence.loadIdentity(instanceName: token)
    XCTAssertEqual(identity.distinctID, "demo_user")
    XCTAssertEqual(identity.peopleDistinctID, "demo_user")
    XCTAssertNotNil(identity.anonymousId)
    XCTAssertEqual(identity.userId, "demo_user")
    XCTAssertEqual(identity.alias, "New Alias")
    XCTAssertEqual(identity.hadPersistedDistinctId, false)

    let superProperties = MixpanelPersistence.loadSuperProperties(instanceName: token)
    XCTAssertEqual(superProperties.count, 7)
    XCTAssertEqual(superProperties["Super Property 1"] as? Int, 1)
    XCTAssertEqual(superProperties["Super Property 7"] as? NSNull, NSNull())
    removeDBfile("testToken")
  }

  func prepareForMigrationFiles(_ fileNames: [String]) {
    for fileName in fileNames {
      let fileManager = FileManager.default
      let filepath = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil)!
      let libraryUrls = fileManager.urls(
        for: .libraryDirectory,
        in: .userDomainMask)
      let destURL = libraryUrls.first?.appendingPathComponent(fileName)
      do {
        try FileManager.default.copyItem(at: filepath, to: destURL!)
      } catch let error {
        print(error)
      }
    }
  }

  func testGzipCompressionInit() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: false, useGzipCompression: true)
    XCTAssertTrue(testMixpanel.useGzipCompression == true, "the init of GzipCompression failed")
  }

  func testGzipCompressionDefault() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
    XCTAssertTrue(
      testMixpanel.useGzipCompression == false, "the default gzip option disabled failed")
  }
}
