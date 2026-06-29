//
//  MixpanelBackupHostTests.swift
//  MixpanelDemoTests
//
//  Covers the backupHost failover feature (parity with the Android SDK's backupHost).
//

import XCTest

@testable import Mixpanel

/// Intercepts URL requests and returns configurable responses per host, allowing tests to simulate
/// primary-host failures and backup-host successes without hitting the network.
private class StubURLProtocol: URLProtocol {
  static var responseByHost: [String: (statusCode: Int, body: String)] = [:]
  static var requestedHosts: [String] = []
  private static let lock = NSLock()

  static func reset() {
    lock.lock()
    responseByHost = [:]
    requestedHosts = []
    lock.unlock()
  }

  static func recordHost(_ host: String) {
    lock.lock()
    requestedHosts.append(host)
    lock.unlock()
  }

  static func hosts() -> [String] {
    lock.lock()
    defer { lock.unlock() }
    return requestedHosts
  }

  override class func canInit(with request: URLRequest) -> Bool {
    guard let host = request.url?.host else { return false }
    return responseByHost[host] != nil
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let url = request.url, let host = url.host,
      let stub = StubURLProtocol.responseByHost[host]
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
      return
    }

    StubURLProtocol.recordHost(host)

    let response = HTTPURLResponse(
      url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: stub.body.data(using: .utf8)!)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

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

  // MARK: - Integration: backup host is called on primary failure

  func testFlushRetriesViaBackupHostWhenPrimaryFails() {
    let primaryHost = "test-primary.mixpanel.com"
    let backupHost = "test-backup.mixpanel.com"

    StubURLProtocol.reset()
    StubURLProtocol.responseByHost[primaryHost] = (statusCode: 500, body: "0")
    StubURLProtocol.responseByHost[backupHost] = (statusCode: 200, body: "1")
    URLProtocol.registerClass(StubURLProtocol.self)

    defer {
      URLProtocol.unregisterClass(StubURLProtocol.self)
      StubURLProtocol.reset()
    }

    let testMixpanel = Mixpanel.initialize(
      token: randomId(), trackAutomaticEvents: false, flushInterval: 60)
    waitForTrackingQueue(testMixpanel)
    testMixpanel.serverURL = "https://\(primaryHost)"
    testMixpanel.backupHost = backupHost
    testMixpanel.track(event: "Backup Host Integration Test")
    flushAndWaitForTrackingQueue(testMixpanel)

    let hosts = StubURLProtocol.hosts()
    XCTAssertTrue(hosts.contains(primaryHost), "Primary host should have been attempted")
    XCTAssertTrue(hosts.contains(backupHost), "Backup host should have been attempted after primary failed")

    let primaryIndex = hosts.firstIndex(of: primaryHost)!
    let backupIndex = hosts.firstIndex(of: backupHost)!
    XCTAssertTrue(primaryIndex < backupIndex, "Primary host should be attempted before backup host")

    XCTAssertTrue(
      eventQueue(token: testMixpanel.apiToken).isEmpty,
      "Events should have been flushed successfully via the backup host")

    removeDBfile(testMixpanel.apiToken)
  }
}
