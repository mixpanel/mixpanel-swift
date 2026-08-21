//
//  AutocaptureTests.swift
//  MixpanelDemoTests
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

#if os(iOS)
class AutocaptureOptionsTests: XCTestCase {

    // MARK: - ClickOptions Tests

    func testClickOptionsDefaultsToEnabled() {
        let options = ClickOptions()
        XCTAssertTrue(options.enabled)
    }

    func testClickOptionsCanBeDisabled() {
        let options = ClickOptions(enabled: false)
        XCTAssertFalse(options.enabled)
    }

    // MARK: - RageClickOptions Tests

    func testRageClickOptionsDefaults() {
        let options = RageClickOptions()
        XCTAssertTrue(options.enabled)
        XCTAssertEqual(options.clickThreshold, 4)
        XCTAssertEqual(options.timeWindowMs, 1000)
        XCTAssertEqual(options.radius, 44)
    }

    func testRageClickOptionsCustomValues() {
        let options = RageClickOptions(
            enabled: true,
            clickThreshold: 5,
            timeWindowMs: 800,
            radius: 60
        )
        XCTAssertEqual(options.clickThreshold, 5)
        XCTAssertEqual(options.timeWindowMs, 800)
        XCTAssertEqual(options.radius, 60)
    }

    // MARK: - DeadClickOptions Tests

    func testDeadClickOptionsDefaults() {
        let options = DeadClickOptions()
        XCTAssertTrue(options.enabled)
        XCTAssertEqual(options.timeWindowMs, 500)
    }

    func testDeadClickOptionsCustomValues() {
        let options = DeadClickOptions(
            enabled: false,
            timeWindowMs: 700
        )
        XCTAssertFalse(options.enabled)
        XCTAssertEqual(options.timeWindowMs, 700)
    }

    // MARK: - AutocaptureOptions Tests

    func testAutocaptureOptionsDefaults() {
        let options = AutocaptureOptions()
        XCTAssertTrue(options.isEnabled)
        XCTAssertTrue(options.clickOptions.enabled)
        XCTAssertTrue(options.rageClickOptions.enabled)
        XCTAssertTrue(options.deadClickOptions.enabled)
    }

    func testAutocaptureOptionsIsEnabledWhenAnyFeatureEnabled() {
        // Only click enabled
        let clickOnly = AutocaptureOptions(
            clickOptions: ClickOptions(enabled: true),
            rageClickOptions: RageClickOptions(enabled: false),
            deadClickOptions: DeadClickOptions(enabled: false)
        )
        XCTAssertTrue(clickOnly.isEnabled)

        // Only rage click enabled
        let rageOnly = AutocaptureOptions(
            clickOptions: ClickOptions(enabled: false),
            rageClickOptions: RageClickOptions(enabled: true),
            deadClickOptions: DeadClickOptions(enabled: false)
        )
        XCTAssertTrue(rageOnly.isEnabled)

        // Only dead click enabled
        let deadOnly = AutocaptureOptions(
            clickOptions: ClickOptions(enabled: false),
            rageClickOptions: RageClickOptions(enabled: false),
            deadClickOptions: DeadClickOptions(enabled: true)
        )
        XCTAssertTrue(deadOnly.isEnabled)
    }

    func testAutocaptureOptionsIsDisabledWhenAllFeaturesDisabled() {
        let options = AutocaptureOptions(
            clickOptions: ClickOptions(enabled: false),
            rageClickOptions: RageClickOptions(enabled: false),
            deadClickOptions: DeadClickOptions(enabled: false)
        )
        XCTAssertFalse(options.isEnabled)
    }
}

class RageClickTrackerTests: XCTestCase {

    // MARK: - Basic Detection

    func testSingleClickIsNotRageClick() {
        let options = RageClickOptions()
        let tracker = RageClickTracker(options: options)

        let result = tracker.trackClick(x: 100, y: 100)

        XCTAssertFalse(result.isRageClick)
    }

