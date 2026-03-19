import Mixpanel
import OpenFeature
import XCTest

@testable import MixpanelOpenFeature

// MARK: - Mock

class MockMixpanelFlags: MixpanelFlags {
  var delegate: MixpanelFlagDelegate?

  var variants: [String: MixpanelFlagVariant] = [:]
  var ready: Bool = true

  func loadFlags() {}

  func areFlagsReady() -> Bool { ready }

  func getVariantSync(_ flagName: String, fallback: MixpanelFlagVariant) -> MixpanelFlagVariant {
    return variants[flagName] ?? fallback
  }

  func getVariant(
    _ flagName: String, fallback: MixpanelFlagVariant,
    completion: @escaping (MixpanelFlagVariant) -> Void
  ) {
    completion(getVariantSync(flagName, fallback: fallback))
  }

  func getVariantValueSync(_ flagName: String, fallbackValue: Any?) -> Any? {
    return getVariantSync(flagName, fallback: MixpanelFlagVariant(value: fallbackValue)).value
  }

  func getVariantValue(
    _ flagName: String, fallbackValue: Any?, completion: @escaping (Any?) -> Void
  ) {
    completion(getVariantValueSync(flagName, fallbackValue: fallbackValue))
  }

  func isEnabledSync(_ flagName: String, fallbackValue: Bool) -> Bool {
    return getVariantValueSync(flagName, fallbackValue: fallbackValue) as? Bool ?? fallbackValue
  }

  func isEnabled(_ flagName: String, fallbackValue: Bool, completion: @escaping (Bool) -> Void) {
    completion(isEnabledSync(flagName, fallbackValue: fallbackValue))
  }

  func getAllVariantsSync() -> [String: MixpanelFlagVariant] {
    return variants
  }

  func getAllVariants(completion: @escaping ([String: MixpanelFlagVariant]) -> Void) {
    completion(variants)
  }
}

// MARK: - Tests

final class MixpanelOpenFeatureProviderTests: XCTestCase {

  // MARK: - Metadata & Hooks

  func testMetadata() {
    let provider = MixpanelOpenFeatureProvider(flags: MockMixpanelFlags())
    XCTAssertEqual(provider.metadata.name, "mixpanel-provider")
  }

  func testHooksEmpty() {
    let provider = MixpanelOpenFeatureProvider(flags: MockMixpanelFlags())
    XCTAssertTrue(provider.hooks.isEmpty)
  }

  // MARK: - Boolean Evaluation

  func testBooleanEvaluation() throws {
    let mock = MockMixpanelFlags()
    mock.variants["bool-flag"] = MixpanelFlagVariant(key: "on", value: true)
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getBooleanEvaluation(key: "bool-flag", defaultValue: false, context: nil)
    XCTAssertEqual(result.value, true)
    XCTAssertEqual(result.variant, "on")
    XCTAssertEqual(result.reason, "STATIC")
  }

