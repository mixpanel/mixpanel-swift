//
//  MixpanelAutomaticEventsTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 5/12/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelAutomaticEventsTests: MixpanelBaseTests {

  func testSession() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0
    testMixpanel.identify(distinctId: "d1")
    waitForTrackingQueue(testMixpanel)
    testMixpanel.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))
    waitForTrackingQueue(testMixpanel)

    let event = eventQueue(token: testMixpanel.apiToken).last
    let people1 = peopleQueue(token: testMixpanel.apiToken)[1]["$add"] as! InternalProperties
    let people2 = peopleQueue(token: testMixpanel.apiToken)[2]["$add"] as! InternalProperties
    XCTAssertEqual(
      (people1["$ae_total_app_sessions"] as? NSNumber)?.intValue, 1,
      "total app sessions should be added by 1")
    XCTAssertNotNil(
      (people2["$ae_total_app_session_length"], "should have session length in $add queue"))
    XCTAssertNotNil(event, "Should have an event")
    XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
    XCTAssertNotNil(
      (event?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
    removeDBfile(testMixpanel.apiToken)
  }

  func testKeepAutomaticEventsIfNetworkNotAvailable() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0
    testMixpanel.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))

    waitForTrackingQueue(testMixpanel)
    let event = eventQueue(token: testMixpanel.apiToken).last
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 2,
      "automatic events should be accumulated if device is offline")
    XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
    removeDBfile(testMixpanel.apiToken)
  }

  func testDiscardAutomaticEventsIftrackAutomaticEventsEnabledIsFalse() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0
    testMixpanel.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 0, "automatic events should not be tracked")
    removeDBfile(testMixpanel.apiToken)
  }

  func testFlushAutomaticEventsIftrackAutomaticEventsEnabledIsTrue() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0
    testMixpanel.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 2, "automatic events should be tracked")

    flushAndWaitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 0, "automatic events should be flushed")
    removeDBfile(testMixpanel.apiToken)
  }

  func testUpdated() {
    let defaults = UserDefaults(suiteName: "Mixpanel")
    let infoDict = Bundle.main.infoDictionary
    let appVersionValue = infoDict?["CFBundleShortVersionString"]
    let savedVersionValue = defaults?.string(forKey: "MPAppVersion")
    XCTAssertEqual(
      appVersionValue as? String, savedVersionValue,
      "Saved version and current version need to be the same")
  }

  func testFirstAppShouldOnlyBeTrackedOnce() {
    let testToken = randomId()
    let mp = Mixpanel.initialize(token: testToken, trackAutomaticEvents: true)
    mp.minimumSessionDuration = 0
    waitForTrackingQueue(mp)
    XCTAssertEqual(
      eventQueue(token: mp.apiToken).count, 1, "First app open should be tracked again")
    flushAndWaitForTrackingQueue(mp)

    let mp2 = Mixpanel.initialize(token: testToken, trackAutomaticEvents: true)
    mp2.minimumSessionDuration = 0
    waitForTrackingQueue(mp2)
    XCTAssertEqual(
      eventQueue(token: mp2.apiToken).count, 0, "First app open should not be tracked again")
  }

  func testAutomaticEventsInMultipleInstances() {
    // remove UserDefaults key and archive files to simulate first app open state
    let defaults = UserDefaults(suiteName: "Mixpanel")
    defaults?.removeObject(forKey: "MPFirstOpen")

    let mp = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: true)
    mp.minimumSessionDuration = 0
    waitForTrackingQueue(mp)
    let mp2 = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: true)
    mp2.minimumSessionDuration = 0
    waitForTrackingQueue(mp2)

    XCTAssertEqual(eventQueue(token: mp.apiToken).count, 1, "there should be only 1 event")
    let appOpenEvent = eventQueue(token: mp.apiToken).last
    XCTAssertEqual(
      appOpenEvent?["event"] as? String, "$ae_first_open", "should be first app open event")

    XCTAssertEqual(eventQueue(token: mp2.apiToken).count, 1, "there should be only 1 event")
    let otherAppOpenEvent = eventQueue(token: mp2.apiToken).last
    XCTAssertEqual(
      otherAppOpenEvent?["event"] as? String, "$ae_first_open", "should be first app open event")

    mp.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))
    mp2.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))
    mp.trackingQueue.sync {}
    mp2.trackingQueue.sync {}
    let appSessionEvent = eventQueue(token: mp.apiToken).last
    XCTAssertNotNil(appSessionEvent, "Should have an event")
    XCTAssertEqual(
      appSessionEvent?["event"] as? String, "$ae_session", "should be app session event")
    XCTAssertNotNil(
      (appSessionEvent?["properties"] as? [String: Any])?["$ae_session_length"],
      "should have session length")
    let otherAppSessionEvent = eventQueue(token: mp2.apiToken).last
    XCTAssertEqual(
      otherAppSessionEvent?["event"] as? String, "$ae_session", "should be app session event")
    XCTAssertNotNil(
      (otherAppSessionEvent?["properties"] as? [String: Any])?["$ae_session_length"],
      "should have session length")
    removeDBfile(mp.apiToken)
    removeDBfile(mp2.apiToken)
  }

  // MARK: - Tests for Deferred Automatic Event Initialization (SwiftUI Early Init Fix)

  func testEnableAutomaticEventsAfterInitializationWithFalse() {
    let testToken = randomId()
    // Initialize with trackAutomaticEvents: false (simulating SwiftUI early init scenario)
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0

    // At this point, no automatic events should be tracked
    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 0,
      "No automatic events should be tracked when initialized with trackAutomaticEvents: false")

    // Now enable automatic events (simulating the app UI being ready)
    testMixpanel.trackAutomaticEventsEnabled = true
    waitForTrackingQueue(testMixpanel)

    // After enabling, first open event should be tracked
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count >= 1,
      "First open event should be tracked after enabling automatic events")
    let firstOpenEvent = eventQueue(token: testMixpanel.apiToken).first
    XCTAssertEqual(
      firstOpenEvent?["event"] as? String, "$ae_first_open",
      "Should have first open event after re-initialization")

    removeDBfile(testMixpanel.apiToken)
  }

  func testEnableAutomaticEventsMethodAfterInitializationWithFalse() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0

    waitForTrackingQueue(testMixpanel)
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count == 0,
      "No automatic events should be tracked initially")

    // Use the explicit enableAutomaticEvents() method
    testMixpanel.enableAutomaticEvents()
    waitForTrackingQueue(testMixpanel)

    // Verify automatic events are now enabled
    XCTAssertTrue(
      testMixpanel.trackAutomaticEventsEnabled,
      "trackAutomaticEventsEnabled should be true after calling enableAutomaticEvents()")
    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).count >= 1,
      "First open event should be tracked after calling enableAutomaticEvents()")

    removeDBfile(testMixpanel.apiToken)
  }

  func testSessionTrackingAfterDeferredAutomaticEventsEnable() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0

    // Enable automatic events after initial setup
    testMixpanel.enableAutomaticEvents()
    waitForTrackingQueue(testMixpanel)

    // Clear previous events (first open)
    let countBefore = eventQueue(token: testMixpanel.apiToken).count

    // Simulate app resignation
    testMixpanel.automaticEvents.perform(
      #selector(AutomaticEvents.appWillResignActive(_:)),
      with: Notification(name: Notification.Name(rawValue: "test")))
    waitForTrackingQueue(testMixpanel)

    // Session event should be tracked
    let countAfter = eventQueue(token: testMixpanel.apiToken).count
    XCTAssertTrue(
      countAfter > countBefore,
      "Session event should be tracked after enabling deferred automatic events")

    let sessionEvent = eventQueue(token: testMixpanel.apiToken).last
    XCTAssertEqual(
      sessionEvent?["event"] as? String, "$ae_session",
      "Should track session event after deferred enable")

    removeDBfile(testMixpanel.apiToken)
  }

  func testMultipleDeferredEnablesAreIdempotent() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0

    // Enable multiple times
    testMixpanel.trackAutomaticEventsEnabled = true
    waitForTrackingQueue(testMixpanel)
    let countAfterFirstEnable = eventQueue(token: testMixpanel.apiToken).count

    testMixpanel.trackAutomaticEventsEnabled = true
    waitForTrackingQueue(testMixpanel)
    let countAfterSecondEnable = eventQueue(token: testMixpanel.apiToken).count

    testMixpanel.enableAutomaticEvents()
    waitForTrackingQueue(testMixpanel)
    let countAfterThirdEnable = eventQueue(token: testMixpanel.apiToken).count

    // The first event count should remain the same despite multiple enables
    XCTAssertEqual(
      countAfterFirstEnable, countAfterSecondEnable,
      "Second enable should not duplicate first open event")
    XCTAssertEqual(
      countAfterSecondEnable, countAfterThirdEnable,
      "Third enable should not duplicate first open event")

    removeDBfile(testMixpanel.apiToken)
  }

  func testDisablingAndReEnablingAutomaticEvents() {
    let testToken = randomId()
    let testMixpanel = Mixpanel.initialize(
      token: testToken, trackAutomaticEvents: true, flushInterval: 60)
    testMixpanel.minimumSessionDuration = 0

    waitForTrackingQueue(testMixpanel)
    let initialEventCount = eventQueue(token: testMixpanel.apiToken).count
    XCTAssertTrue(
      initialEventCount > 0, "Should have first open event initially")

    // Disable automatic events
    testMixpanel.trackAutomaticEventsEnabled = false
    XCTAssertFalse(
      testMixpanel.trackAutomaticEventsEnabled,
      "Should be disabled after setting to false")

    // Re-enable automatic events
    testMixpanel.trackAutomaticEventsEnabled = true
    XCTAssertTrue(
      testMixpanel.trackAutomaticEventsEnabled,
      "Should be re-enabled after setting to true")

    removeDBfile(testMixpanel.apiToken)
  }
}
