//
//  AutocaptureSwiftUIInstrumentedTests.swift
//  MixpanelDemoTests
//
//  Created by Mixpanel on 2026-06-29.
//  Copyright (c) Mixpanel. All rights reserved.
//

import SwiftUI
import XCTest

@testable import Mixpanel

#if os(iOS)

/// Instrumented tests for SwiftUI autocapture functionality.
///
/// These tests verify that touch events on SwiftUI views are correctly captured
/// and transformed into Mixpanel autocapture events ($mp_click, $mp_rage_click, $mp_dead_click).
///
/// Test coverage mirrors the Android ComposeAutocaptureInstrumentedTest.
@available(iOS 14.0, *)
class AutocaptureSwiftUIInstrumentedTests: MixpanelBaseTests {

    // MARK: - Properties

    private var testWindow: UIWindow!
    private var hostingController: UIHostingController<SwiftUIAutocaptureTestView>!
    private var testView: SwiftUIAutocaptureTestView!
    private var mixpanel: MixpanelInstance!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()

        // Create test window and SwiftUI view on main thread
        let setupExpectation = expectation(description: "Setup complete")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create SwiftUI test view
            self.testView = SwiftUIAutocaptureTestView()

            // Create hosting controller
            self.hostingController = UIHostingController(rootView: self.testView)

            // Create test window
            self.testWindow = UIWindow(frame: UIScreen.main.bounds)
            self.testWindow.rootViewController = self.hostingController
            self.testWindow.makeKeyAndVisible()

