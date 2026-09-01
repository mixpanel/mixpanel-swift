//
//  AutocaptureUIKitInstrumentedTests.swift
//  MixpanelDemoTests
//
//  Created by Mixpanel on 2026-06-29.
//  Copyright (c) Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

#if os(iOS)

/// Instrumented tests for UIKit autocapture functionality.
///
/// These tests verify that touch events on UIKit views are correctly captured
/// and transformed into Mixpanel autocapture events ($mp_click, $mp_rage_click, $mp_dead_click).
///
/// Test coverage mirrors the Android AutocaptureInstrumentedTest:
/// 1. Basic click event capture with property verification
/// 2. Element ID resolution rules (accessibilityIdentifier > accessibilityLabel > hash)
/// 3. Rage click detection
/// 4. Dead click detection
/// 5. Multiple clicks generate multiple events
/// 6. Standard Mixpanel properties
class AutocaptureUIKitInstrumentedTests: MixpanelBaseTests {

    // MARK: - Properties

    private var testWindow: UIWindow!
    private var testViewController: UIKitAutocaptureTestViewController!
    private var mixpanel: MixpanelInstance!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()

        // Create test window and view controller on main thread
        let setupExpectation = expectation(description: "Setup complete")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create test window
            self.testWindow = UIWindow(frame: UIScreen.main.bounds)
            self.testViewController = UIKitAutocaptureTestViewController()
            self.testWindow.rootViewController = self.testViewController
            self.testWindow.makeKeyAndVisible()