    func testThreeClicksIsNotRageClick() {
        let options = RageClickOptions(clickThreshold: 4)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // First 3 clicks - should not be rage click
        for i in 1...3 {
            let result = tracker.trackClick(x: 100, y: 100)
            XCTAssertFalse(result.isRageClick, "Click \(i) should not be rage click")
            currentTime += 100  // 100ms between clicks
        }
    }

    func testFourClicksTriggersRageClick() {
        let options = RageClickOptions(clickThreshold: 4)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // First 3 clicks
        for _ in 1...3 {
            _ = tracker.trackClick(x: 100, y: 100)
            currentTime += 100
        }

        // Fourth click should trigger rage click
        let result = tracker.trackClick(x: 100, y: 100)
        XCTAssertTrue(result.isRageClick)
    }

    // MARK: - Time Window

    func testClicksOutsideTimeWindowNotRageClick() {
        let options = RageClickOptions(clickThreshold: 4, timeWindowMs: 1000)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // First click at t=1000
        _ = tracker.trackClick(x: 100, y: 100)

        // Second click at t=1100
        currentTime = 1100
        _ = tracker.trackClick(x: 100, y: 100)

        // Third click at t=1200
        currentTime = 1200
        _ = tracker.trackClick(x: 100, y: 100)

        // Fourth click at t=2100 (outside 1000ms window from first click)
        currentTime = 2100
        let result = tracker.trackClick(x: 100, y: 100)

        // First click is expired, so we only have 3 clicks in window
        XCTAssertFalse(result.isRageClick)
    }

    func testClicksWithinTimeWindowTriggersRageClick() {
        let options = RageClickOptions(clickThreshold: 4, timeWindowMs: 1000)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // All clicks within 1000ms window
        for i in 0..<4 {
            currentTime = Int64(1000 + i * 200)  // 0, 200, 400, 600ms
            let result = tracker.trackClick(x: 100, y: 100)
            if i == 3 {
                XCTAssertTrue(result.isRageClick)
            }
        }
    }

    // MARK: - Spatial Threshold

    func testClicksOutsideSpatialRadiusNotRageClick() {
        let options = RageClickOptions(clickThreshold: 4, radius: 44)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // Clicks at positions more than 44pt apart
        _ = tracker.trackClick(x: 0, y: 0)
        currentTime += 100
        _ = tracker.trackClick(x: 100, y: 0)  // 100pt away
        currentTime += 100
        _ = tracker.trackClick(x: 200, y: 0)  // 100pt away
        currentTime += 100
        let result = tracker.trackClick(x: 300, y: 0)  // 100pt away

        // Each click is too far from previous, not rage click
        XCTAssertFalse(result.isRageClick)
    }

    func testClicksWithinSpatialRadiusTriggersRageClick() {
        let options = RageClickOptions(clickThreshold: 4, radius: 50)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // Clicks within 50pt radius
        _ = tracker.trackClick(x: 100, y: 100)
        currentTime += 100
        _ = tracker.trackClick(x: 110, y: 110)  // ~14pt away
        currentTime += 100
        _ = tracker.trackClick(x: 120, y: 100)  // ~22pt from original
        currentTime += 100
        let result = tracker.trackClick(x: 105, y: 105)  // ~7pt from original

        XCTAssertTrue(result.isRageClick)
    }

    // MARK: - Reset

    func testResetClearsClickHistory() {
        let options = RageClickOptions(clickThreshold: 4)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // Track 3 clicks
        for _ in 1...3 {
            _ = tracker.trackClick(x: 100, y: 100)
            currentTime += 100
        }

        // Reset
        tracker.reset()

        // Fourth click after reset should be like first click
        let result = tracker.trackClick(x: 100, y: 100)
        XCTAssertFalse(result.isRageClick)
    }

    // MARK: - Custom Threshold

