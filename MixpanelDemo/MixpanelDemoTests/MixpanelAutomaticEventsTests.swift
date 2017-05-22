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
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        self.waitForSerialQueue()
        let event = self.mixpanel.eventsQueue.last
        XCTAssertNotNil(event, "Should have an event")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((event?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
    }

    func testUpdated() {
        let defaults = UserDefaults(suiteName: "Mixpanel")
        let infoDict = Bundle.main.infoDictionary
        let appVersionValue = infoDict?["CFBundleShortVersionString"]
        let savedVersionValue = defaults?.string(forKey: "MPAppVersion")
        XCTAssertEqual(appVersionValue as? String, savedVersionValue, "Saved version and current version need to be the same")
    }

    func testMultipleInstances() {
        let mp = Mixpanel.initialize(token: "abc")
        mp.minimumSessionDuration = 0;
        self.mixpanel.minimumSessionDuration = 0;
        self.mixpanel.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        mp.automaticEvents.perform(#selector(AutomaticEvents.appWillResignActive(_:)),
                                              with: Notification(name: Notification.Name(rawValue: "test")))
        self.waitForSerialQueue()
        mp.serialQueue.sync() { }
        let event = self.mixpanel.eventsQueue.last
        XCTAssertNotNil(event, "Should have an event")
        XCTAssertEqual(event?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((event?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")
        let otherEvent = mp.eventsQueue.last
        XCTAssertEqual(otherEvent?["event"] as? String, "$ae_session", "should be app session event")
        XCTAssertNotNil((otherEvent?["properties"] as? [String: Any])?["$ae_session_length"], "should have session length")    }
}
