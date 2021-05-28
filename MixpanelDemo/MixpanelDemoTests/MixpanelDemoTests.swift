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

        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        flushAndWaitForNetworkQueue()
        // Failure count should be 3
        let waitTime =
            mixpanel.flushInstance.flushRequest.networkRequestsAllowedAfterTime - Date().timeIntervalSince1970
        print("Delta wait time is \(waitTime)")
        XCTAssert(waitTime >= 110, "Network backoff time is less than 2 minutes.")
        XCTAssert(mixpanel.flushInstance.flushRequest.networkConsecutiveFailures == 2,
                  "Network failures did not equal 2")
        XCTAssert(mixpanel.eventsQueue.count == 1,
                  "Removed an event from the queue that was not sent")
    }

    func testRetryAfterHTTPHeader() {
        LSNocilla.sharedInstance().clearStubs()
        _ = stubTrack().andReturn(200)?.withHeader("Retry-After", "60")

        mixpanel.track(event: "Fake Event")

        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()

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
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "events should have been flushed")

        for i in 0..<60 {
            mixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "events should have been flushed")
    }


    func testFlushPeople() {
        stubEngage()
        mixpanel.identify(distinctId: "d1")
        for i in 0..<50 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty, "people should have been flushed")
        for i in 0..<60 {
            mixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty, "people should have been flushed")
    }

    func testFlushGroups() {
        stubGroups()
        mixpanel.identify(distinctId: "d1")
        let groupKey = "test_key"
        let groupValue = "test_value"
        for i in 0..<50 {
            mixpanel.getGroup(groupKey: groupKey, groupID: groupValue).set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.groupsQueue.isEmpty, "groups should have been flushed")
        for i in 0..<60 {
            mixpanel.getGroup(groupKey: groupKey, groupID: groupValue).set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty, "groups should have been flushed")
    }

    func testFlushNetworkFailure() {
        LSNocilla.sharedInstance().clearStubs()
        stubTrack().andFailWithError(
            NSError(domain: "com.mixpanel.sdk.testing", code: 1, userInfo: nil))
        for i in 0..<50 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count == 50, "50 events should be queued up")
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count == 50,
                      "events should still be in the queue if flush fails")

    }

    func testFlushQueueContainsCorruptedEvent() {
        stubTrack()
        mixpanel.eventsQueue.append(["event": "bad event1", "properties": ["BadProp": Double.nan]])
        mixpanel.eventsQueue.append(["event": "bad event2", "properties": ["BadProp": Float.nan]])
        mixpanel.eventsQueue.append(["event": "bad event3", "properties": ["BadProp": Double.infinity]])
        mixpanel.eventsQueue.append(["event": "bad event4", "properties": ["BadProp": Float.infinity]])

        for i in 0..<10 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count == 0, "good events should still be flushed")
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
        XCTAssertTrue(mixpanel.eventsQueue.count == 10, "10 events should be queued up")
        flushAndWaitForNetworkQueue()
        for i in 0..<5 {
            mixpanel.track(event: "event \(UInt(i))")
        }
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count == 5, "5 more events should be queued up")
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty, "events should have been flushed")
    }

    func testDropEvents() {
        mixpanel.delegate = self
        var events = Queue()
        for i in 0..<5000 {
            events.append(["i": i])
        }
        mixpanel.eventsQueue = events
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count == 5000)
        for i in 0..<5 {
            mixpanel.track(event: "event", properties: ["i": 5000 + i])
        }
        waitForTrackingQueue()
        let e: InternalProperties = mixpanel.eventsQueue.last!
        XCTAssertTrue(mixpanel.eventsQueue.count == 5000)
        XCTAssertEqual((e["properties"] as? InternalProperties)?["i"] as? Int, 5004)
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
            XCTAssertTrue(mixpanel.eventsQueue.count == 1,
                          "events should be sent right away with default distinct id")
            #if MIXPANEL_UNIQUE_DISTINCT_ID
            XCTAssertEqual((mixpanel.eventsQueue.last?["properties"] as? InternalProperties)?["distinct_id"] as? String,
                           mixpanel.defaultDistinctId(),
                           "events should use default distinct id if none set")
            #endif
            XCTAssertEqual((mixpanel.eventsQueue.last?["properties"] as? InternalProperties)?["$lib_version"] as? String,
                           AutomaticProperties.libVersion(),
                           "events should has lib version in internal properties")
            mixpanel.people.set(property: "p1", to: "a")
            waitForTrackingQueue()
            XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty,
                          "people records should go to unidentified queue before identify:")
            XCTAssertTrue(mixpanel.people.unidentifiedQueue.count == 1,
                          "unidentified people records not queued")
            XCTAssertEqual(mixpanel.people.unidentifiedQueue.last?["$token"] as? String,
                           kTestToken,
                           "incorrect project token in people record")
            let anonymousId = mixpanel.anonymousId
            mixpanel.identify(distinctId: distinctId)
            waitForTrackingQueue()
            XCTAssertEqual(mixpanel.distinctId, distinctId,
                           "mixpanel identify failed to set distinct id")
            XCTAssertEqual(mixpanel.userId, distinctId,
                           "mixpanel identify failed to set user id")
            XCTAssertEqual(mixpanel.anonymousId, anonymousId,
                          "mixpanel identify shouldn't change anonymousId")
            XCTAssertEqual(mixpanel.people.distinctId, distinctId,
                           "mixpanel identify failed to set people distinct id")
            XCTAssertTrue(mixpanel.people.unidentifiedQueue.isEmpty,
                          "identify: should move records from unidentified queue")
            XCTAssertTrue(mixpanel.people.peopleQueue.count == 1,
                          "identify: should move records to main people queue")
            XCTAssertEqual(mixpanel.people.peopleQueue.last?["$token"] as? String,
                           kTestToken, "incorrect project token in people record")
            XCTAssertEqual(mixpanel.people.peopleQueue.last?["$distinct_id"] as? String,
                           distinctId, "distinct id not set properly on unidentified people record")
            let p: InternalProperties = mixpanel.people.peopleQueue.last?["$set"] as! InternalProperties
            XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
            assertDefaultPeopleProperties(p)
            mixpanel.people.set(property: "p1", to: "a")
            waitForTrackingQueue()
            XCTAssertTrue(mixpanel.people.unidentifiedQueue.isEmpty,
                          "once idenitfy: is called, unidentified queue should be skipped")
            XCTAssertTrue(mixpanel.people.peopleQueue.count == 2,
                          "once identify: is called, records should go straight to main queue")
            mixpanel.track(event: "e2")
            waitForTrackingQueue()
            let newDistinctId = (mixpanel.eventsQueue.last?["properties"] as? InternalProperties)?["distinct_id"] as? String
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

        let e: InternalProperties = mixpanel.eventsQueue.last!
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

            let e: InternalProperties = mixpanel.eventsQueue.last!
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
        var tuple = Persistence.restoreIdentity(token: mixpanel.apiToken)
        XCTAssertTrue(distinctId == tuple.0 && distinctId == tuple.1 && anonymousId == tuple.2 && distinctId == tuple.3 && alias == tuple.4)
        mixpanel.archive()
        waitForTrackingQueue()
        mixpanel.unarchive()
        waitForTrackingQueue()
        tuple = Persistence.restoreIdentity(token: mixpanel.apiToken)
        XCTAssertTrue(mixpanel.distinctId == tuple.0 && mixpanel.people.distinctId == tuple.1 && mixpanel.anonymousId == tuple.2 &&
        mixpanel.userId == tuple.3 && mixpanel.alias == tuple.4)
        Persistence.deleteMPUserDefaultsData(token: mixpanel.apiToken)
        waitForTrackingQueue()
        tuple = Persistence.restoreIdentity(token: mixpanel.apiToken)
        XCTAssertTrue("" == tuple.0 && nil == tuple.1 && nil == tuple.2 && nil == tuple.3 && nil == tuple.4)
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
        let e: InternalProperties = mixpanel.eventsQueue.last!
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
        XCTAssertEqual(p["token"] as? String, kTestToken, "incorrect token")
    }

    func testTrackWithCustomProperties() {
        let now = Date()
        let p: Properties = ["string": "yello",
                             "number": 3,
                             "date": now,
                             "$app_version": "override"]
        mixpanel.track(event: "Something Happened", properties: p)
        waitForTrackingQueue()
        let props: InternalProperties = mixpanel.eventsQueue.last?["properties"] as! InternalProperties
        XCTAssertEqual(props["string"] as? String, "yello")
        XCTAssertEqual(props["number"] as? Int, 3)
        XCTAssertEqual(props["date"] as? Date, now)
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
        let props: InternalProperties = mixpanel.eventsQueue.last?["properties"] as! InternalProperties
        XCTAssertNil(props["nil"] as? Double)
        XCTAssertEqual(props["double"] as? Double, 1.0)
        XCTAssertEqual(props["list"] as? Array, [nil, 1.0, 2.0])
        XCTAssertEqual(props["dict"] as? Dictionary, ["nil": nil, "double": 1.0])
        let nestedProp = props["nested"] as? Dictionary<String, Any>
        XCTAssertEqual(nestedProp?["dict"] as? Dictionary, ["nil": nil, "double": 1.0])
        XCTAssertEqual(nestedProp?["list"] as? Array, [nil, 1.0, 2.0])
    }

    func testTrackWithCustomDistinctIdAndToken() {
        let p: Properties = ["token": "t1", "distinct_id": "d1"]
        mixpanel.track(event: "e1", properties: p)
        waitForTrackingQueue()
        let trackToken = (mixpanel.eventsQueue.last?["properties"] as? InternalProperties)?["token"] as? String
        let trackDistinctId = (mixpanel.eventsQueue.last?["properties"] as? InternalProperties)?["distinct_id"] as? String
        XCTAssertEqual(trackToken, "t1", "user-defined distinct id not used in track.")
        XCTAssertEqual(trackDistinctId, "d1", "user-defined distinct id not used in track.")
    }
    
    func testTrackWithGroups() {
        let groupKey = "test_key"
        let groupID = "test_id"
        mixpanel.trackWithGroups(event: "Something Happened", properties: [groupKey: "some other value", "p1": "value"], groups: [groupKey: groupID])
        waitForTrackingQueue()
        let e: InternalProperties = mixpanel.eventsQueue.last!
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
        XCTAssertEqual(p["token"] as? String, kTestToken, "incorrect token")
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

    func testTrackLaunchOptions() {
        let nsJourneyId: NSNumber = 1
        let launchOptions: [UIApplication.LaunchOptionsKey: Any] = [UIApplication.LaunchOptionsKey.remoteNotification: ["mp":
            ["m": 12345, "c": 54321, "journey_id": nsJourneyId, "additional_param": "abcd"]]]
        mixpanel = Mixpanel.initialize(token: kTestToken,
                                       launchOptions: launchOptions,
                                       flushInterval: 60)
        waitForTrackingQueue()
        let e: InternalProperties = mixpanel.eventsQueue.last!
        XCTAssertEqual(e["event"] as? String, "$app_open", "incorrect event name")
        let p: InternalProperties = e["properties"] as! InternalProperties
        XCTAssertEqual(p["campaign_id"] as? Int, 54321, "campaign_id not equal")
        XCTAssertEqual(p["message_id"] as? Int, 12345, "message_id not equal")
        XCTAssertEqual(p["journey_id"] as? Int, 1, "journey_id not equal")
        XCTAssertEqual(p["additional_param"] as? String, "abcd", "additional_param not equal")
        XCTAssertEqual(p["message_type"] as? String, "push", "type does not equal inapp")
    }

    func testTrackPushNotification() {
        let nsJourneyId: NSNumber = 1
        mixpanel.trackPushNotification(["mp": ["m": 98765, "c": 56789, "journey_id": nsJourneyId, "additional_param": "abcd", "from_preview": true]])
        waitForTrackingQueue()
        let e: InternalProperties = mixpanel.eventsQueue.last!
        XCTAssertEqual(e["event"] as? String, "$campaign_received", "incorrect event name")
        let p: InternalProperties = e["properties"] as! InternalProperties
        XCTAssertEqual(p["campaign_id"] as? Int, 56789, "campaign_id not equal")
        XCTAssertEqual(p["message_id"] as? Int, 98765, "message_id not equal")
        XCTAssertEqual(p["journey_id"] as? Int, 1, "journey_id not equal")
        XCTAssertEqual(p["from_preview"] as? Bool, true, "from_preview not equal")
        XCTAssertEqual(p["additional_param"] as? String, "abcd", "additional_param not equal")
        XCTAssertEqual(p["message_type"] as? String, "push", "type does not equal inapp")
    }

    func testTrackPushNotificationMalformed() {
        mixpanel.trackPushNotification(["mp":
            ["m": 11111, "cid": 22222]])
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "Invalid push notification was incorrectly queued.")
        mixpanel.trackPushNotification(["mp": 1])
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "Invalid push notification was incorrectly queued.")
        mixpanel.trackPushNotification([:])
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "Invalid push notification was incorrectly queued.")
        mixpanel.trackPushNotification(["mp": "bad value"])
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "Invalid push notification was incorrectly queued.")
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "Invalid push notification was incorrectly queued.")
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
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty, "events queue failed to reset")
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty, "people queue failed to reset")
        mixpanel = Mixpanel.initialize(token: kTestToken, launchOptions: nil, flushInterval: 60)
        waitForTrackingQueue()
        #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(mixpanel.distinctId, mixpanel.defaultDistinctId(),
                       "distinct id failed to reset after archive")
        #endif
        XCTAssertNil(mixpanel.people.distinctId,
                     "people distinct id failed to reset after archive")
        XCTAssertTrue(mixpanel.currentSuperProperties().isEmpty,
                      "super properties failed to reset after archive")
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "events queue failed to reset after archive")
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty,
                      "people queue failed to reset after archive")
    }

    func testArchiveNSNumberBoolIntProperty() {
        let testToken = randomId()
        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        let aBoolNumber: Bool = true
        let aBoolNSNumber = NSNumber(value: aBoolNumber)
        
        let aIntNumber: Int = 1
        let aIntNSNumber = NSNumber(value: aIntNumber)
        
        mixpanel.track(event: "e1", properties:  ["p1": aBoolNSNumber, "p2": aIntNSNumber])
        mixpanel.archive()
        waitForTrackingQueue()
        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        waitForTrackingQueue()
        let properties: [String: Any] = mixpanel.eventsQueue[0]["properties"] as! [String: Any]
        
        XCTAssertTrue(isBoolNumber(num: properties["p1"]! as! NSNumber),
                          "The bool value should be unarchived as bool")
        XCTAssertFalse(isBoolNumber(num: properties["p2"]! as! NSNumber),
                          "The int value should not be unarchived as bool")
    }
    
    private func isBoolNumber(num: NSNumber) -> Bool
    {
        let boolID = CFBooleanGetTypeID() // the type ID of CFBoolean
        let numID = CFGetTypeID(num) // the type ID of num
        return numID == boolID
    }

    func testArchive() {
        let testToken = randomId()
        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(mixpanel.distinctId, mixpanel.defaultDistinctId(),
                       "default distinct id archive failed")
        #endif
        XCTAssertTrue(mixpanel.currentSuperProperties().isEmpty,
                      "default super properties archive failed")
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty, "default events queue archive failed")
        XCTAssertNil(mixpanel.people.distinctId, "default people distinct id archive failed")
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty, "default people queue archive failed")
        let p: Properties = ["p1": "a"]
        mixpanel.identify(distinctId: "d1")
        mixpanel.registerSuperProperties(p)
        sleep(2)
        mixpanel.track(event: "e1")
        mixpanel.track(event: "e3")
        mixpanel.track(event: "e4")
        mixpanel.track(event: "e5")
        mixpanel.track(event: "e6")
        mixpanel.track(event: "e7")
        mixpanel.track(event: "e8")
        mixpanel.track(event: "e9")
        mixpanel.track(event: "e10")
        mixpanel.people.set(properties: p)
        mixpanel.timedEvents["e2"] = 5
        mixpanel.archive()
        waitForTrackingQueue()
        
        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        waitForTrackingQueue()
        XCTAssertEqual(mixpanel.distinctId, "d1", "custom distinct archive failed")
        XCTAssertTrue(mixpanel.currentSuperProperties().count == 1,
                      "custom super properties archive failed")
        XCTAssertEqual(mixpanel.eventsQueue[1]["event"] as? String, "e1",
                       "event was not successfully archived/unarchived")
        XCTAssertEqual(mixpanel.eventsQueue[2]["event"] as? String, "e3",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[3]["event"] as? String, "e4",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[4]["event"] as? String, "e5",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[5]["event"] as? String, "e6",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[6]["event"] as? String, "e7",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[7]["event"] as? String, "e8",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[8]["event"] as? String, "e9",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.eventsQueue[9]["event"] as? String, "e10",
                       "event was not successfully archived/unarchived or order is incorrect")
        XCTAssertEqual(mixpanel.people.distinctId, "d1",
                       "custom people distinct id archive failed")
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 1, "pending people queue archive failed")
        XCTAssertEqual(mixpanel.timedEvents["e2"] as? Double, 5.0,
                       "timedEvents archive failed")
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(
            atPath: Persistence.filePathWithType(.events, token: testToken)!),
                      "events archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: Persistence.filePathWithType(.people, token: testToken)!),
                      "people archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: Persistence.filePathWithType(.properties, token: testToken)!),
                      "properties archive file not removed")
        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        XCTAssertEqual(mixpanel.distinctId, "d1", "expecting d1 as distinct id as initialised")
        XCTAssertTrue(mixpanel.currentSuperProperties().count == 1,
                      "default super properties expected to have 1 item")
        XCTAssertNotNil(mixpanel.eventsQueue, "default events queue from no file is nil")
        XCTAssertTrue(mixpanel.eventsQueue.count == 10, "default events queue expecting 10 items ($identify call added)")
        XCTAssertNotNil(mixpanel.people.distinctId,
                        "default people distinct id from no file failed")
        XCTAssertNotNil(mixpanel.people.peopleQueue, "default people queue from no file is nil")
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 1, "default people queue expecting 1 item")
        XCTAssertTrue(mixpanel.timedEvents.count == 1, "timedEvents expecting 1 item")
        // corrupt file
        let garbage = "garbage".data(using: String.Encoding.utf8)!
        do {
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.events, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.people, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.properties, token: testToken)!),
                              options: [])
        } catch {
            print("couldn't write data")
        }
        XCTAssertTrue(fileManager.fileExists(
            atPath: Persistence.filePathWithType(.events, token: testToken)!),
                      "events archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: Persistence.filePathWithType(.people, token: testToken)!),
                      "people archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: Persistence.filePathWithType(.properties, token: testToken)!),
                      "properties archive file not removed")
        Persistence.deleteMPUserDefaultsData(token: testToken)
        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        waitForTrackingQueue()
        #if MIXPANEL_UNIQUE_DISTINCT_ID
        XCTAssertEqual(mixpanel.distinctId, mixpanel.defaultDistinctId(),
                       "default distinct id from garbage failed")
        #endif
        XCTAssertTrue(mixpanel.currentSuperProperties().isEmpty,
                      "default super properties from garbage failed")
        XCTAssertNotNil(mixpanel.eventsQueue, "default events queue from garbage is nil")
        XCTAssertTrue(mixpanel.eventsQueue.isEmpty,
                      "default events queue from garbage not empty")
        XCTAssertNil(mixpanel.people.distinctId,
                     "default people distinct id from garbage failed")
        XCTAssertNotNil(mixpanel.people.peopleQueue,
                        "default people queue from garbage is nil")
        XCTAssertTrue(mixpanel.people.peopleQueue.isEmpty,
                      "default people queue from garbage not empty")
        XCTAssertTrue(mixpanel.timedEvents.isEmpty,
                      "timedEvents is not empty")
    }

    func testUnarchiveInconsistentData() {
        // corrupt file
        let fileManager = FileManager.default
        let testToken = randomId()
        // Prior 2.1.7 we used to share every class between main target and extension target(appex). For serialization, this will cause problem.
        // Because if the archive is triggered in extension, the class object will be saved as [Target Name].[Class name] for the key. Since in later version,
        // we removed extension target. If the archive happened in 2.1.6, and unarchive happened in 2.4.4 (this is the case for upgrading the sdk), it will trigger a crash
        // (throw NSException) because when try to map the key [Class name] to [Target Name].[Class name] and [Target Name].[Class name] no longer exists.
        // The below line is to simulate this situation. Foo <--> Extension.Foo, Extension.Foo doesn't exist. We should catch the NSException and reset the file instead of
        // crash the app
        let data = try! Data(contentsOf: Bundle(for: type(of: self)).url(forResource: "test_variant", withExtension: "json")!)
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        let variant = Variant(JSONObject: object as? [String: Any])
        NSKeyedArchiver.setClassName("Extension.Variant", for: Variant.self)
        NSKeyedArchiver.archiveRootObject(variant!, toFile: Persistence.filePathWithType(.events, token: testToken)!)
        NSKeyedArchiver.archiveRootObject(variant!, toFile: Persistence.filePathWithType(.people, token: testToken)!)
        NSKeyedArchiver.archiveRootObject(variant!, toFile: Persistence.filePathWithType(.properties, token: testToken)!)
        NSKeyedArchiver.archiveRootObject(variant!, toFile: Persistence.filePathWithType(.codelessBindings, token: testToken)!)
        NSKeyedArchiver.archiveRootObject(variant!, toFile: Persistence.filePathWithType(.variants, token: testToken)!)
        NSKeyedArchiver.archiveRootObject(variant!, toFile: Persistence.filePathWithType(.optOutStatus, token: testToken)!)

        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        waitForTrackingQueue()
       // waitForArchive()
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.events, token: testToken)!),
                      "events archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.people, token: testToken)!),
                      "people archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.properties, token: testToken)!),
                      "properties archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.codelessBindings, token: testToken)!),
                      "properties archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.variants, token: testToken)!),
                      "properties archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.optOutStatus, token: testToken)!),
                      "properties archive file not removed")
    }

    func testUnarchiveCorruptedData() {
        // corrupt file
        let fileManager = FileManager.default
        let garbage = "garbage".data(using: String.Encoding.utf8)!
        let testToken = randomId()

        do {
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.events, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.people, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.properties, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.codelessBindings, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.variants, token: testToken)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: Persistence.filePathWithType(.optOutStatus, token: testToken)!),
                              options: [])
        } catch {
            print("couldn't write data")
        }

        mixpanel = Mixpanel.initialize(token: testToken, launchOptions: nil, flushInterval: 60)
        waitForTrackingQueue()
        
        
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.events, token: testToken)!),
                      "events archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.people, token: testToken)!),
                      "people archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.properties, token: testToken)!),
                      "properties archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.codelessBindings, token: testToken)!),
                      "properties archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.variants, token: testToken)!),
                      "properties archive file not removed")
        XCTAssertTrue(!fileManager.fileExists(
            atPath: Persistence.filePathWithType(.optOutStatus, token: testToken)!),
                      "properties archive file not removed")
        waitForTrackingQueue()
    }

    func testMixpanelDelegate() {
        mixpanel.delegate = self
        mixpanel.identify(distinctId: "d1")
        mixpanel.track(event: "e1")
        mixpanel.people.set(property: "p1", to: "a")
        waitForTrackingQueue()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(mixpanel.eventsQueue.count == 2, "delegate should have stopped flush")
        XCTAssertTrue(mixpanel.people.peopleQueue.count == 1, "delegate should have stopped flush")
    }

    func testEventTiming() {
        mixpanel.track(event: "Something Happened")
        waitForTrackingQueue()
        var e: InternalProperties = mixpanel.eventsQueue.last!
        var p = e["properties"] as! InternalProperties
        XCTAssertNil(p["$duration"], "New events should not be timed.")
        mixpanel.time(event: "400 Meters")
        mixpanel.track(event: "500 Meters")
        waitForTrackingQueue()
        e = mixpanel.eventsQueue.last!
        p = e["properties"] as! InternalProperties
        XCTAssertNil(p["$duration"], "The exact same event name is required for timing.")
        mixpanel.track(event: "400 Meters")
        waitForTrackingQueue()
        e = mixpanel.eventsQueue.last!
        p = e["properties"] as! InternalProperties
        XCTAssertNotNil(p["$duration"], "This event should be timed.")
        mixpanel.track(event: "400 Meters")
        waitForTrackingQueue()
        e = mixpanel.eventsQueue.last!
        p = e["properties"] as! InternalProperties
        XCTAssertNil(p["$duration"],
                     "Tracking the same event should require a second call to timeEvent.")
        mixpanel.time(event: "Time Event A")
        mixpanel.time(event: "Time Event B")
        mixpanel.time(event: "Time Event C")
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.timedEvents.count == 3, "Each call to time() should add an event to timedEvents")
        XCTAssertNotNil(mixpanel.timedEvents["Time Event A"], "Keys in timedEvents should be event names")
        mixpanel.clearTimedEvent(event: "Time Event A")
        waitForTrackingQueue()
        XCTAssertNil(mixpanel.timedEvents["Time Event A"], "clearTimedEvent should remove key/value pair")
        XCTAssertTrue(mixpanel.timedEvents.count == 2, "clearTimedEvent shoud remove only one key/value pair")
        mixpanel.clearTimedEvents()
        waitForTrackingQueue()
        XCTAssertTrue(mixpanel.timedEvents.count == 0, "clearTimedEvents should remove all key/value pairs")
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
        let q = mixpanel.people.peopleQueue.last!["$set"] as! InternalProperties
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
        waitForMixpanelQueues()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
        waitForMixpanelQueues()
        let q = mixpanel.people.peopleQueue.last!["$set"] as! InternalProperties
        XCTAssertEqual(q[groupKey] as? [String], [groupValue], "addGroup people update not queued")
        assertDefaultPeopleProperties(q)
        
        mixpanel.addGroup(groupKey: groupKey, groupID: groupValue)
        waitForMixpanelQueues()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue])
        waitForMixpanelQueues()
        let q2 = mixpanel.people.peopleQueue.last!["$union"] as! InternalProperties
        XCTAssertEqual(q2[groupKey] as? [String], [groupValue], "addGroup people update not queued")

        let newVal = "new_group"
        mixpanel.addGroup(groupKey: groupKey, groupID: newVal)
        waitForMixpanelQueues()
        XCTAssertEqual(mixpanel.currentSuperProperties()[groupKey] as? [String], [groupValue, newVal])
        waitForMixpanelQueues()
        let q3 = mixpanel.people.peopleQueue.last!["$union"] as! InternalProperties
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
        let q2 = mixpanel.people.peopleQueue.last!["$remove"] as! InternalProperties
        XCTAssertEqual(q2[groupKey] as? String, groupValue, "removeGroup people update not queued")
        
        mixpanel.removeGroup(groupKey: groupKey, groupID: groupValue)
        waitForTrackingQueue()
        XCTAssertNil(mixpanel.currentSuperProperties()[groupKey])
        waitForTrackingQueue()
        let q3 = mixpanel.people.peopleQueue.last!["$unset"] as! [String]
        XCTAssertEqual(q3, [groupKey], "removeGroup people update not queued")
    }
}
