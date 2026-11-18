//
//  MixpanelOptOutTests.swift
//  MixpanelDemoTests
//
//  Created by Zihe Jia on 3/27/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

/// Records the body of every request sent to `host` and answers it with a success response.
private class OptOutRecordingURLProtocol: URLProtocol {
    static let host = "optout-recorder.mixpanel.test"
    private static let lock = NSLock()
    private static var recorded: [(path: String, body: String)] = []

    static func reset() {
        lock.lock()
        recorded = []
        lock.unlock()
    }

    /// Waits up to `timeout` seconds for a request to `path` whose body contains every string.
    static func waitForBody(path: String, containing parts: [String], timeout: TimeInterval = 10)
        -> Bool
    {
        let deadline = Date(timeIntervalSinceNow: timeout)
        repeat {
            if bodies(path: path).contains(where: { body in parts.allSatisfy { body.contains($0) } }) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return false
    }

    static func bodies(path: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.filter { $0.path == path }.map { $0.body }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
        }
        OptOutRecordingURLProtocol.lock.lock()
        OptOutRecordingURLProtocol.recorded.append(
            (path: request.url?.path ?? "", body: String(data: data, encoding: .utf8) ?? ""))
        OptOutRecordingURLProtocol.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("1".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

class MixpanelOptOutTests: MixpanelBaseTests {

    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutYES() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "When initialize with opted out flag set to YES, the current user should have opted out tracking"
        )
        testMixpanel.reset()
        removeDBfile(testMixpanel)
    }

    func testOptInWillAddOptInEvent() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 1,
            "When opted in, event queue should have one even(opt in) being queued")

