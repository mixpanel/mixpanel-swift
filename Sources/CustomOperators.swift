//
//  CustomOperators.swift
//  Mixpanel
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import Foundation
import JSON
import Version
import jsonlogic

// semver_compare / datetime_compare: custom JsonLogic operators for typed runtime targeting.
// Shape: {"<op>": [{"var": key}, "<symbol>", <target>]}, symbol in = != < <= > >=.
// The engine resolves {"var": key} before the operator runs, so each closure receives the
// evaluated [actual, symbol, target] triple as a JSON array. Any shape, type, or parse failure
// returns false (fail closed) rather than throwing.

// SemVer 2.0.0 requires major.minor.patch; partial versions are zero-padded to this.
private let SEMVER_PARTS = 3

let mixpanelCustomOperators: [String: (JSON?) -> JSON] = [
    "semver_compare": semverCompare,
    "datetime_compare": datetimeCompare,
]

func applyRuleWithCustomOperators(_ rule: String, to data: String) throws -> Bool {
    return try JsonLogic(rule, customOperators: mixpanelCustomOperators).applyRule(to: data)
}

private func operands(_ json: JSON?) -> (actual: JSON, symbol: String, target: JSON)? {
    guard case let .Array(values)? = json, values.count == 3 else {
        return nil
    }
    guard let symbol = values[1].string else {
        return nil
    }
    return (values[0], symbol, values[2])
}

private func comparatorMatches(_ cmp: Int64, _ symbol: String) -> Bool {
    switch symbol {
    case "=":
        return cmp == 0
    case "!=":
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

/// `Version(tolerant:)` only tolerates a lowercase "v", so the prefix is stripped here instead.
private func stripVersionPrefix(_ version: String) -> String {
    guard let first = version.first, first == "v" || first == "V" else {
        return version
    }
    return String(version.dropFirst())
}

/// Build metadata is ignored for precedence by SemVer 2.0.0, but `Version(tolerant:)` fails to parse a
/// version that carries it, so it is removed after validation and before parsing.
private func stripBuildMetadata(_ version: String) -> String {
    guard let plus = version.firstIndex(of: "+") else {
        return version
    }
    return String(version[version.startIndex..<plus])
}

private func normalizeSemver(_ version: String) -> String {
    let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
    let stripped = stripVersionPrefix(trimmed)

    var suffixStart = stripped.endIndex
    for separator: Character in ["-", "+"] {
        if let index = stripped.firstIndex(of: separator), index < suffixStart {
            suffixStart = index
        }
    }

    let core = stripped[stripped.startIndex..<suffixStart]
    let suffix = stripped[suffixStart...]

    // A core that is empty or holds more than three segments stays as it is, so it is never padded into
    // a version such as "0.0.0" that would then pass validation.
    let segments = core.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard (1...SEMVER_PARTS).contains(segments.count) else {
        return stripped
    }
    let padded = segments + Array(repeating: "0", count: SEMVER_PARTS - segments.count)
    return padded.joined(separator: ".") + suffix
}

// Using the official semantic versioning 2.0.0 regular expression to handle cross-platform validation
// differences on other SDK's. For example, some platforms allow leading zeros even though it is not valid
// as part of the Semver 2.0.0 spec. See https://semver.org/
private let semverRegex = try? NSRegularExpression(
    pattern: "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)"
        + "(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?"
        + "(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$"
)

private func isValidSemver(_ version: String) -> Bool {
    guard let regex = semverRegex else {
        return false
    }
    let range = NSRange(version.startIndex..<version.endIndex, in: version)
    return regex.firstMatch(in: version, range: range) != nil
}

// Implements a custom operation for semantic versioning comparison that conforms to the semver 2.0.0
// standard. Prior to comparison, any leading version prefix is stripped.
private func semverCompare(_ json: JSON?) -> JSON {
    guard let (actual, symbol, target) = operands(json) else {
        return .Bool(false)
    }
    guard let actualStr = actual.string, let targetStr = target.string else {
        return .Bool(false)
    }
    let actualNormalized = normalizeSemver(actualStr)
    let targetNormalized = normalizeSemver(targetStr)
    guard isValidSemver(actualNormalized), isValidSemver(targetNormalized) else {
        return .Bool(false)
    }
    guard let actualVer = Version(tolerant: stripBuildMetadata(actualNormalized)) else {
        return .Bool(false)
    }
    guard let targetVer = Version(tolerant: stripBuildMetadata(targetNormalized)) else {
        return .Bool(false)
    }
    let cmp: Int64 = actualVer < targetVer ? -1 : (actualVer > targetVer ? 1 : 0)
    let matches = comparatorMatches(cmp, symbol)
    return .Bool(matches)
}

// Implements a custom operation for datetime comparison. The target value stored on the feature flag
// is the millisecond epoch, whereas the actual value provided at evaluation time must be RFC-3339
// formatted.
private func datetimeCompare(_ json: JSON?) -> JSON {
    guard let (actual, symbol, target) = operands(json) else {
        return .Bool(false)
    }
    guard let actualSec = convertRfc3339ToUnixSeconds(actual) else {
        return .Bool(false)
    }
    guard let targetSec = convertUnixMillisecondsToSeconds(target) else {
        return .Bool(false)
    }
    let cmp = actualSec - targetSec
    let matches = comparatorMatches(cmp, symbol)
    return .Bool(matches)
}

private func convertRfc3339ToUnixSeconds(_ json: JSON) -> Int64? {
    guard case let .String(value) = json else {
        return nil
    }
    return parseRFC3339Seconds(value)
}

private func convertUnixMillisecondsToSeconds(_ json: JSON) -> Int64? {
    switch json {
    case let .Int(value):
        return value / 1000
    case let .Double(value):
        // Int64(_:) traps on a value that is NaN, infinite, or beyond Int64's range.
        guard let milliseconds = Int64(exactly: value.rounded(.towardZero)) else {
            return nil
        }
        return milliseconds / 1000
    default:
        return nil
    }
}

// Strict RFC3339 guard for datetime strings.
private let rfc3339Regex = try? NSRegularExpression(
    pattern: "^\\d{4}-\\d{2}-\\d{2}[Tt]\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?([Zz]|[+-]\\d{2}:\\d{2})$"
)

private let rfc3339Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private let rfc3339FractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private func parseRFC3339Seconds(_ value: String) -> Int64? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
    guard let regex = rfc3339Regex, regex.firstMatch(in: normalized, range: range) != nil else {
        return nil
    }
    let date = rfc3339Formatter.date(from: normalized) ?? rfc3339FractionalFormatter.date(from: normalized)
    guard let parsed = date else {
        return nil
    }
    let seconds = parsed.timeIntervalSince1970.rounded(.down)
    return Int64(exactly: seconds)
}