    func testCustomClickThreshold() {
        let options = RageClickOptions(clickThreshold: 6)
        var currentTime: Int64 = 1000
        let tracker = RageClickTracker(options: options, timeProvider: { currentTime })

        // 5 clicks should not trigger
        for i in 1...5 {
            let result = tracker.trackClick(x: 100, y: 100)
            XCTAssertFalse(result.isRageClick, "Click \(i) should not be rage click with threshold 6")
            currentTime += 100
        }

        // 6th click should trigger
        let result = tracker.trackClick(x: 100, y: 100)
        XCTAssertTrue(result.isRageClick)
    }
}

class ClickEventTests: XCTestCase {

    func testToPropertiesIncludesRequiredFields() {
        let event = ClickEvent(
            x: 100,
            y: 200,
            elementId: "test_button",
            tagName: "UIButton",
            role: "Button",
            elements: "UIButton > UIView"
        )

        let props = event.toProperties()

        XCTAssertEqual(props["$x"] as? Int, 100)
        XCTAssertEqual(props["$y"] as? Int, 200)
        XCTAssertEqual(props["$el_id"] as? String, "test_button")
        XCTAssertEqual(props["$el_tag_name"] as? String, "UIButton")
        XCTAssertNil(props["$attr-aria-label"], "Accessibility labels are never reported")
        XCTAssertEqual(props["$attr-role"] as? String, "Button")
        XCTAssertEqual(props["$elements"] as? String, "UIButton > UIView")
    }

    func testToPropertiesOmitsNilValues() {
        let event = ClickEvent(
            x: 100,
            y: 200,
            elementId: "test_button"
        )

        let props = event.toProperties()

        XCTAssertNil(props["$el_tag_name"])
        XCTAssertNil(props["$attr-aria-label"])
        XCTAssertNil(props["$attr-role"])
        XCTAssertNil(props["$elements"])
    }
}

// MARK: - Element ID Resolution Order

/// Stands in for React Native's `RCTView`: an `@objc` `nativeID` property makes `responds(to:)` and
/// `value(forKey:)` behave exactly as they do on a real React Native view.
private final class FakeReactNativeView: UIView {
    @objc var nativeID: String?
}

/// Tests the `$el_id` resolution order implemented by `DefaultElementIdExtractor`:
/// React Native `nativeID` > `accessibilityIdentifier` > `<ClassName>_<hash>`. Accessibility labels
/// are never a source: they are localized and can carry user data.
class DefaultElementIdExtractorTests: XCTestCase {

    /// Matches the anonymous fallback: ClassName_hexHash.
    private let hashIdPattern = "^[A-Za-z0-9_]+_[0-9a-f]+$"

    private let extractor = DefaultElementIdExtractor.shared

    /// The resolver takes a SwiftUI accessibility-tree fallback identifier; the cases below exercise
    /// the UIKit path, where there is none. The SwiftUI cases pass one explicitly.
    private func elementId(for view: UIView) -> String {
        return extractor.elementId(for: view, accessibilityIdentifierFallback: nil)
    }

    private func assertMatchesHashFallback(_ elementId: String, _ message: String = "") {
        XCTAssertNotNil(
            elementId.range(of: hashIdPattern, options: .regularExpression),
            "Expected <ClassName>_<hash>, got: \(elementId). \(message)")
    }

    // MARK: - Priority 1: React Native nativeID

    func testNativeIdWinsOverIdentifierAndLabel() {
        let view = FakeReactNativeView()
        view.nativeID = "rn_checkout_button"
        view.accessibilityIdentifier = "checkout_identifier"
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Checkout"

        XCTAssertEqual(elementId(for: view), "rn_checkout_button")
    }

    func testEmptyNativeIdFallsThroughToIdentifier() {
        let view = FakeReactNativeView()
        view.nativeID = ""
        view.accessibilityIdentifier = "checkout_identifier"

        XCTAssertEqual(elementId(for: view), "checkout_identifier")
    }