            // Force layout
            self.testWindow.layoutIfNeeded()

            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 5)

        // Initialize Mixpanel with autocapture
        let token = randomId()
        let autocaptureOptions = AutocaptureOptions(
            clickOptions: ClickOptions(enabled: true),
            rageClickOptions: RageClickOptions(enabled: true, clickThreshold: 4, timeWindowMs: 1000),
            deadClickOptions: DeadClickOptions(enabled: true, timeWindowMs: 500)
        )

        let options = MixpanelOptions(
            token: token,
            flushInterval: 60,
            instanceName: token,
            trackAutomaticEvents: false,
            optOutTrackingByDefault: false,
            serverURL: kFakeServerUrl,
            autocaptureOptions: autocaptureOptions
        )

        mixpanel = Mixpanel.initialize(options: options)

        // Wait for autocapture to start
        waitForAsyncTasks()
    }

    override func tearDown() {
        // Clean up on main thread
        let teardownExpectation = expectation(description: "Teardown complete")
        DispatchQueue.main.async { [weak self] in
            self?.testWindow?.isHidden = true
            self?.testWindow = nil
            self?.testViewController = nil
            teardownExpectation.fulfill()
        }
        wait(for: [teardownExpectation], timeout: 5)

        // Clean up Mixpanel
        if let token = mixpanel?.apiToken {
            removeDBfile(token)
        }
        super.tearDown()
    }

    // MARK: - Test 1: Basic Click Event

    func testUIKitClickEventBasic() {
        // Given: A button with accessibilityIdentifier
        let button = testViewController.rule1Button

        // When: Simulate tap on the button
        simulateTap(on: button)

        // Then: Verify $mp_click event is captured with correct properties
        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            XCTAssertEqual(props["$el_id"] as? String, "rule1_btn")
            XCTAssertEqual(props["$el_tag_name"] as? String, "UIButton")
            XCTAssertNotNil(props["$x"], "Should have $x coordinate")
            XCTAssertNotNil(props["$y"], "Should have $y coordinate")
        }
    }

    // MARK: - Test 1a: accessibilityIdentifier outranks accessibilityLabel

    /// When a view carries both, the identifier wins $el_id — it is developer-assigned and never
    /// user-visible, so unlike a label it cannot carry PII. The label still travels as
    /// $attr-aria-label.
    func testElementIdIdentifierWinsOverLabel() {
        let button = testViewController.bothButton

        simulateTap(on: button)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            XCTAssertEqual(props["$el_id"] as? String, "both_id")
            XCTAssertEqual(props["$attr-aria-label"] as? String, "Both Label")
        }
    }

    // MARK: - Test 2: Element ID Resolution Rule 2 (accessibilityLabel fallback)

    func testElementIdResolutionRule2() {
        // Given: A button with only accessibilityLabel (no accessibilityIdentifier)
        let button = testViewController.rule2Button

        // When: Simulate tap
        simulateTap(on: button)

        // Then: Element ID should use accessibilityLabel
        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            XCTAssertEqual(props["$el_id"] as? String, "Rule Two Label")
        }
    }

    // MARK: - Test 3: Element ID Resolution Rule 3 (Hash fallback)

    func testElementIdResolutionRule3HashFallback() {
        // Given: A button with no accessibilityIdentifier and no accessibilityLabel
        let button = testViewController.rule3Button

        // When: Simulate tap
        simulateTap(on: button)

        // Then: Element ID should use hash format: ClassName_<hash>
        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertTrue(
                elId.hasPrefix("UIButton_"),
                "Expected hash fallback format, got: \(elId)")
        }
    }

    // MARK: - Test: Child text does not leak when accessibilityLabel is not set

    /// A clickable container with child text but no explicit accessibilityLabel must
    /// not leak the child's visible text into $attr-aria-label or $el_id.
    ///
    /// Simulates a React Native Pressable where the developer did not set
    /// accessibilityLabel. The container has isAccessibilityElement=false and a child
    /// UILabel. UIKit auto-derives accessibilityLabel from child text — the SDK must
    /// not capture that auto-derived value.
    func testNotAccessibleElement_ChildTextDoesNotLeakIntoAriaLabel() {
        let view = testViewController.notAccessibleView

        simulateTap(on: view)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should still be captured")

        if let props = event?.properties {
            // $el_id must NOT contain the child label text
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertFalse(
                elId.contains("Sensitive"),
                "$el_id should not contain child text. Got: \(elId)")

            // $attr-aria-label must be absent — auto-derived label must not leak
            XCTAssertNil(
                props["$attr-aria-label"],
                "$attr-aria-label must not be present when accessibilityLabel is auto-derived")
        }
    }

    // MARK: - Test: Empty accessibilityLabel on UIButton with sensitive title

    /// UIButton with title "4111-1111-1111-1234" and accessibilityLabel="".
    /// The button title must not leak into $attr-aria-label or $el_id.
    func testEmptyAccessibilityLabel_ButtonTitleDoesNotLeak() {
        let button = testViewController.emptyLabelButton

        simulateTap(on: button)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should still be captured")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertFalse(
                elId.contains("4111"),
                "$el_id should not contain button title. Got: \(elId)")

            let ariaLabel = props["$attr-aria-label"] as? String
            XCTAssertTrue(
                ariaLabel == nil || !ariaLabel!.contains("4111"),
                "$attr-aria-label should not contain button title. Got: \(ariaLabel ?? "nil")")
        }
    }

    // MARK: - Visibility Tests

    /// A hidden button (isHidden=true) must not produce autocapture events.
    /// Validates that neither the accessibilityIdentifier nor the accessibilityLabel
    /// of the hidden view leaks into event attributes ($el_id, $attr-aria-label).
    func testHiddenView_NoEventCaptured() {
        let button = testViewController.hiddenButton

        // Directly invoke handleTouch — bypasses hitTest to test extraction guard
        simulateTap(on: button)

        Thread.sleep(forTimeInterval: 0.5)
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let matchingEvents = events.filter {
            guard let props = $0["properties"] as? [String: Any] else { return false }
            let elId = props["$el_id"] as? String ?? ""
            let ariaLabel = props["$attr-aria-label"] as? String ?? ""
            return elId.contains("hidden_btn") || elId.contains("Hidden Sensitive")
                || ariaLabel.contains("Hidden Sensitive")
        }

        XCTAssertEqual(
            matchingEvents.count, 0,
            "Hidden view's identifier and accessibilityLabel must not appear in autocapture events")
    }

    /// A zero-alpha button (alpha=0, fully transparent) must not produce
    /// autocapture events. Validates that neither the accessibilityIdentifier
    /// nor the accessibilityLabel leaks into event attributes.
    func testZeroAlphaView_NoEventCaptured() {
        let button = testViewController.zeroAlphaButton

        simulateTap(on: button)

        Thread.sleep(forTimeInterval: 0.5)
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let matchingEvents = events.filter {
            guard let props = $0["properties"] as? [String: Any] else { return false }
            let elId = props["$el_id"] as? String ?? ""
            let ariaLabel = props["$attr-aria-label"] as? String ?? ""
            return elId.contains("zero_alpha_btn") || elId.contains("ZeroAlpha Sensitive")
                || ariaLabel.contains("ZeroAlpha Sensitive")
        }

        XCTAssertEqual(
            matchingEvents.count, 0,
            "Zero-alpha view's identifier and accessibilityLabel must not appear in autocapture events")
    }

    // MARK: - Accessibility Guard Tests

    /// Scenario 2: View IS accessible (isAccessibilityElement=true) but has no explicit
    /// accessibilityLabel. UIKit auto-derives label from child text — the SDK must NOT
    /// capture that auto-derived value.
    func testAccessibleNoLabel_ChildTextDoesNotLeak() {
        let view = testViewController.accessibleNoLabelView

        simulateTap(on: view)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should still be captured")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertFalse(
                elId.contains("Sensitive") || elId.contains("5678"),
                "$el_id should not contain child text. Got: \(elId)")

            XCTAssertNil(
                props["$attr-aria-label"],
                "$attr-aria-label must not be present when accessibilityLabel is auto-derived")
        }
    }

    /// Scenario 4: View is NOT accessible (isAccessibilityElement=false) but HAS an
    /// explicit accessibilityLabel. The label must NOT be captured because the view
    /// is not an accessibility element.
    func testNotAccessibleWithLabel_LabelDoesNotLeak() {
        let view = testViewController.notAccessibleWithLabelView

        simulateTap(on: view)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should still be captured")

        if let props = event?.properties {
            // Neither accessibilityLabel nor child text must appear in $el_id
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertFalse(
                elId.contains("Sensitive") || elId.contains("9999"),
                "$el_id should not contain accessibilityLabel. Got: \(elId)")
            XCTAssertFalse(
                elId.contains("Some Label"),
                "$el_id should not contain child text. Got: \(elId)")

            // $attr-aria-label must be absent — neither label nor child text
            XCTAssertNil(
                props["$attr-aria-label"],
                "$attr-aria-label must not be present when view is not accessible")
        }
    }

    /// Positive case: View IS accessible AND HAS explicit accessibilityLabel.
    /// The label SHOULD be captured in $el_id and $attr-aria-label.
    func testAccessibleWithLabel_LabelIsCaptured() {
        let view = testViewController.accessibleWithLabelView

        simulateTap(on: view)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should be captured")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "Intended Label",
                "$el_id should use the explicit accessibilityLabel")

            XCTAssertEqual(
                props["$attr-aria-label"] as? String, "Intended Label",
                "$attr-aria-label should be present with explicit label")
        }
    }

    // MARK: - Test 4: Rage Click Detection

    func testRageClickDetection() {
        // Given: A button designated for rage click testing
        let button = testViewController.rageButton

        // When: Perform 4 rapid taps
        for _ in 0..<4 {
            simulateTap(on: button)
            Thread.sleep(forTimeInterval: 0.1)  // Small delay between taps
        }

        // Then: Should capture $mp_rage_click event
        let rageEvent = waitForEvent(named: "$mp_rage_click", timeout: 5)
        XCTAssertNotNil(rageEvent, "Should capture $mp_rage_click after 4 rapid taps")

        if let props = rageEvent?.properties {
            XCTAssertEqual(props["$el_id"] as? String, "rage_btn")
        }
    }

    // MARK: - Test 5: Dead Click Detection

    func testDeadClickDetection() {
        // Given: A button with no action handler (dead click scenario)
        let button = testViewController.deadButton

        // When: Simulate tap and wait for dead click timeout
        simulateTap(on: button)

        // Then: Should capture $mp_click first
        let clickEvent = waitForEvent(named: "$mp_click", timeout: 3)
        XCTAssertNotNil(clickEvent, "Should capture $mp_click event")

        // Then: Should capture $mp_dead_click after timeout (500ms + buffer)
        let deadEvent = waitForEvent(named: "$mp_dead_click", timeout: 3)
        XCTAssertNotNil(deadEvent, "Should capture $mp_dead_click for non-interactive element")

        if let props = deadEvent?.properties {
            XCTAssertEqual(props["$el_id"] as? String, "dead_btn")
        }
    }

    // MARK: - Test 6: Multiple Clicks Generate Multiple Events

    func testMultipleClicksGenerateMultipleEvents() {
        // Given: Three different buttons
        let button1 = testViewController.rule1Button
        let button2 = testViewController.rule2Button
        let button3 = testViewController.bothButton

        // When: Tap each button sequentially
        simulateTap(on: button1)
        Thread.sleep(forTimeInterval: 0.3)

        simulateTap(on: button2)
        Thread.sleep(forTimeInterval: 0.3)

        simulateTap(on: button3)

        // Then: Should capture 3 separate $mp_click events
        Thread.sleep(forTimeInterval: 0.5)  // Wait for all events
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let clickEvents = events.filter { ($0["event"] as? String) == "$mp_click" }
        XCTAssertEqual(clickEvents.count, 3, "Should capture exactly 3 click events")
    }

    // MARK: - Test 7: Standard Properties Included

    func testClickEventHasTokenProperty() {
        // Given: A button
        let button = testViewController.rule1Button

        // When: Simulate tap
        simulateTap(on: button)

        // Wait for the event rather than reading the queue straight after the tap: autocapture
        // hands click processing to a background queue, so emission no longer happens inline with
        // the touch. waitForEvent polls and drains the tracking queue on each attempt.
        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should have autocapture events in queue")

        // Then: Should have standard Mixpanel properties
        if let props = event?.properties {
            XCTAssertNotNil(props["distinct_id"], "Should have distinct_id")
            XCTAssertNotNil(props["token"], "Should have token")
        }
    }

    // MARK: - Test 8: Swipe-back-to-same-position does NOT fire click

    /// Regression test: a swipe that returns to the starting position must NOT register as a tap.
    ///
    /// Before the fix, displacement was only checked at `touchesEnded` by comparing final vs initial
    /// position. A quick swipe down-and-back-up would falsely pass the check. Now, `touchesMoved`
    /// tracks max displacement and rejects the gesture if any move exceeds the slop threshold.
    func testSwipeBackToSamePositionDoesNotFireClick() {
        // Test the production TouchObservingGestureRecognizer's slop logic directly.
        // Create the real GR wired to a TouchInterceptor → autocaptureManager,
        // so a detected tap would produce a real $mp_click event in the queue.
        let gestureExpectation = expectation(description: "Gesture test complete")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.testWindow,
                let manager = self.mixpanel.autocaptureManager
            else {
                gestureExpectation.fulfill()
                return
            }

            // Create a real TouchInterceptor and wire it to the autocapture manager.
            // install() sets the manager reference (may not find the test window
            // via UIApplication.shared.windows, which is fine — we add the GR manually).
            let interceptor = TouchInterceptor()
            interceptor.install(manager: manager)

            // Create the production GR with the interceptor as owner.
            // target/action unused — the GR calls owner.processTouchEnded() directly.
            let gr = TouchObservingGestureRecognizer(
                target: nil, action: nil, owner: interceptor)
            gr.cancelsTouchesInView = false
            gr.delaysTouchesEnded = false
            gr.delaysTouchesBegan = false
            window.addGestureRecognizer(gr)

            let button = self.testViewController.rule1Button
            let center = button.superview?.convert(button.center, to: window) ?? button.center

            // Simulate: touchesBegan at center
            let touchDown = MockUITouch(location: center, view: window)
            gr.touchesBegan(Set([touchDown]), with: UIEvent())

            // Simulate: touchesMoved 200pt down (well beyond 10pt slop)
            let farPoint = CGPoint(x: center.x, y: center.y + 200)
            let touchMoveFar = MockUITouch(location: farPoint, view: window)
            gr.touchesMoved(Set([touchMoveFar]), with: UIEvent())

            // Simulate: touchesMoved back to original position
            let touchMoveBack = MockUITouch(location: center, view: window)
            gr.touchesMoved(Set([touchMoveBack]), with: UIEvent())

            // Simulate: touchesEnded at original position
            let touchUp = MockUITouch(location: center, view: window)
            gr.touchesEnded(Set([touchUp]), with: UIEvent())

            // Clean up
            window.removeGestureRecognizer(gr)

            gestureExpectation.fulfill()
        }

        wait(for: [gestureExpectation], timeout: 5)

        // Verify no $mp_click event was captured — the swipe exceeded slop
        Thread.sleep(forTimeInterval: 1.0)
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let clickEvents = events.filter { ($0["event"] as? String) == "$mp_click" }
        XCTAssertEqual(
            clickEvents.count, 0,
            "Swipe-back-to-same-position should NOT fire $mp_click event")
    }

    // MARK: - Helper Methods

    /// Simulate a tap on a view by injecting touch events
    private func simulateTap(on view: UIView) {
        let tapExpectation = expectation(description: "Tap simulated")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.testWindow else {
                tapExpectation.fulfill()
                return
            }

            // Get the center point of the view in window coordinates
            let center = view.superview?.convert(view.center, to: window) ?? view.center

            // Create touch events
            let downTime = Date()
            let downEvent = UIEvent()

            // Use the autocapture manager directly for testing
            // Since we can't easily create UITouch objects, we call handleTouch directly
            self.mixpanel.autocaptureManager?.handleTouch(at: center, view: view, window: window)

            tapExpectation.fulfill()
        }

        wait(for: [tapExpectation], timeout: 2)
    }

    /// Wait for an autocapture event with the given name
    private func waitForEvent(named eventName: String, timeout: TimeInterval) -> (
        name: String, properties: [String: Any]
    )? {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            // Wait for tracking queue to flush to persistence
            waitForTrackingQueue(mixpanel)

            // Read events from persistence queue
            let events = eventQueue(token: mixpanel.apiToken)
            if let match = events.first(where: { ($0["event"] as? String) == eventName }),
                let props = match["properties"] as? [String: Any]
            {
                return (name: eventName, properties: props)
            }

            // Run loop to allow async operations
            RunLoop.current.run(
                mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }

        return nil
    }
}

