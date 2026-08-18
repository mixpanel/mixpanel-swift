//
//  MixpanelCustomOperatorTests.swift
//  MixpanelDemoTests
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import XCTest

@testable import Mixpanel

/// Golden-vector tests for the semver_compare and datetime_compare custom JsonLogic operators.
class MixpanelCustomOperatorTests: XCTestCase {

    // Epoch-millisecond constants (UTC instants) used as datetime targets, matching the UI's emitted format.
    private let jul16Ms: Int64 = 1_784_160_000_000  // 2026-07-16T00:00:00Z
    private let jan1Ms: Int64 = 1_767_225_600_000  // 2026-01-01T00:00:00Z
    private let dec31Ms: Int64 = 1_798_675_200_000  // 2026-12-31T00:00:00Z
    private let jul16EndMs: Int64 = 1_784_246_399_999  // 2026-07-16T23:59:59.999Z
    private let leapDayMs: Int64 = 1_709_164_800_000  // 2024-02-29T00:00:00Z
    private let jul16IndiaMs: Int64 = 1_784_140_200_000  // 2026-07-16T00:00:00+05:30
    private let jul16PacificMs: Int64 = 1_784_188_800_000  // 2026-07-16T00:00:00-08:00

    // MARK: - Rule / data builders

    private func semverRule(_ key: String, _ sym: String, _ target: String) -> String {
        return "{\"semver_compare\":[{\"var\":\"\(key)\"},\"\(sym)\",\"\(target)\"]}"
    }

    private func datetimeRule(_ key: String, _ sym: String, _ target: Int64) -> String {
        return "{\"datetime_compare\":[{\"var\":\"\(key)\"},\"\(sym)\",\(target)]}"
    }

    private func semverBetween(_ key: String, _ lo: String, _ hi: String) -> String {
        return "{\"and\":[{\"semver_compare\":[{\"var\":\"\(key)\"},\">=\",\"\(lo)\"]},"
            + "{\"semver_compare\":[{\"var\":\"\(key)\"},\"<=\",\"\(hi)\"]}]}"
    }

    private func datetimeBetween(_ key: String, _ lo: Int64, _ hi: Int64) -> String {
        return "{\"and\":[{\"datetime_compare\":[{\"var\":\"\(key)\"},\">=\",\(lo)]},"
            + "{\"datetime_compare\":[{\"var\":\"\(key)\"},\"<=\",\(hi)]}]}"
    }

    private func stringData(_ key: String, _ value: String) -> String {
        return "{\"\(key)\":\"\(value)\"}"
    }

    private func numberData(_ key: String, _ value: Int64) -> String {
        return "{\"\(key)\":\(value)}"
    }

    private func eval(_ rule: String, _ data: String) -> Bool {
        do {
            return try applyRuleWithCustomOperators(rule, to: data)
        } catch {
            XCTFail("rule evaluation threw: \(error)")
            return false
        }
    }

    // MARK: - semver_compare