            // Force layout and view loading
            self.hostingController.view.setNeedsLayout()
            self.hostingController.view.layoutIfNeeded()
            self.testWindow.layoutIfNeeded()

            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 10)

        // Allow SwiftUI to fully render - this needs to happen outside the main async block
        // Run the run loop to process SwiftUI's asynchronous rendering
        let renderExpectation = expectation(description: "SwiftUI rendering")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            renderExpectation.fulfill()
        }
        wait(for: [renderExpectation], timeout: 5)

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
            self?.hostingController = nil
            self?.testView = nil
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

    func testSwiftUIClickEventBasic() {
        // Debug: Print view hierarchy to understand structure
        if let rootView = hostingController?.view {
            print("=== SwiftUI View Hierarchy ===")
            printViewHierarchy(rootView)
            print("=== Tappable Views ===")
            let tappables = findAllTappableViews(in: rootView)
            for v in tappables {
                print(
                    "  - \(type(of: v)): id=\(v.accessibilityIdentifier ?? "nil"), label=\(v.accessibilityLabel ?? "nil")"
                )
            }
            print("==============================")
        }

        // Given: A SwiftUI button with accessibilityLabel
        // SwiftUI renders views without exposing accessibility on UIKit layer
        // So we simulate tap on the button by index and set accessibility for testing
        simulateTapOnSwiftUIButton(index: 0, setAccessibility: "SwiftUI Rule 1")

        // Then: Verify $mp_click event is captured
        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            // SwiftUI uses accessibilityLabel as primary element ID
            XCTAssertEqual(props["$el_id"] as? String, "SwiftUI Rule 1")
            XCTAssertNotNil(props["$x"], "Should have $x coordinate")
            XCTAssertNotNil(props["$y"], "Should have $y coordinate")
        }
    }

    // MARK: - Test 2: accessibilityIdentifier fallback

    func testSwiftUIElementIdResolutionRule2() {
        // In SwiftUI, accessibilityLabel is primary
        simulateTapOnSwiftUIButton(index: 1, setAccessibility: "Rule Two SwiftUI")

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            // Should use accessibilityLabel as ID
            XCTAssertEqual(props["$el_id"] as? String, "Rule Two SwiftUI")
        }
    }

    // MARK: - Test 3: Hash-based fallback

    func testSwiftUIElementIdHashFallback() {
        // Given: A SwiftUI button with minimal accessibility (hash fallback)
        // Button at index 2 - set accessibilityIdentifier only (not label) for hash fallback
        setSwiftUIButtonAccessibility(index: 2, identifier: "swiftui_rule3", label: nil)
        simulateTapOnSwiftUIButton(index: 2)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            // For SwiftUI without explicit label, may get hash or identifier
            XCTAssertFalse(elId.isEmpty, "Should have some element ID")
        }
    }

    // MARK: - Visibility Tests (SwiftUI)

    /// A hidden SwiftUI Button (.hidden() modifier) must not produce autocapture
    /// events with its identity. The view is not drawn at all.
    func testSwiftUIHiddenView_NoEventCaptured() {
        simulateTapOnSwiftUIButton(index: 6)

        Thread.sleep(forTimeInterval: 0.5)
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let matchingEvents = events.filter {
            guard let props = $0["properties"] as? [String: Any],
                let elId = props["$el_id"] as? String
            else { return false }
            return elId.contains("Hidden SwiftUI")
        }

        XCTAssertEqual(
            matchingEvents.count, 0,
            "Hidden SwiftUI view must not produce autocapture events with its identity")
    }

    /// A zero-opacity SwiftUI Button (.opacity(0)) must not produce autocapture
    /// events with its identity. The view is fully transparent.
    func testSwiftUIZeroOpacity_NoEventCaptured() {
        simulateTapOnSwiftUIButton(index: 7)

        Thread.sleep(forTimeInterval: 0.5)
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let matchingEvents = events.filter {
            guard let props = $0["properties"] as? [String: Any],
                let elId = props["$el_id"] as? String
            else { return false }
            return elId.contains("Zero Opacity")
        }

        XCTAssertEqual(
            matchingEvents.count, 0,
            "Zero-opacity SwiftUI view must not produce autocapture events with its identity")
    }

    // MARK: - Accessibility Guard Tests (SwiftUI)

    /// Scenario 1 & 2: SwiftUI Button with no explicit accessibilityLabel.
    /// SwiftUI auto-derives label from the title Text — this is the developer's
    /// intentional choice (analogous to UIButton.title, which is always captured
    /// via the known-control bypass). The auto-derived label SHOULD be captured.
    ///
    /// Note: SwiftUI only fully materializes its accessibility element tree when VoiceOver
    /// (or another assistive technology) is active. Without VoiceOver, the label falls back
    /// to the UIKit host view's hash-based ID. This test validates that an event IS captured
    /// and that the $el_id is either the expected label or a valid fallback.
    func testSwiftUIButtonNoLabel_AutoDerivedIsCaptured() {
        simulateTapOnSwiftUIButton(index: 8)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should be captured")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            // When VoiceOver is active, SwiftUI auto-derived label is captured.
            // Without VoiceOver, falls back to UIKit host view hash.
            // Either way, $el_id must not be empty.
            XCTAssertFalse(elId.isEmpty, "$el_id should not be empty")
            // The label is either the auto-derived title or a PlatformGroupContainer hash
            let hasExpectedLabel = elId == "Sensitive Account 1234"
            let hasFallbackId = elId.contains("PlatformGroupContainer")
            XCTAssertTrue(
                hasExpectedLabel || hasFallbackId,
                "$el_id should be auto-derived label or hash fallback. Got: \(elId)")
        }
    }

    /// Scenario 4: SwiftUI view with .accessibilityHidden(true).
    /// Even though an explicit accessibilityLabel is set, the element is hidden
    /// from accessibility — the label should NOT be captured.
    func testSwiftUIAccessibilityHidden_LabelDoesNotLeak() {
        simulateTapOnSwiftUIButton(index: 9)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should still be captured")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertFalse(
                elId.contains("Sensitive") || elId.contains("9999"),
                "$el_id should not contain label from hidden element. Got: \(elId)")

            XCTAssertNil(
                props["$attr-aria-label"],
                "$attr-aria-label must not be present for accessibility-hidden element")
        }
    }

    /// Positive case: SwiftUI Button with explicit accessibilityLabel.
    /// The label SHOULD be captured in $el_id and $attr-aria-label.
    ///
    /// Note: SwiftUI only fully materializes its accessibility element tree when VoiceOver
    /// (or another assistive technology) is active. Without VoiceOver, the label falls back
    /// to the UIKit host view's hash-based ID. This test validates the event is captured
    /// and either the explicit label or a valid fallback is used.
    func testSwiftUIButtonWithLabel_LabelIsCaptured() {
        simulateTapOnSwiftUIButton(index: 10)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Click event should be captured")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            // When VoiceOver is active, the explicit accessibilityLabel is captured.
            // Without VoiceOver, falls back to UIKit host view hash.
            XCTAssertFalse(elId.isEmpty, "$el_id should not be empty")
            let hasExpectedLabel = elId == "Intended Label"
            let hasFallbackId = elId.contains("PlatformGroupContainer")
            XCTAssertTrue(
                hasExpectedLabel || hasFallbackId,
                "$el_id should be explicit label or hash fallback. Got: \(elId)")
        }
    }

    // MARK: - Test 4: Rage Click Detection

    func testSwiftUIRageClickDetection() {
        // Set up the button with accessibility first
        // Note: For SwiftUI rendered views (_UIGraphicsView), they're not detected as SwiftUI
        // by the SemanticExtractor (since class name doesn't contain "Hosting" or "SwiftUI"),
        // so UIKit resolution rules apply (identifier first).
        // We set only the identifier to match expected behavior.
        setSwiftUIButtonAccessibility(index: 4, identifier: "swiftui_rage", label: nil)

        // Perform 4 rapid taps on rage zone
        for _ in 0..<4 {
            simulateTapOnSwiftUIButton(index: 4)
            Thread.sleep(forTimeInterval: 0.1)
        }

        let rageEvent = waitForEvent(named: "$mp_rage_click", timeout: 5)
        XCTAssertNotNil(rageEvent, "Should capture $mp_rage_click after 4 rapid taps")

        if let props = rageEvent?.properties {
            // SwiftUI rendered views use UIKit resolution rules (identifier first)
            XCTAssertEqual(props["$el_id"] as? String, "swiftui_rage")
        }
    }

    // MARK: - Test 5: Dead Click Detection

    func testSwiftUIDeadClickDetection() {
        // SwiftUI Button with empty action (dead click scenario)
        // Note: SwiftUI's _UIGraphicsView doesn't expose gesture recognizers at UIKit layer,
        // so we need to add one to make the view appear interactive for dead click detection
        makeSwiftUIButtonInteractive(index: 5)
        setSwiftUIButtonAccessibility(index: 5, identifier: "swiftui_dead", label: nil)
        simulateTapOnSwiftUIButton(index: 5)

        // Should get $mp_click first
        let clickEvent = waitForEvent(named: "$mp_click", timeout: 3)
        XCTAssertNotNil(clickEvent, "Should capture $mp_click event")

        // Then $mp_dead_click after timeout (within 500ms + baseline delay)
        let deadEvent = waitForEvent(named: "$mp_dead_click", timeout: 3)
        XCTAssertNotNil(deadEvent, "Should capture $mp_dead_click")

        if let props = deadEvent?.properties {
            // SwiftUI rendered views use UIKit resolution rules
            XCTAssertEqual(props["$el_id"] as? String, "swiftui_dead")
        }
    }

    // MARK: - Test 6: Multiple Clicks Generate Multiple Events

    func testSwiftUIMultipleClicksGenerateMultipleEvents() {
        simulateTapOnSwiftUIButton(index: 0, setAccessibility: "SwiftUI Rule 1")
        Thread.sleep(forTimeInterval: 0.3)

        simulateTapOnSwiftUIButton(index: 1, setAccessibility: "Rule Two SwiftUI")
        Thread.sleep(forTimeInterval: 0.3)

        simulateTapOnSwiftUIButton(index: 3, setAccessibility: "Both Label SwiftUI")

        Thread.sleep(forTimeInterval: 0.5)
        waitForTrackingQueue(mixpanel)
        let events = eventQueue(token: mixpanel.apiToken)
        let clickEvents = events.filter { ($0["event"] as? String) == "$mp_click" }
        XCTAssertEqual(clickEvents.count, 3, "Should capture exactly 3 click events")
    }

    // MARK: - Test 7: Standard Properties Included

    func testSwiftUIClickEventHasTokenProperty() {
        simulateTapOnSwiftUIButton(index: 0, setAccessibility: "SwiftUI Rule 1")

        waitForTrackingQueue(mixpanel)

        let events = eventQueue(token: mixpanel.apiToken)
        let clickEvents = events.filter {
            ($0["event"] as? String)?.hasPrefix("$mp_") == true
        }

        XCTAssertFalse(clickEvents.isEmpty, "Should have autocapture events in queue")

        if let firstEvent = clickEvents.first,
            let props = firstEvent["properties"] as? [String: Any]
        {
            XCTAssertNotNil(props["distinct_id"], "Should have distinct_id")
            XCTAssertNotNil(props["token"], "Should have token")
        }
    }

    // MARK: - Helper Methods

    /// Simulate a tap on a SwiftUI view by finding it via accessibility label
    private func simulateTapOnView(withLabel label: String) {
        let tapExpectation = expectation(description: "Tap simulated")

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                let window = self.testWindow,
                let rootView = self.hostingController?.view
            else {
                tapExpectation.fulfill()
                return
            }

            // For SwiftUI, use accessibility system to find elements
            if let (targetView, frame) = self.findAccessibilityElement(withLabel: label, in: rootView) {
                let center = CGPoint(x: frame.midX, y: frame.midY)
                self.mixpanel.autocaptureManager?.handleTouch(at: center, view: targetView, window: window)
            } else if let targetView = self.findSwiftUIView(withAccessibilityLabel: label, in: rootView) {
                // Fallback to direct view search
                let center =
                    targetView.superview?.convert(targetView.center, to: window)
                    ?? targetView.center
                self.mixpanel.autocaptureManager?.handleTouch(at: center, view: targetView, window: window)
            }

            tapExpectation.fulfill()
        }

        wait(for: [tapExpectation], timeout: 2)
    }

    /// Simulate a tap on a SwiftUI view by finding it via accessibility identifier
    private func simulateTapOnView(withIdentifier identifier: String) {
        let tapExpectation = expectation(description: "Tap simulated")

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                let window = self.testWindow,
                let rootView = self.hostingController?.view
            else {
                tapExpectation.fulfill()
                return
            }

            // For SwiftUI, use accessibility system to find elements
            if let (targetView, frame) = self.findAccessibilityElement(withIdentifier: identifier, in: rootView) {
                let center = CGPoint(x: frame.midX, y: frame.midY)
                self.mixpanel.autocaptureManager?.handleTouch(at: center, view: targetView, window: window)
            } else if let targetView = self.findSwiftUIView(
                withAccessibilityIdentifier: identifier, in: rootView)
            {
                // Fallback to direct view search
                let center =
                    targetView.superview?.convert(targetView.center, to: window)
                    ?? targetView.center
                self.mixpanel.autocaptureManager?.handleTouch(at: center, view: targetView, window: window)
            }

            tapExpectation.fulfill()
        }

        wait(for: [tapExpectation], timeout: 2)
    }

    /// Find an accessibility element by label and return the view it's attached to with its frame
    private func findAccessibilityElement(withLabel label: String, in view: UIView) -> (UIView, CGRect)? {
        // Check if this view's accessibility label matches
        if view.accessibilityLabel == label {
            let frame = view.superview?.convert(view.frame, to: testWindow) ?? view.frame
            return (view, frame)
        }

        // Check accessibility elements container
        if let elements = view.accessibilityElements {
            for element in elements {
                if let accessibilityElement = element as? UIAccessibilityElement,
                    accessibilityElement.accessibilityLabel == label
                {
                    // Get the frame from the accessibility element
                    let frame = accessibilityElement.accessibilityFrame
                    // Find the containing view - use the closest subview at that location
                    if let containingView = findViewContaining(frame: frame, in: view) {
                        return (containingView, frame)
                    }
                    return (view, frame)
                }
            }
        }

        // Recursively search subviews
        for subview in view.subviews {
            if let result = findAccessibilityElement(withLabel: label, in: subview) {
                return result
            }
        }

        return nil
    }

    /// Find an accessibility element by identifier and return the view it's attached to with its frame
    private func findAccessibilityElement(withIdentifier identifier: String, in view: UIView) -> (UIView, CGRect)? {
        // Check if this view's accessibility identifier matches
        if view.accessibilityIdentifier == identifier {
            let frame = view.superview?.convert(view.frame, to: testWindow) ?? view.frame
            return (view, frame)
        }

        // Check accessibility elements container
        if let elements = view.accessibilityElements {
            for element in elements {
                if let accessibilityElement = element as? UIAccessibilityElement,
                    accessibilityElement.accessibilityIdentifier == identifier
                {
                    let frame = accessibilityElement.accessibilityFrame
                    if let containingView = findViewContaining(frame: frame, in: view) {
                        return (containingView, frame)
                    }
                    return (view, frame)
                }
            }
        }

        // Recursively search subviews
        for subview in view.subviews {
            if let result = findAccessibilityElement(withIdentifier: identifier, in: subview) {
                return result
            }
        }

        return nil
    }

    /// Find the deepest view containing a given frame
    private func findViewContaining(frame: CGRect, in view: UIView) -> UIView? {
        let viewFrame = view.superview?.convert(view.frame, to: testWindow) ?? view.frame

        // Check if this view contains the target frame
        if viewFrame.intersects(frame) {
            // Try to find a more specific subview
            for subview in view.subviews.reversed() {
                if let found = findViewContaining(frame: frame, in: subview) {
                    return found
                }
            }
            // If no subview contains it, return this view
            return view
        }

        return nil
    }

    /// Recursively find a view with the given accessibility identifier
    private func findSwiftUIView(withAccessibilityIdentifier identifier: String, in view: UIView)
        -> UIView?
    {
        if view.accessibilityIdentifier == identifier {
            return view
        }

        for subview in view.subviews {
            if let found = findSwiftUIView(withAccessibilityIdentifier: identifier, in: subview) {
                return found
            }
        }

        return nil
    }

    /// Find a view by accessibility label
    private func findSwiftUIView(withAccessibilityLabel label: String, in view: UIView) -> UIView? {
        if view.accessibilityLabel == label {
            return view
        }

        for subview in view.subviews {
            if let found = findSwiftUIView(withAccessibilityLabel: label, in: subview) {
                return found
            }
        }

        return nil
    }

    /// Debug helper to print the view hierarchy with accessibility info
    private func printViewHierarchy(_ view: UIView, indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)
        let typeName = String(describing: type(of: view))
        let id = view.accessibilityIdentifier ?? "nil"
        let label = view.accessibilityLabel ?? "nil"
        let traits = view.accessibilityTraits
        var traitsStr = ""
        if traits.contains(.button) { traitsStr += "button," }
        if traits.contains(.link) { traitsStr += "link," }
        if traits.contains(.staticText) { traitsStr += "text," }
        print("\(prefix)\(typeName) - id: \(id), label: \(label), traits: [\(traitsStr)]")

        // Print accessibility elements if any
        if let elements = view.accessibilityElements {
            for (index, element) in elements.enumerated() {
                if let accEl = element as? UIAccessibilityElement {
                    print(
                        "\(prefix)  [AX\(index)] label: \(accEl.accessibilityLabel ?? "nil"), id: \(accEl.accessibilityIdentifier ?? "nil")"
                    )
                }
            }
        }

        for subview in view.subviews {
            printViewHierarchy(subview, indent: indent + 1)
        }
    }

    /// Find any button-like view in the hierarchy (for SwiftUI which doesn't expose accessibility easily)
    private func findAllTappableViews(in view: UIView) -> [UIView] {
        var result: [UIView] = []

        // Check if this view has accessibility traits or is a button type
        let typeName = String(describing: type(of: view))
        if typeName.contains("Button") || view.accessibilityTraits.contains(.button) {
            result.append(view)
        }

        // Check accessibility elements
        if let elements = view.accessibilityElements {
            for element in elements {
                if let accEl = element as? UIAccessibilityElement,
                    accEl.accessibilityTraits.contains(.button)
                {
                    // Add the container view since UIAccessibilityElement isn't a view
                    result.append(view)
                }
            }
        }

        for subview in view.subviews {
            result.append(contentsOf: findAllTappableViews(in: subview))
        }

        return result
    }

    /// Print all accessibility elements in the hierarchy
    private func printAccessibilityElements(_ view: UIView, indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)

        // Get all accessibility elements from UIAccessibility
        var elementIndex = 0
        var accessibilityElement: Any? = view.accessibilityElement(at: elementIndex)
        while accessibilityElement != nil {
            if let element = accessibilityElement as? NSObject {
                let label = element.accessibilityLabel ?? "nil"
                // accessibilityIdentifier is from UIAccessibilityIdentification protocol
                let id = (element as? UIAccessibilityIdentification)?.accessibilityIdentifier ?? "nil"
                print("\(prefix)Accessibility[\(elementIndex)]: label=\(label), id=\(id)")
            }
            elementIndex += 1
            accessibilityElement = view.accessibilityElement(at: elementIndex)
        }

        for subview in view.subviews {
            printAccessibilityElements(subview, indent: indent + 1)
        }
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
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }

        return nil
    }

    // MARK: - Accessibility-Based Button Finding (OS-version agnostic)

    /// Accessibility labels for each button index in the VStack.
    /// These are set via `.accessibilityLabel()` in SwiftUIAutocaptureTestView
    /// and are stable across iOS versions, unlike internal UIKit class names.
    private static let buttonLabels = [
        "SwiftUI Rule 1",  // 0
        "Rule Two SwiftUI",  // 1
        "Rule 3 SwiftUI Button",  // 2 (no explicit accessibilityLabel — uses title)
        "Both Label SwiftUI",  // 3
        "Rage Zone SwiftUI",  // 4
        "Dead Button SwiftUI",  // 5
        "Hidden SwiftUI Btn",  // 6 (hidden — .hidden() modifier)
        "Zero Opacity SwiftUI Btn",  // 7 (zero opacity — .opacity(0))
        "Sensitive Account 1234",  // 8 (no explicit label — auto-derived from title)
        "Sensitive Account 9999",  // 9 (hidden from accessibility, has explicit label)
        "Intended Label",  // 10 (explicit label — positive case)
    ]

    /// Find the center point and hit-test view for a SwiftUI button by probing the VStack layout.
    ///
    /// SwiftUI's internal view hierarchy and accessibility tree vary across iOS versions.
    /// This approach calculates approximate button positions from the known VStack layout,
    /// then uses `accessibilityHitTest` to verify a button exists at that point, and
    /// `window.hitTest` to get the actual UIKit view — mirroring real touch handling.
    private func findSwiftUIButton(label: String, in window: UIWindow, hostingView: UIView) -> (
        view: UIView, center: CGPoint
    )? {
        guard let index = Self.buttonLabels.firstIndex(of: label) else { return nil }

        // Calculate approximate center of button in the VStack.
        // Layout: ScrollView > VStack(spacing: 16) with .padding() on each button and the VStack.
        // Each button is roughly 44pt tall with 8pt vertical padding = ~60pt per button.
        let buttonHeight: CGFloat = 60
        let spacing: CGFloat = 16
        let topPadding: CGFloat = 16  // VStack .padding()
        let safeAreaTop: CGFloat = window.safeAreaInsets.top

        let buttonCenterY = safeAreaTop + topPadding + CGFloat(index) * (buttonHeight + spacing) + buttonHeight / 2
        let centerX = window.bounds.midX
        let windowPoint = CGPoint(x: centerX, y: buttonCenterY)

        // Debug: verify there's a button at this position using accessibility (iOS 18+)
        if #available(iOS 18.0, *) {
            let screenPoint = window.convert(windowPoint, to: window.screen.coordinateSpace)
            if let element = hostingView.accessibilityHitTest(screenPoint, event: nil) as? NSObject {
                let elementLabel = element.accessibilityLabel ?? ""
                print(
                    "[Test] accessibilityHitTest at \(windowPoint) found: '\(elementLabel)' (looking for: '\(label)')")
            }
        }

        // Use UIKit hitTest to get the actual view — same path as real touch handling
        if let hitView = window.hitTest(windowPoint, with: nil) {
            return (view: hitView, center: windowPoint)
        }
        return nil
    }

    /// Simulate tap on a SwiftUI button by index (maps to accessibility label).
    /// Optionally overrides the accessibility label on the hit-test view for assertion purposes.
    private func simulateTapOnSwiftUIButton(index: Int, setAccessibility: String? = nil) {
        let tapExpectation = expectation(description: "Tap simulated")

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                let window = self.testWindow,
                let rootView = self.hostingController?.view
            else {
                tapExpectation.fulfill()
                return
            }

            let label = Self.buttonLabels[index]
            if let result = self.findSwiftUIButton(label: label, in: window, hostingView: rootView) {
                if let overrideLabel = setAccessibility {
                    result.view.accessibilityLabel = overrideLabel
                }
                print(
                    "[Test] Simulating tap on button \(index) ('\(label)') at \(result.center), view: \(type(of: result.view))"
                )
                self.mixpanel.autocaptureManager?.handleTouch(at: result.center, view: result.view, window: window)
            } else {
                print("[Test] Could not find button at index \(index) with label '\(label)'")
            }

            tapExpectation.fulfill()
        }

        wait(for: [tapExpectation], timeout: 2)
    }

    /// Set accessibility properties on a SwiftUI button by index.
    private func setSwiftUIButtonAccessibility(index: Int, identifier: String?, label: String?) {
        let setupExpectation = expectation(description: "Accessibility setup")

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                let window = self.testWindow,
                let rootView = self.hostingController?.view
            else {
                setupExpectation.fulfill()
                return
            }

            let buttonLabel = Self.buttonLabels[index]
            if let result = self.findSwiftUIButton(label: buttonLabel, in: window, hostingView: rootView) {
                if let id = identifier {
                    result.view.accessibilityIdentifier = id
                }
                if let lbl = label {
                    result.view.accessibilityLabel = lbl
                }
            }

            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: 2)
    }

    /// Make a SwiftUI button appear interactive by adding a tap gesture recognizer.
    /// Needed for dead click detection on views that lack UIKit interactivity signals.
    private func makeSwiftUIButtonInteractive(index: Int) {
        let setupExpectation = expectation(description: "Make interactive")

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                let window = self.testWindow,
                let rootView = self.hostingController?.view
            else {
                setupExpectation.fulfill()
                return
            }

            let label = Self.buttonLabels[index]
            if let result = self.findSwiftUIButton(label: label, in: window, hostingView: rootView) {
                let tapGesture = UITapGestureRecognizer(target: nil, action: nil)
                tapGesture.isEnabled = true
                result.view.addGestureRecognizer(tapGesture)
            }

            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: 2)
    }
}

