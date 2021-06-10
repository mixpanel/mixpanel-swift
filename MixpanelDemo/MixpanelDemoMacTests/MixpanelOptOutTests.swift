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
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        XCTAssertTrue(mixpanel.hasOptedOutTracking(), "When initialize with opted out flag set to YES, the current user should have opted out tracking")
    }

    func testOptInWillAddOptInEvent()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking()
        XCTAssertFalse(mixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count == 1, "When opted in, event queue should have one even(opt in) being queued")

        if mixpanel.eventsQueue.count > 0 {
            let event = mixpanel.eventsQueue.first
            XCTAssertEqual((event!["event"] as? String), "$opt_in", "When opted in, a track '$opt_in' should have been queued")
        }
        else {
            XCTAssertTrue(mixpanel.eventsQueue.count == 1, "When opted in, event queue should have one even(opt in) being queued")
        }
    }

    func testOptInTrackingForDistinctId()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking(distinctId: "testDistinctId")
        XCTAssertFalse(mixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForTrackingQueue()
        if mixpanel.eventsQueue.count > 0 {
            let event = mixpanel.eventsQueue.first
            XCTAssertEqual((event!["event"] as? String), "$opt_in", "When opted in, a track '$opt_in' should have been queued")
        }
        else {
            XCTAssertTrue(mixpanel.eventsQueue.count == 1, "When opted in, event queue should have one even(opt in) being queued")
        }
        
        XCTAssertEqual(mixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(mixpanel.people.distinctId, "testDistinctId", "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(mixpanel.people.unidentifiedQueue.count == 0, "identify: should move records from unidentified queue")
    }
    
    func testOptInTrackingForDistinctIdAndWithEventProperties()
    {
        let now = Date()
        let testProperties: Properties = ["string": "yello",
            "number": 3,
            "date": now,
            "$app_version": "override"]
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking(distinctId: "testDistinctId", properties: testProperties)
        waitForTrackingQueue()
        let props = mixpanel.eventsQueue.first!["properties"] as? InternalProperties
        XCTAssertEqual(props!["string"] as? String, "yello")
        XCTAssertEqual(props!["number"] as? NSNumber, 3)
        XCTAssertEqual(props!["date"] as? Date, now)
        XCTAssertEqual(props!["$app_version"] as? String, "override", "reserved property override failed")
        
        if mixpanel.eventsQueue.count > 0 {
            let event = mixpanel.eventsQueue.first
            XCTAssertEqual((event!["event"] as? String), "$opt_in", "When opted in, a track '$opt_in' should have been queued")
        }
        else {
            XCTAssertTrue(mixpanel.eventsQueue.count == 1, "When opted in, event queue should have one even(opt in) being queued")
        }
        
        XCTAssertEqual(mixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(mixpanel.people.distinctId, "testDistinctId", "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(mixpanel.people.unidentifiedQueue.count == 0, "identify: should move records from unidentified queue")
    }
    
    func testHasOptOutTrackingFlagBeingSetProperlyForMultipleInstances()
    {
        let mixpanel1 = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        XCTAssertTrue(mixpanel1.hasOptedOutTracking(), "When initialize with opted out flag set to YES, the current user should have opted out tracking")
        
        let mixpanel2 = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: false)
        XCTAssertFalse(mixpanel2.hasOptedOutTracking(), "When initialize with opted out flag set to NO, the current user should have opted in tracking")
        
        deleteOptOutSettings(mixpanelInstance: mixpanel1)
        deleteOptOutSettings(mixpanelInstance: mixpanel2)
    }
    
    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: false)
        XCTAssertFalse(mixpanel.hasOptedOutTracking(), "When initialize with opted out flag set to NO, the current user should have opted out tracking")
    }
    
    func testHasOptOutTrackingFlagBeingSetProperlyByDefault()
    {
        mixpanel = Mixpanel.initialize(token: randomId())
        XCTAssertFalse(mixpanel.hasOptedOutTracking(), "By default, the current user should not opted out tracking")
    }
    
    func testHasOptOutTrackingFlagBeingSetProperlyForOptOut()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optOutTracking()
        XCTAssertTrue(mixpanel.hasOptedOutTracking(), "When optOutTracking is called, the current user should have opted out tracking")
    }
    
    func testHasOptOutTrackingFlagBeingSetProperlyForOptIn()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optOutTracking()
        XCTAssertTrue(mixpanel.hasOptedOutTracking(), "When optOutTracking is called, the current user should have opted out tracking")
        mixpanel.optInTracking()
        XCTAssertFalse(mixpanel.hasOptedOutTracking(), "When optOutTracking is called, the current user should have opted in tracking")
    }

    func testEventBeingTrackedBeforeOptOutShouldNotBeCleared()
    {
        mixpanel = Mixpanel.initialize(token: randomId())
        mixpanel.track(event: "a normal event")
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count == 1, "events should be queued")
        mixpanel.optOutTracking()
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count == 1, "When opted out, any events tracked before opted out should not be cleared")
    }

    func testOptOutTrackingWillNotGenerateEventQueue()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optOutTracking()
        for i in 0..<50 {
            mixpanel.track(event: "event \(i)")
        }
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count == 0, "When opted out, events should not be queued")
    }

    func testOptOutTrackingWillNotGeneratePeopleQueue()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optOutTracking()
        for i in 0..<50 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 0, "When opted out, events should not be queued")
    }

    func testOptOutTrackingWillSkipAlias()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optOutTracking()
        mixpanel.createAlias("testAlias", distinctId: "aDistinctId")
        XCTAssertNotEqual(mixpanel.alias, "testAlias", "When opted out, alias should not be set")
    }

    func testOptOutTrackingRegisterSuperProperties()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        mixpanel.optOutTracking()
        mixpanel.registerSuperProperties(properties)
        waitForMixpanelQueues()
        XCTAssertNotEqual(NSDictionary(dictionary: mixpanel.currentSuperProperties()),
                       NSDictionary(dictionary: properties),
                       "When opted out, register super properties should not be successful")
    }

    func testOptOutTrackingRegisterSuperPropertiesOnce()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        mixpanel.optOutTracking()
        mixpanel.registerSuperPropertiesOnce(properties)
        waitForMixpanelQueues()
        XCTAssertNotEqual(NSDictionary(dictionary: mixpanel.currentSuperProperties()),
                          NSDictionary(dictionary: properties),
                          "When opted out, register super properties once should not be successful")
    }

    func testOptOutWilSkipTimeEvent()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optOutTracking()
        mixpanel.time(event: "400 Meters")
        mixpanel.track(event: "400 Meters")
        waitForMixpanelQueues()
        XCTAssertNil(mixpanel.eventsQueue.last, "When opted out, this event should not be timed.")
    }

    func testOptOutTrackingWillPurgeEventQueue()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking()
        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.track(event: "event \(i)")
        }
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count > 50, "When opted in, events should have been queued")
        XCTAssertEqual(mixpanel.eventsQueue.first!["event"] as? String, "$opt_in", "incorrect optin event name")

        mixpanel.optOutTracking()
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count == 0, "When opted out, events should have been purged")
    }

    func testOptOutTrackingWillPurgePeopleQueue()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking()
        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 50, "When opted in, people should have been queued")
        
        mixpanel.optOutTracking()
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 0, "When opted out, people should have been purged")
    }

    func testOptOutWillSkipFlushPeople()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking()
        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 50, "When opted in, people queue should have been queued")

        let peopleQueue = mixpanel.people.peopleQueue
        mixpanel.optOutTracking()
        waitForMixpanelQueues()

        mixpanel.people.peopleQueue = peopleQueue
        mixpanel.flush()
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 50, "When opted out, people queue should not be flushed")
    }

    func testOptOutWillSkipFlushEvent()
    {
        mixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        mixpanel.optInTracking()
        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count > 50, "When opted in, events should have been queued")

        let eventsQueue = mixpanel.eventsQueue
        mixpanel.optOutTracking()
        waitForMixpanelQueues()

        //In order to test if flush will be skipped, we have to create a fake eventsQueue since optOutTracking will clear eventsQueue.
        mixpanel.eventsQueue = eventsQueue
        mixpanel.flush()
        waitForMixpanelQueues()
        XCTAssertTrue(mixpanel.eventsQueue.count > 50, "When opted out, events should not be flushed")
    }
}