    func testSemverCompareOperator() {
        // is, equal
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3")))
        // is, not equal
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.4")))
        // is not
        XCTAssertTrue(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.4")))
        // less than, patch
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.2.3"), stringData("app_version", "1.2.2")))
        // less than, false
        XCTAssertFalse(eval(semverRule("app_version", "<", "1.2.3"), stringData("app_version", "1.2.3")))
        // less or equal, boundary
        XCTAssertTrue(eval(semverRule("app_version", "<=", "1.2.3"), stringData("app_version", "1.2.3")))
        // greater than, minor
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.2.3"), stringData("app_version", "1.3.0")))
        // greater or equal, boundary
        XCTAssertTrue(eval(semverRule("app_version", ">=", "1.2.3"), stringData("app_version", "1.2.3")))
        // double-digit ordering (not lexical)
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.9.0"), stringData("app_version", "1.10.0")))
        // prerelease precedes release
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0"), stringData("app_version", "1.0.0-alpha")))
        // lenient v-prefix
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "v1.2.3")))
        // lenient uppercase V-prefix
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "V1.2.3")))
        // v-prefix keeps prerelease
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0"), stringData("app_version", "v1.0.0-alpha")))
        // v-prefix, not equal
        XCTAssertTrue(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "v1.2.4")))
        // v-prefix, at or below
        XCTAssertTrue(eval(semverRule("app_version", "<=", "1.2.3"), stringData("app_version", "v1.2.3")))
        // v-prefix, greater
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.2.3"), stringData("app_version", "v1.2.4")))
        // v-prefix, at or above
        XCTAssertTrue(eval(semverRule("app_version", ">=", "1.2.3"), stringData("app_version", "v1.2.3")))
        // lenient minor-only target
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2"), stringData("app_version", "1.2.0")))
        // Every symbol is asserted in both directions.
        // is not, equal
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3")))
        // less or equal, above
        XCTAssertFalse(eval(semverRule("app_version", "<=", "1.2.3"), stringData("app_version", "1.2.4")))
        // greater than, below
        XCTAssertFalse(eval(semverRule("app_version", ">", "1.2.3"), stringData("app_version", "1.2.2")))
        // greater or equal, below
        XCTAssertFalse(eval(semverRule("app_version", ">=", "1.2.3"), stringData("app_version", "1.2.2")))
        // prerelease alpha before beta
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-beta"), stringData("app_version", "1.0.0-alpha")))
        // prerelease beta before rc1
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-rc1"), stringData("app_version", "1.0.0-beta")))
        // prerelease rc1 before rc2
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-rc2"), stringData("app_version", "1.0.0-rc1")))
        // more prerelease fields wins
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-alpha.1"), stringData("app_version", "1.0.0-alpha")))
        // numeric identifier below alphanumeric
        XCTAssertTrue(
            eval(semverRule("app_version", "<", "1.0.0-alpha.beta"), stringData("app_version", "1.0.0-alpha.1")))
        // fewer fields below alphanumeric
        XCTAssertTrue(
            eval(semverRule("app_version", "<", "1.0.0-alpha.beta"), stringData("app_version", "1.0.0-alpha")))
        // numeric identifiers compare numerically
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-beta.11"), stringData("app_version", "1.0.0-beta.2")))
        // dotted identifier ordering, letters
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-b.1"), stringData("app_version", "1.0.0-a.1")))
        // dotted identifier ordering, digits
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-a.2"), stringData("app_version", "1.0.0-a.1")))
        // identical prereleases are equal
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.0.0-rc1"), stringData("app_version", "1.0.0-rc1")))
        // rc1 outranks dotted rc.1
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.0.0-rc.1"), stringData("app_version", "1.0.0-rc1")))
        // core version dominates prerelease
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.9.9"), stringData("app_version", "2.0.0-alpha")))
        // A release outranks its own prerelease, asserted from both sides and under every symbol.
        // release outranks its prerelease
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.0.0-alpha"), stringData("app_version", "1.0.0")))
        // release at or above its prerelease
        XCTAssertTrue(eval(semverRule("app_version", ">=", "1.0.0-rc1"), stringData("app_version", "1.0.0")))
        // release differs from its prerelease
        XCTAssertTrue(eval(semverRule("app_version", "!=", "1.0.0-alpha"), stringData("app_version", "1.0.0")))
        // prerelease differs from its release
        XCTAssertTrue(eval(semverRule("app_version", "!=", "1.0.0"), stringData("app_version", "1.0.0-alpha")))
        // prerelease at or below its release
        XCTAssertTrue(eval(semverRule("app_version", "<=", "1.0.0"), stringData("app_version", "1.0.0-alpha")))
        // prerelease of a higher core still wins
        XCTAssertTrue(eval(semverRule("app_version", ">", "0.9.9"), stringData("app_version", "1.0.0-alpha")))
        // prerelease below the next patch
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.1"), stringData("app_version", "1.0.0-rc1")))
        // Prerelease identifier comparison, SemVer 2.0.0 section 11.4.
        // numeric identifiers are not compared lexically
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-10"), stringData("app_version", "1.0.0-2")))
        // numeric identifier ranks below alphanumeric
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-alpha"), stringData("app_version", "1.0.0-1")))
        // hyphen inside an identifier sorts by ascii
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-alpha-1"), stringData("app_version", "1.0.0-alpha")))
        // beta ranks below rc
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0-rc.1"), stringData("app_version", "1.0.0-beta.11")))
        // last prerelease ranks below the release
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0"), stringData("app_version", "1.0.0-rc.1")))
        // build metadata ignored
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.0.0+build2"), stringData("app_version", "1.0.0+build1")))
        // build metadata ignored with prerelease
        XCTAssertTrue(
            eval(semverRule("app_version", "=", "1.0.0-alpha"), stringData("app_version", "1.0.0-alpha+build")))
        // Ignored means equal, so every symbol has to agree with that.
        // build metadata leaves versions equal
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.0.0+build2"), stringData("app_version", "1.0.0+build1")))
        // build metadata is not less
        XCTAssertFalse(eval(semverRule("app_version", "<", "1.0.0+build2"), stringData("app_version", "1.0.0+build1")))
        // build metadata is not greater
        XCTAssertFalse(eval(semverRule("app_version", ">", "1.0.0+build2"), stringData("app_version", "1.0.0+build1")))
        // build metadata at or below
        XCTAssertTrue(eval(semverRule("app_version", "<=", "1.0.0+build2"), stringData("app_version", "1.0.0+build1")))
        // build metadata at or above
        XCTAssertTrue(eval(semverRule("app_version", ">=", "1.0.0+build2"), stringData("app_version", "1.0.0+build1")))
        // build metadata does not block ordering
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.1+build1"), stringData("app_version", "1.0.0+build9")))
        // build metadata does not block reverse ordering
        XCTAssertTrue(eval(semverRule("app_version", ">", "1.0.0+build9"), stringData("app_version", "1.0.1+build1")))
        // build metadata with hyphens is valid
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3+build.1-2")))
        // partial version with prerelease
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2.0-alpha"), stringData("app_version", "1.2-alpha")))
        // partial prerelease below later minor
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.3.1"), stringData("app_version", "1.2-alpha")))
        // partial prerelease below its release
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.2.0"), stringData("app_version", "1.2-alpha")))
        // major-only with prerelease
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0"), stringData("app_version", "1-rc1")))
        // An empty prerelease is invalid, so it is rejected rather than treated as the bare release.
        // empty prerelease, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.0.0"), stringData("app_version", "1.0.0-")))
        // empty prerelease, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.0.0"), stringData("app_version", "1.0.0-")))
        // empty prerelease on partial version, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.0"), stringData("app_version", "1.2-")))
        // empty prerelease on partial version, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.0"), stringData("app_version", "1.2-")))
        // trailing hyphen inside identifier
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.0.0"), stringData("app_version", "1.0.0-alpha-")))
        // SemVer 2.0.0 forbids leading zeros in the core, so these are rejected rather than normalized.
        // leading zero in major, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "01.2.3")))
        // leading zero in major, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "01.2.3")))
        // leading zero in minor, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.02.3")))
        // leading zero in minor, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.02.3")))
        // leading zero in patch, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.03")))
        // leading zero in patch, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.03")))
        // leading zeros throughout, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "01.02.03")))
        // leading zeros throughout, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "01.02.03")))
        // A numeric prerelease identifier may not carry a leading zero either (section 9).
        // numeric prerelease with leading zero, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3-01")))
        // numeric prerelease with leading zero, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3-01")))
        // dotted numeric prerelease with leading zero, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3-rc.01")))
        // dotted numeric prerelease with leading zero, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3-rc.01")))
        // An alphanumeric identifier may contain digits, so this one stays valid.
        // alphanumeric prerelease with digits
        XCTAssertTrue(eval(semverRule("app_version", "<", "1.2.3"), stringData("app_version", "1.2.3-rc01")))
        // whitespace-padded version
        XCTAssertTrue(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", " 1.2.3 ")))
        // between, inside
        XCTAssertTrue(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "1.5.0")))
        // between, low boundary inclusive
        XCTAssertTrue(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "1.2.3")))
        // between, high boundary inclusive
        XCTAssertTrue(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "2.0.0")))
        // between, below
        XCTAssertFalse(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "1.0.0")))
        // between, above
        XCTAssertFalse(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "2.0.1")))
        // A prerelease sits below its own release, which decides both boundary cases.
        // between, prerelease inside
        XCTAssertTrue(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "1.5.0-rc1")))
        // between, prerelease below the high bound
        XCTAssertTrue(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "2.0.0-rc1")))
        // between, prerelease of the low bound falls out
        XCTAssertFalse(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "1.2.3-rc1")))
        // between, invalid version
        XCTAssertFalse(eval(semverBetween("app_version", "1.2.3", "2.0.0"), stringData("app_version", "not-a-version")))
        // between, single-point range
        XCTAssertTrue(eval(semverBetween("app_version", "1.2.3", "1.2.3"), stringData("app_version", "1.2.3")))
        // Fail-closed: unparseable or missing values never match.
        // invalid actual, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "not-a-version")))
        // non-string actual, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), numberData("app_version", 123)))
        // missing property, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), "{}"))
        // A malformed version must never be padded or coerced into a real one. Both symbols are
        // asserted so that "accepted at all" is observable rather than masked by a single false.
        // empty version, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "")))
        // empty version, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "")))
        // bare v, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "v")))
        // bare v, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "v")))
        // leading separator, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "-1.2.3")))
        // leading separator, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "-1.2.3")))
        // trailing dot, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.")))
        // trailing dot, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.")))
        // trailing dot after patch, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3.")))
        // trailing dot after patch, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3.")))
        // empty middle segment, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1..2")))
        // empty middle segment, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1..2")))
        // four components, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3.4")))
        // four components, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3.4")))
        // range prefix, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "^1.2.3")))
        // range prefix, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "^1.2.3")))
        // version inside text, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "abc1.2.3")))
        // version inside text, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "abc1.2.3")))
        // empty build metadata, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3+")))
        // empty build metadata, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3+")))
        // empty prerelease identifier, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3-alpha..1")))
        // empty prerelease identifier, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3-alpha..1")))
        // lone dot prerelease, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3-.")))
        // lone dot prerelease, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3-.")))
        // underscore in prerelease, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "1.2.3-ALPHA_BETA")))
        // underscore in prerelease, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "1.2.3-ALPHA_BETA")))
        // doubled v-prefix, no match
        XCTAssertFalse(eval(semverRule("app_version", "=", "1.2.3"), stringData("app_version", "vv1.2.3")))
        // doubled v-prefix, not-equal also false
        XCTAssertFalse(eval(semverRule("app_version", "!=", "1.2.3"), stringData("app_version", "vv1.2.3")))
    }

    // MARK: - datetime_compare

    func testDatetimeCompareOperator() {
        // Asymmetric contract: subject (runtime var) is a strict RFC3339 string, target is epoch ms.
        // before, true
        XCTAssertTrue(eval(datetimeRule("signup", "<", jul16Ms), stringData("signup", "2026-07-15T00:00:00Z")))
        // before, false
        XCTAssertFalse(eval(datetimeRule("signup", "<", jul16Ms), stringData("signup", "2026-07-16T00:00:00Z")))
        // on (equal), true
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00Z")))
        // not on, true
        XCTAssertTrue(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-17T00:00:00Z")))
        // since (>=), boundary
        XCTAssertTrue(eval(datetimeRule("signup", ">=", jul16Ms), stringData("signup", "2026-07-16T00:00:00Z")))
        // after (>), true
        XCTAssertTrue(eval(datetimeRule("signup", ">", jul16Ms), stringData("signup", "2026-07-17T00:00:00Z")))
        // after (>), false
        XCTAssertFalse(eval(datetimeRule("signup", ">", jul16Ms), stringData("signup", "2026-07-15T00:00:00Z")))
        // Every symbol is asserted in both directions.
        // at or before, boundary
        XCTAssertTrue(eval(datetimeRule("signup", "<=", jul16Ms), stringData("signup", "2026-07-16T00:00:00Z")))
        // at or before, after
        XCTAssertFalse(eval(datetimeRule("signup", "<=", jul16Ms), stringData("signup", "2026-07-17T00:00:00Z")))
        // on (equal), false
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-17T00:00:00Z")))
        // not on, equal
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00Z")))
        // since (>=), before
        XCTAssertFalse(eval(datetimeRule("signup", ">=", jul16Ms), stringData("signup", "2026-07-15T00:00:00Z")))
        // between, inside
        XCTAssertTrue(eval(datetimeBetween("signup", jan1Ms, dec31Ms), stringData("signup", "2026-06-15T00:00:00Z")))
        // between, low boundary inclusive
        XCTAssertTrue(eval(datetimeBetween("signup", jan1Ms, dec31Ms), stringData("signup", "2026-01-01T00:00:00Z")))
        // between, high boundary inclusive
        XCTAssertTrue(eval(datetimeBetween("signup", jan1Ms, dec31Ms), stringData("signup", "2026-12-31T00:00:00Z")))
        // between, before range
        XCTAssertFalse(eval(datetimeBetween("signup", jan1Ms, dec31Ms), stringData("signup", "2025-12-31T00:00:00Z")))
        // between, after range
        XCTAssertFalse(eval(datetimeBetween("signup", jan1Ms, dec31Ms), stringData("signup", "2027-01-01T00:00:00Z")))
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T02:00:00+02:00")))
        XCTAssertTrue(eval(datetimeRule("signup", ">=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.500Z")))
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16EndMs), stringData("signup", "2026-07-16T23:59:59Z")))
        XCTAssertTrue(eval(datetimeRule("signup", "<=", jul16EndMs), stringData("signup", "2026-07-16T23:59:59Z")))
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16t00:00:00z")))
        // leap day
        XCTAssertTrue(eval(datetimeRule("signup", "=", leapDayMs), stringData("signup", "2024-02-29T00:00:00Z")))
        // offset with half-hour minutes
        // rfc3339 subject with offset
        XCTAssertTrue(
            eval(datetimeRule("signup", "=", jul16IndiaMs), stringData("signup", "2026-07-16T00:00:00+05:30")))
        // positive offset precedes utc midnight
        XCTAssertTrue(eval(datetimeRule("signup", "<", jul16Ms), stringData("signup", "2026-07-16T00:00:00+05:30")))
        // negative offset
        XCTAssertTrue(
            eval(datetimeRule("signup", "=", jul16PacificMs), stringData("signup", "2026-07-16T00:00:00-08:00")))
        // negative offset follows utc midnight
        XCTAssertTrue(eval(datetimeRule("signup", ">", jul16Ms), stringData("signup", "2026-07-16T00:00:00-08:00")))
        // zero offset equals Z
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00+00:00")))
        // one-digit fraction
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.5Z")))
        // three-digit fraction
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.500Z")))
        // six-digit fraction
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.123456Z")))
        // nine-digit fraction
        XCTAssertTrue(
            eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.999999999Z")))
        // zero fraction
        // fractional seconds truncated
        // end-of-day target drops its .999
        // end-of-day target is an inclusive bound
        // end-of-day, fractional subject too
        // end-of-day inclusive, fractional subject
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.0Z")))
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16EndMs), stringData("signup", "2026-07-16T23:59:59.999Z")))
        XCTAssertTrue(eval(datetimeRule("signup", "<=", jul16EndMs), stringData("signup", "2026-07-16T23:59:59.999Z")))
        // lowercased subject with fraction
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16t00:00:00.500z")))
        // lowercased subject with offset
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16t02:00:00+02:00")))
        // whitespace-padded subject
        // lowercased rfc3339 subject
        XCTAssertTrue(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", " 2026-07-16T00:00:00Z ")))
        // Shape violations, asserted under both = and != so that "accepted at all" is observable.
        // RFC 3339 also permits 24:00:00 as end-of-day. Platforms disagree on it, so no vector
        // asserts it either way.
        // one-digit month, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-7-16T00:00:00Z")))
        // one-digit month, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-7-16T00:00:00Z")))
        // space separator, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16 00:00:00Z")))
        // space separator, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16 00:00:00Z")))
        // missing zone, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00")))
        // missing zone, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00")))
        // empty fraction, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.Z")))
        // empty fraction, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00.Z")))
        // offset without colon, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00+0200")))
        // offset without colon, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00+0200")))
        // short offset, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00+02")))
        // short offset, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00+02")))
        // trailing junk, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00Zextra")))
        // trailing junk, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00Zextra")))
        // basic format, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "20260716T000000Z")))
        // basic format, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "20260716T000000Z")))
        // zone after lowercase z, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00z00:00")))
        // zone after lowercase z, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00z00:00")))
        // comma fractional separator, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00,5Z")))
        // comma fractional separator, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16T00:00:00,5Z")))
        // A target too large for Int64 fails closed rather than trapping.
        XCTAssertFalse(
            eval(
                "{\"datetime_compare\":[{\"var\":\"signup\"},\"=\",1e308]}",
                stringData("signup", "2026-07-16T00:00:00Z")))
        // target beyond representable range, greater-than also false
        XCTAssertFalse(
            eval(
                "{\"datetime_compare\":[{\"var\":\"signup\"},\">\",1e308]}",
                stringData("signup", "2026-07-16T00:00:00Z")))
        // target beyond representable range, less-than also false
        XCTAssertFalse(
            eval(
                "{\"datetime_compare\":[{\"var\":\"signup\"},\"<\",1e308]}",
                stringData("signup", "2026-07-16T00:00:00Z")))
        // Fail-closed: subject must be an RFC3339 string, target must be an epoch-ms number.
        // numeric subject, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), numberData("signup", jul16Ms)))
        // negative epoch-ms target resolves to -1s
        XCTAssertTrue(eval(datetimeRule("signup", "=", -1500), stringData("signup", "1969-12-31T23:59:59Z")))
        // negative epoch-ms target, not equal
        XCTAssertFalse(eval(datetimeRule("signup", "!=", -1500), stringData("signup", "1969-12-31T23:59:59Z")))
        // negative epoch-ms target, at or after
        XCTAssertTrue(eval(datetimeRule("signup", ">=", -1500), stringData("signup", "1969-12-31T23:59:59Z")))
        // negative epoch-ms target, before
        XCTAssertTrue(eval(datetimeRule("signup", "<", -1500), stringData("signup", "1969-12-31T23:59:58Z")))
        // negative epoch-ms target, after
        XCTAssertTrue(eval(datetimeRule("signup", ">", -2500), stringData("signup", "1969-12-31T23:59:59Z")))
        // subject floors, it does not truncate
        XCTAssertTrue(eval(datetimeRule("signup", "=", -2000), stringData("signup", "1969-12-31T23:59:58.500Z")))
        // subject floors, not to -1s
        XCTAssertTrue(eval(datetimeRule("signup", "!=", -1000), stringData("signup", "1969-12-31T23:59:58.500Z")))
        // bare date subject, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16")))
        // bare date subject, not-equal also false
        XCTAssertFalse(eval(datetimeRule("signup", "!=", jul16Ms), stringData("signup", "2026-07-16")))
        // zoneless datetime subject, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "2026-07-16T00:00:00")))
        // non-datetime string, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), stringData("signup", "yesterday")))
        // missing property, no match
        XCTAssertFalse(eval(datetimeRule("signup", "=", jul16Ms), "{}"))
    }
}