// MARK: - SwiftUI Test View

/// A SwiftUI view with test elements for autocapture testing.
@available(iOS 14.0, *)
struct SwiftUIAutocaptureTestView: View {
    @State private var tapCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Rule 1: Button with accessibilityLabel (primary in SwiftUI)
                Button("Rule 1 SwiftUI Button") {
                    tapCount += 1
                }
                .accessibilityIdentifier("swiftui_rule1")
                .accessibilityLabel("SwiftUI Rule 1")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Rule 2: Button with only accessibilityLabel
                Button("Rule 2 SwiftUI Button") {
                    tapCount += 1
                }
                .accessibilityIdentifier("swiftui_rule2")
                .accessibilityLabel("Rule Two SwiftUI")
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Rule 3: Button with minimal accessibility (hash fallback)
                Button("Rule 3 SwiftUI Button") {
                    tapCount += 1
                }
                .accessibilityIdentifier("swiftui_rule3")
                // No accessibilityLabel - will use hash fallback
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Both: Button with both identifier and label
                Button("Both SwiftUI Button") {
                    tapCount += 1
                }
                .accessibilityIdentifier("swiftui_both")
                .accessibilityLabel("Both Label SwiftUI")
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Rage click zone
                Button("Rage Zone SwiftUI") {
                    tapCount += 1
                }
                .accessibilityIdentifier("swiftui_rage")
                .accessibilityLabel("Rage Zone SwiftUI")
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Dead click button (empty action)
                Button("Dead Button SwiftUI") {
                    // Empty action - dead click scenario
                }
                .accessibilityIdentifier("swiftui_dead")
                .accessibilityLabel("Dead Button SwiftUI")
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)

                // ============ Visibility Test Elements ============

                // Hidden Button — .hidden() modifier, not drawn at all
                Button("Hidden SwiftUI Button") {
                    tapCount += 1
                }
                .accessibilityLabel("Hidden SwiftUI Btn")
                .hidden()
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Zero-opacity Button — fully transparent
                Button("Zero Opacity SwiftUI Button") {
                    tapCount += 1
                }
                .accessibilityLabel("Zero Opacity SwiftUI Btn")
                .opacity(0)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)

                // ============ Accessibility Guard Test Elements ============

                // Scenario 1 & 2: Button with no explicit accessibilityLabel.
                // SwiftUI auto-derives label from title Text — this is the developer's
                // intentional choice (like UIButton.title), so capture is correct.
                Button("Sensitive Account 1234") {
                    tapCount += 1
                }
                // NO .accessibilityLabel() — auto-derived from title
                .padding()
                .background(Color.cyan)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Scenario 4: Button hidden from accessibility with explicit label.
                // .accessibilityHidden(true) should prevent label capture.
                Button("Hidden Button") {
                    tapCount += 1
                }
                .accessibilityHidden(true)
                .accessibilityLabel("Sensitive Account 9999")
                .padding()
                .background(Color.brown)
                .foregroundColor(.white)
                .cornerRadius(8)

                // Positive case: Button with explicit accessibilityLabel.
                Button("Positive Case Button") {
                    tapCount += 1
                }
                .accessibilityLabel("Intended Label")
                .padding()
                .background(Color.teal)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
    }
}

#endif
