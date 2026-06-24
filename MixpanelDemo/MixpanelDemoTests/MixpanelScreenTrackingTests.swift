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
    testMixpanel.screenView(screenName: "HomeScreen", properties: properties)

    waitForTrackingQueue(testMixpanel)

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(events.count, 1)

    let event = events.first
    XCTAssertEqual(event?["event"] as? String, "$mp_page_view")

    let props = event?["properties"] as? InternalProperties
    XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
    XCTAssertEqual(props?["extra_prop"] as? String, "extra_value")
    XCTAssertNotNil(props?["$screen_height"])

    removeDBfile(testMixpanel.apiToken)
  }

  func testScreenViewWithoutProperties() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
    testMixpanel.screenView(screenName: "HomeScreen")

    waitForTrackingQueue(testMixpanel)

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(events.count, 1)

    let event = events.first
    XCTAssertEqual(event?["event"] as? String, "$mp_page_view")

    let props = event?["properties"] as? InternalProperties
    XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")

    removeDBfile(testMixpanel.apiToken)
  }

  func testScreenViewNilScreenName() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)

    testMixpanel.screenView(screenName: nil)
    testMixpanel.screenView(screenName: "")

    waitForTrackingQueue(testMixpanel)

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(events.count, 0)

    removeDBfile(testMixpanel.apiToken)
  }

  func testScreenLeave() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
    let properties: Properties = ["time_spent": 30]
    testMixpanel.screenLeave(screenName: "HomeScreen", properties: properties)

    waitForTrackingQueue(testMixpanel)

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(events.count, 1)

    let event = events.first
    XCTAssertEqual(event?["event"] as? String, "$mp_page_leave")

    let props = event?["properties"] as? InternalProperties
    XCTAssertEqual(props?["current_page_title"] as? String, "HomeScreen")
    XCTAssertEqual(props?["time_spent"] as? Int, 30)

    removeDBfile(testMixpanel.apiToken)
  }

  func testScreenLeaveNilScreenName() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)

    testMixpanel.screenLeave(screenName: nil)
    testMixpanel.screenLeave(screenName: "")

    waitForTrackingQueue(testMixpanel)

    let events = eventQueue(token: testMixpanel.apiToken)
    XCTAssertEqual(events.count, 0)

    removeDBfile(testMixpanel.apiToken)
  }
}
