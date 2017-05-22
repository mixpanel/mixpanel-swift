//
//  MixpanelBaseTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelBaseTests: XCTestCase, MixpanelDelegate {
    var mixpanel: MixpanelInstance!
    var mixpanelWillFlush: Bool!
    static var requestCount = 0

    override func setUp() {
        NSLog("starting test setup...")
        super.setUp()

        LSNocilla.sharedInstance().start()
        mixpanelWillFlush = false
        mixpanel = Mixpanel.initialize(token: kTestToken, launchOptions: nil, flushInterval: 0)
        NSLog("finished test setup")
    }

    override func tearDown() {
        super.tearDown()
        stubTrack()
        stubDecide()
        mixpanel.reset()
        waitForSerialQueue()

        LSNocilla.sharedInstance().stop()
        LSNocilla.sharedInstance().clearStubs()

        mixpanel = nil
    }

    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool {
        return mixpanelWillFlush
    }

    func waitForSerialQueue() {
        mixpanel.serialQueue.sync() {
            return
        }
    }

    func waitForAsyncTasks() {
        var hasCompletedTask = false
        DispatchQueue.main.async {
            hasCompletedTask = true
        }

        let loopUntil = Date(timeIntervalSinceNow: 10)
        while !hasCompletedTask && loopUntil.timeIntervalSinceNow > 0 {
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: loopUntil)
        }
    }

    func flushAndWaitForSerialQueue() {
        mixpanel.flush()
        waitForSerialQueue()
    }

    func assertDefaultPeopleProperties(_ properties: InternalProperties) {
        XCTAssertNotNil(properties["$ios_device_model"], "missing $ios_device_model property")
        XCTAssertNotNil(properties["$ios_lib_version"], "missing $ios_lib_version property")
        XCTAssertNotNil(properties["$ios_version"], "missing $ios_version property")
        XCTAssertNotNil(properties["$ios_app_version"], "missing $ios_app_version property")
        XCTAssertNotNil(properties["$ios_app_release"], "missing $ios_app_release property")
    }

    func allPropertyTypes() -> Properties {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        let date = dateFormatter.date(from: "2012-09-28 19:14:36 PDT")
        let nested = ["p1": ["p2": ["p3": ["bottom"]]]]
        return ["string": "yello",
                "number": 3,
                "date": date!,
                "dictionary": ["k": "v"],
                "array": ["1"],
                "null": NSNull(),
                "nested": nested,
                "url": URL(string: "https://mixpanel.com/")!,
                "float": 1.3]
    }

    func topViewController() -> UIViewController {
        var rootViewController = UIApplication.shared.keyWindow?.rootViewController
        while rootViewController?.presentedViewController != nil {
            rootViewController = rootViewController?.presentedViewController
        }
        return rootViewController!
    }

}
