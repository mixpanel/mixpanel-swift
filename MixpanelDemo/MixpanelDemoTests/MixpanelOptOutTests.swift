//
//  MixpanelOptOutTests.swift
//  MixpanelDemoTests
//
//  Created by Zihe Jia on 3/27/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

class MixpanelOptOutTests: MixpanelBaseTests {

    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutYES() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "When initialize with opted out flag set to YES, the current user should have opted out tracking"
        )
        testMixpanel.reset()
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptInWillAddOptInEvent() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 1,
            "When opted in, event queue should have one even(opt in) being queued")

        if eventQueue(token: testMixpanel.apiToken).count > 0 {
            let event = eventQueue(token: testMixpanel.apiToken).first
            XCTAssertEqual(
                (event!["event"] as? String), "$opt_in",
                "When opted in, a track '$opt_in' should have been queued")
        } else {
            XCTAssertTrue(
                eventQueue(token: testMixpanel.apiToken).count == 1,
                "When opted in, event queue should have one even(opt in) being queued")
        }
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptInTrackingForDistinctId() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, optOutTrackingByDefault: true)
        testMixpanel.optInTracking(distinctId: "testDistinctId")
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForTrackingQueue(testMixpanel)
        let event1 = eventQueue(token: testMixpanel.apiToken).first
        let event2 = eventQueue(token: testMixpanel.apiToken).last
        XCTAssertTrue(
            (event1!["event"] as? String) == "$opt_in" || (event2!["event"] as? String) == "$opt_in",
            "When opted in, a track '$opt_in' should have been queued")
        XCTAssertEqual(
            testMixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(
            testMixpanel.people.distinctId, "testDistinctId",
            "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 0,
            "identify: should move records from unidentified queue")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptInTrackingForDistinctIdAndWithEventProperties() {
        let now = Date()
        let testProperties: Properties = [
            "string": "yello",
            "number": 3,
            "date": now,
            "$app_version": "override",
        ]
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        testMixpanel.optInTracking(distinctId: "testDistinctId", properties: testProperties)
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        let eventQueueValue = eventQueue(token: testMixpanel.apiToken)
        let props = eventQueueValue[0]["properties"] as? InternalProperties
        XCTAssertEqual(props!["string"] as? String, "yello")
        XCTAssertEqual(props!["number"] as? NSNumber, 3)
        compareDate(dateString: props!["date"] as! String, dateDate: now)
        XCTAssertEqual(
            props!["$app_version"] as? String, "override", "reserved property override failed")

        if eventQueueValue.count > 0 {
            let event = eventQueueValue[0]
            XCTAssertEqual(
                (event["event"] as? String), "$opt_in",
                "When opted in, a track '$opt_in' should have been queued")
        } else {
            XCTAssertTrue(
                eventQueueValue.count == 1,
                "When opted in, event queue should have one even(opt in) being queued")
        }

        XCTAssertEqual(
            testMixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(
            testMixpanel.people.distinctId, "testDistinctId",
            "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 0,
            "identify: should move records from unidentified queue")
        removeDBfile(testMixpanel.apiToken)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForMultipleInstances() {
        let mixpanel1 = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        waitForTrackingQueue(mixpanel1)
        XCTAssertTrue(
            mixpanel1.hasOptedOutTracking(),
            "When initialize with opted out flag set to YES, the current user should have opted out tracking"
        )
        removeDBfile(mixpanel1.apiToken)

        let mixpanel2 = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: false)
        XCTAssertFalse(
            mixpanel2.hasOptedOutTracking(),
            "When initialize with opted out flag set to NO, the current user should have opted in tracking"
        )
        removeDBfile(mixpanel2.apiToken)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: false)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "When initialize with opted out flag set to NO, the current user should have opted out tracking"
        )
        removeDBfile(testMixpanel.apiToken)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyByDefault() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: true)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "By default, the current user should not opted out tracking")
        removeDBfile(testMixpanel.apiToken)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForOptOut() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "When optOutTracking is called, the current user should have opted out tracking")
        removeDBfile(testMixpanel.apiToken)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForOptIn() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "When optOutTracking is called, the current user should have opted out tracking")
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "When optOutTracking is called, the current user should have opted in tracking")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutTrackingWillNotGenerateEventQueue() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        for i in 0..<50 {
            testMixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 0,
            "When opted out, events should not be queued")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutTrackingWillNotGeneratePeopleQueue() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        for i in 0..<50 {
            testMixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).count == 0,
            "When opted out, events should not be queued")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutTrackingWillSkipAlias() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        testMixpanel.createAlias("testAlias", distinctId: "aDistinctId")
        XCTAssertNotEqual(testMixpanel.alias, "testAlias", "When opted out, alias should not be set")
        removeDBfile(testMixpanel.apiToken)
    }

    func testEventBeingTrackedBeforeOptOutShouldNotBeCleared() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: true)
        waitForAsyncTasks()
        testMixpanel.track(event: "a normal event")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 2, "events should be queued")
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 2,
            "When opted out, any events tracked before opted out should not be cleared")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutTrackingRegisterSuperProperties() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        testMixpanel.optOutTracking()
        testMixpanel.registerSuperProperties(properties)
        waitForTrackingQueue(testMixpanel)
        XCTAssertNotEqual(
            NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
            NSDictionary(dictionary: properties),
            "When opted out, register super properties should not be successful")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutTrackingRegisterSuperPropertiesOnce() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        testMixpanel.optOutTracking()
        testMixpanel.registerSuperPropertiesOnce(properties)
        waitForTrackingQueue(testMixpanel)
        XCTAssertNotEqual(
            NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
            NSDictionary(dictionary: properties),
            "When opted out, register super properties once should not be successful")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutWilSkipTimeEvent() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.time(event: "400 Meters")
        testMixpanel.track(event: "400 Meters")
        waitForTrackingQueue(testMixpanel)
        XCTAssertNil(
            eventQueue(token: testMixpanel.apiToken).last,
            "When opted out, this event should not be timed.")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutWillSkipFlushPeople() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 0,
            optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        for i in 0..<1 {
            testMixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).count == 1,
            "When opted in, people queue should have been queued")

        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).count == 1,
            "When opted out, people queue should not be flushed")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutByDefaultTrueSkipsFirstAppOpen() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 0,
            "When opted out, first app open should not be tracked")
        removeDBfile(testMixpanel.apiToken)
    }

    // MARK: - Autocapture Opt-Out Tests

    func testAutocaptureNotStartedWhenOptedOutByDefault() {
        let token = randomId()
        let options = MixpanelOptions(
            token: token,
            flushInterval: 60,
            instanceName: token,
            trackAutomaticEvents: false,
            optOutTrackingByDefault: true,
            serverURL: kFakeServerUrl,
            autocaptureOptions: AutocaptureOptions()
        )
        let testMixpanel = Mixpanel.initialize(options: options)
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()

        XCTAssertTrue(testMixpanel.hasOptedOutTracking())
        XCTAssertNil(
            testMixpanel.autocaptureManager,
            "AutocaptureManager should not be created when opted out by default")

        removeDBfile(token)
    }

    func testAutocaptureStopsOnOptOut() {
        let token = randomId()
        let options = MixpanelOptions(
            token: token,
            flushInterval: 60,
            instanceName: token,
            trackAutomaticEvents: false,
            optOutTrackingByDefault: false,
            serverURL: kFakeServerUrl,
            autocaptureOptions: AutocaptureOptions()
        )
        let testMixpanel = Mixpanel.initialize(options: options)
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()

        XCTAssertNotNil(testMixpanel.autocaptureManager,
                        "AutocaptureManager should be created when not opted out")
        XCTAssertTrue(testMixpanel.autocaptureManager!.isStarted,
                      "AutocaptureManager should be started")

        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()

        XCTAssertFalse(testMixpanel.autocaptureManager!.isStarted,
                       "AutocaptureManager should be stopped after opt-out")

        removeDBfile(token)
    }

    func testAutocaptureRestartsOnOptIn() {
        let token = randomId()
        let options = MixpanelOptions(
            token: token,
            flushInterval: 60,
            instanceName: token,
            trackAutomaticEvents: false,
            optOutTrackingByDefault: false,
            serverURL: kFakeServerUrl,
            autocaptureOptions: AutocaptureOptions()
        )
        let testMixpanel = Mixpanel.initialize(options: options)
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()

        // Opt out — autocapture stops
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()
        XCTAssertFalse(testMixpanel.autocaptureManager!.isStarted,
                       "AutocaptureManager should be stopped after opt-out")

        // Opt in — autocapture restarts
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()
        XCTAssertNotNil(testMixpanel.autocaptureManager,
                        "AutocaptureManager should exist after opt-in")
        XCTAssertTrue(testMixpanel.autocaptureManager!.isStarted,
                      "AutocaptureManager should be started after opt-in")

        removeDBfile(token)
    }

    func testAutocaptureStartsOnOptInAfterOptOutByDefault() {
        let token = randomId()
        let options = MixpanelOptions(
            token: token,
            flushInterval: 60,
            instanceName: token,
            trackAutomaticEvents: false,
            optOutTrackingByDefault: true,
            serverURL: kFakeServerUrl,
            autocaptureOptions: AutocaptureOptions()
        )
        let testMixpanel = Mixpanel.initialize(options: options)
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()

        XCTAssertNil(testMixpanel.autocaptureManager,
                     "AutocaptureManager should not be created when opted out by default")

        // Opt in — autocapture should be created and started
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        waitForAsyncTasks()

        XCTAssertNotNil(testMixpanel.autocaptureManager,
                        "AutocaptureManager should be created after opt-in")
        XCTAssertTrue(testMixpanel.autocaptureManager!.isStarted,
                      "AutocaptureManager should be started after opt-in")

        removeDBfile(token)
    }

    // MARK: - Existing Tests

    func testOptOutWillSkipFlushEvent() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optInTracking()
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        for i in 0..<1 {
            testMixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 2,
            "When opted in, events should have been queued")

        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 2,
            "When opted out, events should not be flushed")
        removeDBfile(testMixpanel.apiToken)
    }
}