    func testViewWithoutNativeIdPropertyIsHandled() {
        // A plain UIView does not declare `nativeID`; the KVC probe must not throw.
        let view = UIView()
        view.accessibilityIdentifier = "plain_view"

        XCTAssertEqual(elementId(for: view), "plain_view")
    }

    // MARK: - Priority 2: accessibilityIdentifier

    func testIdentifierIsUsedAndLabelIsIgnored() {
        // The identifier is stable and never user-visible; the label is neither.
        let button = UIButton()
        button.accessibilityIdentifier = "checkout_identifier"
        button.accessibilityLabel = "Checkout"

        XCTAssertEqual(elementId(for: button), "checkout_identifier")
    }

    func testEmptyIdentifierFallsThroughToTheStructuralHash() {
        let button = UIButton()
        button.accessibilityIdentifier = ""
        button.accessibilityLabel = "Checkout"

        let elementId = elementId(for: button)
        assertMatchesHashFallback(elementId)
        XCTAssertFalse(elementId.contains("Checkout"), "Labels are never used as identity")
    }

    func testInternalIdentifiersAreSkipped() {
        for internalIdentifier in ["_privateThing", "AXID-42", "UITransitionView-1"] {
            let button = UIButton()
            button.accessibilityIdentifier = internalIdentifier

            assertMatchesHashFallback(
                elementId(for: button),
                "Framework-internal identifier \(internalIdentifier) should be skipped")
        }
    }

    // MARK: - Accessibility labels are never used

    func testLabelIsNeverUsedAsIdentity() {
        // Localized text would give the same element a different id per language, and a label can
        // carry user data, so no view shape may resolve to it.
        for view in [UILabel(), UIButton(), UIView()] as [UIView] {
            view.isAccessibilityElement = true
            view.accessibilityLabel = "Account ending 4321"

            let elementId = elementId(for: view)
            assertMatchesHashFallback(elementId)
            XCTAssertFalse(
                elementId.contains("4321"),
                "\(type(of: view)) leaked its label into $el_id")
        }
    }

    // MARK: - Priority 4: hash fallback

    func testHashFallbackUsesClassName() {
        let elementId = elementId(for: UIButton())

        XCTAssertNotNil(
            elementId.range(of: "^UIButton_[0-9a-f]+$", options: .regularExpression),
            "Expected UIButton_<hash>, got: \(elementId)")
    }

    func testHashFallbackIsStableForTheSameStructure() {
        // The hash describes where the view sits, not which instance it is, so an identical layout
        // built twice — as on every launch — resolves to the same id.
        func buildLeaf() -> UIView {
            let root = UIView()
            let row = UIView()
            let leaf = UIButton()
            row.addSubview(leaf)
            root.addSubview(row)
            return leaf
        }

        XCTAssertEqual(
            elementId(for: buildLeaf()),
            elementId(for: buildLeaf()),
            "The same structure must resolve to the same id")
    }

    func testHashFallbackDistinguishesSiblingPositions() {
        let root = UIView()
        let first = UIButton()
        let second = UIButton()
        root.addSubview(first)
        root.addSubview(second)

        XCTAssertNotEqual(
            elementId(for: first), elementId(for: second),
            "Siblings at different positions must resolve to different ids")
    }

    func testAnonymousIdMatchesTheDefaultChainFallback() {
        // The end of the resolution chain and anonymousId() must produce the same identifier — the
        // hash fallback has no second implementation.
        let view = UIButton()

        XCTAssertEqual(
            elementId(for: view),
            DefaultElementIdExtractor.anonymousId(for: view))
    }

    // MARK: - SwiftUI fallbacks (values read from the accessibility element tree)

    func testIdentifierFallbackUsedWhenViewHasNoIdentifier() {
        let view = UIView()

        XCTAssertEqual(
            extractor.elementId(
                for: view, accessibilityIdentifierFallback: "swiftui_checkout"),
            "swiftui_checkout",
            "The SwiftUI identifier read from the accessibility tree is used")
    }

