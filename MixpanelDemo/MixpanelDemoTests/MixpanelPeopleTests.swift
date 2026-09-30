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
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
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
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
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
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        let p: Properties = ["$ios_app_version": "override"]
        testMixpanel.people.set(properties: p)
        waitForTrackingQueue(testMixpanel)
        let q = peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(
            q["$ios_app_version"] as? String,
            "override",
            "reserved property override failed")
        assertDefaultPeopleProperties(q)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleSetTo() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.set(property: "p1", to: "a")
        waitForTrackingQueue(testMixpanel)
        let p: InternalProperties =
            peopleQueue(token: testMixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
        assertDefaultPeopleProperties(p)
        removeDBfile(testMixpanel.apiToken)
    }

    func testIdentifyStampsQueuedUnidentifiedPeopleRecords() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.people.set(properties: ["p1": "a"])
        waitForTrackingQueue(testMixpanel)
        let queued = unIdentifiedPeopleQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(queued.count, 1)
        XCTAssertNil(queued.first?["$distinct_id"], "unidentified record must not carry a distinct id yet")
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).isEmpty)

        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).isEmpty,
            "identify should move queued records to the identified queue")
        let identified = peopleQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(identified.count, 1)
        XCTAssertEqual(identified.first?["$distinct_id"] as? String, "d1")
        XCTAssertEqual((identified.first?["$set"] as? InternalProperties)?["p1"] as? String, "a")
        removeDBfile(testMixpanel.apiToken)
    }

    func testQueuedPeopleRecordsKeepIdentityAcrossIdentifyChange() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.identify(distinctId: "A")
        testMixpanel.people.set(properties: ["p1": "a"])
        waitForTrackingQueue(testMixpanel)
        testMixpanel.identify(distinctId: "B")
        testMixpanel.people.set(properties: ["p2": "b"])
        waitForTrackingQueue(testMixpanel)

        let identified = peopleQueue(token: testMixpanel.apiToken)
        XCTAssertEqual(identified.count, 2)
        let forA = identified.first { ($0["$set"] as? InternalProperties)?["p1"] != nil }
        let forB = identified.first { ($0["$set"] as? InternalProperties)?["p2"] != nil }
        XCTAssertEqual(forA?["$distinct_id"] as? String, "A", "record queued under A was re-attributed")
        XCTAssertEqual(forB?["$distinct_id"] as? String, "B")
        removeDBfile(testMixpanel.apiToken)
    }

    func testResetDropsOnlyUnidentifiedPeopleRecords() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.people.set(properties: ["p1": "a"])
        waitForTrackingQueue(testMixpanel)
        XCTAssertEqual(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count, 1)

        testMixpanel.delegate = self  // mixpanelWillFlush is false: no network inside reset()
        testMixpanel.reset()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).isEmpty)
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).isEmpty, "reset must not promote unidentified records")
        removeDBfile(testMixpanel.apiToken)
    }

    func testSaveEntitiesKeepsFlag() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        let row: InternalProperties = ["$set": ["p1": "a"]]
        testMixpanel.trackingQueue.sync {
            testMixpanel.mixpanelPersistence.saveEntities(
                [row], type: .people, flag: PersistenceConstant.unIdentifiedFlag)
            testMixpanel.mixpanelPersistence.saveEntities([row], type: .people)
        }
        XCTAssertEqual(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count, 1,
            "the unidentified flag must survive saveEntities")
        XCTAssertEqual(
            peopleQueue(token: testMixpanel.apiToken).count, 1,
            "the default flag still saves identified rows")

        testMixpanel.delegate = self  // mixpanelWillFlush is false: no network inside reset()
        testMixpanel.reset()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).isEmpty,
            "reset drops the unidentified row")
        XCTAssertEqual(
            peopleQueue(token: testMixpanel.apiToken).count, 1, "reset keeps the identified row")
        removeDBfile(testMixpanel.apiToken)
    }

    func testLoadPeopleFillsMissingDistinctIdOnly() {
        let token = randomId()
        let testMixpanel = Mixpanel.initialize(
            token: token, trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.identify(distinctId: "current")
        waitForTrackingQueue(testMixpanel)

        // Simulate rows written by older SDK versions: identified flag but no $distinct_id.
        let persistence = MixpanelPersistence(instanceName: token)
        persistence.saveEntity(["$token": token, "$set": ["legacy": true]], type: .people)
        persistence.saveEntity(
            ["$token": token, "$distinct_id": "someone-else", "$set": ["stamped": true]], type: .people)

        let loaded = persistence.loadEntitiesInBatch(type: .people)
        XCTAssertEqual(loaded.count, 2)
        let legacy = loaded.first { ($0["$set"] as? InternalProperties)?["legacy"] != nil }
        let stamped = loaded.first { ($0["$set"] as? InternalProperties)?["stamped"] != nil }
        XCTAssertEqual(legacy?["$distinct_id"] as? String, "current", "missing id should be filled in")
        XCTAssertEqual(stamped?["$distinct_id"] as? String, "someone-else", "existing id must never be overwritten")
        removeDBfile(token)
    }

    func testIdentifyStopsWhenPeopleRowUpdatesFail() {
        let token = randomId()
        let testMixpanel = Mixpanel.initialize(
            token: token, trackAutomaticEvents: false, flushInterval: 60)
        for i in 0..<3 {
            testMixpanel.people.set(properties: ["p\(i)": i])
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertEqual(unIdentifiedPeopleQueue(token: token).count, 3)

        failPeopleUpdates(token)
        testMixpanel.identify(distinctId: "d1")
        // Before the fix this block never ran: identify re-read the same rows forever. Stop here
        // on a timeout, because anything that waits on trackingQueue would then hang the run.
        let identifyFinished = XCTestExpectation(description: "identify returned")
        testMixpanel.trackingQueue.async { identifyFinished.fulfill() }
        guard XCTWaiter().wait(for: [identifyFinished], timeout: 10) == .completed else {
            return XCTFail("identify never returned after a failed write")
        }

        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: token).isEmpty,
            "a failed write should recreate the database, as other write paths do")
        XCTAssertTrue(peopleQueue(token: token).isEmpty)

        testMixpanel.track(event: "after failure")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: token).contains { ($0["event"] as? String) == "after failure" },
            "tracking should keep working after the failed identify")
        removeDBfile(token)
    }

    func testDropUnidentifiedPeopleRecords() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        waitForAsyncTasks()
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
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
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
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
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
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.increment(property: "p1", by: 3)
        waitForTrackingQueue(testMixpanel)
        let p: InternalProperties =
            peopleQueue(token: testMixpanel.apiToken).last!["$add"] as! InternalProperties
        XCTAssertTrue(p.count == 1, "incorrect people properties: \(p)")
        XCTAssertEqual(p["p1"] as? Double, 3, "custom people property not queued")
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleDeleteUser() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.deleteUser()
        waitForTrackingQueue(testMixpanel)
        let p: InternalProperties =
            peopleQueue(token: testMixpanel.apiToken).last!["$delete"] as! InternalProperties
        XCTAssertTrue(p.isEmpty, "incorrect people properties: \(p)")
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackChargeDecimal() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.trackCharge(amount: 25.34)
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop =
            ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"]
            as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?[
            "$time"]
        XCTAssertEqual(prop, 25.34)
        XCTAssertNotNil(prop2)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackChargeZero() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        testMixpanel.people.trackCharge(amount: 0)
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop =
            ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"]
            as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?[
            "$time"]
        XCTAssertEqual(prop, 0)
        XCTAssertNotNil(prop2)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackChargeWithTime() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        let p: Properties = allPropertyTypes()
        testMixpanel.people.trackCharge(amount: 25, properties: ["$time": p["date"]!])
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop =
            ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"]
            as? Double
        let prop2 =
            ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$time"]
            as? String
        XCTAssertEqual(prop, 25)
        compareDate(dateString: prop2!, dateDate: p["date"] as! Date)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackChargeWithProperties() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.trackCharge(amount: 25, properties: ["p1": "a"])
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop =
            ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"]
            as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?[
            "p1"]
        XCTAssertEqual(prop, 25)
        XCTAssertEqual(prop2 as? String, "a")
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleTrackCharge() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.trackCharge(amount: 25)
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let prop =
            ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?["$amount"]
            as? Double
        let prop2 = ((r["$append"] as? InternalProperties)?["$transactions"] as? InternalProperties)?[
            "$time"]
        XCTAssertEqual(prop, 25)
        XCTAssertNotNil(prop2)
        removeDBfile(testMixpanel.apiToken)
    }

    func testPeopleClearCharges() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: true, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.people.clearCharges()
        waitForTrackingQueue(testMixpanel)
        let r: InternalProperties = peopleQueue(token: testMixpanel.apiToken).last!
        let transactions = (r["$set"] as? InternalProperties)?["$transactions"] as? [MixpanelType]
        XCTAssertEqual(transactions?.count, 0)
        removeDBfile(testMixpanel.apiToken)
    }
}
