//
//  MixpanelGroupTests.swift
//  MixpanelDemo
//
//  Created by Iris McLeary on 9/5/2018.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemoMac

class MixpanelGroupTests: MixpanelBaseTests {

    func testGroupSet() {
        let groupKey = "test_key"
        let groupID = "test_id"
        let p: Properties = ["p1": "a"]
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        let q = msg["$set"] as! InternalProperties
        XCTAssertEqual(q["p1"] as? String, "a", "custom group property not queued")
    }

    func testGroupSetIntegerID() {
        let groupKey = "test_key"
        let groupID = 3
        let p: Properties = ["p1": "a"]
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! Int, groupID)
        let q = msg["$set"] as! InternalProperties
        XCTAssertEqual(q["p1"] as? String, "a", "custom group property not queued")
    }

    func testGroupSetOnce() {
        let groupKey = "test_key"
        let groupID = "test_id"
        let p: Properties = ["p1": "a"]
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).setOnce(properties: p)
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        let q = msg["$set_once"] as! InternalProperties
        XCTAssertEqual(q["p1"] as? String, "a", "custom group property not queued")
    }

    func testGroupSetTo() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(property: "p1", to: "a")
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        let p = msg["$set"] as! InternalProperties
        XCTAssertEqual(p["p1"] as? String, "a", "custom group property not queued")
    }

    func testGroupUnset() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).unset(property: "p1")
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        XCTAssertEqual(msg["$unset"] as! [String], ["p1"], "group property unset not queued")
    }

    func testGroupRemove() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).remove(key: "p1", value: "a")
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        XCTAssertEqual(msg["$remove"] as? [String: String], ["p1": "a"], "group property remove not queued")
    }

    func testGroupUnion() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).union(key: "p1", values: ["a"])
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        XCTAssertEqual(msg["$union"] as? [String: [String]], ["p1": ["a"]], "group property union not queued")
    }


    func testGroupAssertPropertyTypes() {
        let groupKey = "test_key"
        let groupID = "test_id"
        let p: Properties = ["URL": [Data()]]
        XCTExpectAssert("unsupported property type was allowed") {
            mixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
        }
        XCTExpectAssert("unsupported property type was allowed") {
            mixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(property: "p1", to: [Data()])
        }
    }

    func testDeleteGroup() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.getGroup(groupKey: groupKey, groupID: groupID).deleteGroup()
        waitForTrackingQueue()
        let msg = groupQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(msg["$group_key"] as! String, groupKey)
        XCTAssertEqual(msg["$group_id"] as! String, groupID)
        let p: InternalProperties = msg["$delete"] as! InternalProperties
        XCTAssertTrue(p.isEmpty, "incorrect group properties: \(p)")
    }
}
