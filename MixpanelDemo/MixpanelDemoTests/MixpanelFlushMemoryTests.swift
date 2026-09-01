//
//  MixpanelFlushMemoryTests.swift
//  MixpanelDemo
//
//  Regression coverage for the flush-path fixes that bound how much is deserialized into
//  memory at once. Each test here corresponds to a crash mode that produced an
//  NSMallocException inside JSONSerialization during MPDB.readRows.
//

import XCTest

@testable import Mixpanel

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

    /// Excluding automatic events must tolerate a row with no `event` key.
    ///
    /// The filter used to force-unwrap `$0["event"] as! String`, so a single malformed row took
    /// the process down on every flush. Such a row is kept and left for the API to reject.
    func testExcludingAutomaticEventsToleratesRowWithoutEventKey() {
        let token = randomId()
        let persistence = MixpanelPersistence(instanceName: token)

        persistence.saveEntity(["properties": ["index": 1]], type: .events)
        persistence.saveEntity(["event": "real", "properties": ["index": 2]], type: .events)
        persistence.saveEntity(["event": "$ae_session", "properties": ["index": 3]], type: .events)

        let entities = persistence.loadEntitiesInBatch(type: .events, excludeAutomaticEvents: true)

        XCTAssertEqual(entities.count, 2, "the malformed row should be kept and $ae_ excluded")
        XCTAssertNil(entities.first?["event"], "the malformed row should be the first one kept")
        XCTAssertEqual(entities.last?["event"] as? String, "real")

        persistence.closeDB()
        removeDBfile(token)
    }

    // MARK: - Drain loop

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
        // Each waitForTrackingQueue pass drains two read → send iterations of the chain;
        // three batches need two passes.
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

        // Claims the flush slot, then parks in mixpanelWillFlush on the tracking queue.
        testMixpanel.flush()

        // Every one of these must be dropped by the coalescing guard while the first is parked.
        for _ in 0..<5 {
            testMixpanel.flush()
        }

        delegate.shouldGate = false
        delegate.openGate()
        waitForTrackingQueue(testMixpanel)

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
}
