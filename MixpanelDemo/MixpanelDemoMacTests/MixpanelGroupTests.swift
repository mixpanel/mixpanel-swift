//
//  MixpanelGroupTests.swift
//  MixpanelDemo
//
//  Created by Iris McLeary on 9/5/2018.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel
@testable import MixpanelDemoMac

class MixpanelGroupTests: MixpanelBaseTests {

  func testGroupSet() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    let p: Properties = ["p1": "a"]
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    let q = msg["$set"] as! InternalProperties
    XCTAssertEqual(q["p1"] as? String, "a", "custom group property not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupSetIntegerID() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = 3
    let p: Properties = ["p1": "a"]
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! Int, groupID)
    let q = msg["$set"] as! InternalProperties
    XCTAssertEqual(q["p1"] as? String, "a", "custom group property not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupSetOnce() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    let p: Properties = ["p1": "a"]
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).setOnce(properties: p)
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    let q = msg["$set_once"] as! InternalProperties
    XCTAssertEqual(q["p1"] as? String, "a", "custom group property not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupSetTo() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(property: "p1", to: "a")
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    let p = msg["$set"] as! InternalProperties
    XCTAssertEqual(p["p1"] as? String, "a", "custom group property not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupUnset() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).unset(property: "p1")
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    XCTAssertEqual(msg["$unset"] as! [String], ["p1"], "group property unset not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupRemove() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).remove(key: "p1", value: "a")
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    XCTAssertEqual(
      msg["$remove"] as? [String: String], ["p1": "a"], "group property remove not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupUnion() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).union(key: "p1", values: ["a"])
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    XCTAssertEqual(
      msg["$union"] as? [String: [String]], ["p1": ["a"]], "group property union not queued")
    removeDBfile(testMixpanel)
  }

  func testGroupAssertPropertyTypes() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    let p: Properties = ["URL": [Data()]]
    XCTExpectAssert("unsupported property type was allowed") {
      testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
    }
    XCTExpectAssert("unsupported property type was allowed") {
      testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).set(property: "p1", to: [Data()])
    }
    removeDBfile(testMixpanel)
  }

  func testDeleteGroup() {
    let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
    let groupKey = "test_key"
    let groupID = "test_id"
    testMixpanel.getGroup(groupKey: groupKey, groupID: groupID).deleteGroup()
    waitForTrackingQueue(testMixpanel)
    let msg = groupQueue(token: testMixpanel.apiToken).last!
    XCTAssertEqual(msg["$group_key"] as! String, groupKey)
    XCTAssertEqual(msg["$group_id"] as! String, groupID)
    let p: InternalProperties = msg["$delete"] as! InternalProperties
    XCTAssertTrue(p.isEmpty, "incorrect group properties: \(p)")
    removeDBfile(testMixpanel)
  }
}
