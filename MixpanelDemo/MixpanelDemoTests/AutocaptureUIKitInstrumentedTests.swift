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
        serverURL: kFakeServerUrl
      )
      options.autocaptureOptions = autocaptureOptions

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

      // Wait and check event queue for full properties
      waitForTrackingQueue(mixpanel)

      // Then: Should have standard Mixpanel properties
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
              let manager = self.mixpanel.autocaptureManager else {
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
           let props = match["properties"] as? [String: Any] {
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
        deadButton,
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

#endif
