//
//  MixpanelEventBridgeTests.swift
//  MixpanelDemoMacTests
//
//  Created by Mixpanel on 2026-04-07.
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import MixpanelSwiftCommon
import XCTest

@testable import Mixpanel

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
class MixpanelEventBridgeTests: MixpanelBaseTests {

    // MARK: - Event Bridge Notified on Track

    func testEventBridgeNotifiedOnTrack() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        let eventName = "BridgeTestEvent_\(randomId())"
        let expectation = XCTestExpectation(description: "Event bridge is notified when event is tracked")

        let stream = MixpanelEventBridge.shared.eventStream()
        let task = Task {
            for await event in stream {
                if event.eventName == eventName {
                    expectation.fulfill()
                    break
                }
            }
        }

        testMixpanel.track(event: eventName)
        waitForTrackingQueue(testMixpanel)

        wait(for: [expectation], timeout: 2.0)
        task.cancel()
        removeDBfile(testMixpanel.apiToken)
    }

    // MARK: - Event Bridge Receives Properties

    func testEventBridgeReceivesEventProperties() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), trackAutomaticEvents: false)
        let eventName = "BridgePropsTest_\(randomId())"
        let expectation = XCTestExpectation(
            description: "Event bridge receives event with correct properties")

        let stream = MixpanelEventBridge.shared.eventStream()
        let task = Task {
            for await event in stream {
                if event.eventName == eventName {
                    XCTAssertEqual(event.properties["testKey"] as? String, "testValue")
                    expectation.fulfill()
                    break
                }
            }
        }

        testMixpanel.track(event: eventName, properties: ["testKey": "testValue"])
        waitForTrackingQueue(testMixpanel)

        wait(for: [expectation], timeout: 2.0)
        task.cancel()
        removeDBfile(testMixpanel.apiToken)
    }

    // MARK: - Event Bridge Not Notified When Opted Out

    func testEventBridgeNotNotifiedWhenOptedOut() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), optOutTrackingByDefault: true, trackAutomaticEvents: false)
        let eventName = "BridgeOptOutTest_\(randomId())"
        let noEventExpectation = XCTestExpectation(
            description: "Event bridge should not be notified when tracking is opted out")
        noEventExpectation.isInverted = true

        let stream = MixpanelEventBridge.shared.eventStream()
        let task = Task {
            for await event in stream {
                if event.eventName == eventName {
                    noEventExpectation.fulfill()
                }
            }
        }

        testMixpanel.track(event: eventName)
        waitForTrackingQueue(testMixpanel)

        wait(for: [noEventExpectation], timeout: 1.0)
        task.cancel()
        removeDBfile(testMixpanel.apiToken)
    }

}
