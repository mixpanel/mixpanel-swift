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
        accessibleLabel: "Test Button",
        role: "Button",
        elements: "UIButton > UIView"
      )

      let props = event.toProperties()

      XCTAssertEqual(props["$x"] as? Int, 100)
      XCTAssertEqual(props["$y"] as? Int, 200)
      XCTAssertEqual(props["$el_id"] as? String, "test_button")
      XCTAssertEqual(props["$el_tag_name"] as? String, "UIButton")
      XCTAssertEqual(props["$attr-aria-label"] as? String, "Test Button")
      XCTAssertEqual(props["$attr-role"] as? String, "Button")
      XCTAssertEqual(props["$elements"] as? String, "UIButton > UIView")
    }

    func testToPropertiesOmitsNilValues() {
      let event = ClickEvent(
        x: 100,
        y: 200,
        elementId: "test_button",
        tagName: "UIButton",
        accessibleLabel: nil,
        role: nil,
        elements: "UIButton"
      )

      let props = event.toProperties()

      XCTAssertNil(props["$attr-aria-label"])
      XCTAssertNil(props["$attr-role"])
    }
  }
#endif
