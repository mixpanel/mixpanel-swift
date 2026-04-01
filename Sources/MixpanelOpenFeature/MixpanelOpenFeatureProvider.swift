import Combine
import Foundation
import Mixpanel
import OpenFeature

struct MixpanelProviderMetadata: ProviderMetadata {
  var name: String? = "mixpanel-provider"
}

public class MixpanelOpenFeatureProvider: FeatureProvider {
  private let flags: MixpanelFlags
  private let eventHandler = EventHandler()

  private static let sentinelKey = "__openfeature_flag_not_found__"

  public var hooks: [any Hook] { [] }
  public var metadata: ProviderMetadata { MixpanelProviderMetadata() }

  public init(flags: MixpanelFlags) {
    self.flags = flags
  }

  public func observe() -> AnyPublisher<ProviderEvent?, Never> {
    return eventHandler.observe()
  }

  public func initialize(initialContext: (any EvaluationContext)?) async throws {
    guard let context = initialContext else { return }
    let contextDict = Self.convertContext(context)
    await withCheckedContinuation { continuation in
      flags.setContext(contextDict) {
        continuation.resume()
      }
    }
  }

  public func onContextSet(
    oldContext: (any EvaluationContext)?, newContext: any EvaluationContext
  ) async throws {
    let contextDict = Self.convertContext(newContext)
    await withCheckedContinuation { continuation in
      flags.setContext(contextDict) {
        continuation.resume()
      }
    }
  }

  public func getBooleanEvaluation(
    key: String, defaultValue: Bool, context: (any EvaluationContext)?
  ) throws -> ProviderEvaluation<Bool> {
    let variant: MixpanelFlagVariant
    do {
      guard let v = try resolve(key) else {
        return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .flagNotFound)
      }
      variant = v
    } catch {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .providerNotReady)
    }
    guard let boolValue = variant.value as? Bool else {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .typeMismatch)
    }
    return ProviderEvaluation(value: boolValue, variant: variant.key, reason: "STATIC")
  }

  public func getStringEvaluation(
    key: String, defaultValue: String, context: (any EvaluationContext)?
  ) throws -> ProviderEvaluation<String> {
    let variant: MixpanelFlagVariant
    do {
      guard let v = try resolve(key) else {
        return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .flagNotFound)
      }
      variant = v
    } catch {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .providerNotReady)
    }
    guard let stringValue = variant.value as? String else {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .typeMismatch)
    }
    return ProviderEvaluation(value: stringValue, variant: variant.key, reason: "STATIC")
  }

  public func getIntegerEvaluation(
    key: String, defaultValue: Int64, context: (any EvaluationContext)?
  ) throws -> ProviderEvaluation<Int64> {
    let variant: MixpanelFlagVariant
    do {
      guard let v = try resolve(key) else {
        return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .flagNotFound)
      }
      variant = v
    } catch {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .providerNotReady)
    }
    guard let intValue = toInt64(variant.value) else {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .typeMismatch)
    }
    return ProviderEvaluation(value: intValue, variant: variant.key, reason: "STATIC")
  }

  public func getDoubleEvaluation(
    key: String, defaultValue: Double, context: (any EvaluationContext)?
  ) throws -> ProviderEvaluation<Double> {
    let variant: MixpanelFlagVariant
    do {
      guard let v = try resolve(key) else {
        return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .flagNotFound)
      }
      variant = v
    } catch {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .providerNotReady)
    }
    guard let doubleValue = toDouble(variant.value) else {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .typeMismatch)
    }
    return ProviderEvaluation(value: doubleValue, variant: variant.key, reason: "STATIC")
  }

  public func getObjectEvaluation(
    key: String, defaultValue: Value, context: (any EvaluationContext)?
  ) throws -> ProviderEvaluation<Value> {
    let variant: MixpanelFlagVariant
    do {
      guard let v = try resolve(key) else {
        return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .flagNotFound)
      }
      variant = v
    } catch {
      return ProviderEvaluation(value: defaultValue, reason: "DEFAULT", errorCode: .providerNotReady)
    }
    let value = toValue(variant.value)
    return ProviderEvaluation(value: value, variant: variant.key, reason: "STATIC")
  }

  // MARK: - Private

  private static func convertContext(_ context: any EvaluationContext) -> [String: Any] {
    var dict: [String: Any] = [:]
    let targetingKey = context.getTargetingKey()
    if !targetingKey.isEmpty {
      dict["targetingKey"] = targetingKey
    }
    for (key, value) in context.asMap() {
      dict[key] = convertValue(value)
    }
    return dict
  }

  private static func convertValue(_ value: Value) -> Any {
    switch value {
    case .boolean(let v): return v
    case .string(let v): return v
    case .integer(let v): return v
    case .double(let v): return v
    case .date(let v): return v.timeIntervalSince1970
    case .list(let v): return v.map { convertValue($0) }
    case .structure(let v): return v.mapValues { convertValue($0) }
    case .null: return NSNull()
    }
  }

  private func resolve(_ key: String) throws -> MixpanelFlagVariant? {
    guard flags.areFlagsReady() else {
      throw OpenFeatureError.providerNotReadyError
    }

    let fallback = MixpanelFlagVariant(key: Self.sentinelKey)
    let variant = flags.getVariantSync(key, fallback: fallback)

    guard variant.key != Self.sentinelKey else {
      return nil
    }

    return variant
  }

  private func toInt64(_ value: Any?) -> Int64? {
    switch value {
    case let v as Int: return Int64(v)
    case let v as Int64: return v
    case let v as Int32: return Int64(v)
    case let v as Double where v == Double(Int64(v)): return Int64(v)
    case let v as Float where v == Float(Int64(v)): return Int64(v)
    default: return nil
    }
  }

  private func toDouble(_ value: Any?) -> Double? {
    switch value {
    case let v as Double: return v
    case let v as Float: return Double(v)
    case let v as Int: return Double(v)
    case let v as Int64: return Double(v)
    case let v as Int32: return Double(v)
    default: return nil
    }
  }

  private func toValue(_ value: Any?) -> Value {
    switch value {
    case nil:
      return .null
    case let v as Bool:
      return .boolean(v)
    case let v as String:
      return .string(v)
    case let v as Int:
      return .integer(Int64(v))
    case let v as Int64:
      return .integer(v)
    case let v as Double:
      return .double(v)
    case let v as [Any?]:
      return .list(v.map { toValue($0) })
    case let v as [String: Any?]:
      return .structure(v.mapValues { toValue($0) })
    default:
      return .null
    }
  }
}
