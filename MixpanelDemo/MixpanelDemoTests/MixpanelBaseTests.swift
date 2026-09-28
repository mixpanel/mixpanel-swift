//
//  MixpanelBaseTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import SQLite3
import XCTest

@testable import Mixpanel

class MixpanelBaseTests: XCTestCase, MixpanelDelegate {
    var mixpanelWillFlush: Bool!
    static var requestCount = 0

    override func setUp() {
        NSLog("starting test setup...")
        super.setUp()
        mixpanelWillFlush = false
        let defaults = UserDefaults(suiteName: "Mixpanel")
        defaults?.removeObject(forKey: "MPFirstOpen")

        NSLog("finished test setup")
    }

    override func tearDown() {
        super.tearDown()
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

        } catch let error as NSError {
            print("An error took place: \(error)")
        }
    }

    func dbFilePath(_ token: String? = nil) -> String {
        let manager = FileManager.default
        #if os(iOS)
        let url = manager.urls(for: .libraryDirectory, in: .userDomainMask).last
        #else
        let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).last
        #endif  // os(iOS)
        guard let apiToken = token else {
            return ""
        }

        guard let urlUnwrapped = url?.appendingPathComponent("\(apiToken)_MPDB.sqlite").path
        else {
            return ""
        }
        return urlUnwrapped
    }

    /// Makes every UPDATE on `token`'s people table fail with a real SQLite error, by installing an
    /// aborting trigger through a separate connection. The connection is closed right away, so
    /// the SDK's connection is the only one left and its recreate closes cleanly.
    func failPeopleUpdates(_ token: String) {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbFilePath(token), &db), SQLITE_OK)
        let sql = """
            CREATE TRIGGER fail_people_updates BEFORE UPDATE ON mixpanel_\(token)_people \
            BEGIN SELECT RAISE(ABORT, 'forced update failure'); END;
            """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
    }

    /// Counts every row in one of `token`'s tables, readable or not, through a separate connection.
    func rowCount(_ token: String, table: String) -> Int {
        var db: OpaquePointer?
        guard sqlite3_open(dbFilePath(token), &db) == SQLITE_OK else {
            XCTFail("could not open the test database")
            return -1
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard
            sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM mixpanel_\(token)_\(table)", -1, &statement, nil)
                == SQLITE_OK
        else {
            XCTFail("could not count rows in \(table)")
            return -1
        }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW ? Int(sqlite3_column_int(statement, 0)) : -1
    }

    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool {
        return mixpanelWillFlush
    }

    func waitForTrackingQueue(_ mixpanel: MixpanelInstance) {
        mixpanel.trackingQueue.sync {
            mixpanel.networkQueue.sync {
                return
            }
        }
        mixpanel.trackingQueue.sync {
            mixpanel.networkQueue.sync {
                return
            }
        }
    }

    func randomId() -> String {
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
        return MixpanelPersistence.init(instanceName: token).loadEntitiesInBatch(type: .events)
    }

    func peopleQueue(token: String) -> Queue {
        return MixpanelPersistence.init(instanceName: token).loadEntitiesInBatch(type: .people)
    }

    func unIdentifiedPeopleQueue(token: String) -> Queue {
        return MixpanelPersistence.init(instanceName: token).loadEntitiesInBatch(
            type: .people, flag: PersistenceConstant.unIdentifiedFlag)
    }

    func groupQueue(token: String) -> Queue {
        return MixpanelPersistence.init(instanceName: token).loadEntitiesInBatch(type: .groups)
    }

    func flushAndWaitForTrackingQueue(_ mixpanel: MixpanelInstance) {
        // A flush now drains in several queue hops, so wait on its completion rather than on the
        // queues. Two flushes are kept so existing retry and backoff expectations still hold.
        for _ in 0..<2 {
            let flushed = expectation(description: "flush completed")
            mixpanel.flush { flushed.fulfill() }
            wait(for: [flushed], timeout: 130)
        }
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
        return [
            "string": "yello",
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

}
