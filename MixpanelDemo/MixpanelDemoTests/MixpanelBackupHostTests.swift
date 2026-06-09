//
//  MixpanelBackupHostTests.swift
//  MixpanelDemoTests
//
//  Covers the backupHost failover feature (parity with the Android SDK's backupHost).
//

import XCTest

@testable import Mixpanel

class MixpanelBackupHostTests: MixpanelBaseTests {

  // MARK: - Host substitution helper

  func testBackupBaseURLSwapsHostPreservingScheme() {
    let result = BasePath.backupBaseURL(
      base: "https://api.mixpanel.com", backupHost: "api-backup.mixpanel.com")
    XCTAssertEqual(result, "https://api-backup.mixpanel.com")
  }

  func testBackupBaseURLPreservesPort() {
    let result = BasePath.backupBaseURL(
      base: "https://api.mixpanel.com:8443", backupHost: "api-backup.mixpanel.com")
    XCTAssertEqual(result, "https://api-backup.mixpanel.com:8443")
  }

  func testBackupBaseURLPreservesNonDefaultScheme() {
    let result = BasePath.backupBaseURL(
      base: "http://api.mixpanel.com", backupHost: "api-backup.mixpanel.com")
    XCTAssertEqual(result, "http://api-backup.mixpanel.com")
  }

  func testBackupBaseURLAcceptsFullURLAsBackupHost() {
    // A full URL is accepted as a convenience; only its host is used. The scheme/port still come
    // from the primary base.
    let result = BasePath.backupBaseURL(
      base: "https://api.mixpanel.com", backupHost: "https://api-backup.mixpanel.com")
    XCTAssertEqual(result, "https://api-backup.mixpanel.com")
  }

  func testBackupBaseURLReturnsNilWhenBaseHasNoHost() {
    // No scheme means URLComponents parses the whole string as a path, so there's no host to swap.
    XCTAssertNil(BasePath.backupBaseURL(base: "api.mixpanel.com", backupHost: "backup.example.com"))
  }

  func testBackupBaseURLReturnsNilForEmptyBackupHost() {
    XCTAssertNil(BasePath.backupBaseURL(base: "https://api.mixpanel.com", backupHost: ""))
  }

  // MARK: - Fallback decision logic

  func testShouldFallBackOnConnectionFailure() {
    let error = NSError(domain: "test", code: -1009, userInfo: nil)
    XCTAssertTrue(FlushRequest.shouldFallBackToBackup(.other(error)))
  }

  func testShouldFallBackOnNoData() {
    XCTAssertTrue(FlushRequest.shouldFallBackToBackup(.noData))
  }

  func testShouldFallBackOnServerError() {
    XCTAssertTrue(FlushRequest.shouldFallBackToBackup(.notOKStatusCode(statusCode: 500)))
    XCTAssertTrue(FlushRequest.shouldFallBackToBackup(.notOKStatusCode(statusCode: 503)))
  }

  func testShouldNotFallBackOnClientError() {
    XCTAssertFalse(FlushRequest.shouldFallBackToBackup(.notOKStatusCode(statusCode: 400)))
    XCTAssertFalse(FlushRequest.shouldFallBackToBackup(.notOKStatusCode(statusCode: 404)))
    XCTAssertFalse(FlushRequest.shouldFallBackToBackup(.notOKStatusCode(statusCode: 413)))
  }

  func testShouldNotFallBackOnParseError() {
    // A parse error means the primary responded with a 200 — it's reachable, so don't fail over.
    XCTAssertFalse(FlushRequest.shouldFallBackToBackup(.parseError))
  }

  // MARK: - Plumbing: options -> instance -> flush -> request

  func testBackupHostFromOptionsPropagatesToFlushRequest() {
    let options = MixpanelOptions(token: randomId(), backupHost: "api-backup.mixpanel.com")
    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    XCTAssertEqual(testMixpanel.backupHost, "api-backup.mixpanel.com")
    XCTAssertEqual(testMixpanel.flushInstance.backupHost, "api-backup.mixpanel.com")
    XCTAssertEqual(
      testMixpanel.flushInstance.flushRequest.backupHost, "api-backup.mixpanel.com")

    removeDBfile(testMixpanel.apiToken)
  }

  func testNoBackupHostByDefault() {
    let options = MixpanelOptions(token: randomId())
    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    XCTAssertNil(testMixpanel.backupHost)
    XCTAssertNil(testMixpanel.flushInstance.backupHost)
    XCTAssertNil(testMixpanel.flushInstance.flushRequest.backupHost)

    removeDBfile(testMixpanel.apiToken)
  }

  func testSettingBackupHostAfterInitPropagates() {
    let options = MixpanelOptions(token: randomId())
    let testMixpanel = Mixpanel.initialize(options: options)
    waitForTrackingQueue(testMixpanel)

    testMixpanel.backupHost = "api-backup.mixpanel.com"
    XCTAssertEqual(testMixpanel.flushInstance.backupHost, "api-backup.mixpanel.com")
    XCTAssertEqual(
      testMixpanel.flushInstance.flushRequest.backupHost, "api-backup.mixpanel.com")

    // Clearing it propagates too.
    testMixpanel.backupHost = nil
    XCTAssertNil(testMixpanel.flushInstance.backupHost)
    XCTAssertNil(testMixpanel.flushInstance.flushRequest.backupHost)

    removeDBfile(testMixpanel.apiToken)
  }
}