    func testViewIdentifierWinsOverIdentifierFallback() {
        let view = UIView()
        view.accessibilityIdentifier = "own_identifier"

        XCTAssertEqual(
            extractor.elementId(for: view, accessibilityIdentifierFallback: "tree_identifier"),
            "own_identifier")
    }

    func testStructuralHashUsedWhenNoIdentifierAnywhere() {
        let view = UIView()

        assertMatchesHashFallback(
            extractor.elementId(for: view, accessibilityIdentifierFallback: nil))
    }

    func testInternalIdentifierFallbackIsSkipped() {
        let view = UIView()

        let elementId = extractor.elementId(
            for: view, accessibilityIdentifierFallback: "_UIKitInternal")

        assertMatchesHashFallback(elementId)
    }

    func testEmptyIdentifierFallbackResolvesToHash() {
        let view = UIView()

        assertMatchesHashFallback(
            extractor.elementId(for: view, accessibilityIdentifierFallback: ""))
    }
}

/// Verifies the `$el_id` that reaches the `ClickEvent` — the integration point between
/// `DefaultElementIdExtractor` and the hit-test path.
class SemanticExtractorElementIdTests: XCTestCase {

    private let point = CGPoint(x: 10, y: 20)

    private func elementId(for view: UIView) -> String {
        return SemanticExtractor()
            .extractSemantics(from: view, at: point)
            .elementId
    }

    func testAccessibilityIdentifierResolvesElementId() {
        let button = UIButton()
        button.accessibilityIdentifier = "checkout_identifier"
        button.accessibilityLabel = "Checkout"

        XCTAssertEqual(elementId(for: button), "checkout_identifier")
    }

    func testViewWithoutIdentifierFallsBackToAnonymousId() {
        let button = UIButton()
        button.accessibilityLabel = "Checkout"

        let resolved = elementId(for: button)

        XCTAssertEqual(resolved, DefaultElementIdExtractor.anonymousId(for: button))
        XCTAssertFalse(resolved.contains("Checkout"))
    }

    func testAccessibilityLabelIsNeverReported() {
        // The identifier wins $el_id, and the label is not reported anywhere.
        let button = UIButton()
        button.accessibilityIdentifier = "checkout_identifier"
        button.accessibilityLabel = "Checkout"

        let event = SemanticExtractor()
            .extractSemantics(from: button, at: point)

        XCTAssertEqual(event.elementId, "checkout_identifier")
        XCTAssertNil(
            event.toProperties()["$attr-aria-label"],
            "Accessibility labels are localized and can carry user data — never reported")
    }
}

/// End-to-end coverage for `$el_id`: the identifier the SDK resolves must survive SDK
/// initialization and govern the `$el_id` of a `$mp_click` produced by a real touch.
class ElementIdExtractorEndToEndTests: MixpanelBaseTests {

    private var testWindow: UIWindow!
    private var testViewController: UIViewController!
    private var button: UIButton!
    private var mixpanel: MixpanelInstance!

    override func setUp() {
        super.setUp()

        let setupExpectation = expectation(description: "Setup complete")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.button = UIButton(type: .system)
            self.button.setTitle("Checkout", for: .normal)
            self.button.accessibilityIdentifier = "checkout_identifier"
            self.button.accessibilityLabel = "Checkout"
            self.button.frame = CGRect(x: 20, y: 100, width: 200, height: 44)
            self.button.addTarget(self, action: #selector(self.buttonTapped), for: .touchUpInside)

            self.testViewController = UIViewController()
            self.testViewController.view.addSubview(self.button)

            self.testWindow = UIWindow(frame: UIScreen.main.bounds)
            self.testWindow.rootViewController = self.testViewController
            self.testWindow.makeKeyAndVisible()
            self.testWindow.layoutIfNeeded()

            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 5)
    }

