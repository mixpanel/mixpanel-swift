//
//  MixpanelBaseTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla
import SQLite3

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelBaseTests: XCTestCase, MixpanelDelegate {
    var mixpanel: MixpanelInstance!
    var mixpanelWillFlush: Bool!
    static var requestCount = 0

    override func setUp() {
        NSLog("starting test setup...")
        super.setUp()
        stubTrack()
        stubDecide()
        stubEngage()
        stubGroups()
        LSNocilla.sharedInstance().start()
        mixpanelWillFlush = false
        mixpanel = Mixpanel.initialize(token: kTestToken, flushInterval: 0)
        mixpanel.reset()
        waitForTrackingQueue()

        if let loginView = self.topViewController() as? LoginViewController {
            loginView.goToMainView()
        } else {
            NSLog("Expected login screen but not found.")
        }

        NSLog("finished test setup")
    }

    override func tearDown() {
        super.tearDown()
        stubTrack()
        stubDecide()
        stubEngage()
        stubGroups()
        mixpanel.reset()
        waitForTrackingQueue()

        LSNocilla.sharedInstance().stop()
        LSNocilla.sharedInstance().clearStubs()

        mixpanel = nil
    }

    
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool {
        return mixpanelWillFlush
    }

    func waitForTrackingQueue() {
        mixpanel.trackingQueue.sync() {
            return
        }
    }
    
    func randomId() -> String
    {
        return String(format: "%08x%08x", arc4random(), arc4random())
    }
    
    func waitForAsyncTasks() {
        var hasCompletedTask = false
        DispatchQueue.main.async {
            hasCompletedTask = true
        }

        let loopUntil = Date(timeIntervalSinceNow: 10)
        while !hasCompletedTask && loopUntil.timeIntervalSinceNow > 0 {
            RunLoop.current.run(mode: RunLoop.Mode.default, before: loopUntil)
        }
    }
    
    func eventQueue(token: String) -> Queue {
        let dataMap = MPDBTest.readRows(.events, projectToken: token, numRows: Int.max)
        var jsonArray : [InternalProperties] = []
        for (key, value) in dataMap {
            if let jsonObject = JSONHandler.deserializeData(value) as? InternalProperties {
                var entity = jsonObject
                entity["id"] = key
                jsonArray.append(entity)
            }
        }
        return jsonArray
    }

    func peopleQueue(token: String) -> Queue {
        let dataMap = MPDBTest.readRows(.people, projectToken: token, numRows: Int.max)
        var jsonArray : [InternalProperties] = []
        for (key, value) in dataMap {
            if let jsonObject = JSONHandler.deserializeData(value) as? InternalProperties {
                var entity = jsonObject
                entity["id"] = key
                jsonArray.append(entity)
            }
        }
        return jsonArray
    }
    
    func unIdentifiedPeopleQueue(token: String) -> Queue {
        let dataMap = MPDBTest.readRows(.people, projectToken: token, numRows: Int.max, flag: true)
        var jsonArray : [InternalProperties] = []
        for (key, value) in dataMap {
            if let jsonObject = JSONHandler.deserializeData(value) as? InternalProperties {
                var entity = jsonObject
                entity["id"] = key
                jsonArray.append(entity)
            }
        }
        return jsonArray
    }
    
    func groupQueue(token: String) -> Queue {
        return MixpanelPersistence.sharedInstance.loadEntitiesInBatch(type: .groups, token: token, batchSize: Int.max)
    }
    
    func flushAndWaitForTrackingQueue() {
        mixpanel.flush()
        waitForTrackingQueue()
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
        let opt: String? = nil
        return ["string": "yello",
                "number": 3,
                "date": date!,
                "dictionary": ["k": "v", "opt": opt as Any],
                "array": ["1", opt as Any],
                "null": NSNull(),
                "nested": nested,
                "url": URL(string: "https://mixpanel.com/")!,
                "float": 1.3,
                "optional": opt,
        ]
    }

    func topViewController() -> UIViewController {
        var rootViewController = UIApplication.shared.keyWindow?.rootViewController
        while rootViewController?.presentedViewController != nil {
            rootViewController = rootViewController?.presentedViewController
        }
        return rootViewController!
    }

}
