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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)

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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
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

    // MARK: - Batch size validation

    /// A zero or negative batch size must not cause infinite recursion.
    ///
    /// If batchSize is 0, each read returns empty queues. The drain loop checks
    /// `eventQueue.count == batchSize` to detect full batches; with both being 0, this is true,
    /// causing infinite recursive reschedules with no progress. Batch size must be clamped to
    /// at least 1.
    func testZeroBatchSizeIsClampedToOne() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
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

    /// While any people rows remain queued, groups must not be touched. Events start empty here
    /// so the drain advances past `.events` in a single (empty) iteration before this invariant
    /// is exercised.
    func testFlushDrainsPeopleCompletelyBeforeTouchingGroups() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
        testMixpanel.flushBatchSize = 1

        let peopleTotal = 40
        for index in 0..<peopleTotal {
            testMixpanel.people.set(properties: ["index": index])
        }
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        XCTAssertTrue(eventQueue(token: testMixpanel.apiToken).isEmpty)
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
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)

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
    /// track() calls issued immediately after flush() races ahead of the flush's later
    /// iterations (each of which only gets re-enqueued once the previous batch's network round
    /// trip completes) — landing in the table before those later reads run. This reliably
    /// produces reads whose rows were tracked after the flush began, exercising the
    /// flushStartTime watermark: without it, the drain would keep recursing on `.events` as
    /// long as reads return rows, leaving people/groups untouched within this bounded wait
    /// window (it would still finish eventually, once the flood itself ran out, just far later
    /// than the few passes given below).
    func testFlushDoesNotStarvePeopleAndGroupsUnderContinuousEventTracking() {
        let testMixpanel = Mixpanel.initialize(
            token: randomId(), flushInterval: 60, trackAutomaticEvents: false)
        testMixpanel.flushBatchSize = 5

        // A small pre-flush backlog of events.
        for index in 0..<5 {
            testMixpanel.track(event: "preFlushEvent\(index)")
        }
        testMixpanel.people.set(properties: ["prop": "value"])
        testMixpanel.getGroup(groupKey: "company", groupID: "mixpanel").set(properties: ["prop": "value"])
        waitForTrackingQueue(testMixpanel)

        XCTAssertEqual(eventQueue(token: testMixpanel.apiToken).count, 5)
        XCTAssertFalse(peopleQueue(token: testMixpanel.apiToken).isEmpty)
        XCTAssertFalse(groupQueue(token: testMixpanel.apiToken).isEmpty)

        testMixpanel.flush()
        // Flood far more events than could possibly drain within the bounded wait below,
        // simulating tracking that continuously outpaces the drain.
        for index in 0..<200 {
            testMixpanel.track(event: "duringFlushEvent\(index)")
        }

        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)
        waitForTrackingQueue(testMixpanel)

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
}
