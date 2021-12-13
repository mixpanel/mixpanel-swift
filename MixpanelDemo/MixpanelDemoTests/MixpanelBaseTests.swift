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

class MixpanelBaseTests: XCTestCase, MixpanelDelegate {
    var mixpanelWillFlush: Bool!
    static var requestCount = 0

    override func setUp() {
        NSLog("starting test setup...")
        super.setUp()
        stubCalls()
        mixpanelWillFlush = false

        NSLog("finished test setup")
    }

    func stubCalls() {
        stubTrack()
        stubDecide()
        stubEngage()
        stubGroups()
        LSNocilla.sharedInstance().start()
    }
    
    override func tearDown() {
        super.tearDown()
        stubTrack()
        stubDecide()
        stubEngage()
        stubGroups()

        LSNocilla.sharedInstance().stop()
        LSNocilla.sharedInstance().clearStubs()
    }
    
    func removeDBfile(_ token: String? = nil) {
        do {
             let fileManager = FileManager.default
            
            // Check if file exists
            if fileManager.fileExists(atPath: dbFilePath(token)) {
                // Delete file
                try fileManager.removeItem(atPath: dbFilePath(token))
            } else {
                print("Unable to delete the test db file at \(dbFilePath(token)), the file does not exist")
            }
         
        }
        catch let error as NSError {
            print("An error took place: \(error)")
        }
    }
    
    func dbFilePath(_ token: String? = nil) -> String {
        let manager = FileManager.default
        #if os(iOS)
        let url = manager.urls(for: .libraryDirectory, in: .userDomainMask).last
        #else
        let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).last
        #endif // os(iOS)
        guard let apiToken = token else {
            return ""
        }
        
        guard let urlUnwrapped = url?.appendingPathComponent("\(token ?? apiToken)_MPDB.sqlite").path else {
            return ""
        }
        return urlUnwrapped
    }

    
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool {
        return mixpanelWillFlush
    }

    func waitForTrackingQueue(_ mixpanel: MixpanelInstance) {
        mixpanel.trackingQueue.sync() {
            mixpanel.networkQueue.sync() {
                return
            }
        }
        mixpanel.trackingQueue.sync() {
            mixpanel.networkQueue.sync() {
                return
            }
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
        return MixpanelPersistence.init(token: token).loadEntitiesInBatch(type: .events)
    }

    func peopleQueue(token: String) -> Queue {
        return MixpanelPersistence.init(token: token).loadEntitiesInBatch(type: .people)
    }
    
    func unIdentifiedPeopleQueue(token: String) -> Queue {
        return MixpanelPersistence.init(token: token).loadEntitiesInBatch(type: .people, flag: PersistenceConstant.unIdentifiedFlag)
    }
    
    func groupQueue(token: String) -> Queue {
        return MixpanelPersistence.init(token: token).loadEntitiesInBatch(type: .groups)
    }
    
    func flushAndWaitForTrackingQueue(_ mixpanel: MixpanelInstance) {
        mixpanel.flush()
        waitForTrackingQueue(mixpanel)
        mixpanel.flush()
        waitForTrackingQueue(mixpanel)
    }

    func assertDefaultPeopleProperties(_ properties: InternalProperties) {
        XCTAssertNotNil(properties["$ios_device_model"], "missing $ios_device_model property")
        XCTAssertNotNil(properties["$ios_lib_version"], "missing $ios_lib_version property")
        XCTAssertNotNil(properties["$ios_version"], "missing $ios_version property")
        XCTAssertNotNil(properties["$ios_app_version"], "missing $ios_app_version property")
        XCTAssertNotNil(properties["$ios_app_release"], "missing $ios_app_release property")
    }

    func compareDate(dateString: String, dateDate: Date) {
        let dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.string(from: dateDate)
        XCTAssertEqual(String(date.prefix(19)), String(dateString.prefix(19)))
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