  func testBooleanEvaluationTypeMismatch() {
    let mock = MockMixpanelFlags()
    mock.variants["str-flag"] = MixpanelFlagVariant(key: "v", value: "not-a-bool")
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getBooleanEvaluation(key: "str-flag", defaultValue: false, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .typeMismatchError)
    }
  }

  // MARK: - String Evaluation

  func testStringEvaluation() throws {
    let mock = MockMixpanelFlags()
    mock.variants["str-flag"] = MixpanelFlagVariant(key: "variant-a", value: "hello")
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getStringEvaluation(key: "str-flag", defaultValue: "default", context: nil)
    XCTAssertEqual(result.value, "hello")
    XCTAssertEqual(result.variant, "variant-a")
    XCTAssertEqual(result.reason, "STATIC")
  }

  func testStringEvaluationTypeMismatch() {
    let mock = MockMixpanelFlags()
    mock.variants["bool-flag"] = MixpanelFlagVariant(key: "on", value: true)
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getStringEvaluation(key: "bool-flag", defaultValue: "default", context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .typeMismatchError)
    }
  }

  // MARK: - Integer Evaluation

  func testIntegerEvaluation() throws {
    let mock = MockMixpanelFlags()
    mock.variants["int-flag"] = MixpanelFlagVariant(key: "big", value: 42)
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getIntegerEvaluation(key: "int-flag", defaultValue: 0, context: nil)
    XCTAssertEqual(result.value, Int64(42))
    XCTAssertEqual(result.reason, "STATIC")
  }

  func testIntegerEvaluationFromWholeDouble() throws {
    let mock = MockMixpanelFlags()
    mock.variants["int-flag"] = MixpanelFlagVariant(key: "big", value: Double(42))
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getIntegerEvaluation(key: "int-flag", defaultValue: 0, context: nil)
    XCTAssertEqual(result.value, Int64(42))
  }

  func testIntegerEvaluationTypeMismatch() {
    let mock = MockMixpanelFlags()
    mock.variants["str-flag"] = MixpanelFlagVariant(key: "v", value: "not-an-int")
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getIntegerEvaluation(key: "str-flag", defaultValue: 0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .typeMismatchError)
    }
  }

  func testIntegerEvaluationFractionalDoubleTypeMismatch() {
    let mock = MockMixpanelFlags()
    mock.variants["float-flag"] = MixpanelFlagVariant(key: "v", value: 3.14)
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getIntegerEvaluation(key: "float-flag", defaultValue: 0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .typeMismatchError)
    }
  }

  // MARK: - Double Evaluation

  func testDoubleEvaluation() throws {
    let mock = MockMixpanelFlags()
    mock.variants["float-flag"] = MixpanelFlagVariant(key: "half", value: 0.5)
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getDoubleEvaluation(key: "float-flag", defaultValue: 0.0, context: nil)
    XCTAssertEqual(result.value, 0.5)
    XCTAssertEqual(result.reason, "STATIC")
  }

  func testDoubleEvaluationFromInt() throws {
    let mock = MockMixpanelFlags()
    mock.variants["int-flag"] = MixpanelFlagVariant(key: "v", value: 42)
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getDoubleEvaluation(key: "int-flag", defaultValue: 0.0, context: nil)
    XCTAssertEqual(result.value, 42.0)
  }

  func testDoubleEvaluationTypeMismatch() {
    let mock = MockMixpanelFlags()
    mock.variants["str-flag"] = MixpanelFlagVariant(key: "v", value: "not-a-double")
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getDoubleEvaluation(key: "str-flag", defaultValue: 1.0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .typeMismatchError)
    }
  }

  // MARK: - Object Evaluation

  func testObjectEvaluation() throws {
    let mock = MockMixpanelFlags()
    mock.variants["obj-flag"] = MixpanelFlagVariant(
      key: "config", value: ["key": "value"] as [String: Any])
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getObjectEvaluation(key: "obj-flag", defaultValue: .null, context: nil)
    XCTAssertEqual(result.value, .structure(["key": .string("value")]))
    XCTAssertEqual(result.variant, "config")
    XCTAssertEqual(result.reason, "STATIC")
  }

  func testObjectEvaluationWithString() throws {
    let mock = MockMixpanelFlags()
    mock.variants["str-flag"] = MixpanelFlagVariant(key: "v", value: "hello")
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    let result = try provider.getObjectEvaluation(key: "str-flag", defaultValue: .null, context: nil)
    XCTAssertEqual(result.value, .string("hello"))
  }

  // MARK: - Flag Not Found

  func testFlagNotFound() {
    let mock = MockMixpanelFlags()
    mock.ready = true
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getBooleanEvaluation(key: "missing-flag", defaultValue: false, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .flagNotFoundError(key: "missing-flag"))
    }
  }

  func testFlagNotFoundAllTypes() {
    let mock = MockMixpanelFlags()
    mock.ready = true
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getStringEvaluation(key: "missing", defaultValue: "", context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .flagNotFoundError(key: "missing"))
    }

    XCTAssertThrowsError(
      try provider.getIntegerEvaluation(key: "missing", defaultValue: 0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .flagNotFoundError(key: "missing"))
    }

    XCTAssertThrowsError(
      try provider.getDoubleEvaluation(key: "missing", defaultValue: 0.0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .flagNotFoundError(key: "missing"))
    }

    XCTAssertThrowsError(
      try provider.getObjectEvaluation(key: "missing", defaultValue: .null, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .flagNotFoundError(key: "missing"))
    }
  }

  // MARK: - Provider Not Ready

  func testProviderNotReady() {
    let mock = MockMixpanelFlags()
    mock.ready = false
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getBooleanEvaluation(key: "any-flag", defaultValue: false, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .providerNotReadyError)
    }
  }

  func testProviderNotReadyAllTypes() {
    let mock = MockMixpanelFlags()
    mock.ready = false
    let provider = MixpanelOpenFeatureProvider(flags: mock)

    XCTAssertThrowsError(
      try provider.getStringEvaluation(key: "f", defaultValue: "d", context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .providerNotReadyError)
    }

    XCTAssertThrowsError(
      try provider.getIntegerEvaluation(key: "f", defaultValue: 0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .providerNotReadyError)
    }

    XCTAssertThrowsError(
      try provider.getDoubleEvaluation(key: "f", defaultValue: 0.0, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .providerNotReadyError)
    }

    XCTAssertThrowsError(
      try provider.getObjectEvaluation(key: "f", defaultValue: .null, context: nil)
    ) { error in
      XCTAssertEqual(error as? OpenFeatureError, .providerNotReadyError)
    }
  }
}
