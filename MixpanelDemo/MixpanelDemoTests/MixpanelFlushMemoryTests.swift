//
//  MixpanelFlushMemoryTests.swift
//  MixpanelDemo
//
//  Regression coverage for the flush-path fixes that bound how much is deserialized into
//  memory at once. Each test here corresponds to a crash mode that produced an
//  NSMallocException inside JSONSerialization during MPDB.readRows.
//

import UIKit
import XCTest

@testable import Mixpanel

/// Answers every request to `kFakeServerUrl` with a successful response and records the path and
/// body of each, so tests can see exactly what was sent without touching the real API.
private class RecordingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [(path: String, body: String)] = []

    static func reset() {
        lock.lock()
        recorded = []
        lock.unlock()
    }

    static func requests() -> [(path: String, body: String)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.host == URL(string: kFakeServerUrl)?.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        RecordingURLProtocol.lock.lock()
        // `path` drops the trailing slash: "/track/" is recorded as "/track".
        RecordingURLProtocol.recorded.append((url.path, Self.bodyString(of: request)))
        RecordingURLProtocol.lock.unlock()

        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: "1".data(using: .utf8)!)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession moves `httpBody` into `httpBodyStream` before a protocol sees the request.
    private static func bodyString(of request: URLRequest) -> String {
        if let body = request.httpBody {
            return String(decoding: body, as: UTF8.self)
        }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

class MixpanelFlushMemoryTests: MixpanelBaseTests {

    // MARK: - Oversized rows

    /// A row too large to parse must be skipped and deleted, never handed to JSONSerialization.
    ///
    /// Parsing one can exhaust memory, which Foundation raises as an NSMallocException — an
    /// Objective-C exception that JSONHandler's do/catch cannot intercept. Because the API also
    /// rejects a payload that size, the row could never drain: every later flush would reach it
    /// and take the process down again.
    func testOversizedRowIsDroppedWithoutBeingDeserialized() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        let first: InternalProperties = ["event": "first", "properties": ["index": 1]]
        mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(first)!)

        let oversized: InternalProperties = [
            "event": "oversized",
            "properties": ["blob": String(repeating: "a", count: APIConstants.maxRowByteSize)],
        ]
        let oversizedData = JSONHandler.serializeJSONObject(oversized)!
        XCTAssertGreaterThan(
            oversizedData.count, APIConstants.maxRowByteSize,
            "test fixture must exceed the row limit to exercise the guard")
        mpdb.insertRow(.events, data: oversizedData)

        let last: InternalProperties = ["event": "last", "properties": ["index": 2]]
        mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(last)!)

        let rows = mpdb.readRows(.events, numRows: 100)
        XCTAssertEqual(
            rows.compactMap { $0["event"] as? String }, ["first", "last"],
            "oversized row should be skipped while its neighbours still read")

        // It must be gone from the table, not merely skipped: a row that is skipped but left
        // behind still occupies a slot in every subsequent bounded read, so a table full of them
        // would stop draining entirely.
        let rowsAfter = mpdb.readRows(.events, numRows: 100)
        XCTAssertEqual(
            rowsAfter.compactMap { $0["event"] as? String }, ["first", "last"],
            "oversized row should have been deleted, not re-read")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    // MARK: - Bounded reads

    /// A read must never pull more than the requested number of rows, however large the table.
    ///
    /// A full flush used to request `Int.max`, which MPDB translated into a SELECT with no LIMIT
    /// clause — every queued row deserialized into memory at once. It now requests
    /// `APIConstants.maxBatchSize`, and rows past that bound stay in SQLite for the next flush.
    func testReadIsBoundedForTablesLargerThanTheFlushSize() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        let bound = APIConstants.maxBatchSize
        let excess = 25
        for index in 0..<(bound + excess) {
            let event: InternalProperties = ["event": "event\(index)", "properties": ["index": index]]
            mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(event)!)
        }

        let bounded = mpdb.readRows(.events, numRows: bound)
        XCTAssertEqual(bounded.count, bound, "read should stop at the requested bound")

        // The remainder is still queued rather than dropped.
        let all = mpdb.readRows(.events, numRows: bound + excess)
        XCTAssertEqual(all.count, bound + excess, "rows past the bound should remain queued")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    /// A read must stop before the row that would push its cumulative bytes past the budget.
    ///
    /// The row bound alone is not enough: `maxBatchSize` rows that are each individually legal can
    /// still sum to hundreds of megabytes, and JSON parsing inflates raw bytes several-fold once
    /// materialized as Foundation objects. Rows past the budget stay queued for the next flush.
    func testReadStopsAtTheByteBudget() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        let rowCount = 10
        var rowSizes: [Int] = []
        for index in 0..<rowCount {
            let event: InternalProperties = [
                "event": "event\(index)",
                "properties": ["blob": String(repeating: "a", count: 10_000)],
            ]
            let data = JSONHandler.serializeJSONObject(event)!
            rowSizes.append(data.count)
            mpdb.insertRow(.events, data: data)
        }

        // Mirror the reader's rule against the known row sizes: the first row is always taken,
        // then rows are taken while they fit within the budget.
        let byteBudget = 25_000
        var expectedCount = 0
        var bytes = 0
        for size in rowSizes {
            if expectedCount > 0 && bytes + size > byteBudget {
                break
            }
            expectedCount += 1
            bytes += size
        }
        XCTAssertTrue(
            0 < expectedCount && expectedCount < rowCount,
            "test fixture must make the budget bind between the first and last row")

        let rows = mpdb.readRows(.events, numRows: rowCount, byteBudget: byteBudget)
        XCTAssertEqual(rows.count, expectedCount, "read should stop at the byte budget")

        // Rows past the budget are still queued rather than dropped.
        let all = mpdb.readRows(.events, numRows: rowCount)
        XCTAssertEqual(all.count, rowCount, "rows past the budget should remain queued")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    /// A budget smaller than the first row must still read that row, or the queue would stall:
    /// every flush would read nothing and the same row would head the queue forever.
    func testByteBudgetAlwaysReadsAtLeastOneRow() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        for index in 0..<2 {
            let event: InternalProperties = ["event": "event\(index)", "properties": ["index": index]]
            mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(event)!)
        }

        let rows = mpdb.readRows(.events, numRows: 100, byteBudget: 1)
        XCTAssertEqual(
            rows.compactMap { $0["event"] as? String }, ["event0"],
            "exactly the first row should be read when it alone exceeds the budget")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    // MARK: - Malformed rows

    /// Rows that fail JSON deserialization must be dropped and deleted, not left to block valid events.
    ///
    /// When a serialized row cannot be deserialized, it must be deleted to prevent it from
    /// consuming the read budget on every flush. A batch of malformed rows followed by valid
    /// events would return an empty batch and stop, starving the valid events indefinitely.
    func testMalformedRowsThatFailDeserializationAreDeleted() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        let first: InternalProperties = ["event": "first", "properties": ["index": 1]]
        mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(first)!)

        // Insert a row with invalid JSON data (truncated JSON string)
        let invalidJSON = "{\"event\": \"broken".data(using: .utf8)!
        mpdb.insertRow(.events, data: invalidJSON)

        let last: InternalProperties = ["event": "last", "properties": ["index": 2]]
        mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(last)!)

        // First read: malformed row should be skipped and deleted, so we get first and last
        let rows = mpdb.readRows(.events, numRows: 100)
        XCTAssertEqual(
            rows.compactMap { $0["event"] as? String }, ["first", "last"],
            "malformed row should be skipped while its neighbours read successfully")

        // Second read: malformed row must be gone, not re-read
        let rowsAfter = mpdb.readRows(.events, numRows: 100)
        XCTAssertEqual(
            rowsAfter.compactMap { $0["event"] as? String }, ["first", "last"],
            "malformed row should have been deleted, not re-read")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    /// A batch that is entirely malformed rows must still delete them, even though the read
    /// itself returns nothing for that call.
    ///
    /// `readRows` has no internal pagination: if every physical row within its `numRows` window
    /// is malformed, the call returns empty (there is nothing behind that window for it to see).
    /// That's fine — the malformed rows are still deleted as a side effect, so the *next* call
    /// against the same window finds them gone and reaches whatever is behind them. Starvation
    /// is avoided at the drain-loop level (MixpanelInstance.flushBatches), which keeps calling
    /// as long as the previous read returned anything at all — see
    /// testFlushDrainsPastAFullyMalformedBatch below for that half of the fix.
    func testFullyMalformedBatchIsDeletedEvenThoughTheReadReturnsEmpty() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        let batchSize = APIConstants.maxBatchSize
        let invalidJSON = "{\"broken".data(using: .utf8)!

        // Insert enough malformed rows to fill one whole read window.
        for _ in 0..<batchSize {
            mpdb.insertRow(.events, data: invalidJSON)
        }

        // Insert valid events right behind them.
        for index in 0..<10 {
            let event: InternalProperties = ["event": "event\(index)", "properties": ["index": index]]
            mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(event)!)
        }

        // First call: the window is entirely malformed rows, so nothing valid comes back —
        // but they must still be deleted.
        let firstRead = mpdb.readRows(.events, numRows: batchSize)
        XCTAssertTrue(firstRead.isEmpty, "a window of only malformed rows returns nothing")

        // Second call: the malformed rows are gone, so this window now reaches the valid events.
        let secondRead = mpdb.readRows(.events, numRows: batchSize)
        XCTAssertEqual(secondRead.count, 10, "valid events should surface once malformed rows ahead of them are gone")
        XCTAssertTrue(
            secondRead.allSatisfy { ($0["event"] as? String)?.hasPrefix("event") == true },
            "only valid events should be returned")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    // MARK: - Drain loop

    /// A short-but-non-empty batch (here, shrunk by dropped malformed rows sharing its read
    /// window) must not be mistaken for an empty queue — the drain must keep going past it
    /// within the same flush() call, reaching valid events queued behind it.
    ///
    /// Previously the drain loop only continued when a read returned exactly `flushBatchSize`
    /// rows, treating anything less as "queue empty." A read window containing mostly malformed
    /// rows plus a few valid ones returns fewer than `flushBatchSize` entries even though more
    /// valid events are queued right behind that window — the old check would stop the flush
    /// there, stranding those events until some later flush. The loop must instead keep draining
    /// as long as the previous read returned anything at all, stopping only on a genuinely empty
    /// read.
    func testFlushDrainsPastAShortBatchCausedByMalformedRows() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)

        let batchSize = testMixpanel.flushBatchSize
        let invalidJSON = "{\"broken".data(using: .utf8)!
        let validInFirstWindow = 3
        let mpdb = MPDB.init(token: testMixpanel.apiToken)
        mpdb.open()
        // Malformed rows fill most of the first read window; a few valid ones fill the rest,
        // so that window's read returns a short (non-empty, non-full) batch.
        for _ in 0..<(batchSize - validInFirstWindow) {
            mpdb.insertRow(.events, data: invalidJSON)
        }
        mpdb.close()
        for index in 0..<validInFirstWindow {
            testMixpanel.track(event: "firstWindowEvent\(index)")
        }
        waitForTrackingQueue(testMixpanel)

        // More valid events, reachable only once the drain continues past the first window.
        let secondWindowCount = 10
        for index in 0..<secondWindowCount {
            testMixpanel.track(event: "secondWindowEvent\(index)")
        }
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "valid events queued behind a short (malformed-shrunk) batch should still be sent within this flush"
        )
        removeDBfile(testMixpanel.apiToken)
    }

    /// A single flush call must drain a queue larger than one batch, by repeating
    /// read → send → delete in `flushBatchSize` batches until the table is empty.
    func testSingleFlushDrainsQueueLargerThanOneBatch() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        let total = APIConstants.maxBatchSize * 2 + 20
        for index in 0..<total {
            testMixpanel.track(event: "event\(index)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertEqual(eventQueue(token: testMixpanel.apiToken).count, total)

        testMixpanel.flush()
        // Each waitForTrackingQueue pass drains two read → send iterations of the chain: three
        // real batches (50 + 50 + 20) plus one extra, empty iteration the drain loop now runs
        // to confirm the queue is exhausted (it continues on any non-empty read, not just a
        // full one) — four iterations in total. Three passes leaves margin over the two that
        // would exactly cover it.
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "one flush call should drain all \(total) events, not just the first batch")
        removeDBfile(testMixpanel.apiToken)
    }

    /// A failed request must stop the drain and leave every unsent row queued — the loop
    /// may not spin against a dead endpoint, and nothing may be deleted without a send.
    func testFailedSendStopsDrainAndKeepsRows() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.serverURL = kFakeServerUrl
        let total = APIConstants.maxBatchSize * 2 + 20
        for index in 0..<total {
            testMixpanel.track(event: "event\(index)")
        }
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)

        XCTAssertEqual(
            eventQueue(token: testMixpanel.apiToken).count, total,
            "a failed send should stop the drain with every row still queued")
        removeDBfile(testMixpanel.apiToken)
    }

    // MARK: - Flush coalescing

    /// Counts how many flushes get past the coalescing guard, and can hold one open while the
    /// test fires more. Returning `false` keeps the test off the network.
    private final class GatedFlushDelegate: MixpanelDelegate {
        private(set) var willFlushCount = 0
        private let gate = DispatchSemaphore(value: 0)
        var shouldGate = true

        func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool {
            willFlushCount += 1
            if shouldGate {
                gate.wait()
            }
            return false
        }

        func openGate() {
            gate.signal()
        }
    }

    /// Only one flush may be in flight; calls that arrive while one is running are dropped.
    ///
    /// Each queued flush used to load its own events/people/groups payload and hold it alive in a
    /// pending closure until the serial, network-bound send drained ahead of it. Callers that
    /// flush per-event piled up enough of those payloads to exhaust memory.
    func testOverlappingFlushesAreCoalesced() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        let delegate = GatedFlushDelegate()
        testMixpanel.delegate = delegate
        testMixpanel.track(event: "event")

        XCTAssertFalse(testMixpanel.isFlushInProgress, "no flush should be running before the first call")

        // Claims the flush slot, then parks in mixpanelWillFlush on the tracking queue.
        XCTAssertTrue(testMixpanel.flush(), "the first flush should claim the slot and start")
        XCTAssertTrue(
            testMixpanel.isFlushInProgress,
            "the public flag must report the parked flush so apps can skip scheduling another")

        // Every one of these must be dropped by the coalescing guard while the first is parked,
        // report that via the return value, and still fire its own completion right away.
        let rejectedCompletions = expectation(description: "rejected completions fired")
        rejectedCompletions.expectedFulfillmentCount = 5
        for _ in 0..<5 {
            let started = testMixpanel.flush {
                rejectedCompletions.fulfill()
            }
            XCTAssertFalse(started, "an overlapping flush must report that it did not start")
        }
        wait(for: [rejectedCompletions], timeout: 5)

        delegate.shouldGate = false
        delegate.openGate()
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            testMixpanel.isFlushInProgress, "the flag must clear once the flush releases its slot")

        XCTAssertEqual(
            delegate.willFlushCount, 1,
            "only the first flush should have run; the rest should have been coalesced")

        // The slot must be released so later flushes still work — a leaked flag would stop
        // flushing for the lifetime of the instance.
        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        XCTAssertEqual(
            delegate.willFlushCount, 2, "the flush slot should be released after a flush finishes")

        testMixpanel.delegate = nil
        removeDBfile(testMixpanel.apiToken)
    }

    func testBackgroundTaskProtectsActiveFlushUntilItFinishes() throws {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 0)
        let delegate = GatedFlushDelegate()
        testMixpanel.delegate = delegate
        defer {
            delegate.openGate()
            testMixpanel.delegate = nil
            removeDBfile(testMixpanel.apiToken)
        }

        let finished = expectation(description: "active flush finished")
        testMixpanel.flush {
            XCTAssertEqual(testMixpanel.taskId, .invalid)
            finished.fulfill()
        }

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        let backgroundTaskId = testMixpanel.taskId
        if backgroundTaskId == .invalid {
            delegate.openGate()
            wait(for: [finished], timeout: 5)
            throw XCTSkip("The test host was not granted UIKit background execution")
        }

        let overlapping = expectation(description: "overlapping flush returned")
        let overlappingStarted = testMixpanel.flush {
            XCTAssertEqual(
                testMixpanel.taskId, backgroundTaskId,
                "An overlapping completion must preserve background execution")
            overlapping.fulfill()
        }
        XCTAssertFalse(overlappingStarted, "the overlapping call must be rejected, not start a second flush")
        wait(for: [overlapping], timeout: 5)

        delegate.openGate()
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(delegate.willFlushCount, 1)
    }

    // MARK: - Delegate cadence

    /// Counts delegate calls without vetoing, so the drain actually runs its iterations.
    private final class CountingFlushDelegate: MixpanelDelegate {
        private(set) var willFlushCount = 0

        func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool {
            willFlushCount += 1
            return true
        }
    }

    /// `mixpanelWillFlush` is a per-flush question, not a per-batch one.
    ///
    /// The drain runs one iteration per batch and per queue type, so a flush that visits events,
    /// people, and groups runs at least three iterations. The delegate must still be asked exactly
    /// once — apps doing heavy work in that callback must not see it multiply with the backlog.
    func testDelegateIsAskedOncePerFlush() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.serverURL = kFakeServerUrl
        let delegate = CountingFlushDelegate()
        testMixpanel.delegate = delegate
        let total = APIConstants.maxBatchSize * 2 + 20
        for index in 0..<total {
            testMixpanel.track(event: "event\(index)")
        }
        waitForTrackingQueue(testMixpanel)

        let finished = expectation(description: "flush finished")
        XCTAssertTrue(testMixpanel.flush { finished.fulfill() })
        wait(for: [finished], timeout: 10)

        XCTAssertEqual(
            delegate.willFlushCount, 1,
            "the delegate should be asked once per flush, not once per batch or queue type")
        XCTAssertEqual(
            eventQueue(token: testMixpanel.apiToken).count, total,
            "sanity check: the drain ran against the fake server and left every row queued")

        testMixpanel.delegate = nil
        removeDBfile(testMixpanel.apiToken)
    }

    // MARK: - Batch size validation

    /// A zero or negative batch size must not cause infinite recursion.
    ///
    /// If batchSize is 0, each read returns empty queues. The drain loop checks
    /// `eventQueue.count == batchSize` to detect full batches; with both being 0, this is true,
    /// causing infinite recursive reschedules with no progress. Batch size must be clamped to
    /// at least 1.
    func testZeroBatchSizeIsClampedToOne() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.track(event: "event1")
        waitForTrackingQueue(testMixpanel)

        // Attempt to set batch size to 0 (should be clamped to 1)
        testMixpanel.flushBatchSize = 0
        XCTAssertGreaterThanOrEqual(
            testMixpanel.flushBatchSize, 1,
            "batch size should be clamped to at least 1")

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "flush should complete and drain queue even with 0-attempt")
        removeDBfile(testMixpanel.apiToken)
    }

    /// Negative batch sizes must also be clamped to 1.
    func testNegativeBatchSizeIsClampedToOne() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.track(event: "event1")
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flushBatchSize = -5
        XCTAssertGreaterThanOrEqual(
            testMixpanel.flushBatchSize, 1,
            "batch size should be clamped to at least 1")

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "flush should complete even with negative batch size input")
        removeDBfile(testMixpanel.apiToken)
    }

    // MARK: - Sequential queue ordering (events → people → groups)

    /// While any events remain queued, people and groups must not be touched at all.
    ///
    /// The flush drain previously loaded and sent one batch from all three queues in every
    /// iteration (events, people, and groups interleaved). It now advances to `.people` only
    /// once `.events` returns empty, matching the Android SDK's per-table drain order. A batch
    /// size of 1 and a large event count make it effectively impossible for the whole events
    /// queue to drain before this loop can observe an in-progress state.
    func testFlushDrainsEventsCompletelyBeforeTouchingPeopleOrGroups() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.flushBatchSize = 1

        let eventsTotal = 40
        for index in 0..<eventsTotal {
            testMixpanel.track(event: "event\(index)")
        }
        testMixpanel.people.set(properties: ["prop": "value"])
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        let peopleCountBefore = peopleQueue(token: testMixpanel.apiToken).count
        let groupCountBefore = groupQueue(token: testMixpanel.apiToken).count
        XCTAssertGreaterThan(peopleCountBefore, 0)
        XCTAssertGreaterThan(groupCountBefore, 0)

        testMixpanel.flush()

        // Poll while events still has rows. At every such checkpoint, people/groups must remain
        // exactly as they started — interleaved batching would have sent at least one people and
        // groups batch alongside the very first events batch. Bounded by eventsTotal so a stuck
        // drain fails the test instead of hanging.
        var observedProgress = false
        for _ in 0..<eventsTotal {
            waitForTrackingQueue(testMixpanel)
            let eventsRemaining = eventQueue(token: testMixpanel.apiToken).count
            if eventsRemaining < eventsTotal {
                observedProgress = true
            }
            if eventsRemaining == 0 {
                break
            }
            XCTAssertEqual(
                peopleQueue(token: testMixpanel.apiToken).count, peopleCountBefore,
                "people must not be touched while any events remain queued")
            XCTAssertEqual(
                groupQueue(token: testMixpanel.apiToken).count, groupCountBefore,
                "groups must not be touched while any events remain queued")
        }

        XCTAssertTrue(observedProgress, "events queue should have started draining")
        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "events queue should fully drain within this bounded loop")

        removeDBfile(testMixpanel.apiToken)
    }

    /// While any people rows remain queued, groups must not be touched. Events start with only
    /// the single "$identify" event queued by identify() below, so the drain advances past
    /// `.events` in a single iteration (sending just that one event, since flushBatchSize is 1)
    /// before this invariant is exercised.
    func testFlushDrainsPeopleCompletelyBeforeTouchingGroups() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.flushBatchSize = 1

        let peopleTotal = 40
        for index in 0..<peopleTotal {
            testMixpanel.people.set(properties: ["index": index])
        }
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        XCTAssertEqual(
            eventQueue(token: testMixpanel.apiToken).count, 1,
            "identify() above queues its own $identify event")
        let groupCountBefore = groupQueue(token: testMixpanel.apiToken).count
        XCTAssertGreaterThan(groupCountBefore, 0)

        testMixpanel.flush()

        var observedProgress = false
        for _ in 0..<(peopleTotal + 2) {
            waitForTrackingQueue(testMixpanel)
            let peopleRemaining = peopleQueue(token: testMixpanel.apiToken).count
            if peopleRemaining < peopleTotal {
                observedProgress = true
            }
            if peopleRemaining == 0 {
                break
            }
            XCTAssertEqual(
                groupQueue(token: testMixpanel.apiToken).count, groupCountBefore,
                "groups must not be touched while any people rows remain queued")
        }

        XCTAssertTrue(observedProgress, "people queue should have started draining")
        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).isEmpty,
            "people queue should fully drain within this bounded loop")

        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        XCTAssertTrue(
            groupQueue(token: testMixpanel.apiToken).isEmpty,
            "groups should drain once people is fully empty")

        removeDBfile(testMixpanel.apiToken)
    }

    /// Empty leading queue types must be skipped without error, landing on the first non-empty
    /// type. Exercises the `if !queue.isEmpty` guard around the send call (added so an empty
    /// queue never reaches `flushQueue`), together with the events → people → groups state
    /// advancement when both events and people start empty.
    func testFlushSkipsEmptyLeadingQueuesAndDrainsGroups() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)

        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).isEmpty)
        XCTAssertTrue(peopleQueue(token: testMixpanel.apiToken).isEmpty)
        XCTAssertFalse(groupQueue(token: testMixpanel.apiToken).isEmpty)

        testMixpanel.flush()
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            groupQueue(token: testMixpanel.apiToken).isEmpty,
            "groups should still drain when both preceding queue types start empty")

        removeDBfile(testMixpanel.apiToken)
    }

    /// Continuous tracking during a flush must not starve people/groups behind an
    /// ever-refilling events queue.
    ///
    /// track() and the flush's own reads share the same serial trackingQueue, so a burst of
    /// track() calls issued after flush() races ahead of the flush's later iterations (each of
    /// which only gets re-enqueued once the previous batch's network round trip completes) —
    /// landing in the table before those later reads run. Without the row-id watermark taken at
    /// flush start, the drain would keep recursing on `.events` as long as reads return rows,
    /// leaving people/groups untouched indefinitely.
    ///
    /// No delay is needed between flush() and the flood: flush() enqueues the block that takes
    /// the watermark before it returns, and every flood row is inserted by a block enqueued
    /// after it, so each one has a higher id than the watermark regardless of timing.
    func testFlushDoesNotStarvePeopleAndGroupsUnderContinuousEventTracking() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.flushBatchSize = 5

        // A small pre-flush backlog of events.
        for index in 0..<5 {
            testMixpanel.track(event: "preFlushEvent\(index)")
        }
        testMixpanel.people.set(properties: ["prop": "value"])
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        // identify() above queued its own "$identify" event ahead of the 5 tracked here.
        XCTAssertEqual(eventQueue(token: testMixpanel.apiToken).count, 6)
        XCTAssertFalse(peopleQueue(token: testMixpanel.apiToken).isEmpty)
        XCTAssertFalse(groupQueue(token: testMixpanel.apiToken).isEmpty)

        testMixpanel.flush()
        // Flood far more events than could possibly drain within a few batches, simulating
        // tracking that continuously outpaces the drain.
        for index in 0..<200 {
            testMixpanel.track(event: "duringFlushEvent\(index)")
        }

        // Poll instead of assuming a fixed wait count, so this adapts to actual network timing.
        for _ in 0..<10 {
            waitForTrackingQueue(testMixpanel)
            if peopleQueue(token: testMixpanel.apiToken).isEmpty
                && groupQueue(token: testMixpanel.apiToken).isEmpty
            {
                break
            }
        }

        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).isEmpty,
            "people must be drained even while events keep being tracked faster than they empty")
        XCTAssertTrue(
            groupQueue(token: testMixpanel.apiToken).isEmpty,
            "groups must be drained even while events keep being tracked faster than they empty")
        XCTAssertFalse(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "events tracked during this flush should be left for a later flush, not chased indefinitely")

        removeDBfile(testMixpanel.apiToken)
    }

    /// Events tracked during a flush with a backdated custom `time` must still be left for a
    /// later flush.
    ///
    /// The watermark is the SQLite row id, not the payload timestamp, so an app that overrides
    /// `time` (allowed for every property) cannot make its during-flush rows look like pre-flush
    /// backlog and keep the events drain going while people/groups starve.
    func testBackdatedEventsTrackedDuringFlushDoNotStarveOtherQueues() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.identify(distinctId: "d1")
        testMixpanel.flushBatchSize = 5

        for index in 0..<5 {
            testMixpanel.track(event: "preFlushEvent\(index)")
        }
        testMixpanel.people.set(properties: ["prop": "value"])
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        testMixpanel.flush()
        let oneHourAgo = (Date().timeIntervalSince1970 - 3600) * 1000
        for index in 0..<200 {
            testMixpanel.track(event: "backdatedEvent\(index)", properties: ["time": oneHourAgo])
        }

        for _ in 0..<10 {
            waitForTrackingQueue(testMixpanel)
            if peopleQueue(token: testMixpanel.apiToken).isEmpty
                && groupQueue(token: testMixpanel.apiToken).isEmpty
            {
                break
            }
        }

        XCTAssertTrue(
            peopleQueue(token: testMixpanel.apiToken).isEmpty,
            "people must drain even when during-flush events carry backdated timestamps")
        XCTAssertTrue(
            groupQueue(token: testMixpanel.apiToken).isEmpty,
            "groups must drain even when during-flush events carry backdated timestamps")
        XCTAssertFalse(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "backdated events tracked during the flush must be left for a later flush")

        removeDBfile(testMixpanel.apiToken)
    }

    /// A queued event with a future custom `time` must not end the events drain early.
    ///
    /// Only rows above the row-id watermark are excluded; a pre-flush row is drained whatever
    /// its payload timestamp says, so a full flush still empties the whole backlog.
    func testFutureCustomEventTimeDoesNotStopFullFlushEarly() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.flushBatchSize = 2

        let tomorrow = (Date().timeIntervalSince1970 + 86_400) * 1000
        testMixpanel.track(event: "futureEvent", properties: ["time": tomorrow])
        for index in 0..<4 {
            testMixpanel.track(event: "event\(index)")
        }
        waitForTrackingQueue(testMixpanel)
        XCTAssertEqual(eventQueue(token: testMixpanel.apiToken).count, 5)

        let finished = expectation(description: "flush finished")
        testMixpanel.flush {
            finished.fulfill()
        }
        wait(for: [finished], timeout: 30)
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            eventQueue(token: testMixpanel.apiToken).isEmpty,
            "every pre-flush event should be sent regardless of its custom time")

        removeDBfile(testMixpanel.apiToken)
    }

    /// `maxRowId` and `readRows(maxRowId:)` agree exactly at the boundary: the watermark row is
    /// included, the next row is excluded, and an empty table yields a watermark that reads
    /// nothing.
    func testReadRowsHonorsRowIdWatermarkBoundary() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        XCTAssertEqual(mpdb.maxRowId(.events), 0, "an empty table has no rows to watermark")
        XCTAssertTrue(
            mpdb.readRows(.events, numRows: 100, maxRowId: 0).isEmpty,
            "a watermark of 0 must read nothing")

        for index in 0..<3 {
            let event: InternalProperties = ["event": "event\(index)", "properties": ["index": index]]
            mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(event)!)
        }
        let watermark = mpdb.maxRowId(.events)
        XCTAssertGreaterThan(watermark, 0)

        let late: InternalProperties = ["event": "late", "properties": ["index": 3]]
        mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(late)!)
        XCTAssertEqual(mpdb.maxRowId(.events), watermark + 1, "ids are consecutive AUTOINCREMENT")

        let bounded = mpdb.readRows(.events, numRows: 100, maxRowId: watermark)
        XCTAssertEqual(
            bounded.compactMap { $0["event"] as? String }, ["event0", "event1", "event2"],
            "the watermark row is included and the row after it is excluded")
        XCTAssertEqual(bounded.last?["id"] as? Int32, watermark)

        let unbounded = mpdb.readRows(.events, numRows: 100)
        XCTAssertEqual(unbounded.count, 4, "without a watermark every row is read")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    /// An oversized entity must be rejected at save time, never written to SQLite.
    ///
    /// `readRows` already drops rows over `maxRowByteSize`, but that is a safety net for rows
    /// written by older SDK versions; new ones should never reach disk. `maxRowId` proves the
    /// row was skipped rather than inserted and later dropped.
    func testSaveEntityRejectsOversizedRowBeforeInsert() {
        let token = randomId()
        let persistence = MixpanelPersistence(instanceName: token)

        persistence.saveEntity(["event": "first", "properties": ["index": 1]], type: .events)
        let oversized: InternalProperties = [
            "event": "oversized",
            "properties": ["blob": String(repeating: "a", count: APIConstants.maxRowByteSize)],
        ]
        persistence.saveEntity(oversized, type: .events)
        persistence.saveEntity(["event": "last", "properties": ["index": 2]], type: .events)

        XCTAssertEqual(
            persistence.mpdb.maxRowId(.events), 2,
            "only the two valid rows should have been inserted")
        XCTAssertEqual(
            persistence.loadEntitiesInBatch(type: .events).compactMap { $0["event"] as? String },
            ["first", "last"])

        persistence.closeDB()
        removeDBfile(token)
    }

    /// A row whose data column is NULL or zero-length must be deleted, not left in place.
    ///
    /// Such a row is never returned, so if it were not deleted it would occupy a slot in every
    /// bounded read forever and permanently hide the valid rows behind it. A one-row window makes
    /// that stall visible: the first read drops the empty row, and the second must reach the
    /// valid one.
    func testEmptyDataRowIsDeletedSoItCannotBlockTheQueue() {
        let mpdb = MPDB.init(token: randomId())
        mpdb.open()

        mpdb.insertRow(.events, data: Data())
        XCTAssertEqual(mpdb.maxRowId(.events), 1, "the empty row must actually be inserted")
        let valid: InternalProperties = ["event": "valid", "properties": ["index": 1]]
        mpdb.insertRow(.events, data: JSONHandler.serializeJSONObject(valid)!)

        XCTAssertTrue(
            mpdb.readRows(.events, numRows: 1).isEmpty,
            "the first one-row window holds only the empty row, which is dropped")
        XCTAssertEqual(
            mpdb.readRows(.events, numRows: 1).compactMap { $0["event"] as? String }, ["valid"],
            "the empty row must be gone so the next window reaches the valid row")

        mpdb.close()
        removeDBfile(mpdb.apiToken)
    }

    /// reset() must still send what was queued before it, under the pre-reset identity.
    ///
    /// Queued events and identified people rows already carry their distinct id, so reset keeps
    /// them rather than deleting them, and the flush it starts sends them under the user who
    /// created them. People rows must not be re-stamped with the post-reset identity when read.
    func testResetSendsPendingDataUnderPreResetIdentity() {
        RecordingURLProtocol.reset()
        URLProtocol.registerClass(RecordingURLProtocol.self)
        defer { URLProtocol.unregisterClass(RecordingURLProtocol.self) }

        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        testMixpanel.serverURL = kFakeServerUrl
        testMixpanel.identify(distinctId: "userBeforeReset")
        testMixpanel.track(event: "beforeReset")
        testMixpanel.people.set(properties: ["prop": "value"])
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        let resetFinished = expectation(description: "reset finished")
        testMixpanel.reset {
            resetFinished.fulfill()
        }
        wait(for: [resetFinished], timeout: 10)
        waitForTrackingQueue(testMixpanel)

        let requests = RecordingURLProtocol.requests()
        let paths = Set(requests.map { $0.path })
        XCTAssertTrue(paths.contains("/track"), "pending events should be sent after reset")
        XCTAssertTrue(paths.contains("/engage"), "pending people updates should be sent after reset")
        XCTAssertTrue(paths.contains("/groups"), "pending group updates should be sent after reset")
        XCTAssertTrue(
            requests.contains { $0.path == "/engage" && $0.body.contains("userBeforeReset") },
            "people updates must keep the pre-reset distinct id")

        removeDBfile(testMixpanel.apiToken)
    }

    /// Profile updates made before any identify() must not survive reset() and attach to the
    /// next identified user.
    func testResetDiscardsUnidentifiedPeopleUpdates() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
        let persistence = MixpanelPersistence(instanceName: testMixpanel.apiToken)
        testMixpanel.people.set(properties: ["anonymousProp": "value"])
        waitForTrackingQueue(testMixpanel)
        XCTAssertFalse(
            persistence.loadEntitiesInBatch(
                type: .people, flag: PersistenceConstant.unIdentifiedFlag
            ).isEmpty,
            "a profile update before identify() is queued as unidentified")

        testMixpanel.reset()
        testMixpanel.identify(distinctId: "nextUser")
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(
            persistence.loadEntitiesInBatch(
                type: .people, flag: PersistenceConstant.unIdentifiedFlag
            ).isEmpty,
            "reset should discard unidentified profile updates")
        XCTAssertFalse(
            peopleQueue(token: testMixpanel.apiToken).contains {
                ($0["$set"] as? InternalProperties)?["anonymousProp"] != nil
            },
            "pre-reset anonymous updates must not be attributed to the next identified user")

        persistence.closeDB()
        removeDBfile(testMixpanel.apiToken)
    }
}
