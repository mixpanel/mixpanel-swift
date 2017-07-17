//
//  MixpanelNotificationTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 8/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelNotificationTests: MixpanelBaseTests {

    var buttons = [[String: Any]]()
    var notificationDict = [String: Any]()

    override func setUp() {
        super.setUp()
        buttons.append(["text": "Done",
                        "text_color": UInt(34567),
                        "bg_color": UInt(0),
                        "border_color": UInt(34567),
                        "cta_url": "maps://"])
        buttons.append(["text": "Cancel",
                        "text_color": UInt(23456),
                        "bg_color": UInt(34567),
                        "border_color": UInt(34567),
                        "cta_url": "maps://"])
        notificationDict = ["id": 3,
                            "message_id": 1,
                            "title": "title",
                            "title_color": UInt(12345),
                            "type": "takeover",
                            "body": "body",
                            "body_color": UInt(12345),
                            "image_url": "https://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png",
                            "bg_color": UInt(23456),
                            "close_color": UInt(34567),
                            "buttons": buttons,
                            "extras": [
                                "image_fade": false
            ]] as [String : Any]
    }

    func testMalformedImageURL() {
        var notificationDict = self.notificationDict
        notificationDict["image_url"] = "1466606494290.684919.uwp5.png"
        let notification = TakeoverNotification(JSONObject: notificationDict)
        XCTAssertEqual(notification?.imageURL.absoluteString, "1466606494290.684919.uwp5@2x.png")
    }

    func testParseNotification() {
        // valid
        XCTAssertNotNil(TakeoverNotification(JSONObject: notificationDict))
        // nil
        XCTAssertNil(TakeoverNotification(JSONObject: nil))
        // empty
        XCTAssertNil(TakeoverNotification(JSONObject: [:]))
        // garbage keys
        let testingInApp = TakeoverNotification(JSONObject: ["gar": "bage"])
        XCTAssertNil(testingInApp)
        var testDict: [String: Any]!
        // invalid id
        testDict = notificationDict
        testDict["id"] = false
        XCTAssertNil(TakeoverNotification(JSONObject: testDict))
        // invalid cta
        testDict = notificationDict
        testDict["buttons"] = [[
            "text": false,
            "text_color": UInt(34567),
            "bg_color": UInt(0),
            "border_color": UInt(34567),
            "cta_url": "maps://"
        ]]
        XCTAssertNil(TakeoverNotification(JSONObject: testDict))
        // invalid image_urls
        testDict = notificationDict
        testDict["image_url"] = false
        XCTAssertNil(TakeoverNotification(JSONObject: testDict))
        // invalid image_urls item
        testDict = notificationDict
        testDict["image_url"] = [false]
        XCTAssertNil(TakeoverNotification(JSONObject: testDict))
        // an image with a space in the URL should be % encoded
        testDict = notificationDict
        testDict["image_url"] = "https://test.com/animagewithaspace init.jpg"
        XCTAssertNotNil(TakeoverNotification(JSONObject: testDict))
        // invalid color
        testDict = notificationDict
        testDict["bg_color"] = false
        XCTAssertNil(TakeoverNotification(JSONObject: testDict))
    }

    func testNoDoubleShowNotification() {
        LSNocilla.sharedInstance().stop()
        let numberOfWindows = UIApplication.shared.windows.count
        let notif = TakeoverNotification(JSONObject: notificationDict)
        mixpanel.decideInstance.notificationsInstance.showNotification(notif!)
        mixpanel.decideInstance.notificationsInstance.showNotification(notif!)
        //wait for notifs to be shown from main queue
        waitForAsyncTasks()
        XCTAssertTrue(UIApplication.shared.windows.count == numberOfWindows + 1, "Notification was not presented")
        XCTAssertTrue(mixpanel.eventsQueue.count == 1, "should only show same notification once (and track 1 notif shown event)")
        XCTAssertEqual(mixpanel.eventsQueue.last?["event"] as? String, "$campaign_delivery", "last event should be campaign delivery")
        let expectation = self.expectation(description: "notification closed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.mixpanel.decideInstance.notificationsInstance.currentlyShowingNotification = nil
            var currentInApp: BaseNotificationViewController? = nil
            for window in UIApplication.shared.windows {
                if window.rootViewController is BaseNotificationViewController {
                    currentInApp = window.rootViewController as? BaseNotificationViewController
                    break
                }
            }
            if let currentInAppVC = currentInApp {
                currentInAppVC.hide(animated: true, completion: {
                    expectation.fulfill()
                })
            } else {
                XCTAssertTrue(false, "Couldn't find InApp Notification to dismiss")
            }
        }
        waitForExpectations(timeout: mixpanel.miniNotificationPresentationTime * 2, handler: nil)
    }

    func isNotificationShowing() -> BaseNotificationViewController? {
        var latestVC: BaseNotificationViewController? = nil
        for window in UIApplication.shared.windows {
            if window.rootViewController is BaseNotificationViewController {
                latestVC = window.rootViewController as? BaseNotificationViewController
            }
        }
        return latestVC
    }

}
