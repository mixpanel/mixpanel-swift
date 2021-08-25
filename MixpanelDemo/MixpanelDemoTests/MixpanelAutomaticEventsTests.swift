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
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.identify(distinctId: "d1")
        waitForTrackingQueue()
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue()
        
        let event = eventQueue(token: mixpanel.apiToken).last
        let people1 = peopleQueue(token: mixpanel.apiToken)[0]["$add"] as! InternalProperties
        let people2 = peopleQueue(token: mixpanel.apiToken)[1]["$add"] as! InternalProperties
        XCTAssertEqual((people1["$ae_total_app_sessions"] as? NSNumber)?.intValue, 1, "total app sessions should be added by 1")
        XCTAssertNotNil((people2["$ae_total_app_session_length"], "should have session length in $add queue"))
        XCTAssertNotNil(event, "Should have an event")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((event?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
    }

    func testKeepAutomaticEventsIfNetworkNotAvailable() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))

        waitForTrackingQueue()
        let event = eventQueue(token: mixpanel.apiToken).last
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 1, "automatic events should be accumulated if check decide is offline(decideInstance.automaticEventsEnabled is nil)")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
    }

    func testDiscardAutomaticEventsIftrackAutomaticEventsEnabledIsFalse() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.trackAutomaticEventsEnabled = false
        MixpanelPersistence.init(token: mixpanel.apiToken).saveAutomacticEventsEnabledFlag(value: true, fromDecide: true)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 0, "automatic events should not be tracked")
    }

    func testFlushAutomaticEventsIftrackAutomaticEventsEnabledIsTrue() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.trackAutomaticEventsEnabled = true
        MixpanelPersistence.init(token: mixpanel.apiToken).saveAutomacticEventsEnabledFlag(value: false, fromDecide: true)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 1, "automatic events should be tracked")
        
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 0, "automatic events should be flushed")
    }

    
    func testDiscardAutomaticEventsIfDecideIsFalse() {
        self.mixpanel.minimumSessionDuration = 0;
        MixpanelPersistence.init(token: mixpanel.apiToken).saveAutomacticEventsEnabledFlag(value: false, fromDecide: true)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))

        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 0, "automatic events should be discarded")
    }
    
    func testFlushAutomaticEventsIfDecideIsTrue() {
        self.mixpanel.minimumSessionDuration = 0;
        MixpanelPersistence.init(token: mixpanel.apiToken).saveAutomacticEventsEnabledFlag(value: true, fromDecide: true)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        waitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 1, "automatic events should be tracked")
        
        flushAndWaitForTrackingQueue()
        XCTAssertTrue(eventQueue(token: mixpanel.apiToken).count == 0, "automatic events should be flushed")
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
