//
//  CustomOperators.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import Foundation
import MixpanelSwiftCommon

let mixpanelCustomOperators: [String: MixpanelJSONLogicRule.CustomOperator] = [
    "semver_compare": { semverCompare($0) },
    "datetime_compare": { datetimeCompare($0) },
]

func applyRuleWithCustomOperators(_ rule: String, to data: String) throws -> Bool {
    return try MixpanelJSONLogicRule(rule, customOperators: mixpanelCustomOperators).evaluate(data: data)
}

private func operands(_ json: MixpanelJSON?) -> (actual: MixpanelJSON, symbol: String, target: MixpanelJSON)? {
    guard case .array(let values)? = json, values.count == 3 else {
        return nil
    }
    guard let symbol = values[1].string else {
        return nil
    }
    return (values[0], symbol, values[2])
}

private func comparatorMatches(_ cmp: Int64, _ symbol: String) -> Bool {
    switch symbol {
        case "===":
            return cmp == 0
        case "!==":
            return cmp != 0
        case "<":
            return cmp < 0
        case "<=":
            return cmp <= 0
        case ">":
            return cmp > 0
        case ">=":
            return cmp >= 0
        default:
            return false
    }
}

// Implements a custom operation for semantic versioning comparison that conforms to the semver 2.0.0
// standard. The comparison itself lives in MixpanelSwiftCommon so it can back either engine.
private func semverCompare(_ json: MixpanelJSON?) -> MixpanelJSON {
    guard let (actual, symbol, target) = operands(json) else {
        return .bool(false)
    }
    guard let actualStr = actual.string, let targetStr = target.string else {
        return .bool(false)
    }
    guard let cmp = SemanticVersion.compare(actualStr, targetStr) else {
        return .bool(false)
    }
    let matches = comparatorMatches(cmp, symbol)
    return .bool(matches)
}

// Implements a custom operation for datetime comparison. The target value stored on the feature flag
// is the millisecond epoch, whereas the actual value provided at evaluation time must be RFC-3339
// formatted.
private func datetimeCompare(_ json: MixpanelJSON?) -> MixpanelJSON {
    guard let (actual, symbol, target) = operands(json) else {
        return .bool(false)
    }
    guard let actualSec = convertRfc3339ToUnixSeconds(actual) else {
        return .bool(false)
    }
    guard let targetSec = convertUnixMillisecondsToSeconds(target) else {
        return .bool(false)
    }
    let cmp = actualSec - targetSec
    let matches = comparatorMatches(cmp, symbol)
    return .bool(matches)
}

private func convertRfc3339ToUnixSeconds(_ json: MixpanelJSON) -> Int64? {
    guard case .string(let value) = json else {
        return nil
    }
    return Rfc3339.toUnixSeconds(value)
}

private func convertUnixMillisecondsToSeconds(_ json: MixpanelJSON) -> Int64? {
    switch json {
        case .int(let value):
            return Rfc3339.epochMillisToUnixSeconds(value)
        case .double(let value):
            return Rfc3339.epochMillisToUnixSeconds(value)
        default:
            return nil
    }
}
