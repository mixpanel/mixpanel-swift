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
    
    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutYES()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(testMixpanel.hasOptedOutTracking(), "When initialize with opted out flag set to YES, the current user should have opted out tracking")
        testMixpanel.reset()
        removeDBfile(testMixpanel)
    }

    func testOptInWillAddOptInEvent()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        XCTAssertFalse(testMixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "When opted in, event queue should have one even(opt in) being queued")

        if eventQueue(token: testMixpanel.apiToken).count > 0 {
            let event = eventQueue(token: testMixpanel.apiToken).first
            XCTAssertEqual((event!["event"] as? String), "$opt_in", "When opted in, a track '$opt_in' should have been queued")
        }
        else {
            XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "When opted in, event queue should have one even(opt in) being queued")
        }
        removeDBfile(testMixpanel)
    }

    func testOptInTrackingForDistinctId()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking(distinctId: "testDistinctId")
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(testMixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForTrackingQueue(testMixpanel)
        let event = eventQueue(token: testMixpanel.apiToken).first
        XCTAssertEqual((event!["event"] as? String), "$opt_in", "When opted in, a track '$opt_in' should have been queued")
        XCTAssertEqual(testMixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(testMixpanel.people.distinctId, "testDistinctId", "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 0, "identify: should move records from unidentified queue")
        removeDBfile(testMixpanel)
    }

    func testOptInTrackingForDistinctIdAndWithEventProperties()
    {
        let now = Date()
        let testProperties: Properties = ["string": "yello",
            "number": 3,
            "date": now,
            "$app_version": "override"]
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking(distinctId: "testDistinctId", properties: testProperties)
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        let eventQueueValue = eventQueue(token: testMixpanel.apiToken)
        
        let props = eventQueueValue.first!["properties"] as? InternalProperties
        XCTAssertEqual(props!["string"] as? String, "yello")
        XCTAssertEqual(props!["number"] as? NSNumber, 3)
        compareDate(dateString: props!["date"] as! String, dateDate: now)
        XCTAssertEqual(props!["$app_version"] as? String, "override", "reserved property override failed")

        if eventQueueValue.count > 0 {
            let event = eventQueueValue.first
            XCTAssertEqual((event!["event"] as? String), "$opt_in", "When opted in, a track '$opt_in' should have been queued")
        }
        else {
            XCTAssertTrue(eventQueueValue.count == 1, "When opted in, event queue should have one even(opt in) being queued")
        }

        XCTAssertEqual(testMixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(testMixpanel.people.distinctId, "testDistinctId", "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 0, "identify: should move records from unidentified queue")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForMultipleInstances()
    {
        let mixpanel1 = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(mixpanel1)
        XCTAssertTrue(mixpanel1.hasOptedOutTracking(), "When initialize with opted out flag set to YES, the current user should have opted out tracking")
        removeDBfile(mixpanel1)

        let mixpanel2 = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: false)
        XCTAssertFalse(mixpanel2.hasOptedOutTracking(), "When initialize with opted out flag set to NO, the current user should have opted in tracking")
        removeDBfile(mixpanel2)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: false)
        XCTAssertFalse(testMixpanel.hasOptedOutTracking(), "When initialize with opted out flag set to NO, the current user should have opted out tracking")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyByDefault()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId())
        XCTAssertFalse(testMixpanel.hasOptedOutTracking(), "By default, the current user should not opted out tracking")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForOptOut()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        XCTAssertTrue(testMixpanel.hasOptedOutTracking(), "When optOutTracking is called, the current user should have opted out tracking")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForOptIn()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(testMixpanel.hasOptedOutTracking(), "When optOutTracking is called, the current user should have opted out tracking")
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(testMixpanel.hasOptedOutTracking(), "When optOutTracking is called, the current user should have opted in tracking")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingWillNotGenerateEventQueue()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        for i in 0..<50 {
            testMixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 0, "When opted out, events should not be queued")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingWillNotGeneratePeopleQueue()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        for i in 0..<50 {
            testMixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).count == 0, "When opted out, events should not be queued")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingWillSkipAlias()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        testMixpanel.createAlias("testAlias", distinctId: "aDistinctId")
        XCTAssertNotEqual(testMixpanel.alias, "testAlias", "When opted out, alias should not be set")
        removeDBfile(testMixpanel)
    }

    func testEventBeingTrackedBeforeOptOutShouldNotBeCleared()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId())
        testMixpanel.track(event: "a normal event")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "events should be queued")
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "When opted out, any events tracked before opted out should not be cleared")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingRegisterSuperProperties()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.registerSuperProperties(properties)
        waitForTrackingQueue(testMixpanel)
        XCTAssertNotEqual(NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
                       NSDictionary(dictionary: properties),
                       "When opted out, register super properties should not be successful")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingRegisterSuperPropertiesOnce()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.registerSuperPropertiesOnce(properties)
        waitForTrackingQueue(testMixpanel)
            XCTAssertNotEqual(NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
                              NSDictionary(dictionary: properties),
                          "When opted out, register super properties once should not be successful")
        removeDBfile(testMixpanel)
    }

    func testOptOutWilSkipTimeEvent()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.time(event: "400 Meters")
        testMixpanel.track(event: "400 Meters")
        waitForTrackingQueue(testMixpanel)
        XCTAssertNil(eventQueue(token:testMixpanel.apiToken).last, "When opted out, this event should not be timed.")
        removeDBfile(testMixpanel)
    }

    func testOptOutWillSkipFlushPeople()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        for i in 0..<1 {
            testMixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).count == 1, "When opted in, people queue should have been queued")

        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).count == 1, "When opted out, people queue should not be flushed")
        removeDBfile(testMixpanel)
    }

    func testOptOutWillSkipFlushEvent()
    {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        for i in 0..<1 {
            testMixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 3, "When opted in, events should have been queued")

        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 3, "When opted out, events should not be flushed")
        removeDBfile(testMixpanel)
    }
}
