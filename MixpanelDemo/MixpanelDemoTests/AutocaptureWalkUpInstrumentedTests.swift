//
//  AutocaptureWalkUpInstrumentedTests.swift
//  MixpanelDemoTests
//
//  Created by Mixpanel on 2026-08-03.
//  Copyright (c) Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

#if os(iOS)

// MARK: - Test View Controller

/// A view controller with programmatic UI elements designed to test the walk-up-to-clickable-parent
/// behavior in SemanticExtractor. Each scenario exercises a different combination of interactivity
/// and identity on leaf vs. ancestor views.
class WalkUpUIKitTestViewController: UIViewController {

    // MARK: - Scenario 1: Non-interactive leaf (no identity) inside interactive parent

    let basicContainer: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "card_container"
        view.backgroundColor = .systemGray6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let basicLeaf: UILabel = {
        let label = UILabel()
        label.text = "Basic Leaf"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Scenario 2: Non-interactive leaf WITH accessibilityLabel inside interactive parent

    let labeledLeafContainer: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "parent_of_labeled"
        view.backgroundColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let labeledLeaf: UILabel = {
        let label = UILabel()
        label.text = "Labeled Leaf"
        label.accessibilityLabel = "leaf_label"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Scenario 3: Interactive leaf (UIButton, no identity) inside interactive parent

    let clickableLeafParent: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "parent_of_clickable"
        view.backgroundColor = .systemGray4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let clickableLeafNoId: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clickable No ID", for: .normal)
        button.accessibilityIdentifier = nil
        button.accessibilityLabel = nil
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Scenario 4: Interactive leaf (UIButton) WITH identity inside interactive parent

    let clickableLeafWithIdParent: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "parent_of_btn"
        view.backgroundColor = .systemGray3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let clickableLeafWithId: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clickable With ID", for: .normal)
        button.accessibilityIdentifier = "inner_clickable_btn"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Scenario 5: Non-interactive leaf inside NON-interactive container

    let nonInteractiveContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let nonInteractiveLeaf: UILabel = {
        let label = UILabel()
        label.text = "Non-Interactive Leaf"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Scenario 5b: Non-interactive leaf with label inside NON-interactive container

    let nonInteractiveLabeledLeaf: UILabel = {
        let label = UILabel()
        label.text = "Orphan Labeled Leaf"
        label.accessibilityLabel = "orphan_label"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Scenario 6: Nested interactives (outer > inner > leaf)

    let outerInteractive: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "outer_interactive"
        view.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let innerInteractive: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "inner_interactive"
        view.backgroundColor = .systemGreen.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let nestedLeaf: UILabel = {
        let label = UILabel()
        label.text = "Nested Leaf"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Scenario 7: Deep nesting (interactive parent > 9 non-interactive views > leaf)

    let deepParent: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "deep_parent"
        view.backgroundColor = .systemOrange.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let deepLeaf: UILabel = {
        let label = UILabel()
        label.text = "Deep Leaf"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Scenario 8: Disabled interactive parent (UIButton with isEnabled=false)

    let enabledGrandparent: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "enabled_grandparent"
        view.backgroundColor = .systemRed.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let disabledParent: UIButton = {
        let button = UIButton(type: .system)
        button.isEnabled = false
        button.accessibilityIdentifier = "disabled_parent"
        button.setTitle("Disabled Button", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let disabledLeaf: UILabel = {
        let label = UILabel()
        label.text = "Leaf inside disabled button"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }

    private func setupUI() {
        // -- Scenario 1: basicContainer > basicLeaf
        let tapGesture1 = UITapGestureRecognizer(target: self, action: #selector(noOp))
        basicContainer.addGestureRecognizer(tapGesture1)
        basicContainer.addSubview(basicLeaf)

        // -- Scenario 2: labeledLeafContainer > labeledLeaf
        let tapGesture2 = UITapGestureRecognizer(target: self, action: #selector(noOp))
        labeledLeafContainer.addGestureRecognizer(tapGesture2)
        labeledLeafContainer.addSubview(labeledLeaf)

        // -- Scenario 3: clickableLeafParent > clickableLeafNoId (button with target)
        let tapGesture3 = UITapGestureRecognizer(target: self, action: #selector(noOp))
        clickableLeafParent.addGestureRecognizer(tapGesture3)
        clickableLeafNoId.addTarget(self, action: #selector(noOp), for: .touchUpInside)
        clickableLeafParent.addSubview(clickableLeafNoId)

        // -- Scenario 4: clickableLeafWithIdParent > clickableLeafWithId (button with target + id)
        let tapGesture4 = UITapGestureRecognizer(target: self, action: #selector(noOp))
        clickableLeafWithIdParent.addGestureRecognizer(tapGesture4)
        clickableLeafWithId.addTarget(self, action: #selector(noOp), for: .touchUpInside)
        clickableLeafWithIdParent.addSubview(clickableLeafWithId)

        // -- Scenario 5: nonInteractiveContainer > nonInteractiveLeaf + nonInteractiveLabeledLeaf
        nonInteractiveContainer.addSubview(nonInteractiveLeaf)
        nonInteractiveContainer.addSubview(nonInteractiveLabeledLeaf)

        // -- Scenario 6: outerInteractive > innerInteractive > nestedLeaf
        let tapGestureOuter = UITapGestureRecognizer(target: self, action: #selector(noOp))
        outerInteractive.addGestureRecognizer(tapGestureOuter)
        let tapGestureInner = UITapGestureRecognizer(target: self, action: #selector(noOp))
        innerInteractive.addGestureRecognizer(tapGestureInner)
        innerInteractive.addSubview(nestedLeaf)
        outerInteractive.addSubview(innerInteractive)

        // -- Scenario 7: deepParent > 9 non-interactive UIViews > deepLeaf
        let tapGestureDeep = UITapGestureRecognizer(target: self, action: #selector(noOp))
        deepParent.addGestureRecognizer(tapGestureDeep)
        var currentParent: UIView = deepParent
        for _ in 0..<9 {
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            currentParent.addSubview(wrapper)
            NSLayoutConstraint.activate([
                wrapper.topAnchor.constraint(equalTo: currentParent.topAnchor),
                wrapper.leadingAnchor.constraint(equalTo: currentParent.leadingAnchor),
                wrapper.trailingAnchor.constraint(equalTo: currentParent.trailingAnchor),
                wrapper.bottomAnchor.constraint(equalTo: currentParent.bottomAnchor),
            ])
            currentParent = wrapper
        }
        currentParent.addSubview(deepLeaf)

        // -- Scenario 8: enabledGrandparent > disabledParent (UIButton, disabled) > disabledLeaf
        let tapGestureGrandparent = UITapGestureRecognizer(target: self, action: #selector(noOp))
        enabledGrandparent.addGestureRecognizer(tapGestureGrandparent)
        disabledParent.addTarget(self, action: #selector(noOp), for: .touchUpInside)
        disabledParent.addSubview(disabledLeaf)
        enabledGrandparent.addSubview(disabledParent)

        // Assemble into a scroll view with a vertical stack
        let stackView = UIStackView(arrangedSubviews: [
            basicContainer,
            labeledLeafContainer,
            clickableLeafParent,
            clickableLeafWithIdParent,
            nonInteractiveContainer,
            outerInteractive,
            deepParent,
            enabledGrandparent,
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(stackView)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        // Fixed heights for containers
        let containerHeight: CGFloat = 60
        for container in stackView.arrangedSubviews {
            container.heightAnchor.constraint(equalToConstant: containerHeight).isActive = true
        }

        // Internal constraints for leaf views within their containers

        // Scenario 1
        NSLayoutConstraint.activate([
            basicLeaf.centerXAnchor.constraint(equalTo: basicContainer.centerXAnchor),
            basicLeaf.centerYAnchor.constraint(equalTo: basicContainer.centerYAnchor),
        ])

        // Scenario 2
        NSLayoutConstraint.activate([
            labeledLeaf.centerXAnchor.constraint(equalTo: labeledLeafContainer.centerXAnchor),
            labeledLeaf.centerYAnchor.constraint(equalTo: labeledLeafContainer.centerYAnchor),
        ])

        // Scenario 3
        NSLayoutConstraint.activate([
            clickableLeafNoId.centerXAnchor.constraint(equalTo: clickableLeafParent.centerXAnchor),
            clickableLeafNoId.centerYAnchor.constraint(equalTo: clickableLeafParent.centerYAnchor),
        ])

        // Scenario 4
        NSLayoutConstraint.activate([
            clickableLeafWithId.centerXAnchor.constraint(equalTo: clickableLeafWithIdParent.centerXAnchor),
            clickableLeafWithId.centerYAnchor.constraint(equalTo: clickableLeafWithIdParent.centerYAnchor),
        ])

        // Scenario 5
        NSLayoutConstraint.activate([
            nonInteractiveLeaf.leadingAnchor.constraint(equalTo: nonInteractiveContainer.leadingAnchor, constant: 8),
            nonInteractiveLeaf.centerYAnchor.constraint(equalTo: nonInteractiveContainer.centerYAnchor),
            nonInteractiveLabeledLeaf.trailingAnchor.constraint(
                equalTo: nonInteractiveContainer.trailingAnchor, constant: -8),
            nonInteractiveLabeledLeaf.centerYAnchor.constraint(equalTo: nonInteractiveContainer.centerYAnchor),
        ])

        // Scenario 6
        NSLayoutConstraint.activate([
            innerInteractive.topAnchor.constraint(equalTo: outerInteractive.topAnchor, constant: 4),
            innerInteractive.leadingAnchor.constraint(equalTo: outerInteractive.leadingAnchor, constant: 4),
            innerInteractive.trailingAnchor.constraint(equalTo: outerInteractive.trailingAnchor, constant: -4),
            innerInteractive.bottomAnchor.constraint(equalTo: outerInteractive.bottomAnchor, constant: -4),
            nestedLeaf.centerXAnchor.constraint(equalTo: innerInteractive.centerXAnchor),
            nestedLeaf.centerYAnchor.constraint(equalTo: innerInteractive.centerYAnchor),
        ])

        // Scenario 7 - deepLeaf inside the innermost wrapper
        NSLayoutConstraint.activate([
            deepLeaf.centerXAnchor.constraint(equalTo: currentParent.centerXAnchor),
            deepLeaf.centerYAnchor.constraint(equalTo: currentParent.centerYAnchor),
        ])

        // Scenario 8
        NSLayoutConstraint.activate([
            disabledParent.topAnchor.constraint(equalTo: enabledGrandparent.topAnchor, constant: 4),
            disabledParent.leadingAnchor.constraint(equalTo: enabledGrandparent.leadingAnchor, constant: 4),
            disabledParent.trailingAnchor.constraint(equalTo: enabledGrandparent.trailingAnchor, constant: -4),
            disabledParent.bottomAnchor.constraint(equalTo: enabledGrandparent.bottomAnchor, constant: -4),
            disabledLeaf.centerXAnchor.constraint(equalTo: disabledParent.centerXAnchor),
            disabledLeaf.centerYAnchor.constraint(equalTo: disabledParent.centerYAnchor),
        ])
    }

    @objc private func noOp() {
        // Empty handler - makes the view interactive via tap gesture recognizer
    }
}

// MARK: - Walk-Up UIKit Tests

/// Instrumented tests for the walk-up-to-clickable-parent behavior in SemanticExtractor.
///
/// When a non-interactive view is tapped, the SDK walks up the view hierarchy to find the nearest
/// interactive ancestor (UIControl with targets, view with enabled UITapGestureRecognizer, or view
/// with .button accessibility trait). The element ID is then extracted from that ancestor.
///
/// If the tapped view IS interactive, no walk-up occurs and its own identity is used.
class AutocaptureWalkUpUIKitTests: MixpanelBaseTests {

    // MARK: - Properties

    private var testWindow: UIWindow!
    private var testVC: WalkUpUIKitTestViewController!
    private var mixpanel: MixpanelInstance!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()

        let setupExpectation = expectation(description: "Setup complete")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.testWindow = UIWindow(frame: UIScreen.main.bounds)
            self.testVC = WalkUpUIKitTestViewController()
            self.testWindow.rootViewController = self.testVC
            self.testWindow.makeKeyAndVisible()
            self.testWindow.layoutIfNeeded()
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 5)

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
        waitForAsyncTasks()
    }

    override func tearDown() {
        let teardownExpectation = expectation(description: "Teardown complete")
        DispatchQueue.main.async { [weak self] in
            self?.testWindow?.isHidden = true
            self?.testWindow = nil
            self?.testVC = nil
            teardownExpectation.fulfill()
        }
        wait(for: [teardownExpectation], timeout: 5)

        if let token = mixpanel?.apiToken {
            removeDBfile(token)
        }
        super.tearDown()
    }

    // MARK: - Test 1: Non-interactive leaf without identity -> walk-up -> parent's id

    func testWalkUp_NonInteractiveLeafNoIdentity_GetsParentId() {
        simulateTap(on: testVC.basicLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for non-interactive leaf")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "card_container",
                "Walk-up should resolve to interactive parent's accessibilityIdentifier")
        }
    }

    // MARK: - Test 2: Non-interactive leaf WITH label -> walk-up -> parent's id

    func testWalkUp_NonInteractiveLeafWithLabel_GetsParentId() {
        simulateTap(on: testVC.labeledLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for labeled non-interactive leaf")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "parent_of_labeled",
                "Walk-up should resolve to interactive parent's accessibilityIdentifier, ignoring leaf's label")
        }
    }

    // MARK: - Test 3: Interactive leaf (no identity) -> NO walk-up -> own hash

    func testNoWalkUp_InteractiveLeafNoIdentity_GetsOwnHash() {
        simulateTap(on: testVC.clickableLeafNoId)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for interactive leaf without identity")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertTrue(
                elId.hasPrefix("UIButton_"),
                "Interactive leaf with no identity should use hash fallback, got: \(elId)")
        }
    }

    // MARK: - Test 4: Interactive leaf WITH identity -> NO walk-up -> own id

    func testNoWalkUp_InteractiveLeafWithIdentity_GetsOwnId() {
        simulateTap(on: testVC.clickableLeafWithId)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for interactive leaf with identity")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "inner_clickable_btn",
                "Interactive leaf should use its own accessibilityIdentifier, not walk up")
        }
    }

    // MARK: - Test 5: Non-interactive leaf, no interactive ancestor -> hash fallback

    func testNoWalkUp_NonInteractiveLeafNoInteractiveAncestor_HashFallback() {
        simulateTap(on: testVC.nonInteractiveLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for orphan non-interactive leaf")

        if let props = event?.properties {
            let elId = props["$el_id"] as? String ?? ""
            XCTAssertTrue(
                elId.hasPrefix("UILabel_"),
                "Non-interactive leaf with no interactive ancestor should use hash fallback, got: \(elId)")
        }
    }

    // MARK: - Test 5b: Non-interactive leaf with label, no interactive ancestor -> own label

    func testNoWalkUp_NonInteractiveLeafWithLabelNoInteractiveAncestor_GetsOwnLabel() {
        simulateTap(on: testVC.nonInteractiveLabeledLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for orphan labeled leaf")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "orphan_label",
                "Non-interactive leaf with label but no interactive ancestor should use own accessibilityLabel")
        }
    }

    // MARK: - Test 6: Nested interactives -> stops at inner interactive

    func testWalkUp_NestedInteractives_StopsAtInner() {
        simulateTap(on: testVC.nestedLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for leaf inside nested interactives")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "inner_interactive",
                "Walk-up should stop at the nearest (inner) interactive ancestor")
        }
    }

    // MARK: - Test 7: Deep nesting within 10 levels -> walk-up finds interactive ancestor

    func testWalkUp_DeepNesting_FindsInteractiveWithin10Levels() {
        simulateTap(on: testVC.deepLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for deeply nested leaf")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "deep_parent",
                "Walk-up should find interactive ancestor within 10 levels of nesting")
        }
    }

    // MARK: - Test 8: Disabled interactive parent -> walk-up stops at disabled parent

    func testWalkUp_DisabledInteractiveParent_StopsAtDisabledParent() {
        simulateTap(on: testVC.disabledLeaf)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for leaf inside disabled interactive parent")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "disabled_parent",
                "Walk-up should stop at disabled UIButton (still has targets, so still interactive)")
        }
    }

    // MARK: - Test 9: Disabled button tapped directly -> keeps own identity

    func testNoWalkUp_DisabledButtonTappedDirectly_KeepsOwnId() {
        simulateTap(on: testVC.disabledParent)

        let event = waitForEvent(named: "$mp_click", timeout: 5)
        XCTAssertNotNil(event, "Should capture $mp_click event for disabled button tapped directly")

        if let props = event?.properties {
            XCTAssertEqual(
                props["$el_id"] as? String, "disabled_parent",
                "Disabled button tapped directly should keep its own identity")
        }
    }

    // MARK: - Helper Methods

    /// Simulate a tap on a view by calling handleTouch on the autocapture manager.
    private func simulateTap(on view: UIView) {
        let tapExpectation = expectation(description: "Tap simulated")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.testWindow else {
                tapExpectation.fulfill()
                return
            }

            let center = view.superview?.convert(view.center, to: window) ?? view.center
            self.mixpanel.autocaptureManager?.handleTouch(at: center, view: view, window: window)

            tapExpectation.fulfill()
        }

        wait(for: [tapExpectation], timeout: 2)
    }

    /// Poll the event queue until an event with the given name appears, or timeout.
    private func waitForEvent(named eventName: String, timeout: TimeInterval) -> (
        name: String, properties: [String: Any]
    )? {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            waitForTrackingQueue(mixpanel)

            let events = eventQueue(token: mixpanel.apiToken)
            if let match = events.first(where: { ($0["event"] as? String) == eventName }),
                let props = match["properties"] as? [String: Any]
            {
                return (name: eventName, properties: props)
            }

            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }

        return nil
    }
}

#endif
