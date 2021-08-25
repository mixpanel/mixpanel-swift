//
//  MixpanelDemoTests.swift
//  MixpanelDemoTests
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelDemoTests: MixpanelBaseTests {

    func test5XXResponse() {
        LSNocilla.sharedInstance().clearStubs()
        _ = stubTrack().andReturn(503)

        mixpanel.track(event: "Fake Event")
        flushAndWaitForTrackingQueue()
        // Failure count should be 3
        let waitTime =
            mixpanel.flushInstance.flushRequest.networkRequestsAllowedAfterTime - Date().timeIntervalSince1970
        print("Delta wait time is \(waitTime)")
        XCTAssert(waitTime >= 110, "Network backoff time is less than 2 minutes.")
        XCTAssert(mixpanel.flushInstance.flushRequest.networkConsecutiveFailures == 2,
                  "Network failures did not equal 2")

        XCTAssert(eventQueue(token: mixpanel.apiToken).count == 1,
                  "Removed an event from the queue that was not sent")
    }

    func testRetryAfterHTTPHeader() {
        LSNocilla.sharedInstance().clearStubs()
        _ = stubTrack().andReturn(200)?.withHeader("Retry-After", "60")

        mixpanel.track(event: "Fake Event")
        flushAndWaitForTrackingQueue()

        // Failure count should be 3
        let waitTime =
            mixpanel.flushInstance.flushRequest.networkRequestsAllowedAfterTime - Date().timeIntervalSince1970
        print("Delta wait time is \(waitTime)")
        XCTAssert(fabs(60 - waitTime) < 5, "Mixpanel did not respect 'Retry-After' HTTP header")
        XCTAssert(mixpanel.flushInstance.flushRequest.networkConsecutiveFailures == 0,
                  "Network failures did not equal 0")
    }

    func testFlushEvents() {
        stubTrack()

        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.track(event: "event \(i)")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).isEmpty,
                      "events should have been flushed")

        for i in 0..<60 {
            mixpanel.track(event: "event \(i)")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).isEmpty,
                      "events should have been flushed")
    }


    func testFlushPeople() {
        stubEngage()
        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(peopleQueue(token: mixpanel.apiToken).isEmpty, "people should have been flushed")
        for i in 0..<60 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(peopleQueue(token: mixpanel.apiToken).isEmpty, "people should have been flushed")
    }

    func testFlushGroups() {
        stubGroups()
        mixpanel.identify(distinctId: "d1")
        let groupKey = "test_key"
        let groupValue = "test_value"
        for i in 0..<50 {
            mixpanel.getGroup(groupKey: groupKey, groupID: groupValue).set(property: "p1", to: "\(i)")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(groupQueue(token: mixpanel.apiToken).isEmpty, "groups should have been flushed")
        for i in 0..<60 {
            mixpanel.getGroup(groupKey: groupKey, groupID: groupValue).set(property: "p1", to: "\(i)")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(peopleQueue(token: mixpanel.apiToken).isEmpty, "groups should have been flushed")
    }

    func testFlushNetworkFailure() {
        LSNocilla.sharedInstance().clearStubs()
        stubTrack().andFailWithError(
            NSError(domain: "com.mixpanel.sdk.testing", code: 1, userInfo: nil))
        for i in 0..<50 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        waitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 50, "50 events should be queued up")
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 50,
                      "events should still be in the queue if flush fails")
    }

    func testFlushQueueContainsCorruptedEvent() {
        stubTrack()
        mixpanel.mixpanelPersistence.saveEntity(["event": "bad event1", "properties": ["BadProp": Double.nan]], type: .events)
        mixpanel.mixpanelPersistence.saveEntity(["event": "bad event2", "properties": ["BadProp": Float.nan]], type: .events)
        mixpanel.mixpanelPersistence.saveEntity(["event": "bad event3", "properties": ["BadProp": Double.infinity]], type: .events)
        mixpanel.mixpanelPersistence.saveEntity(["event": "bad event4", "properties": ["BadProp": Float.infinity]], type: .events)

        for i in 0..<10 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 0, "good events should still be flushed")
    }
    
    func testAddEventContainsInvalidJsonObjectDoubleNaN() {
        stubTrack()
        XCTExpectAssert("unsupported property type was allowed") {
            mixpanel.track(event: "bad event", properties: ["BadProp": Double.nan])
        }
    }

    func testAddEventContainsInvalidJsonObjectFloatNaN() {
        XCTExpectAssert("unsupported property type was allowed") {
            mixpanel.track(event: "bad event", properties: ["BadProp": Float.nan])
        }
    }

    func testAddEventContainsInvalidJsonObjectDoubleInfinity() {
        XCTExpectAssert("unsupported property type was allowed") {
            mixpanel.track(event: "bad event", properties: ["BadProp": Double.infinity])
        }
    }

    func testAddEventContainsInvalidJsonObjectFloatInfinity() {
        XCTExpectAssert("unsupported property type was allowed") {
            mixpanel.track(event: "bad event", properties: ["BadProp": Float.infinity])
        }
    }

    func testAddingEventsAfterFlush() {
        stubTrack()
        for i in 0..<10 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        waitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 10, "10 events should be queued up")
        flushAndWaitForTrackingQueue()
        for i in 0..<5 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        waitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 5, "5 more events should be queued up")
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).isEmpty, "events should have been flushed")
    }


    func testIdentify() {
        stubTrack()
        stubEngage()
        for _ in 0..<2 {
            // run this twice to test reset works correctly wrt to distinct ids
            let distinctId: String = "d1"
            // try this for ODIN and nil
            #if MIXPANEL_UNIQUE_DISTINCT_ID
            XCTAssertEqual(mixpanel.distinctId,
                           mixpanel.defaultDistinctId(),
                           "mixpanel identify failed to set default distinct id")
            XCTAssertEqual(mixpanel.anonymousId,
                           mixpanel.defaultDistinctId(),
                           "mixpanel failed to set default anonymous id")
            #endif
            XCTAssertNil(mixpanel.people.distinctId,
                         "mixpanel people distinct id should default to nil")
            XCTAssertNil(mixpanel.people.distinctId,
                         "mixpanel user id should default to nil")
            mixpanel.track(event: "e1")
            waitForTrackingQueue()
            let eventsQueue = eventQueue(token: mixpanel.apiToken)
            XCTAssertTrue(eventsQueue.count == 1,
                          "events should be sent right away with default distinct id")
            #if MIXPANEL_UNIQUE_DISTINCT_ID
            XCTAssertEqual((eventsQueue.last?["properties"] as? InternalProperties)?["distinct_id"] as? String,
                           mixpanel.defaultDistinctId(),
                           "events should use default distinct id if none set")
            #endif
            XCTAssertEqual((eventsQueue.last?["properties"] as? InternalProperties)?["$lib_version"] as? String,
                           AutomaticProperties.libVersion(),
                           "events should has lib version in internal properties")
            mixpanel.people.set(property: "p1", to: "a")
            waitForTrackingQueue()
            var peopleQueue_value = peopleQueue(token: mixpanel.apiToken)
            var unidentifiedQueue = unIdentifiedPeopleQueue(token: mixpanel.apiToken)
            XCTAssertTrue(peopleQueue_value.isEmpty,
                          "people records should go to unidentified queue before identify:")
            XCTAssertTrue(unidentifiedQueue.count == 1,
                          "unidentified people records not queued")
            XCTAssertEqual(unidentifiedQueue.last?["$token"] as? String,
                           mixpanel.apiToken,
                           "incorrect project token in people record")
            let anonymousId = mixpanel.anonymousId
            mixpanel.identify(distinctId: distinctId)
            waitForTrackingQueue()
            peopleQueue_value = peopleQueue(token: mixpanel.apiToken)
            unidentifiedQueue = unIdentifiedPeopleQueue(token: mixpanel.apiToken)
            XCTAssertEqual(mixpanel.distinctId, distinctId,
                           "mixpanel identify failed to set distinct id")
            XCTAssertEqual(mixpanel.userId, distinctId,
                           "mixpanel identify failed to set user id")
            XCTAssertEqual(mixpanel.anonymousId, anonymousId,
                          "mixpanel identify shouldn't change anonymousId")
            XCTAssertEqual(mixpanel.people.distinctId, distinctId,
                           "mixpanel identify failed to set people distinct id")
            XCTAssertTrue(unidentifiedQueue.isEmpty,
                          "identify: should move records from unidentified queue")
            XCTAssertTrue(peopleQueue_value.count > 0,
                          "identify: should move records to main people queue")
            XCTAssertEqual(peopleQueue_value.last?["$token"] as? String,
                           mixpanel.apiToken, "incorrect project token in people record")
            let p: InternalProperties = peopleQueue_value.last?["$set"] as! InternalProperties
            XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
            assertDefaultPeopleProperties(p)
            peopleQueue_value = peopleQueue(token: mixpanel.apiToken)
            
            mixpanel.people.set(property: "p1", to: "a")
            waitForTrackingQueue()
            
            peopleQueue_value = peopleQueue(token: mixpanel.apiToken)
            unidentifiedQueue = unIdentifiedPeopleQueue(token: mixpanel.apiToken)
            XCTAssertEqual(peopleQueue_value.last?["$distinct_id"] as? String,
                           distinctId, "distinct id not set properly on unidentified people record")
            XCTAssertTrue(unidentifiedQueue.isEmpty,
                          "once idenitfy: is called, unidentified queue should be skipped")
            XCTAssertTrue(peopleQueue_value.count > 0 ,
                          "once identify: is called, records should go straight to main queue")
            mixpanel.track(event: "e2")
            waitForTrackingQueue()
            let newDistinctId = (eventQueue(token: mixpanel.apiToken).last?["properties"] as? InternalProperties)?["distinct_id"] as? String
            XCTAssertEqual(newDistinctId, distinctId,
                           "events should use new distinct id after identify:")
            mixpanel.reset()
            waitForTrackingQueue()
        }
    }

    func testIdentifyTrack() {
        stubTrack()
        stubEngage()

        let distinctIdBeforeIdentify: String? = mixpanel.distinctId
        let distinctId = "testIdentifyTrack"

        mixpanel.identify(distinctId: distinctId)
        mixpanel.identify(distinctId: distinctId)
        waitForTrackingQueue()
        waitForTrackingQueue()

        let e: InternalProperties = eventQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(e["event"] as? String, "$identify", "incorrect event name")
        let p: InternalProperties = e["properties"] as! InternalProperties
        XCTAssertEqual(p["distinct_id"] as? String, distinctId, "wrong distinct_id")
        XCTAssertEqual(p["$anon_distinct_id"] as? String, distinctIdBeforeIdentify, "wrong $anon_distinct_id")
    }

    func testIdentifyResetTrack() {
        stubTrack()
        stubEngage()

        let originalDistinctId: String? = mixpanel.distinctId
        let distinctId = "testIdentifyTrack"
        mixpanel.reset()
        waitForTrackingQueue()

        for i in 1...3 {
            let prevDistinctId: String? = mixpanel.distinctId
            let newDistinctId = distinctId + String(i)
            mixpanel.identify(distinctId: newDistinctId)
            waitForTrackingQueue()
            waitForTrackingQueue()

            let e: InternalProperties = eventQueue(token: mixpanel.apiToken).last!
            XCTAssertEqual(e["event"] as? String, "$identify", "incorrect event name")
            let p: InternalProperties = e["properties"] as! InternalProperties
            XCTAssertEqual(p["distinct_id"] as? String, newDistinctId, "wrong distinct_id")
            XCTAssertEqual(p["$anon_distinct_id"] as? String, prevDistinctId, "wrong $anon_distinct_id")
            XCTAssertNotEqual(prevDistinctId, originalDistinctId, "After reset, UUID will be used - never the same");
            #if MIXPANEL_UNIQUE_DISTINCT_ID
            XCTAssertEqual(prevDistinctId, originalDistinctId, "After reset, IFV will be used - always the same");
            #endif
            mixpanel.reset()
            waitForTrackingQueue()
        }
    }

    func testPersistentIdentity() {
        stubTrack()
        let anonymousId: String? = mixpanel.anonymousId
        let distinctId: String = "d1"
        let alias: String = "a1"
        mixpanel.identify(distinctId: distinctId)
        waitForTrackingQueue()
        mixpanel.createAlias(alias, distinctId: mixpanel.distinctId)
        waitForTrackingQueue()
        var mixpanelIdentity = mixpanel.mixpanelPersistence.loadIdentity()
        XCTAssertTrue(distinctId == mixpanelIdentity.distinctID && distinctId == mixpanelIdentity.peopleDistinctID && anonymousId == mixpanelIdentity.anoymousId && distinctId == mixpanelIdentity.userId && alias == mixpanelIdentity.alias)
        mixpanel.archive()
        waitForTrackingQueue()
        mixpanel.unarchive()
        waitForTrackingQueue()
        mixpanelIdentity = mixpanel.mixpanelPersistence.loadIdentity()
        XCTAssertTrue(mixpanel.distinctId == mixpanelIdentity.distinctID && mixpanel.people.distinctId == mixpanelIdentity.peopleDistinctID && mixpanel.anonymousId == mixpanelIdentity.anoymousId &&
        mixpanel.userId == mixpanelIdentity.userId && mixpanel.alias == mixpanelIdentity.alias)
        mixpanel.mixpanelPersistence.deleteMPUserDefaultsData()
        waitForTrackingQueue()
        mixpanelIdentity = mixpanel.mixpanelPersistence.loadIdentity()
        XCTAssertTrue("" == mixpanelIdentity.distinctID && nil == mixpanelIdentity.peopleDistinctID && nil == mixpanelIdentity.anoymousId && nil == mixpanelIdentity.userId && nil == mixpanelIdentity.alias)
    }

    func testHadPersistedDistinctId() {
      stubTrack()
      XCTAssertNotNil(mixpanel.anonymousId)
      XCTAssertNotNil(mixpanel.distinctId)
      let distinctId: String = "d1"
      mixpanel.anonymousId = nil
      mixpanel.userId = nil
      mixpanel.alias = nil
      mixpanel.distinctId = distinctId
      mixpanel.archive()

      XCTAssertEqual(mixpanel.distinctId, distinctId)

      let userId: String = "u1"
      mixpanel.identify(distinctId: userId)
      waitForTrackingQueue()
      XCTAssertEqual(mixpanel.anonymousId, distinctId)
      XCTAssertEqual(mixpanel.userId, userId)
      XCTAssertEqual(mixpanel.distinctId, userId)
      XCTAssertTrue(mixpanel.hadPersistedDistinctId!)
    }

    func testTrackWithDefaultProperties() {
        mixpanel.track(event: "Something Happened")
        waitForTrackingQueue()
        let e: InternalProperties = eventQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(e["event"] as? String, "Something Happened", "incorrect event name")
        let p: InternalProperties = e["properties"] as! InternalProperties
        XCTAssertNotNil(p["$app_build_number"], "$app_build_number not set")
        XCTAssertNotNil(p["$app_version_string"], "$app_version_string not set")
        XCTAssertNotNil(p["$lib_version"], "$lib_version not set")
        XCTAssertNotNil(p["$model"], "$model not set")
        XCTAssertNotNil(p["$os"], "$os not set")
        XCTAssertNotNil(p["$os_version"], "$os_version not set")
        XCTAssertNotNil(p["$screen_height"], "$screen_height not set")
        XCTAssertNotNil(p["$screen_width"], "$screen_width not set")
        XCTAssertNotNil(p["distinct_id"], "distinct_id not set")
        XCTAssertNotNil(p["time"], "time not set")
        XCTAssertEqual(p["$manufacturer"] as? String, "Apple", "incorrect $manufacturer")
        XCTAssertEqual(p["mp_lib"] as? String, "swift", "incorrect mp_lib")
        XCTAssertEqual(p["token"] as? String, mixpanel.apiToken, "incorrect token")
    }

    func testTrackWithCustomProperties() {
        let now = Date()
        let p: Properties = ["string": "yello",
                             "number": 3,
                             "date": now,
                             "$app_version": "override"]
        mixpanel.track(event: "Something Happened", properties: p)
        waitForTrackingQueue()
        let props: InternalProperties = eventQueue(token: mixpanel.apiToken).last?["properties"] as! InternalProperties
        XCTAssertEqual(props["string"] as? String, "yello")
        XCTAssertEqual(props["number"] as? Int, 3)
        let dateValue = props["date"] as! String
        compareDate(dateString: dateValue, dateDate: now)
        XCTAssertEqual(props["$app_version"] as? String, "override",
                       "reserved property override failed")
    }
    
    func testTrackWithOptionalProperties() {
        let optNil: Double? = nil
        let optDouble: Double? = 1.0
        let optArray: Array<Double?> = [nil, 1.0, 2.0]
        let optDict: Dictionary<String, Double?> = ["nil": nil, "double": 1.0]
        let nested: Dictionary<String, Any> = ["list": optArray, "dict": optDict]
        let p: Properties = ["nil": optNil,
                             "double": optDouble,
                             "list": optArray,
                             "dict": optDict,
                             "nested": nested,
                            ]
        mixpanel.track(event: "Optional Test", properties: p)
        waitForTrackingQueue()
        let props: InternalProperties = eventQueue(token: mixpanel.apiToken).last?["properties"] as! InternalProperties
        XCTAssertNil(props["nil"] as? Double)
        XCTAssertEqual(props["double"] as? Double, 1.0)
        XCTAssertEqual(props["list"] as? Array, [1.0, 2.0])
        XCTAssertEqual(props["dict"] as? Dictionary, ["nil": nil, "double": 1.0])
        let nestedProp = props["nested"] as? Dictionary<String, Any>
        XCTAssertEqual(nestedProp?["dict"] as? Dictionary, ["nil": nil, "double": 1.0])
        XCTAssertEqual(nestedProp?["list"] as? Array, [1.0, 2.0])
    }

    func testTrackWithCustomDistinctIdAndToken() {
        let p: Properties = ["token": "t1", "distinct_id": "d1"]
        mixpanel.track(event: "e1", properties: p)
        waitForTrackingQueue()
        let trackToken = (eventQueue(token: mixpanel.apiToken).last?["properties"] as? InternalProperties)?["token"] as? String
        let trackDistinctId = (eventQueue(token: mixpanel.apiToken).last?["properties"] as? InternalProperties)?["distinct_id"] as? String
        XCTAssertEqual(trackToken, "t1", "user-defined distinct id not used in track.")
        XCTAssertEqual(trackDistinctId, "d1", "user-defined distinct id not used in track.")
    }

    func testTrackWithGroups() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.trackWithGroups(event: "Something Happened", properties: [groupKey: "some other value", "p1": "value"], groups: [groupKey: groupID])
        waitForTrackingQueue()
        let e: InternalProperties = eventQueue(token: mixpanel.apiToken).last!
        XCTAssertEqual(e["event"] as? String, "Something Happened", "incorrect event name")
        let p: InternalProperties = e["properties"] as! InternalProperties
        XCTAssertNotNil(p["$app_build_number"], "$app_build_number not set")
        XCTAssertNotNil(p["$app_version_string"], "$app_version_string not set")
        XCTAssertNotNil(p["$lib_version"], "$lib_version not set")
        XCTAssertNotNil(p["$model"], "$model not set")
        XCTAssertNotNil(p["$os"], "$os not set")
        XCTAssertNotNil(p["$os_version"], "$os_version not set")
        XCTAssertNotNil(p["$screen_height"], "$screen_height not set")
        XCTAssertNotNil(p["$screen_width"], "$screen_width not set")
        XCTAssertNotNil(p["distinct_id"], "distinct_id not set")
        XCTAssertNotNil(p["time"], "time not set")
        XCTAssertEqual(p["$manufacturer"] as? String, "Apple", "incorrect $manufacturer")
        XCTAssertEqual(p["mp_lib"] as? String, "swift", "incorrect mp_lib")
        XCTAssertEqual(p["token"] as? String, mixpanel.apiToken, "incorrect token")
        XCTAssertEqual(p[groupKey] as? String, groupID, "incorrect group id")
        XCTAssertEqual(p["p1"] as? String, "value", "incorrect group value")
    }

    func testRegisterSuperProperties() {
        var p: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        mixpanel.registerSuperProperties(p)
        waitForTrackingQueue()
        XCTAssertEqual(NSDictionary(dictionary: mixpanel.currentSuperProperties()),
                       NSDictionary(dictionary: p),
                       "register super properties failed")
        p = ["p1": "b"]
        mixpanel.registerSuperProperties(p)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()["p1"] as? String, "b",
                       "register super properties failed to overwrite existing value")
        p = ["p4": "a"]
        mixpanel.registerSuperPropertiesOnce(p)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()["p4"] as? String, "a",
                       "register super properties once failed first time")
        p = ["p4": "b"]
        mixpanel.registerSuperPropertiesOnce(p)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()["p4"] as? String, "a",
                       "register super properties once failed second time")
        p = ["p4": "c"]
        mixpanel.registerSuperPropertiesOnce(p, defaultValue: "d")
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()["p4"] as? String, "a",
                       "register super properties once with default value failed when no match")
        mixpanel.registerSuperPropertiesOnce(p, defaultValue: "a")
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()["p4"] as? String, "c",
                       "register super properties once with default value failed when match")
        mixpanel.unregisterSuperProperty("a")
        waitForTrackingQueue()
        XCTAssertNil(mixpanel.currentSuperProperties()["a"],
                     "unregister super property failed")
        // unregister non-existent super property should not throw
        mixpanel.unregisterSuperProperty("a")
        mixpanel.clearSuperProperties()
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.currentSuperProperties().isEmpty,
                      "clear super properties failed")
    }

    func testInvalidPropertiesTrack() {
        let p: Properties = ["data": [Data()]]
        XCTExpectAssert("property type should not be allowed") {
            mixpanel.track(event: "e1", properties: p)
        }
    }

    func testInvalidSuperProperties() {
        let p: Properties = ["data": [Data()]]
        XCTExpectAssert("property type should not be allowed") {
            mixpanel.registerSuperProperties(p)
        }
    }

    func testInvalidSuperProperties2() {
        let p: Properties = ["data": [Data()]]
        XCTExpectAssert("property type should not be allowed") {
            mixpanel.registerSuperPropertiesOnce(p)
        }
    }

    func testInvalidSuperProperties3() {
        let p: Properties = ["data": [Data()]]
        XCTExpectAssert("property type should not be allowed") {
            mixpanel.registerSuperPropertiesOnce(p, defaultValue: "v")
        }
    }

    func testValidPropertiesTrack() {
        let p: Properties = allPropertyTypes()
        mixpanel.track(event: "e1", properties: p)
    }

    func testValidSuperProperties() {
        let p: Properties = allPropertyTypes()
        mixpanel.registerSuperProperties(p)
        mixpanel.registerSuperPropertiesOnce(p)
        mixpanel.registerSuperPropertiesOnce(p, defaultValue: "v")
    }

    func testReset() {
        stubTrack()
        stubEngage()
        mixpanel.identify(distinctId: "d1")
        mixpanel.track(event: "e1")
        let p: Properties = ["p1": "a"]
        mixpanel.registerSuperProperties(p)
        mixpanel.people.set(properties: p)
        mixpanel.archive()
        mixpanel.reset()
        waitForTrackingQueue()
        #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(mixpanel.distinctId,
                       mixpanel.defaultDistinctId(),
                       "distinct id failed to reset")
        #endif
        XCTAssertNil(mixpanel.people.distinctId, "people distinct id failed to reset")
        XCTAssertTrue(mixpanel.currentSuperProperties().isEmpty,
                      "super properties failed to reset")
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).isEmpty, "events queue failed to reset")
        XCTAssertTrue(peopleQueue(token: mixpanel.apiToken).isEmpty, "people queue failed to reset")
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        waitForTrackingQueue(testMixpanel)
        #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(testMixpanel.distinctId, mixpanel.defaultDistinctId(),
                       "distinct id failed to reset after archive")
        #endif
        XCTAssertNil(testMixpanel.people.distinctId,
                     "people distinct id failed to reset after archive")
        XCTAssertTrue(testMixpanel.currentSuperProperties().isEmpty,
                      "super properties failed to reset after archive")
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).isEmpty,
                      "events queue failed to reset after archive")
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).isEmpty,
                      "people queue failed to reset after archive")
        removeDBfile(testMixpanel.apiToken)
    }

    func testArchiveNSNumberBoolIntProperty() {
        let testToken = randomId()
        let testMixpanel = Mixpanel.initialize(token: testToken, flushInterval: 60)
        let aBoolNumber: Bool = true
        let aBoolNSNumber = NSNumber(value: aBoolNumber)

        let aIntNumber: Int = 1
        let aIntNSNumber = NSNumber(value: aIntNumber)

        testMixpanel.track(event: "e1", properties:  ["p1": aBoolNSNumber, "p2": aIntNSNumber])
        testMixpanel.archive()
        waitForTrackingQueue(testMixpanel)
        
        let testMixpanel2 = Mixpanel.initialize(token: testToken, flushInterval: 60)
        waitForTrackingQueue(testMixpanel2)
        let properties: [String: Any] = eventQueue(token: testMixpanel2.apiToken)[0]["properties"] as! [String: Any]

        XCTAssertTrue(isBoolNumber(num: properties["p1"]! as! NSNumber),
                          "The bool value should be unarchived as bool")
        XCTAssertFalse(isBoolNumber(num: properties["p2"]! as! NSNumber),
                          "The int value should not be unarchived as bool")
        removeDBfile(testToken)
    }

    private func isBoolNumber(num: NSNumber) -> Bool
    {
        let boolID = CFBooleanGetTypeID() // the type ID of CFBoolean
        let numID = CFGetTypeID(num) // the type ID of num
        return numID == boolID
    }

    func testArchive() {
        let testToken = randomId()
        let testMixpanel = Mixpanel.initialize(token: testToken, flushInterval: 60)
        #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(testMixpanel.distinctId, testMixpanel.defaultDistinctId(),
                       "default distinct id archive failed")
        #endif
        XCTAssertTrue(testMixpanel.currentSuperProperties().isEmpty,
                      "default super properties archive failed")
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).isEmpty, "default events queue archive failed")
        XCTAssertNil(testMixpanel.people.distinctId, "default people distinct id archive failed")
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).isEmpty, "default people queue archive failed")
        let p: Properties = ["p1": "a"]
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        testMixpanel.registerSuperProperties(p)
        testMixpanel.track(event: "e1")
        testMixpanel.track(event: "e2")
        testMixpanel.track(event: "e3")
        testMixpanel.track(event: "e4")
        testMixpanel.track(event: "e5")
        testMixpanel.track(event: "e6")
        testMixpanel.track(event: "e7")
        testMixpanel.track(event: "e8")
        testMixpanel.track(event: "e9")
        testMixpanel.people.set(properties: p)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.timedEvents["e2"] = 5
        testMixpanel.archive()
        let testMixpanel2 = Mixpanel.initialize(token: testToken, flushInterval: 60)
        waitForTrackingQueue(testMixpanel2)
        sleep(1)
        XCTAssertEqual(testMixpanel2.distinctId, "d1", "custom distinct archive failed")
        XCTAssertTrue(testMixpanel2.currentSuperProperties().count == 1,
                      "custom super properties archive failed")
        let eventQueueValue = eventQueue(token: testMixpanel2.apiToken)
        
        XCTAssertEqual(eventQueueValue[1]["event"] as? String, "e1",
                       "event was not successfully archived/unarchived")
        XCTAssertEqual(eventQueueValue[2]["event"] as? String, "e2",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[3]["event"] as? String, "e3",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[4]["event"] as? String, "e4",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[5]["event"] as? String, "e5",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[6]["event"] as? String, "e6",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[7]["event"] as? String, "e7",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[8]["event"] as? String, "e8",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(eventQueueValue[9]["event"] as? String, "e9",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(testMixpanel2.people.distinctId, "d1",
                       "custom people distinct id archive failed")
        XCTAssertTrue(peopleQueue(token: testMixpanel2.apiToken).count == 1, "pending people queue archive failed")
        XCTAssertEqual(testMixpanel2.timedEvents["e2"] as? Double, 5.0,
                       "timedEvents archive failed")

        let testMixpanel3 = Mixpanel.initialize(token: testToken, flushInterval: 60)
        XCTAssertEqual(testMixpanel3.distinctId, "d1", "expecting d1 as distinct id as initialised")
        XCTAssertTrue(testMixpanel3.currentSuperProperties().count == 1,
                      "default super properties expected to have 1 item")
        XCTAssertNotNil(eventQueue(token: testMixpanel3.apiToken), "default events queue is nil")
        XCTAssertTrue(eventQueue(token: testMixpanel3.apiToken).count == 10, "default events queue expecting 10 items ($identify call added)")
        XCTAssertNotNil(testMixpanel3.people.distinctId,
                        "default people distinct id from no file failed")
        XCTAssertNotNil(peopleQueue(token:testMixpanel3.apiToken), "default people queue from no file is nil")
        XCTAssertTrue(peopleQueue(token:testMixpanel3.apiToken).count == 1, "default people queue expecting 1 item")
        XCTAssertTrue(testMixpanel3.timedEvents.count == 1, "timedEvents expecting 1 item")
        removeDBfile(testToken)
    }


    func testMixpanelDelegate() {
        mixpanel.delegate = self
        mixpanel.identify(distinctId: "d1")
        mixpanel.track(event: "e1")
        mixpanel.people.set(property: "p1", to: "a")
        waitForTrackingQueue()
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 2, "delegate should have stopped flush")
        XCTAssertTrue(peopleQueue(token: mixpanel.apiToken).count == 1, "delegate should have stopped flush")
    }

    func testEventTiming() {
        mixpanel.track(event: "Something Happened")
        waitForTrackingQueue()
        var e: InternalProperties = eventQueue(token: mixpanel.apiToken).last!
        var p = e["properties"] as! InternalProperties
        XCTAssertNil(p["$duration"], "New events should not be timed.")
        mixpanel.time(event: "400 Meters")
        mixpanel.track(event: "500 Meters")
        waitForTrackingQueue()
        e = eventQueue(token: mixpanel.apiToken).last!
        p = e["properties"] as! InternalProperties
        XCTAssertNil(p["$duration"], "The exact same event name is required for timing.")
        mixpanel.track(event: "400 Meters")
        waitForTrackingQueue()
        e = eventQueue(token: mixpanel.apiToken).last!
        p = e["properties"] as! InternalProperties
        XCTAssertNotNil(p["$duration"], "This event should be timed.")
        mixpanel.track(event: "400 Meters")
        waitForTrackingQueue()
        e = eventQueue(token: mixpanel.apiToken).last!
        p = e["properties"] as! InternalProperties
        XCTAssertNil(p["$duration"],
                     "Tracking the same event should require a second call to timeEvent.")
        mixpanel.time(event: "Time Event A")
        mixpanel.time(event: "Time Event B")
        mixpanel.time(event: "Time Event C")
        waitForTrackingQueue()
        var testTimedEvents = mixpanel.mixpanelPersistence.loadTimedEvents()
        XCTAssertTrue(testTimedEvents.count == 3, "Each call to time() should add an event to timedEvents")
        XCTAssertNotNil(testTimedEvents["Time Event A"], "Keys in timedEvents should be event names")
        mixpanel.clearTimedEvent(event: "Time Event A")
        waitForTrackingQueue()
        testTimedEvents = mixpanel.mixpanelPersistence.loadTimedEvents()
        XCTAssertNil(testTimedEvents["Time Event A"], "clearTimedEvent should remove key/value pair")
        XCTAssertTrue(testTimedEvents.count == 2, "clearTimedEvent shoud remove only one key/value pair")
        mixpanel.clearTimedEvents()
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.mixpanelPersistence.loadTimedEvents().count == 0, "clearTimedEvents should remove all key/value pairs")
    }

    func testTelephonyInfoInitialized() {
        XCTAssertNotNil(MixpanelInstance.telephonyInfo, "telephonyInfo wasn't initialized")
    }

    func testReadWriteLock() {
        var array = [Int]()
        let lock = ReadWriteLock(label: "test")
        let queue = DispatchQueue(label: "concurrent", qos: .utility, attributes: .concurrent)
        for _ in 0..<10 {
            queue.async {
                lock.write {
                    for i in 0..<100 {
                        array.append(i)
                    }
                }
            }

            queue.async {
                lock.read {
                    XCTAssertTrue(array.count % 100 == 0, "supposed to happen after write")
                }
            }
        }
    }

    func testSetGroup() {
        stubTrack()
        stubEngage()
        mixpanel.identify(distinctId: "d1")
        let groupKey = "test_key"
        let groupValue = "test_value"
        mixpanel.setGroup(groupKey: groupKey, groupIDs: [groupValue])
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
        let q = peopleQueue(token: mixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(q[groupKey] as? [String], [groupValue], "group value people property not queued")
        assertDefaultPeopleProperties(q)
    }

    func testAddGroup() {
        stubTrack()
        stubEngage()
        mixpanel.identify(distinctId: "d1")
        let groupKey = "test_key"
        let groupValue = "test_value"

        mixpanel.addGroup(groupKey: groupKey, groupID: groupValue)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
        waitForTrackingQueue()
        let q = peopleQueue(token: mixpanel.apiToken).last!["$set"] as! InternalProperties
        XCTAssertEqual(q[groupKey] as? [String], [groupValue], "addGroup people update not queued")
        assertDefaultPeopleProperties(q)

        mixpanel.addGroup(groupKey: groupKey, groupID: groupValue)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
        waitForTrackingQueue()
        waitForTrackingQueue()
        let q2 = peopleQueue(token: mixpanel.apiToken).last!["$union"] as! InternalProperties
        XCTAssertEqual(q2[groupKey] as? [String], [groupValue], "addGroup people update not queued")

        let newVal = "new_group"
        mixpanel.addGroup(groupKey: groupKey, groupID: newVal)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue, newVal])
        waitForTrackingQueue()
        waitForTrackingQueue()
        let q3 = peopleQueue(token: mixpanel.apiToken).last!["$union"] as! InternalProperties
        XCTAssertEqual(q3[groupKey] as? [String], [newVal], "addGroup people update not queued")
    }

    func testRemoveGroup() {
        stubTrack()
        stubEngage()
        mixpanel.identify(distinctId: "d1")
        let groupKey = "test_key"
        let groupValue = "test_value"
        let newVal = "new_group"

        mixpanel.setGroup(groupKey: groupKey, groupIDs: [groupValue, newVal])
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue, newVal])

        mixpanel.removeGroup(groupKey: groupKey, groupID: groupValue)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [newVal])
        waitForTrackingQueue()
        let q2 = peopleQueue(token: mixpanel.apiToken).last!["$remove"] as! InternalProperties
        XCTAssertEqual(q2[groupKey] as? String, groupValue, "removeGroup people update not queued")

        mixpanel.removeGroup(groupKey: groupKey, groupID: groupValue)
        waitForTrackingQueue()
        XCTAssertNil(mixpanel.currentSuperProperties()[groupKey])
        waitForTrackingQueue()
        let q3 = peopleQueue(token: mixpanel.apiToken).last!["$unset"] as! [String]
        XCTAssertEqual(q3, [groupKey], "removeGroup people update not queued")
    }
    
    
    func testReadWriteMultiThreadShouldNotCrash() {
        let concurentQueue = DispatchQueue(label: "multithread", attributes: .concurrent)
        for n in 1...10 {
            concurentQueue.async {
                self.mixpanel.track(event: "event\(n)")
            }
            concurentQueue.async {
                self.mixpanel.flush()
            }
            concurentQueue.async {
                self.mixpanel.archive()
            }
            concurentQueue.async {
                self.mixpanel.reset()
            }
            concurentQueue.async {
                self.mixpanel.createAlias("aaa11", distinctId: self.mixpanel.distinctId)
                self.mixpanel.identify(distinctId: "test")
            }
            concurentQueue.async {
                self.mixpanel.registerSuperProperties(["Plan": "Mega"])
            }
            concurentQueue.async {
                let _ = self.mixpanel.currentSuperProperties()
            }
            concurentQueue.async {
                self.mixpanel.people.set(property: "aaa", to: "SwiftSDK Cocoapods")
                self.mixpanel.getGroup(groupKey: "test", groupID: 123).set(properties: ["test": 123])
                self.mixpanel.removeGroup(groupKey: "test", groupID: 123)
            }
            concurentQueue.async {
                self.mixpanel.track(event: "test")
                self.mixpanel.time(event: "test")
                self.mixpanel.clearTimedEvents()
            }
        }
        sleep(5)
    }
    
}
