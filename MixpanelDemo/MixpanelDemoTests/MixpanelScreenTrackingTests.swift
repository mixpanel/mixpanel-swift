//
//  MixpanelScreenTrackingTests.swift
//  MixpanelDemo
//
//  Created for screenView and screenLeave tracking methods
//

import XCTest

@testable import Mixpanel

class MixpanelScreenTrackingTests: MixpanelBaseTests {

    func testScreenView() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        let properties: Properties = ["extra_prop": "extra_value"]
        testMixpanel.autocapture.trackScreenView(screenName: "HomeScreen", properties: properties)

        waitForTrackingQueue(testMixpanel)

        let events = eventQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(events.count, 1)

        let event = events.first
        XCTAssertEqual(event?["event"] as? String, "$mp_page_view")

        let props = event?["properties"] as? InternalProperties
        XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
        XCTAssertEqual(props?["$mp_autocapture"] as? Bool, true)
        XCTAssertEqual(props?["extra_prop"] as? String, "extra_value")
        XCTAssertNotNil(props?["$screen_height"])

        removeDBfile(testMixpanel.apiToken)
    }

    func testScreenViewWithoutProperties() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        testMixpanel.autocapture.trackScreenView(screenName: "HomeScreen")

        waitForTrackingQueue(testMixpanel)

        let events = eventQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(events.count, 1)

        let event = events.first
        XCTAssertEqual(event?["event"] as? String, "$mp_page_view")

        let props = event?["properties"] as? InternalProperties
        XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
        XCTAssertEqual(props?["$mp_autocapture"] as? Bool, true)

        removeDBfile(testMixpanel.apiToken)
    }

    func testScreenLeave() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        let properties: Properties = ["time_spent": 30]
        testMixpanel.autocapture.trackScreenLeave(screenName: "HomeScreen", properties: properties)

        waitForTrackingQueue(testMixpanel)

        let events = eventQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(events.count, 1)

        let event = events.first
        XCTAssertEqual(event?["event"] as? String, "$mp_page_leave")

        let props = event?["properties"] as? InternalProperties
        XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
        XCTAssertEqual(props?["$mp_autocapture"] as? Bool, true)
        XCTAssertEqual(props?["time_spent"] as? Int, 30)

        removeDBfile(testMixpanel.apiToken)
    }

    func testScreenLeaveWithoutProperties() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        testMixpanel.autocapture.trackScreenLeave(screenName: "HomeScreen")

        waitForTrackingQueue(testMixpanel)

        let events = eventQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(events.count, 1)

        let event = events.first
        XCTAssertEqual(event?["event"] as? String, "$mp_page_leave")

        let props = event?["properties"] as? InternalProperties
        XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
        XCTAssertEqual(props?["$mp_autocapture"] as? Bool, true)

        removeDBfile(testMixpanel.apiToken)
    }

    func testSdkPropertiesCannotBeOverridden() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        let properties: Properties = [
            "current_page_title": "SpoofedTitle",
            "$mp_autocapture": false,
        ]
        testMixpanel.autocapture.trackScreenView(screenName: "HomeScreen", properties: properties)

        waitForTrackingQueue(testMixpanel)

        let events = eventQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(events.count, 1)

        let props = events.first?["properties"] as? InternalProperties
        XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
        XCTAssertEqual(props?["$mp_autocapture"] as? Bool, true)

        removeDBfile(testMixpanel.apiToken)
    }
}
