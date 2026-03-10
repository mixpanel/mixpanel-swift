//
//  MixpanelEventBridgeTests.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-03-03.
//

import XCTest
@testable import Mixpanel

class MixpanelEventBridgeTests: XCTestCase {

    var bridge: MixpanelEventBridge!

    override func setUp() {
        super.setUp()
        bridge = MixpanelEventBridge.shared
        bridge.removeAllListeners()
    }

    override func tearDown() {
        bridge.removeAllListeners()
        super.tearDown()
    }

    // MARK: - Event Struct Tests

    func testEventStructCreation() {
        let event = MixpanelEventBridgeEvent(
            name: "test_event",
            properties: ["key": "value", "number": 42]
        )

        XCTAssertEqual(event.name, "test_event")
        XCTAssertEqual(event.properties["key"] as? String, "value")
        XCTAssertEqual(event.properties["number"] as? Int, 42)
    }

    // MARK: - Listener Registration Tests

    func testRegisterListener() {
        let listener = MockEventListener()
        bridge.registerListener(listener)

        let expectation = XCTestExpectation(description: "Listener receives event")
        listener.onEventTracked = { event in
            XCTAssertEqual(event.name, "test")
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: [:]
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testUnregisterListener() {
        let listener = MockEventListener()
        bridge.registerListener(listener)
        bridge.unregisterListener(listener)

        listener.onEventTracked = { _ in
            XCTFail("Listener should not receive events after unregistering")
        }

        bridge.notifyListeners(
            event: "test",
            properties: [:]
        )

        // Wait a bit to ensure no events are received
        let expectation = XCTestExpectation(description: "No events received")
        expectation.isInverted = true
        wait(for: [expectation], timeout: 0.5)
    }

    func testRemoveAllListeners() {
        let listener1 = MockEventListener()
        let listener2 = MockEventListener()
        bridge.registerListener(listener1)
        bridge.registerListener(listener2)

        bridge.removeAllListeners()

        var eventCount = 0
        listener1.onEventTracked = { _ in eventCount += 1 }
        listener2.onEventTracked = { _ in eventCount += 1 }

        bridge.notifyListeners(
            event: "test",
            properties: [:]
        )

        // Wait a bit to ensure no events are received
        let expectation = XCTestExpectation(description: "No events received")
        expectation.isInverted = true
        wait(for: [expectation], timeout: 0.5)

        XCTAssertEqual(eventCount, 0)
    }

    func testDuplicateRegistrationIgnored() {
        let listener = MockEventListener()
        bridge.registerListener(listener)
        bridge.registerListener(listener) // Register again

        var eventCount = 0
        listener.onEventTracked = { _ in
            eventCount += 1
        }

        let expectation = XCTestExpectation(description: "Listener receives event once")
        expectation.expectedFulfillmentCount = 1

        listener.onEventTracked = { _ in
            eventCount += 1
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: [:]
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventCount, 1, "Event should be received only once")
    }

    // MARK: - Property Filtering Tests

    func testPropertyFilterAllowAll() {
        let listener = MockEventListener()
        listener.filterMode = .allowAll
        bridge.registerListener(listener)

        let expectation = XCTestExpectation(description: "Listener receives all properties")
        listener.onEventTracked = { event in
            XCTAssertEqual(event.properties.count, 3)
            XCTAssertNotNil(event.properties["name"])
            XCTAssertNotNil(event.properties["email"])
            XCTAssertNotNil(event.properties["phone"])
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: ["name": "John", "email": "john@example.com", "phone": "123"],
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testPropertyFilterBlockList() {
        let listener = MockEventListener()
        listener.filterMode = .blockList(["email", "phone"])
        bridge.registerListener(listener)

        let expectation = XCTestExpectation(description: "Listener receives filtered properties")
        listener.onEventTracked = { event in
            XCTAssertEqual(event.properties.count, 1)
            XCTAssertNotNil(event.properties["name"])
            XCTAssertNil(event.properties["email"])
            XCTAssertNil(event.properties["phone"])
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: ["name": "John", "email": "john@example.com", "phone": "123"],
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testPropertyFilterAllowList() {
        let listener = MockEventListener()
        listener.filterMode = .allowList(["name"])
        bridge.registerListener(listener)

        let expectation = XCTestExpectation(description: "Listener receives only allowed properties")
        listener.onEventTracked = { event in
            XCTAssertEqual(event.properties.count, 1)
            XCTAssertNotNil(event.properties["name"])
            XCTAssertNil(event.properties["email"])
            XCTAssertNil(event.properties["phone"])
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: ["name": "John", "email": "john@example.com", "phone": "123"],
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testMultipleListenersWithDifferentFilters() {
        let listener1 = MockEventListener()
        listener1.filterMode = .allowAll

        let listener2 = MockEventListener()
        listener2.filterMode = .blockList(["email"])

        bridge.registerListener(listener1)
        bridge.registerListener(listener2)

        let expectation1 = XCTestExpectation(description: "Listener 1 receives all properties")
        let expectation2 = XCTestExpectation(description: "Listener 2 receives filtered properties")

        listener1.onEventTracked = { event in
            XCTAssertEqual(event.properties.count, 2)
            expectation1.fulfill()
        }

        listener2.onEventTracked = { event in
            XCTAssertEqual(event.properties.count, 1)
            XCTAssertNotNil(event.properties["name"])
            XCTAssertNil(event.properties["email"])
            expectation2.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: ["name": "John", "email": "john@example.com"],
        )

        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    // MARK: - Weak Reference Tests

    func testWeakReferenceCleanup() {
        var listener: MockEventListener? = MockEventListener()
        bridge.registerListener(listener!)

        // Create weak reference
        weak var weakListener = listener

        // Deallocate listener
        listener = nil

        // Verify cleanup happens
        let expectation = XCTestExpectation(description: "Listener should be cleaned up")
        expectation.isInverted = true

        weakListener?.onEventTracked = { _ in
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: [:]
        )

        wait(for: [expectation], timeout: 0.5)
        XCTAssertNil(weakListener)
    }

    // MARK: - Async Dispatch Tests

    func testAsyncDispatch() {
        let listener = MockEventListener()
        bridge.registerListener(listener)

        let expectation = XCTestExpectation(description: "Event dispatched asynchronously")
        listener.onEventTracked = { _ in
            // Verify we're not on the main thread
            XCTAssertFalse(Thread.isMainThread)
            expectation.fulfill()
        }

        bridge.notifyListeners(
            event: "test",
            properties: [:]
        )

        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Mock Listener

class MockEventListener: MixpanelEventListener {

    var filterMode: PropertyFilterMode = .allowAll
    var onEventTracked: ((MixpanelEventBridgeEvent) -> Void)?

    var propertyFilterMode: PropertyFilterMode {
        return filterMode
    }

    func mixpanelDidTrackEvent(_ event: MixpanelEventBridgeEvent) {
        onEventTracked?(event)
    }
}