    override func tearDown() {
        let teardownExpectation = expectation(description: "Teardown complete")
        DispatchQueue.main.async { [weak self] in
            self?.testWindow?.isHidden = true
            self?.testWindow = nil
            self?.testViewController = nil
            self?.button = nil
            teardownExpectation.fulfill()
        }
        wait(for: [teardownExpectation], timeout: 5)

        if let token = mixpanel?.apiToken {
            removeDBfile(token)
        }
        mixpanel = nil
        super.tearDown()
    }

    @objc private func buttonTapped() {}

    func testDefaultResolutionEndToEnd() {
        startMixpanel()

        simulateTap()

        let properties = waitForClickProperties()
        XCTAssertNotNil(properties, "Should capture $mp_click event")
        XCTAssertEqual(properties?["$el_id"] as? String, "checkout_identifier")
    }

    /// A React Native view exposes the JS-side `nativeID` prop as an `@objc` property; it must win
    /// $el_id over the accessibility metadata React Native also sets.
    func testReactNativeNativeIdWinsEndToEnd() {
        startMixpanel()

        let setupExpectation = expectation(description: "RN view added")
        let rnView = FakeReactNativeView()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            rnView.nativeID = "rn_checkout_button"
            rnView.accessibilityIdentifier = "rn_view_identifier"
            rnView.isAccessibilityElement = true
            rnView.accessibilityLabel = "Checkout"
            rnView.frame = CGRect(x: 20, y: 200, width: 200, height: 44)
            // React Native attaches touch handling via gesture recognizers; one is enough to make
            // the view read as interactive so the hit test stops here instead of walking up.
            rnView.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(self.buttonTapped)))
            self.testViewController.view.addSubview(rnView)
            self.testWindow.layoutIfNeeded()
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 5)

        let tapExpectation = expectation(description: "Tap simulated")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.testWindow else {
                tapExpectation.fulfill()
                return
            }
            let center = rnView.superview?.convert(rnView.center, to: window) ?? rnView.center
            self.mixpanel.autocaptureManager?.handleTouch(at: center, view: rnView, window: window)
            tapExpectation.fulfill()
        }
        wait(for: [tapExpectation], timeout: 2)

        let properties = waitForClickProperties()
        XCTAssertNotNil(properties, "Should capture $mp_click event")
        XCTAssertEqual(properties?["$el_id"] as? String, "rn_checkout_button")
    }

    // MARK: - Helpers

    private func startMixpanel() {
        let token = randomId()
        let options = MixpanelOptions(
            token: token,
            flushInterval: 60,
            instanceName: token,
            trackAutomaticEvents: false,
            optOutTrackingByDefault: false,
            serverURL: kFakeServerUrl,
            autocaptureOptions: AutocaptureOptions(
                clickOptions: ClickOptions(enabled: true),
                rageClickOptions: RageClickOptions(enabled: false),
                deadClickOptions: DeadClickOptions(enabled: false)
            )
        )

        mixpanel = Mixpanel.initialize(options: options)
        waitForAsyncTasks()
    }

    private func simulateTap() {
        let tapExpectation = expectation(description: "Tap simulated")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.testWindow, let button = self.button else {
                tapExpectation.fulfill()
                return
            }
            let center = button.superview?.convert(button.center, to: window) ?? button.center
            self.mixpanel.autocaptureManager?.handleTouch(at: center, view: button, window: window)
            tapExpectation.fulfill()
        }
        wait(for: [tapExpectation], timeout: 2)
    }

    private func waitForClickProperties(timeout: TimeInterval = 5) -> [String: Any]? {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            waitForTrackingQueue(mixpanel)

            let events = eventQueue(token: mixpanel.apiToken)
            if let match = events.first(where: { ($0["event"] as? String) == "$mp_click" }),
                let properties = match["properties"] as? [String: Any]
            {
                return properties
            }

            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        return nil
    }
}
#endif
