//
//  DisplayTriggersTest.swift
//  MixpanelDemoTests
//
//  Created by Madhu Palani on 3/6/19.
//  Copyright © 2019 Mixpanel. All rights reserved.
//

import Foundation
import XCTest

@testable import Mixpanel
@testable import MixpanelDemo

class InAppNotificationTest : XCTestCase {
    
    func testMatchesEvent() {
        let displayTriggers = [["event": "test_event_1", "selector": ["operator": "<", "children": [["property": "event", "value": "created_at"], ["property": "literal", "value": ["window": ["value": -1, "unit": "hour"]]]]]], ["event": "test_event_2", "selector": ["operator": "==", "children": [["property": "event", "value": "city"], ["property": "literal", "value": "San Francisco"]]]]]
        
        let inapp = InAppNotification(JSONObject: ["id": 1, "message_id": 1, "extras": [:], "display_triggers": displayTriggers, "bg_color": UInt(101), "body_color": UInt(101), "image_url": "https://www.test.com/test.jpg", "type": "mini"])
        let inappWithoutTriggers = InAppNotification(JSONObject: ["id": 1, "message_id": 1, "extras": [:], "bg_color": UInt(101), "body_color": UInt(101), "image_url": "https://www.test.com/test.jpg", "type": "mini"])
        XCTAssertNotNil(inapp)
        XCTAssertNotNil(inapp?.payload()["display_triggers"] as? [Any])
        XCTAssertNotNil(inappWithoutTriggers?.payload()["display_triggers"] as? [Any])
        
        XCTAssertFalse(inappWithoutTriggers!.matchesEvent(event: "test_event_1", properties: InternalProperties()))
        XCTAssertTrue(inapp!.matchesEvent(event: "test_event_1", properties: ["created_at": Date()]))
        XCTAssertFalse(inapp!.matchesEvent(event: "test_event_1", properties: ["created_at": Date().addingTimeInterval(2*60*60)]))
        XCTAssertFalse(inapp!.matchesEvent(event: "test_event_1", properties: ["city": "San Francisco"]))
        XCTAssertTrue(inapp!.matchesEvent(event: "test_event_2", properties: ["created_at": Date().addingTimeInterval(2*60*60), "city": "San Francisco"]))
        XCTAssertFalse(inapp!.matchesEvent(event: "test_event_2", properties: ["created_at": Date(), "city": "Los Angeles"]))
        XCTAssertFalse(inapp!.matchesEvent(event: "test_event_2", properties: ["city": "Los Angeles"]))
    }
}
