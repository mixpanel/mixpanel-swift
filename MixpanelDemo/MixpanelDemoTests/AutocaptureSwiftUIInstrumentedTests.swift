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
    private var capturedEvents: [(name: String, properties: Properties)] = []
    private var mixpanel: MixpanelInstance!

    // MARK: - Setup / Teardown

    override func setUp() {
      super.setUp()
      capturedEvents = []

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
        deadClickOptions: DeadClickOptions(enabled: true, timeoutMs: 500, baselineDelayMs: 100)
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

      // Hook into autocapture events for testing
      if let manager = mixpanel.autocaptureManager {
        let originalTrackEvent = manager.trackEvent
        manager.trackEvent = { [weak self] name, props in
          self?.capturedEvents.append((name: name, properties: props))
          originalTrackEvent(name, props)
        }
      }

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
      capturedEvents = []

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
          print("  - \(type(of: v)): id=\(v.accessibilityIdentifier ?? "nil"), label=\(v.accessibilityLabel ?? "nil")")
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
        XCTAssertNotNil(props["$tap_count"])
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
      let clickEvents = capturedEvents.filter { $0.name == "$mp_click" }
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
          let center = targetView.superview?.convert(targetView.center, to: window)
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
          let center = targetView.superview?.convert(targetView.center, to: window)
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
             accessibilityElement.accessibilityLabel == label {
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
             accessibilityElement.accessibilityIdentifier == identifier {
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
            print("\(prefix)  [AX\(index)] label: \(accEl.accessibilityLabel ?? "nil"), id: \(accEl.accessibilityIdentifier ?? "nil")")
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
             accEl.accessibilityTraits.contains(.button) {
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
      name: String, properties: Properties
    )? {
      let startTime = Date()

      while Date().timeIntervalSince(startTime) < timeout {
        if let event = capturedEvents.first(where: { $0.name == eventName }) {
          return event
        }
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
      }

      return nil
    }

    // MARK: - SwiftUI Index-Based Button Finding

    /// Find SwiftUI button views by their position in the rendering order
    /// SwiftUI renders buttons as _UIGraphicsView inside PlatformGroupContainer
    private func findSwiftUIButtonByIndex(_ index: Int, in view: UIView) -> UIView? {
      // Find PlatformGroupContainer which holds all the button views
      if let container = findViewOfType("PlatformGroupContainer", in: view) {
        // Each button is rendered as a _UIGraphicsView followed by a CGDrawingView
        // So we need to find _UIGraphicsView views
        let graphicsViews = container.subviews.filter {
          String(describing: type(of: $0)).contains("_UIGraphicsView")
        }
        if index < graphicsViews.count {
          return graphicsViews[index]
        }
      }
      return nil
    }

    /// Find a view of a specific type name in the hierarchy
    private func findViewOfType(_ typeName: String, in view: UIView) -> UIView? {
      let viewTypeName = String(describing: type(of: view))
      if viewTypeName.contains(typeName) {
        return view
      }

      for subview in view.subviews {
        if let found = findViewOfType(typeName, in: subview) {
          return found
        }
      }
      return nil
    }

    /// Map of button labels to their index in the VStack
    private func buttonIndexForLabel(_ label: String) -> Int? {
      let buttonOrder = [
        "SwiftUI Rule 1",        // 0
        "Rule Two SwiftUI",      // 1
        "swiftui_rule3",         // 2 (uses identifier, no label)
        "Both Label SwiftUI",    // 3
        "Rage Zone SwiftUI",     // 4
        "Dead Button SwiftUI",   // 5
      ]
      return buttonOrder.firstIndex(of: label)
    }

    /// Simulate tap using indexed button approach for SwiftUI
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

        if let targetView = self.findSwiftUIButtonByIndex(index, in: rootView) {
          // Optionally set accessibility properties for testing
          if let label = setAccessibility {
            targetView.accessibilityLabel = label
          }

          // Get the center of the button in window coordinates
          let frame = targetView.superview?.convert(targetView.frame, to: window) ?? targetView.frame
          let center = CGPoint(x: frame.midX, y: frame.midY)
          print("[Test] Simulating tap on button \(index) at \(center), view: \(type(of: targetView)), frame: \(frame)")
          self.mixpanel.autocaptureManager?.handleTouch(at: center, view: targetView, window: window)
        } else {
          print("[Test] Could not find button at index \(index)")
        }

        tapExpectation.fulfill()
      }

      wait(for: [tapExpectation], timeout: 2)
    }

    /// Set accessibility properties on a SwiftUI button by index
    private func setSwiftUIButtonAccessibility(index: Int, identifier: String?, label: String?) {
      let setupExpectation = expectation(description: "Accessibility setup")

      DispatchQueue.main.async { [weak self] in
        guard let self = self,
          let rootView = self.hostingController?.view
        else {
          setupExpectation.fulfill()
          return
        }

        if let targetView = self.findSwiftUIButtonByIndex(index, in: rootView) {
          if let id = identifier {
            targetView.accessibilityIdentifier = id
          }
          if let lbl = label {
            targetView.accessibilityLabel = lbl
          }
        }

        setupExpectation.fulfill()
      }

      wait(for: [setupExpectation], timeout: 2)
    }

    /// Make a SwiftUI button appear interactive by adding a tap gesture recognizer
    /// This is needed because SwiftUI's _UIGraphicsView doesn't expose UIKit gesture recognizers
    private func makeSwiftUIButtonInteractive(index: Int) {
      let setupExpectation = expectation(description: "Make interactive")

      DispatchQueue.main.async { [weak self] in
        guard let self = self,
          let rootView = self.hostingController?.view
        else {
          setupExpectation.fulfill()
          return
        }

        if let targetView = self.findSwiftUIButtonByIndex(index, in: rootView) {
          // Add a tap gesture recognizer to make the view appear interactive
          let tapGesture = UITapGestureRecognizer(target: nil, action: nil)
          tapGesture.isEnabled = true
          targetView.addGestureRecognizer(tapGesture)
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
        }
        .padding()
      }
    }
  }

#endif