        if eventQueue(token: testMixpanel.apiToken).count > 0 {
            let event = eventQueue(token: testMixpanel.apiToken).first
            XCTAssertEqual(
                (event!["event"] as? String), "$opt_in",
                "When opted in, a track '$opt_in' should have been queued")
        } else {
            XCTAssertTrue(
                eventQueue(token: testMixpanel.apiToken).count == 1,
                "When opted in, event queue should have one even(opt in) being queued")
        }
        removeDBfile(testMixpanel)
    }

    func testOptInTrackingForDistinctId() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking(distinctId: "testDistinctId")
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(), "The current user should have opted in tracking")
        waitForTrackingQueue(testMixpanel)
        let event = eventQueue(token: testMixpanel.apiToken).first
        XCTAssertEqual(
            (event!["event"] as? String), "$opt_in",
            "When opted in, a track '$opt_in' should have been queued")
        XCTAssertEqual(
            testMixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(
            testMixpanel.people.distinctId, "testDistinctId",
            "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 0,
            "identify: should move records from unidentified queue")
        removeDBfile(testMixpanel)
    }

    func testOptInTrackingForDistinctIdAndWithEventProperties() {
        let now = Date()
        let testProperties: Properties = [
            "string": "yello",
            "number": 3,
            "date": now,
            "$app_version": "override",
        ]
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking(distinctId: "testDistinctId", properties: testProperties)
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        let eventQueueValue = eventQueue(token: testMixpanel.apiToken)

        let props = eventQueueValue.first!["properties"] as? InternalProperties
        XCTAssertEqual(props!["string"] as? String, "yello")
        XCTAssertEqual(props!["number"] as? NSNumber, 3)
        compareDate(dateString: props!["date"] as! String, dateDate: now)
        XCTAssertEqual(
            props!["$app_version"] as? String, "override", "reserved property override failed")

        if eventQueueValue.count > 0 {
            let event = eventQueueValue.first
            XCTAssertEqual(
                (event!["event"] as? String), "$opt_in",
                "When opted in, a track '$opt_in' should have been queued")
        } else {
            XCTAssertTrue(
                eventQueueValue.count == 1,
                "When opted in, event queue should have one even(opt in) being queued")
        }

        XCTAssertEqual(
            testMixpanel.distinctId, "testDistinctId", "mixpanel identify failed to set distinct id")
        XCTAssertEqual(
            testMixpanel.people.distinctId, "testDistinctId",
            "mixpanel identify failed to set people distinct id")
        XCTAssertTrue(
            unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count == 0,
            "identify: should move records from unidentified queue")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForMultipleInstances() {
        let mixpanel1 = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(mixpanel1)
        XCTAssertTrue(
            mixpanel1.hasOptedOutTracking(),
            "When initialize with opted out flag set to YES, the current user should have opted out tracking"
        )
        removeDBfile(mixpanel1)

        let mixpanel2 = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: false)
        XCTAssertFalse(
            mixpanel2.hasOptedOutTracking(),
            "When initialize with opted out flag set to NO, the current user should have opted in tracking"
        )
        removeDBfile(mixpanel2)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyAfterInitializedWithOptedOutNO() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: false)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "When initialize with opted out flag set to NO, the current user should have opted out tracking"
        )
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyByDefault() {
        let testMixpanel = Mixpanel.initialize(token: randomId())
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "By default, the current user should not opted out tracking")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForOptOut() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "When optOutTracking is called, the current user should have opted out tracking")
        removeDBfile(testMixpanel)
    }

    func testHasOptOutTrackingFlagBeingSetProperlyForOptIn() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "When optOutTracking is called, the current user should have opted out tracking")
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "When optOutTracking is called, the current user should have opted in tracking")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingWillNotGenerateEventQueue() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        for i in 0..<50 {
            testMixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 0,
            "When opted out, events should not be queued")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingWillNotGeneratePeopleQueue() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        for i in 0..<50 {
            testMixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).count == 0,
            "When opted out, events should not be queued")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingWillSkipAlias() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        testMixpanel.createAlias("testAlias", distinctId: "aDistinctId")
        XCTAssertNotEqual(testMixpanel.alias, "testAlias", "When opted out, alias should not be set")
        removeDBfile(testMixpanel)
    }

    func testEventBeingTrackedBeforeOptOutShouldNotBeCleared() {
        let testMixpanel = Mixpanel.initialize(token: randomId())
        testMixpanel.track(event: "a normal event")
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).count == 1, "events should be queued")
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 1,
            "When opted out, any events tracked before opted out should not be cleared")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingRegisterSuperProperties() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        testMixpanel.registerSuperProperties(properties)
        waitForTrackingQueue(testMixpanel)
        XCTAssertNotEqual(
            NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
            NSDictionary(dictionary: properties),
            "When opted out, register super properties should not be successful")
        removeDBfile(testMixpanel)
    }

    func testOptOutTrackingRegisterSuperPropertiesOnce() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        let properties: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.registerSuperPropertiesOnce(properties)
        waitForTrackingQueue(testMixpanel)
        XCTAssertNotEqual(
            NSDictionary(dictionary: testMixpanel.currentSuperProperties()),
            NSDictionary(dictionary: properties),
            "When opted out, register super properties once should not be successful")
        removeDBfile(testMixpanel)
    }

    func testOptOutWilSkipTimeEvent() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.time(event: "400 Meters")
        testMixpanel.track(event: "400 Meters")
        waitForTrackingQueue(testMixpanel)
        XCTAssertNil(
            eventQueue(token: testMixpanel.apiToken).last,
            "When opted out, this event should not be timed.")
        removeDBfile(testMixpanel)
    }

    func testOptOutWillSkipFlushPeople() {
        OptOutRecordingURLProtocol.reset()
        URLProtocol.registerClass(OptOutRecordingURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(OptOutRecordingURLProtocol.self)
            OptOutRecordingURLProtocol.reset()
        }
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 0,
            optOutTrackingByDefault: true, serverURL: "https://\(OptOutRecordingURLProtocol.host)")
        testMixpanel.optInTracking()
        waitForTrackingQueue(testMixpanel)
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        for i in 0..<1 {
            testMixpanel.people.set(property: "p1", to: "\(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).count == 1,
            "When opted in, people queue should have been queued")

        // Opting out sends the pending update and the $delete for d1, then nothing else.
        testMixpanel.optOutTracking()
        XCTAssertTrue(
            OptOutRecordingURLProtocol.waitForBody(path: "/engage", containing: ["\"$delete\"", "\"d1\""]))
        waitForTrackingQueue(testMixpanel)
        let sentBeforeFlush = OptOutRecordingURLProtocol.bodies(path: "/engage")
        XCTAssertTrue(sentBeforeFlush.contains { $0.contains("\"$delete\"") })

        testMixpanel.people.set(property: "p2", to: "after opt-out")
        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        XCTAssertEqual(
            OptOutRecordingURLProtocol.bodies(path: "/engage"), sentBeforeFlush,
            "When opted out, flush should not send people updates")
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).isEmpty,
            "When opted out, people updates should not be queued")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutWillSkipFlushEvent() {
        let testMixpanel = Mixpanel.initialize(token: randomId(), optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        testMixpanel.identify(distinctId: "d1")
        waitForTrackingQueue(testMixpanel)
        for i in 0..<1 {
            testMixpanel.track(event: "event \(i)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 3,
            "When opted in, events should have been queued")

        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).count == 3,
            "When opted out, events should not be flushed")
        removeDBfile(testMixpanel)
    }

    // MARK: - SDK-306 / SDK-288

    func testOptOutSendsDeleteForIdentifiedUser() {
        OptOutRecordingURLProtocol.reset()
        URLProtocol.registerClass(OptOutRecordingURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(OptOutRecordingURLProtocol.self)
            OptOutRecordingURLProtocol.reset()
        }
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 0,
            serverURL: "https://\(OptOutRecordingURLProtocol.host)")
        testMixpanel.identify(distinctId: "user-306")
        testMixpanel.people.set(property: "plan", to: "pro")
        flushAndWaitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            OptOutRecordingURLProtocol.waitForBody(path: "/engage", containing: ["\"$set\""]),
            "The recorder should see the profile update sent before opting out")

        testMixpanel.optOutTracking()
        _ = OptOutRecordingURLProtocol.waitForBody(
            path: "/engage", containing: ["\"$delete\"", "\"user-306\""])
        waitForTrackingQueue(testMixpanel)

        let deletes = OptOutRecordingURLProtocol.bodies(path: "/engage").filter {
            $0.contains("\"$delete\"") && $0.contains("\"user-306\"")
        }
        XCTAssertEqual(deletes.count, 1, "optOutTracking should send $delete for the identified user")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutDeleteIsNotReattributedToNextUser() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 0)
        // Keep every row in the queue so it can be inspected.
        testMixpanel.delegate = self
        testMixpanel.identify(distinctId: "user-a")
        waitForTrackingQueue(testMixpanel)
        testMixpanel.optOutTracking()
        waitForTrackingQueue(testMixpanel)

        testMixpanel.optInTracking(distinctId: "user-b")
        waitForTrackingQueue(testMixpanel)

        let deletesForUserB = peopleQueue(token: testMixpanel.apiToken).filter {
            $0["$delete"] != nil && $0["$distinct_id"] as? String == "user-b"
        }
        XCTAssertTrue(
            deletesForUserB.isEmpty,
            "The $delete queued by opting out user-a must never target user-b")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptOutRightAfterFlushStillSendsDelete() {
        OptOutRecordingURLProtocol.reset()
        URLProtocol.registerClass(OptOutRecordingURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(OptOutRecordingURLProtocol.self)
            OptOutRecordingURLProtocol.reset()
        }
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 0,
            serverURL: "https://\(OptOutRecordingURLProtocol.host)")
        testMixpanel.identify(distinctId: "user-flushing")
        testMixpanel.track(event: "before opt-out")
        testMixpanel.people.set(property: "plan", to: "pro")
        // The flush pass is usually still running when the opt-out block runs.
        testMixpanel.flush()
        testMixpanel.optOutTracking()
        _ = OptOutRecordingURLProtocol.waitForBody(
            path: "/engage", containing: ["\"$delete\"", "\"user-flushing\""])
        waitForTrackingQueue(testMixpanel)

        let deletes = OptOutRecordingURLProtocol.bodies(path: "/engage").filter {
            $0.contains("\"$delete\"") && $0.contains("\"user-flushing\"")
        }
        XCTAssertEqual(deletes.count, 1, "optOutTracking during a flush should still send $delete")
        removeDBfile(testMixpanel.apiToken)
    }

    func testOptInDropsUnidentifiedDeleteFromOlderVersions() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 0,
            optOutTrackingByDefault: true)
        testMixpanel.delegate = self
        waitForTrackingQueue(testMixpanel)
        // Older SDK versions left the opt-out $delete queued without a distinct id.
        testMixpanel.mixpanelPersistence.saveEntity(
            ["$delete": [:] as InternalProperties, "$token": testMixpanel.apiToken],
            type: .people, flag: PersistenceConstant.unIdentifiedFlag)
        XCTAssertEqual(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).count, 1)

        testMixpanel.optInTracking(distinctId: "user-b")
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(unIdentifiedPeopleQueue(token: testMixpanel.apiToken).isEmpty)
        XCTAssertFalse(
            peopleQueue(token: testMixpanel.apiToken).contains { $0["$delete"] != nil },
            "A stale $delete must not be attached to the user who opts in")
        removeDBfile(testMixpanel.apiToken)
    }

    func testResetKeepsOptInStatusAcrossRelaunch() {
        let token = randomId()
        var testMixpanel = Mixpanel.initialize(
            token: token, optOutTrackingByDefault: true)
        testMixpanel.optInTracking()
        testMixpanel.reset()
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(testMixpanel.hasOptedOutTracking())
        XCTAssertEqual(MixpanelPersistence.loadOptOutStatusFlag(instanceName: token), false)

        // Simulate an app relaunch.
        Mixpanel.removeInstance(name: token)
        testMixpanel = Mixpanel.initialize(
            token: token, optOutTrackingByDefault: true)
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.hasOptedOutTracking(),
            "A user who opted in must stay opted in after reset() and a relaunch")
        removeDBfile(token)
    }

    func testResetKeepsOptOutStatusAcrossRelaunch() {
        let token = randomId()
        var testMixpanel = Mixpanel.initialize(token: token)
        testMixpanel.optOutTracking()
        testMixpanel.reset()
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(testMixpanel.hasOptedOutTracking())
        XCTAssertEqual(MixpanelPersistence.loadOptOutStatusFlag(instanceName: token), true)

        // Simulate an app relaunch.
        Mixpanel.removeInstance(name: token)
        testMixpanel = Mixpanel.initialize(token: token)
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            testMixpanel.hasOptedOutTracking(),
            "A user who opted out must stay opted out after reset() and a relaunch")
        removeDBfile(token)
    }
}
