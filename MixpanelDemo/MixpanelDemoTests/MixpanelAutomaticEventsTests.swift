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

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testSession() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.identify(distinctId: "d1")
        sleep(1)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        self.waitForMixpanelQueues()
        let event = self.mixpanel.eventsQueue.last
        let people1 = self.mixpanel.people.peopleQueue[0]["$add"] as! InternalProperties
        let people2 = self.mixpanel.people.peopleQueue[1]["$add"] as! InternalProperties
        XCTAssertEqual(people1["$ae_total_app_sessions"] as? Double, 1, "total app sessions should be added by 1")
        XCTAssertNotNil((people2["$ae_total_app_session_length"], "should have session length in $add queue"))
        XCTAssertNotNil(event, "Should have an event")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((event?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
    }

    func testKeepAutomaticEventsIfNetworkNotAvailable() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.decideInstance.automaticEventsEnabled = nil
        self.mixpanel.identify(distinctId: "d1")
        sleep(1)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        
        self.waitForMixpanelQueues()

        flushAndWaitForNetworkQueue()
        let event = self.mixpanel.eventsQueue.last
        XCTAssertTrue(self.mixpanel.eventsQueue.count > 0, "automatic events should be accumulated if check decide is offline(decideInstance.automaticEventsEnabled is nil)")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
    }
    
    func testDiscardAutomaticEventsIftrackAutomaticEventsEnabledIsFalse() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.trackAutomaticEventsEnabled = false
        self.mixpanel.decideInstance.automaticEventsEnabled = nil
        self.mixpanel.identify(distinctId: "d1")
        sleep(1)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        
        self.waitForMixpanelQueues()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, "automatic events should be discarded")
    }
    
    func testFlushAutomaticEventsIftrackAutomaticEventsEnabledIsTrue() {
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.trackAutomaticEventsEnabled = false
        self.mixpanel.decideInstance.automaticEventsEnabled = nil
        self.mixpanel.identify(distinctId: "d1")
        sleep(1)
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        
        self.waitForMixpanelQueues()
        flushAndWaitForNetworkQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, "automatic events should be flushed")
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
        
        let mp = Mixpanel.initialize(token: "abc")
        mp.reset()
        mp.minimumSessionDuration = 0;
        let mp2 = Mixpanel.initialize(token: "xyz")
        mp2.reset()
        mp2.minimumSessionDuration = 0;
        
        mp.automaticEvents.perform(#selector(AutomaticEvents.appDidBecomeActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp2.automaticEvents.perform(#selector(AutomaticEvents.appDidBecomeActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp.trackingQueue.sync { }
        mp2.trackingQueue.sync { }
        
        XCTAssertEqual(mp.eventsQueue.count, 1, "there should be only 1 event")
        let appOpenEvent = mp.eventsQueue.last
        XCTAssertEqual(appOpenEvent?["event"] as? String, "$ae_first_open", "should be first app open event")
        
        XCTAssertEqual(mp2.eventsQueue.count, 1, "there should be only 1 event")
        let otherAppOpenEvent = mp2.eventsQueue.last
        XCTAssertEqual(otherAppOpenEvent?["event"] as? String, "$ae_first_open", "should be first app open event")
        
        mp.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp2.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp.trackingQueue.sync { }
        mp2.trackingQueue.sync { }
        let appSessionEvent = mp.eventsQueue.last
        XCTAssertNotNil(appSessionEvent, "Should have an event")
        XCTAssertEqual(appSessionEvent?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((appSessionEvent?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
        let otherAppSessionEvent = mp2.eventsQueue.last
        XCTAssertEqual(otherAppSessionEvent?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((otherAppSessionEvent?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
    }
}
