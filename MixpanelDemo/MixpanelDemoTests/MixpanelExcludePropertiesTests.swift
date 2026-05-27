//
//  MixpanelExcludePropertiesTests.swift
//  MixpanelDemoTests
//

import XCTest

@testable import Mixpanel

class MixpanelExcludePropertiesTests: MixpanelBaseTests {

  // MARK: - Direct helper tests (mirror Android ExcludePropertiesTest)

  /// Mirrors a representative subset of what the SDK puts in the properties bag for an event:
  /// reserved identity/routing keys, auto-properties, and a custom user property.
  private func buildSampleEventProps() -> InternalProperties {
    return [
      "token": "test-token",
      "time": 1_700_000_000_000.0,
      "distinct_id": "abc-123",
      "$device_id": "device-xyz",
      "$user_id": "user-42",
      "$had_persisted_distinct_id": true,
      "$insert_id": "insert-1",
      "mp_lib": "swift",
      "$lib_version": "5.0.0",
      "$os": "iOS",
      "$screen_height": 1920,
      "$screen_width": 1080,
      "$carrier": "Verizon",
      "custom_user_prop": "value",
    ]
  }

  func testEmptyExcludeSetIsNoOp() {
    var props = buildSampleEventProps()
    let before = props.count
    Track.applyExcludeProperties(&props, exclude: [])
    XCTAssertEqual(props.count, before)
  }

  func testStripsAutoProperty() {
    var props = buildSampleEventProps()
    Track.applyExcludeProperties(&props, exclude: ["$screen_height"])
    XCTAssertNil(props["$screen_height"])
    // Adjacent auto-props remain untouched.
    XCTAssertNotNil(props["$screen_width"])
    XCTAssertNotNil(props["$lib_version"])
  }

  func testStripsCustomUserProperty() {
    var props = buildSampleEventProps()
    Track.applyExcludeProperties(&props, exclude: ["custom_user_prop"])
    XCTAssertNil(props["custom_user_prop"])
  }

  func testReservedKeysAreNeverStripped() {
    var props = buildSampleEventProps()
    // Drive the test from the canonical reserved set so adding a new reserved key
    // here automatically tightens this test rather than leaving it stale.
    let exclude = MixpanelOptions.reservedPropertyKeys

    // Sanity check: every reserved key we're about to try to exclude is actually
    // present in the sample, otherwise the test would silently pass for missing keys.
    for key in MixpanelOptions.reservedPropertyKeys {
      XCTAssertNotNil(props[key], "Sample event props is missing reserved key \(key)")
    }

    Track.applyExcludeProperties(&props, exclude: exclude)

    for key in MixpanelOptions.reservedPropertyKeys {
      XCTAssertNotNil(props[key], "Reserved key was stripped: \(key)")
    }
  }

  /// `$insert_id` is in the Mixpanel ingestion vocabulary but this SDK never writes it
  /// (we use `$mp_event_id` inside `$mp_metadata` for dedup, which lives outside the
  /// properties bag). If a customer lists `$insert_id` in their exclude set we should
  /// honor it — there's nothing to protect.
  func testInsertIdIsNotReserved() {
    var props = buildSampleEventProps()
    Track.applyExcludeProperties(&props, exclude: ["$insert_id"])
    XCTAssertNil(props["$insert_id"])
  }

  func testMultiplePropertiesStripped() {
    var props = buildSampleEventProps()
    let exclude: Set<String> = [
      "$screen_height", "$screen_width", "$carrier", "custom_user_prop",
    ]

    Track.applyExcludeProperties(&props, exclude: exclude)

    XCTAssertNil(props["$screen_height"])
    XCTAssertNil(props["$screen_width"])
    XCTAssertNil(props["$carrier"])
    XCTAssertNil(props["custom_user_prop"])
    // Untouched samples
    XCTAssertNotNil(props["$os"])
    XCTAssertNotNil(props["$lib_version"])
  }

