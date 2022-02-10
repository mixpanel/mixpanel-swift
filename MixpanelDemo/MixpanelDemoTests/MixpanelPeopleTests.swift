//
//  MixpanelPeopleTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelPeopleTests: MixpanelBaseTests {

    func testPeopleSet() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        let p: Properties = ["p1": "a"]
        testMixpanel.people.set(properties: p)
        waitForTrackingQueue(testMixpanel)
        let q = peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(q["p1"] as? String, "a", "custom people property not queued")
        assertDefaultPeopleProperties(q)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleSetOnce() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        let p: Properties = ["p1": "a"]
        testMixpanel.people.setOnce(properties: p)
        waitForTrackingQueue(testMixpanel)
        let q = peopleQueue(token: testMixpanel.apiToken).last!["$set_once"] as! InternalProperties
        XCTAssertEqual(q["p1"] as? String, "a", "custom people property not queued")
        assertDefaultPeopleProperties(q)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleSetReservedProperty() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        let p: Properties = ["$ios_app_version": "override"]
        testMixpanel.people.set(properties: p)
        waitForTrackingQueue(testMixpanel)
        let q = peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(q["$ios_app_version"] as? String,
                       "override",
                       "reserved property override failed")
        assertDefaultPeopleProperties(q)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleSetTo() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.set(property: "p1", to: "a")
        waitForTrackingQueue(testMixpanel)
        let p: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
        assertDefaultPeopleProperties(p)
        removeDBfile(testMixpanel.apiToken)
    }

    func testDropUnidentifiedPeopleRecords() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        for i in 0..<505 {
            testMixpanel.people.set(property: "i", to: i)
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 506)
        var r: InternalProperties = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)[1]
        XCTAssertEqual((r["$set"] as? InternalProperties)?["i"] as? Int, 0)
        r = unIdentifiedPeopleQueue(token: testMixpanel.apiToken).last!
        XCTAssertEqual((r["$set"] as? InternalProperties)?["i"] as? Int, 504)
        removeDBfile(testMixpanel.apiToken)
    }


    func testPeopleAssertPropertyTypes() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        var p: Properties = ["URL": [Data()]]
        XCTExpectAssert("unsupported property type was allowed") {
            testMixpanel.people.set(properties: p)
        }
        XCTExpectAssert("unsupported property type was allowed") {
            testMixpanel.people.set(property: "p1", to: [Data()])
        }
        p = ["p1": "a"]
        // increment should require a number
        XCTExpectAssert("unsupported property type was allowed") {
            testMixpanel.people.increment(properties: p)
        }
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleIncrement() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        let p: Properties = ["p1": 3]
        testMixpanel.people.increment(properties: p)
        waitForTrackingQueue(testMixpanel)
        let q = peopleQueue(token: testMixpanel.apiToken).last!["$add"] as! InternalProperties
        XCTAssertTrue(q.count == 1, "incorrect people properties: \(p)")
        XCTAssertEqual(q["p1"] as? Int, 3, "custom people property not queued")
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleIncrementBy() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.increment(property: "p1", by: 3)
        waitForTrackingQueue(testMixpanel)
        let p: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!["$add"] as! InternalProperties
        XCTAssertTrue(p.count == 1, "incorrect people properties: \(p)")
        XCTAssertEqual(p["p1"] as? Double, 3, "custom people property not queued")
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleDeleteUser() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.deleteUser()
        waitForTrackingQueue(testMixpanel)
        let p: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!["$delete"] as! InternalProperties
        XCTAssertTrue(p.isEmpty, "incorrect people properties: \(p)")
        removeDBfile(testMixpanel.apiToken)
    }


    func testPeopleTrackChargeDecimal() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.trackCharge(amount: 25.34)
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$time"]
        XCTAssertEqual(prop, 25.34)
        XCTAssertNotNil(prop2)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackChargeZero() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        testMixpanel.people.trackCharge(amount: 0)
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$time"]
        XCTAssertEqual(prop, 0)
        XCTAssertNotNil(prop2)
        removeDBfile(testMixpanel.apiToken)
    }
    
    func testPeopleTrackChargeWithTime() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        let p: Properties = allPropertyTypes()
        testMixpanel.people.trackCharge(amount: 25, properties: ["$time": p["date"]!])
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$time"] as? String
        XCTAssertEqual(prop, 25)
        compareDate(dateString: prop2!, dateDate: p["date"] as! Date)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackChargeWithProperties() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.trackCharge(amount: 25, properties: ["p1": "a"])
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["p1"]
        XCTAssertEqual(prop, 25)
        XCTAssertEqual(prop2 as? String, "a")
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackCharge() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.trackCharge(amount: 25)
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$time"]
        XCTAssertEqual(prop, 25)
        XCTAssertNotNil(prop2)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleClearCharges() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.clearCharges()
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let transactions = (r["$set"] as? InternalProperties)?["$transactions"] as? [MixpanelType]
        XCTAssertEqual(transactions?.count, 0)
        removeDBfile(testMixpanel.apiToken)
    }
}
