//
//  MixpanelAutomaticEventsTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 5/12/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelAutomaticEventsTests: MixpanelBaseTests {

    func testSession() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.minimumSessionDuration = 0;
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        testMixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue(testMixpanel)
        
        let event = eventQueue(token: testMixpanel.apiToken).last
        let people1 = peopleQueue(token: testMixpanel.apiToken)[0]["$add"] as! InternalProperties
        let people2 = peopleQueue(token: testMixpanel.apiToken)[1]["$add"] as! InternalProperties
        XCTAssertEqual((people1["$ae_total_app_sessions"] as? NSNumber)?.intValue, 1, "total app sessions should be added by 1")
        XCTAssertNotNil((people2["$ae_total_app_session_length"], "should have session length in $add queue"))
        XCTAssertNotNil(event, "Should have an event")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((event?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
        removeDBfile(testMixpanel.apiToken)
    }

    func testKeepAutomaticEventsIfNetworkNotAvailable() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.minimumSessionDuration = 0;
        testMixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))

        waitForTrackingQueue(testMixpanel)
        let event = eventQueue(token: testMixpanel.apiToken).last
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "automatic events should be accumulated if check decide is offline(decideInstance.automaticEventsEnabled is nil)")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
        removeDBfile(testMixpanel.apiToken)
    }

    func testDiscardAutomaticEventsIftrackAutomaticEventsEnabledIsFalse() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.minimumSessionDuration = 0;
        testMixpanel.trackAutomaticEventsEnabled = false
        MixpanelPersistence.saveAutomacticEventsEnabledFlag(value: true, fromDecide: true, apiToken: testMixpanel.apiToken)
        testMixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 0, "automatic events should not be tracked")
        removeDBfile(testMixpanel.apiToken)
    }

    func testFlushAutomaticEventsIftrackAutomaticEventsEnabledIsTrue() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.minimumSessionDuration = 0;
        testMixpanel.trackAutomaticEventsEnabled = true
        MixpanelPersistence.saveAutomacticEventsEnabledFlag(value: false, fromDecide: true, apiToken: testMixpanel.apiToken)
        testMixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "automatic events should be tracked")
        
        flushAndWaitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 0, "automatic events should be flushed")
        removeDBfile(testMixpanel.apiToken)
    }

    
    func testDiscardAutomaticEventsIfDecideIsFalse() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.minimumSessionDuration = 0;
        MixpanelPersistence.saveAutomacticEventsEnabledFlag(value: false, fromDecide: true, apiToken: testMixpanel.apiToken)
        testMixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))

        flushAndWaitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 0, "automatic events should be discarded")
        removeDBfile(testMixpanel.apiToken)
    }
    
    func testFlushAutomaticEventsIfDecideIsTrue() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), flushInterval: 60)
        testMixpanel.minimumSessionDuration = 0;
        MixpanelPersistence.saveAutomacticEventsEnabledFlag(value: true, fromDecide: true, apiToken: testMixpanel.apiToken)
        testMixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "automatic events should be tracked")
        
        flushAndWaitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 0, "automatic events should be flushed")
        removeDBfile(testMixpanel.apiToken)
    }

    func testUpdated() {
        let defaults = UserDefaults(suiteName: "Mixpanel")
        let infoDict = Bundle.main.infoDictionary
        let appVersionValue = infoDict?["CFBundleShortVersionString"]
        let savedVersionValue = defaults?.string(forKey: "MPAppVersion")
        XCTAssertEqual(appVersionValue as? String, savedVersionValue, "Saved version and current version need to be the same")
    }

    func testMultipleInstances() {
        // remove UserDefaults key and archive files to simulate first app open state
        let defaults = UserDefaults(suiteName: "Mixpanel")
        defaults?.removeObject(forKey: "MPFirstOpen")
        do {
            let url = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if fileURL.absoluteString.contains("mixpanel-") {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        } catch {
            XCTFail()
        }

        let mp = Mixpanel.initialize(token: randomId())
        mp.reset()
        mp.minimumSessionDuration = 0;
        let mp2 = Mixpanel.initialize(token: randomId())
        mp2.reset()
        mp2.minimumSessionDuration = 0;

        mp.automaticEvents.perform(#selector(AutomaticEvents.appDidBecomeActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp2.automaticEvents.perform(#selector(AutomaticEvents.appDidBecomeActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp.trackingQueue.sync { }
        mp2.trackingQueue.sync { }

        XCTAssertEqual(eventQueue(token: mp.apiToken).count, 1, "there should be only 1 event")
        let appOpenEvent = eventQueue(token: mp.apiToken).last
        XCTAssertEqual(appOpenEvent?["event"] as? String, "$ae_first_open", "should be first app open event")

        XCTAssertEqual(eventQueue(token: mp2.apiToken).count, 1, "there should be only 1 event")
        let otherAppOpenEvent = eventQueue(token: mp2.apiToken).last
        XCTAssertEqual(otherAppOpenEvent?["event"] as? String, "$ae_first_open", "should be first app open event")

        mp.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp2.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp.trackingQueue.sync { }
        mp2.trackingQueue.sync { }
        let appSessionEvent = eventQueue(token: mp.apiToken).last
        XCTAssertNotNil(appSessionEvent, "Should have an event")
        XCTAssertEqual(appSessionEvent?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((appSessionEvent?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
        let otherAppSessionEvent = eventQueue(token: mp2.apiToken).last
        XCTAssertEqual(otherAppSessionEvent?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((otherAppSessionEvent?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
        removeDBfile(mp.apiToken)
        removeDBfile(mp2.apiToken)
    }
}