  func testExcludedKeyNotPresentIsNoOp() {
    var props = buildSampleEventProps()
    let before = props.count
    Track.applyExcludeProperties(&props, exclude: ["never_added"])
    XCTAssertEqual(props.count, before)
  }

  // MARK: - End-to-end integration tests

  /// Pick the event by name — `identify` (and other auto-events) can land on the queue
  /// alongside the event under test, so `.last!` is unreliable.
  private func findEvent(
    in mixpanel: MixpanelInstance, named eventName: String
  ) -> InternalProperties? {
    return eventQueue(token: mixpanel.apiToken).first(where: {
      ($0["event"] as? String) == eventName
    })
  }

  func testExcludePropertiesStripsAutoAndCustomFromQueuedEvent() {
    let token = randomId()
    let options = MixpanelOptions(
      token: token,
      flushInterval: 60,
      excludeProperties: ["$lib_version", "custom_prop"])
    let testMixpanel = Mixpanel.initialize(options: options)
    testMixpanel.track(event: "test_event", properties: ["custom_prop": "v", "keep_me": "yes"])
    waitForTrackingQueue(testMixpanel)

    let event = findEvent(in: testMixpanel, named: "test_event")!
    let props = event["properties"] as! InternalProperties

    // Excluded keys are gone.
    XCTAssertNil(props["$lib_version"])
    XCTAssertNil(props["custom_prop"])
    // Non-excluded custom property survives.
    XCTAssertEqual(props["keep_me"] as? String, "yes")
    // Reserved keys still present.
    XCTAssertNotNil(props["token"])
    XCTAssertNotNil(props["time"])
    XCTAssertNotNil(props["distinct_id"])
    // $mp_metadata lives at the envelope level, not inside properties — confirm it
    // survives at the envelope (the filter's scope ends at `properties`).
    XCTAssertNotNil(event["$mp_metadata"])

    removeDBfile(testMixpanel.apiToken)
  }

  func testExcludePropertiesCannotStripReservedKeysEndToEnd() {
    let token = randomId()
    let options = MixpanelOptions(
      token: token,
      flushInterval: 60,
      // Customer mistakenly lists a reserved key — must still be sent.
      excludeProperties: ["distinct_id", "token"])
    let testMixpanel = Mixpanel.initialize(options: options)
    testMixpanel.track(event: "test_event")
    waitForTrackingQueue(testMixpanel)

    let event = findEvent(in: testMixpanel, named: "test_event")!
    let props = event["properties"] as! InternalProperties
    XCTAssertNotNil(props["distinct_id"], "reserved key distinct_id was stripped")
    XCTAssertNotNil(props["token"], "reserved key token was stripped")

    removeDBfile(testMixpanel.apiToken)
  }

  func testDefaultOptionsStripNothing() {
    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
    testMixpanel.track(event: "test_event", properties: ["custom_prop": "v"])
    waitForTrackingQueue(testMixpanel)

    let event = findEvent(in: testMixpanel, named: "test_event")!
    let props = event["properties"] as! InternalProperties
    XCTAssertEqual(props["custom_prop"] as? String, "v")
    XCTAssertNotNil(props["$lib_version"])

    removeDBfile(testMixpanel.apiToken)
  }

  // MARK: - People exclude tests

  /// Pick the People record by action key (`$set`, `$set_once`, `$add`, …). After
  /// `identify` + a People call, the queue contains both the identify-driven merge
  /// and the test's own action, so action-name matching is the reliable filter.
  private func findPeopleRecord(
    in mixpanel: MixpanelInstance, action: String
  ) -> InternalProperties? {
    return peopleQueue(token: mixpanel.apiToken).first(where: { $0[action] != nil })
  }

