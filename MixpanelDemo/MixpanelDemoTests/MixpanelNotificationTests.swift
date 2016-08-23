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

    func testMalformedImageURL() {
        let info: Properties = ["id": 3,
                                "message_id": 1,
                                "title": "title",
                                "type": "takeover",
                                "style": "dark",
                                "body": "body",
                                "cta": "cta",
                                "cta_url": "maps://",
                                "image_url": "1466606494290.684919.uwp5.png"]
        let notification = InAppNotification(JSONObject: info)
        XCTAssertEqual(notification?.imageURL.absoluteString, "1466606494290.684919.uwp5@2x.png")
    }

    func testParseNotification() {
        // invalid bad title
        let invalid: Properties = ["id": 3,
                                   "title": 5,
                                   "type": "takeover",
                                   "style": "dark",
                                   "body": "Hi!",
                                   "cta_url": "blah blah blah",
                                   "cta": NSNull(),
                                   "image_url": []]
        XCTAssertNil(InAppNotification(JSONObject: invalid))
        // valid
        let notifDict: Properties = ["id": 3,
                                     "message_id": 1,
                                     "title": "title",
                                     "type": "takeover",
                                     "style": "dark",
                                     "body": "body",
                                     "cta": "cta",
                                     "cta_url": "maps://",
                                     "image_url": "http://mixpanel.com/coolimage.png"]
        XCTAssertNotNil(InAppNotification(JSONObject: notifDict))
        // nil
        XCTAssertNil(InAppNotification(JSONObject: nil))
        // empty
        XCTAssertNil(InAppNotification(JSONObject: [:]))
        // garbage keys
        let testingInApp = InAppNotification(JSONObject: ["gar": "bage"])
        XCTAssertNil(testingInApp)
        var testDict: [String: Any]!
        // invalid id
        testDict = notifDict
        testDict["id"] = false
        XCTAssertNil(InAppNotification(JSONObject: testDict))
        // invalid title
        testDict = notifDict
        testDict["title"] = false
        XCTAssertNil(InAppNotification(JSONObject: testDict))
        // invalid body
        testDict = notifDict
        testDict["body"] = false
        XCTAssertNil(InAppNotification(JSONObject: testDict))
        // invalid cta
        testDict = notifDict
        testDict["cta"] = false
        XCTAssertNil(InAppNotification(JSONObject: testDict))
        // invalid image_urls
        testDict = notifDict
        testDict["image_url"] = false
        XCTAssertNil(InAppNotification(JSONObject: testDict))
        // invalid image_urls item
        testDict = notifDict
        testDict["image_url"] = [false]
        XCTAssertNil(InAppNotification(JSONObject: testDict))
        // an image with a space in the URL should be % encoded
        testDict = notifDict
        testDict["image_url"] = "https://test.com/animagewithaspace init.jpg"
        XCTAssertNotNil(InAppNotification(JSONObject: testDict))
    }

    func testNoDoubleShowNotification() {
        LSNocilla.sharedInstance().stop()
        let notifDict: Properties = ["id": 3,
                                     "message_id": 1,
                                     "title": "title",
                                     "type": "takeover",
                                     "style": "light",
                                     "body": "body",
                                     "cta": "cta",
                                     "cta_url": "maps://",
                                     "image_url": "https://cdn.mxpnl.com/site_media/images/engage/inapp_messages/mini/icon_coin.png"]
        let notif = InAppNotification(JSONObject: notifDict)
        mixpanel.decideInstance.notificationsInstance.showNotification(notif!)
        mixpanel.decideInstance.notificationsInstance.showNotification(notif!)
        //wait for notifs to be shown from main queue
        waitForAsyncTasks()
        XCTAssertTrue(UIApplication.shared.windows.count == 2, "Notification was not presented")
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
