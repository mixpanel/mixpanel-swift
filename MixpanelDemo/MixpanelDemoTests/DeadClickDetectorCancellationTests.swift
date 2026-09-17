//
//  DeadClickDetectorCancellationTests.swift
//  MixpanelDemoTests
//
//  Copyright (c) Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

#if os(iOS)

/// Tests that a new tap always supersedes the pending dead-click check, matching Android's
/// `DeadClickDetector.startDetection`.
///
/// These drive `DeadClickDetector` directly against an offscreen window whose hierarchy never
/// changes, so a check that survives cancellation always fires. That isolates the cancellation
/// contract from incidental UI changes, which would otherwise suppress the event for the wrong
/// reason and make the tests pass vacuously.
class DeadClickDetectorCancellationTests: XCTestCase {

    /// Short enough to keep the suite fast, long enough that a second tap lands inside it.
    private let timeWindowMs = 150
    private var timeWindow: TimeInterval { Double(timeWindowMs) / 1000 }

    private var detector: DeadClickDetector!
    private var window: UIWindow!
    private var button: UIButton!
    private var label: UILabel!
    private var toggle: UISwitch!
    private var deadClicks: [ClickEvent] = []

    override func setUp() {
        super.setUp()

        // Deliberately not attached to a window scene: `captureSnapshot` then reports a constant
        // window count, so nothing another test's windows do can look like a UI response here.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 44)
        button.accessibilityIdentifier = "dead_btn"

        label = UILabel(frame: CGRect(x: 0, y: 50, width: 100, height: 44))
        label.text = "static text"

        toggle = UISwitch(frame: CGRect(x: 0, y: 100, width: 51, height: 31))

        for view in [button, label, toggle] as [UIView] {
            window.addSubview(view)
        }
        window.layoutIfNeeded()

        deadClicks = []
        detector = DeadClickDetector(options: DeadClickOptions(timeWindowMs: timeWindowMs))
        detector.onDeadClick = { [weak self] event in
            self?.deadClicks.append(event)
        }
    }

    override func tearDown() {
        detector.cancelPendingCheck()
        detector = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testEligibleTapReplacesPreviousPendingCheck() {
        tap(button, elementId: "first")
        tap(button, elementId: "second")

        waitPastTimeWindow()

        // The first check is cancelled, not merely deduplicated: exactly one event, for the tap
        // that is still pending.
        XCTAssertEqual(deadClicks.map(\.elementId), ["second"])
    }

    func testNonInteractiveTapCancelsPreviousCheckWithoutStartingAnother() {
        tap(button, elementId: "first")
        tap(label, elementId: "plain_text", isInteractive: false)

        waitPastTimeWindow()

        XCTAssertTrue(
            deadClicks.isEmpty,
            "A non-interactive tap must cancel the pending check and start no replacement")
    }

    func testExcludedControlTapCancelsPreviousCheckWithoutStartingAnother() {
        XCTAssertTrue(detector.shouldExclude(view: toggle), "UISwitch is expected to be excluded")

        tap(button, elementId: "first")
        tap(toggle, elementId: "toggle")

        waitPastTimeWindow()

        XCTAssertTrue(
            deadClicks.isEmpty,
            "An excluded-control tap must cancel the pending check and start no replacement")
    }

    func testExplicitCancellationPreventsTheEvent() {
        tap(button, elementId: "first")
        detector.cancelPendingCheck()

        waitPastTimeWindow()

        XCTAssertTrue(deadClicks.isEmpty, "A cancelled timer must not emit the previous tap")
    }

    func testSupersededTimerCannotEmitTheReplacementEarly() {
        tap(button, elementId: "first")
        // Stagger the taps so the first timer expires well before the second one does.
        wait(timeWindow * 0.5)
        tap(button, elementId: "second")

        // The first tap's timer has now expired. It must stay silent rather than firing the
        // second tap's check before that tap's own window has elapsed.
        wait(timeWindow * 0.6)
        XCTAssertTrue(deadClicks.isEmpty, "The superseded timer must not fire the pending check")

        waitPastTimeWindow()
        XCTAssertEqual(deadClicks.map(\.elementId), ["second"])
    }

    func testEligibleTapWithNoResponseStillEmitsAfterTimeout() {
        tap(button, elementId: "only")

        waitPastTimeWindow()

        XCTAssertEqual(deadClicks.map(\.elementId), ["only"])
    }

    // MARK: - Helpers

    private func tap(_ view: UIView, elementId: String, isInteractive: Bool = true) {
        let event = ClickEvent(
            x: view.frame.midX, y: view.frame.midY, elementId: elementId,
            tagName: String(describing: type(of: view)), isInteractive: isInteractive)
        detector.startMonitoring(event: event, view: view, in: window)
    }

    /// Advance past a full time window plus scheduling slack, pumping the run loop so the
    /// detector's main-thread check can run.
    private func waitPastTimeWindow() {
        wait(timeWindow + 0.35)
    }

    private func wait(_ seconds: TimeInterval) {
        let expectation = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { expectation.fulfill() }
        wait(for: [expectation], timeout: seconds + 5)
    }
}

#endif