// MARK: - Test View Controller

/// A view controller with programmatically created UI elements for testing autocapture.
///
/// This mirrors the Android XmlAutocaptureTestActivity with equivalent test elements.
class UIKitAutocaptureTestViewController: UIViewController {

    // MARK: - Test Elements

    /// Rule 1: Button with accessibilityIdentifier (primary resolution)
    let rule1Button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Rule 1 Button", for: .normal)
        button.accessibilityIdentifier = "rule1_btn"
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        // Has action handler (interactive)
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()

    /// Rule 2: Button with accessibilityLabel only (no identifier)
    let rule2Button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Rule 2 Button", for: .normal)
        button.accessibilityIdentifier = nil
        button.accessibilityLabel = "Rule Two Label"
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()

    /// Rule 3: Button with no identifier and no label (hash fallback)
    let rule3Button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Rule 3 Button", for: .normal)
        button.accessibilityIdentifier = nil
        button.accessibilityLabel = nil
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()

    /// Button with both identifier and label (identifier wins)
    let bothButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Both Button", for: .normal)
        button.accessibilityIdentifier = "both_id"
        button.accessibilityLabel = "Both Label"
        button.backgroundColor = .systemPurple
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()

    /// Button for rage click testing
    let rageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Rage Zone", for: .normal)
        button.accessibilityIdentifier = "rage_btn"
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()