  func testExcludePropertiesStripsAutoAndCustomFromPeopleSet() {
    let token = randomId()
    let options = MixpanelOptions(
      token: token,
      flushInterval: 60,
      excludeProperties: ["$ios_lib_version", "secret_prop"])
    let testMixpanel = Mixpanel.initialize(options: options)
    testMixpanel.identify(distinctId: "u1")
    testMixpanel.people.set(properties: ["secret_prop": "x", "keep_me": "y"])
    waitForTrackingQueue(testMixpanel)

    let record = peopleQueue(token: testMixpanel.apiToken).first(where: { $0["$set"] != nil })!
    let bag = record["$set"] as! InternalProperties

    // Excluded auto-prop and custom prop are stripped.
    XCTAssertNil(bag["$ios_lib_version"])
    XCTAssertNil(bag["secret_prop"])
    // Non-excluded custom prop survives.
    XCTAssertEqual(bag["keep_me"] as? String, "y")
    // Other auto-props are untouched.
    XCTAssertNotNil(bag["$ios_device_model"])
    // Envelope-level routing keys live outside the bag and are unaffected.
    XCTAssertNotNil(record["$token"])
    XCTAssertNotNil(record["$distinct_id"])

    removeDBfile(testMixpanel.apiToken)
  }

  /// Swift-specific deviation from Android: this SDK merges
  /// `AutomaticProperties.peopleProperties` into both `$set` and `$set_once`, so the
  /// filter runs on `$set_once` here. Android only merges into `$set` and filters
  /// accordingly.
  func testExcludePropertiesAppliesToPeopleSetOnce() {
    let token = randomId()
    let options = MixpanelOptions(
      token: token,
      flushInterval: 60,
      excludeProperties: ["$ios_lib_version", "secret_prop"])
    let testMixpanel = Mixpanel.initialize(options: options)
    testMixpanel.identify(distinctId: "u1")
    testMixpanel.people.setOnce(properties: ["secret_prop": "x", "keep_me": "y"])
    waitForTrackingQueue(testMixpanel)

    let record = findPeopleRecord(in: testMixpanel, action: "$set_once")!
    let bag = record["$set_once"] as! InternalProperties

    XCTAssertNil(bag["$ios_lib_version"])
    XCTAssertNil(bag["secret_prop"])
    XCTAssertEqual(bag["keep_me"] as? String, "y")
    XCTAssertNotNil(bag["$ios_device_model"])

    removeDBfile(testMixpanel.apiToken)
  }

  /// Mutating operators (`$add`, `$append`, `$union`, `$unset`) treat the bag as
  /// operands rather than a property dictionary to mutate; the filter must NOT
  /// touch them, since stripping a key from e.g. an `$unset` list would silently
  /// change the operation's meaning.
  func testExcludePropertiesPassThroughForMutatingPeopleOperators() {
    let token = randomId()
    let options = MixpanelOptions(
      token: token,
      flushInterval: 60,
      excludeProperties: ["secret_prop"])
    let testMixpanel = Mixpanel.initialize(options: options)
    testMixpanel.identify(distinctId: "u1")

    testMixpanel.people.increment(property: "secret_prop", by: 1)
    testMixpanel.people.append(properties: ["secret_prop": "v"])
    testMixpanel.people.union(properties: ["secret_prop": ["v"]])
    testMixpanel.people.unset(properties: ["secret_prop"])
    waitForTrackingQueue(testMixpanel)

    XCTAssertEqual(
      (findPeopleRecord(in: testMixpanel, action: "$add")!["$add"] as! InternalProperties)[
        "secret_prop"] as? Double, 1, "$add must not be filtered")
    XCTAssertEqual(
      (findPeopleRecord(in: testMixpanel, action: "$append")!["$append"] as! InternalProperties)[
        "secret_prop"] as? String, "v", "$append must not be filtered")
    XCTAssertNotNil(
      (findPeopleRecord(in: testMixpanel, action: "$union")!["$union"] as! InternalProperties)[
        "secret_prop"], "$union must not be filtered")
    // $unset stores the property names as an array under the action key.
    let unsetNames = findPeopleRecord(in: testMixpanel, action: "$unset")!["$unset"] as! [String]
    XCTAssertTrue(
      unsetNames.contains("secret_prop"),
      "$unset operand list must not be filtered (would silently change semantics)")

    removeDBfile(testMixpanel.apiToken)
  }
}