    /// Simulates a React Native Pressable with accessible={false} containing child text.
    /// The container has isAccessibilityElement=false and a child UILabel whose text
    /// UIKit auto-derives into the container's accessibilityLabel.
    /// This auto-derived label must NOT leak into $el_id or $attr-aria-label.
    let notAccessibleView: UIView = {
        let container = UIView()
        container.isAccessibilityElement = false
        container.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        container.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        container.addGestureRecognizer(tap)
        // Child label — UIKit auto-derives container's accessibilityLabel from this text
        let childLabel = UILabel()
        childLabel.text = "Sensitive Account 1234"
        childLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(childLabel)
        NSLayoutConstraint.activate([
            childLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            childLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }()

    /// Button with a sensitive title and accessibilityLabel explicitly set to "".
    /// Tests whether UIKit auto-derives the label from the title or respects "".
    let emptyLabelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("4111-1111-1111-1234", for: .normal)
        button.accessibilityLabel = ""
        button.accessibilityIdentifier = nil
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()

    /// Scenario 2: Accessible + no accessibilityLabel + child text.
    /// isAccessibilityElement=true, no explicit accessibilityLabel set.
    /// Child text must NOT leak into $el_id or $attr-aria-label.
    let accessibleNoLabelView: UIView = {
        let container = UIView()
        container.isAccessibilityElement = true
        container.backgroundColor = .systemGreen.withAlphaComponent(0.1)
        container.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        container.addGestureRecognizer(tap)
        let childLabel = UILabel()
        childLabel.text = "Sensitive Account 5678"
        childLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(childLabel)
        NSLayoutConstraint.activate([
            childLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            childLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }()

    /// Scenario 4: Not accessible + HAS explicit accessibilityLabel.
    /// isAccessibilityElement=false, accessibilityLabel="Sensitive Account 9999".
    /// Neither the label nor child text should leak.
    let notAccessibleWithLabelView: UIView = {
        let container = UIView()
        container.isAccessibilityElement = false
        container.accessibilityLabel = "Sensitive Account 9999"
        container.backgroundColor = .systemPurple.withAlphaComponent(0.1)
        container.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        container.addGestureRecognizer(tap)
        let childLabel = UILabel()
        childLabel.text = "Some Label"
        childLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(childLabel)
        NSLayoutConstraint.activate([
            childLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            childLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }()

    /// Positive case: Accessible + explicit accessibilityLabel.
    /// isAccessibilityElement=true, accessibilityLabel="Intended Label".
    /// The label SHOULD be captured.
    let accessibleWithLabelView: UIView = {
        let container = UIView()
        container.isAccessibilityElement = true
        container.accessibilityLabel = "Intended Label"
        container.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        container.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        container.addGestureRecognizer(tap)
        return container
    }()

    /// Hidden button — isHidden=true, not drawn at all
    let hiddenButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Hidden Button", for: .normal)
        button.accessibilityIdentifier = "hidden_btn"
        button.accessibilityLabel = "Hidden Sensitive PII"
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    /// Zero-alpha button — alpha=0, fully transparent
    let zeroAlphaButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Zero Alpha Button", for: .normal)
        button.accessibilityIdentifier = "zero_alpha_btn"
        button.accessibilityLabel = "ZeroAlpha Sensitive PII"
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(nil, action: #selector(buttonTapped), for: .touchUpInside)
        button.alpha = 0
        return button
    }()

    /// Button with no action handler (for dead click testing)
    let deadButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dead Button", for: .normal)
        button.accessibilityIdentifier = "dead_btn"
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        // NO action handler - dead click scenario
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }

    private func setupUI() {
        let stackView = UIStackView(arrangedSubviews: [
            rule1Button,
            rule2Button,
            rule3Button,
            bothButton,
            rageButton,
            hiddenButton,
            zeroAlphaButton,
            deadButton,
            notAccessibleView,
            emptyLabelButton,
            accessibleNoLabelView,
            notAccessibleWithLabelView,
            accessibleWithLabelView,
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        // Set fixed height for buttons
        for button in stackView.arrangedSubviews {
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }
    }

    @objc private func buttonTapped() {
        // Empty handler - just to make button interactive
    }
}

// MARK: - Test helpers for gesture recognizer testing

/// Minimal UITouch subclass that returns a fixed location.
/// Used to exercise TouchObservingGestureRecognizer's slop logic in tests.
private class MockUITouch: UITouch {
    private let mockLocation: CGPoint
    private let mockView: UIView?

    init(location: CGPoint, view: UIView?) {
        self.mockLocation = location
        self.mockView = view
        super.init()
    }

    override func location(in view: UIView?) -> CGPoint {
        return mockLocation
    }

    override var view: UIView? {
        return mockView
    }
}

// MARK: - UIKit accessibilityLabel Auto-Derivation Verification Tests

/// These tests verify UIKit's auto-derivation behavior for each control type listed
/// in SemanticExtractor.findAccessibilityLabel's known-control bypass.
///
/// For each control, we check:
/// 1. When accessibilityLabel is nil (not set), does UIKit auto-derive it from visible text?
/// 2. When accessibilityLabel is "" (explicitly empty), does UIKit respect the empty value?
///
/// This documents the actual runtime behavior to inform PII-safe extraction decisions.
class UIKitAccessibilityLabelDerivationTests: XCTestCase {

    // MARK: - UIButton

    func testUIButton_NilLabel_DoesNotDeriveFromTitle() {
        let button = UIButton(type: .system)
        button.setTitle("Card 4111-1111-1111-1234", for: .normal)
        // accessibilityLabel is NOT set (nil by default)

        let label = button.accessibilityLabel
        // UIButton does NOT auto-derive accessibilityLabel from title at the property level.
        // VoiceOver reads the title, but view.accessibilityLabel remains nil.
        XCTAssertNil(label, "UIButton should NOT auto-derive accessibilityLabel from title")
    }

    func testUIButton_EmptyLabel_DoesNotDeriveFromTitle() {
        let button = UIButton(type: .system)
        button.setTitle("Card 4111-1111-1111-1234", for: .normal)
        button.accessibilityLabel = ""

        let label = button.accessibilityLabel
        // Check whether UIKit respects empty string or falls back to title
        let isEmpty = (label == nil || label!.isEmpty)
        XCTAssertTrue(
            isEmpty,
            "UIButton with accessibilityLabel='' should not derive from title. Got: \(label ?? "nil")")
    }

    // MARK: - UILabel

    func testUILabel_NilLabel_DoesNotDeriveFromText() {
        let uiLabel = UILabel()
        uiLabel.text = "Account 9876-5432"
        // accessibilityLabel is NOT set

        let label = uiLabel.accessibilityLabel
        // UILabel does NOT auto-derive accessibilityLabel from text at the property level.
        // VoiceOver reads the text, but view.accessibilityLabel remains nil.
        XCTAssertNil(label, "UILabel should NOT auto-derive accessibilityLabel from text")
    }

    func testUILabel_EmptyLabel_DoesNotDeriveFromText() {
        let uiLabel = UILabel()
        uiLabel.text = "Account 9876-5432"
        uiLabel.accessibilityLabel = ""

        let label = uiLabel.accessibilityLabel
        let isEmpty = (label == nil || label!.isEmpty)
        XCTAssertTrue(
            isEmpty,
            "UILabel with accessibilityLabel='' should not derive from text. Got: \(label ?? "nil")")
    }

    // MARK: - UISwitch

    func testUISwitch_NilLabel_CheckDerivation() {
        let toggle = UISwitch()
        toggle.isOn = true
        // accessibilityLabel is NOT set

        let label = toggle.accessibilityLabel
        // UISwitch has no visible text — document whether label is nil or has a default
        // (This test documents behavior, not asserts a specific value)
        if let label = label, !label.isEmpty {
            // If non-nil, it should NOT contain user data (switch has no text input)
            XCTAssertFalse(
                label.contains("Account") || label.contains("1234"),
                "UISwitch should not contain user data. Got: \(label)")
        }
        // Record the actual value for documentation
        print("UISwitch default accessibilityLabel: \(label ?? "nil")")
    }

    // MARK: - UISlider

    func testUISlider_NilLabel_CheckDerivation() {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        // accessibilityLabel is NOT set

        let label = slider.accessibilityLabel
        if let label = label, !label.isEmpty {
            XCTAssertFalse(
                label.contains("Account") || label.contains("1234"),
                "UISlider should not contain user data. Got: \(label)")
        }
        print("UISlider default accessibilityLabel: \(label ?? "nil")")
    }

    // MARK: - UITextField

    func testUITextField_NilLabel_WithTypedText() {
        let textField = UITextField()
        textField.text = "john.doe@example.com"
        textField.placeholder = "Enter email"
        // accessibilityLabel is NOT set

        let label = textField.accessibilityLabel
        // Critical: does the TYPED TEXT leak into accessibilityLabel?
        if let label = label, !label.isEmpty {
            let typedTextLeaks = label.contains("john.doe") || label.contains("example.com")
            print("UITextField accessibilityLabel with typed text: \(label)")
            print("UITextField typed text leaks into accessibilityLabel: \(typedTextLeaks)")
        } else {
            print("UITextField default accessibilityLabel: nil/empty")
        }
    }

    func testUITextField_NilLabel_WithPlaceholderOnly() {
        let textField = UITextField()
        textField.text = nil
        textField.placeholder = "Enter email"
        // accessibilityLabel is NOT set

        let label = textField.accessibilityLabel
        print("UITextField accessibilityLabel with placeholder only: \(label ?? "nil")")
    }

    func testUITextField_NilLabel_CheckAccessibilityValue() {
        let textField = UITextField()
        textField.text = "john.doe@example.com"
        textField.placeholder = "Enter email"

        let label = textField.accessibilityLabel
        let value = textField.accessibilityValue
        print("UITextField accessibilityLabel: \(label ?? "nil")")
        print("UITextField accessibilityValue: \(value ?? "nil")")
        // Document whether typed text goes to label, value, or both
    }

    // MARK: - UITextView

    func testUITextView_NilLabel_WithTypedText() {
        let textView = UITextView()
        textView.text = "SSN: 123-45-6789"
        // accessibilityLabel is NOT set

        let label = textView.accessibilityLabel
        if let label = label, !label.isEmpty {
            let typedTextLeaks = label.contains("123-45") || label.contains("6789")
            print("UITextView accessibilityLabel with typed text: \(label)")
            print("UITextView typed text leaks into accessibilityLabel: \(typedTextLeaks)")
        } else {
            print("UITextView default accessibilityLabel: nil/empty")
        }
    }

    func testUITextView_NilLabel_CheckAccessibilityValue() {
        let textView = UITextView()
        textView.text = "SSN: 123-45-6789"

        let label = textView.accessibilityLabel
        let value = textView.accessibilityValue
        print("UITextView accessibilityLabel: \(label ?? "nil")")
        print("UITextView accessibilityValue: \(value ?? "nil")")
    }

    // MARK: - UISegmentedControl

    func testUISegmentedControl_NilLabel_DerivesFromSegments() {
        let segControl = UISegmentedControl(items: ["Personal", "Business", "Account 1234"])
        segControl.selectedSegmentIndex = 0
        // accessibilityLabel is NOT set

        let label = segControl.accessibilityLabel
        print("UISegmentedControl accessibilityLabel: \(label ?? "nil")")
        // Check if segment titles leak into the overall control's label
        if let label = label, !label.isEmpty {
            let segmentTextLeaks = label.contains("Personal") || label.contains("1234")
            print("UISegmentedControl segment text leaks: \(segmentTextLeaks)")
        }
    }

    // MARK: - UIStepper

    func testUIStepper_NilLabel_CheckDerivation() {
        let stepper = UIStepper()
        stepper.value = 5
        stepper.minimumValue = 0
        stepper.maximumValue = 10
        // accessibilityLabel is NOT set

        let label = stepper.accessibilityLabel
        print("UIStepper default accessibilityLabel: \(label ?? "nil")")
    }

    // MARK: - UIImageView

    func testUIImageView_NilLabel_CheckDerivation() {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "star.fill")
        imageView.accessibilityLabel = nil
        // accessibilityLabel is NOT set

        let label = imageView.accessibilityLabel
        print("UIImageView default accessibilityLabel: \(label ?? "nil")")
        // UIImageView has no text — label should be nil unless derived from image name
    }

    // MARK: - UIScrollView (not a known control, but in role detection)

    func testUIScrollView_NilLabel_CheckDerivation() {
        let scrollView = UIScrollView()
        let childLabel = UILabel()
        childLabel.text = "Secret Data 9999"
        scrollView.addSubview(childLabel)

        let label = scrollView.accessibilityLabel
        print("UIScrollView default accessibilityLabel: \(label ?? "nil")")
        if let label = label, !label.isEmpty {
            let childTextLeaks = label.contains("Secret") || label.contains("9999")
            print("UIScrollView child text leaks: \(childTextLeaks)")
        }
    }

    // MARK: - UITableViewCell (common clickable container with child text)

    func testUITableViewCell_NilLabel_WithChildText() {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Card ending 1234"
        // accessibilityLabel is NOT set

        let label = cell.accessibilityLabel
        print("UITableViewCell accessibilityLabel: \(label ?? "nil")")
        if let label = label, !label.isEmpty {
            let childTextLeaks = label.contains("1234")
            print("UITableViewCell child text leaks: \(childTextLeaks)")
        }
    }
}

#endif
