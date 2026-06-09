//
//  FlushRequest.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

enum FlushType: String {
  case events = "/track/"
  case people = "/engage/"
  case groups = "/groups/"
}

class FlushRequest: Network {

  var networkRequestsAllowedAfterTime = 0.0
  var networkConsecutiveFailures = 0

  func sendRequest(
    _ requestData: String,
    type: FlushType,
    useIP: Bool,
    headers: [String: String],
    queryItems: [URLQueryItem] = [],
    useGzipCompression: Bool
  ) -> Bool {

    let responseParser: (Data) -> Int? = { data in
      let response = String(data: data, encoding: String.Encoding.utf8)
      if let response = response {
        return Int(response) ?? 0
      }
      return nil
    }

    var resourceHeaders: [String: String] = ["Content-Type": "application/json"].merging(headers) {
      (_, new) in new
    }
    var compressedData: Data? = nil

    if useGzipCompression && type == .events {
      if let requestDataRaw = requestData.data(using: .utf8) {
        do {
          compressedData = try requestDataRaw.gzipCompressed()
          resourceHeaders["Content-Encoding"] = "gzip"
        } catch {
          MixpanelLogger.error(message: "Failed to compress data with gzip: \(error)")
        }
      }
    }
    let ipString = useIP ? "1" : "0"
    var resourceQueryItems: [URLQueryItem] = [URLQueryItem(name: "ip", value: ipString)]
    resourceQueryItems.append(contentsOf: queryItems)
    let resource = Network.buildResource(
      path: type.rawValue,
      method: .post,
      requestBody: compressedData ?? requestData.data(using: .utf8),
      queryItems: resourceQueryItems,
      headers: resourceHeaders,
      parse: responseParser)
    var result = false
    let semaphore = DispatchSemaphore(value: 0)
    flushRequestHandler(
      serverURL,
      resource: resource,
      completion: { success in
        result = success
        semaphore.signal()
      })
    _ = semaphore.wait(timeout: .now() + 120.0)
    return result
  }

  private func flushRequestHandler(
    _ base: String,
    resource: Resource<Int>,
    completion: @escaping (Bool) -> Void
  ) {

    Network.apiRequest(
      base: base, resource: resource,
      failure: { (reason, _, response) in
        // On a connection-level failure to the primary host, fall back to the configured backup
        // host (if any) before giving up. Mirrors the Android SDK's backupHost behavior: the
        // backup is only attempted when the primary couldn't be reached or returned a server-side
        // error — never for client errors (4xx), where a different host won't help.
        if let backupBase = self.backupBaseURL(forPrimary: base, failureReason: reason) {
          MixpanelLogger.info(
            message:
              "Primary host request to \(resource.path) failed (\(reason)); retrying via backup host"
          )
          Network.apiRequest(
            base: backupBase, resource: resource,
            failure: { (backupReason, _, backupResponse) in
              self.handleFlushFailure(
                path: resource.path, reason: backupReason, response: backupResponse,
                completion: completion)
            },
            success: { (result, backupResponse) in
              self.handleFlushSuccess(
                base: backupBase, result: result, response: backupResponse, completion: completion)
            })
        } else {
          self.handleFlushFailure(
            path: resource.path, reason: reason, response: response, completion: completion)
        }
      },
      success: { (result, response) in
        self.handleFlushSuccess(
          base: base, result: result, response: response, completion: completion)
      })
  }

  private func handleFlushSuccess(
    base: String, result: Int, response: URLResponse?, completion: @escaping (Bool) -> Void
  ) {
    networkConsecutiveFailures = 0
    updateRetryDelay(response)
    if result == 0 {
      MixpanelLogger.info(message: "\(base) api rejected some items")
    }
    completion(true)
  }

  private func handleFlushFailure(
    path: String, reason: Reason, response: URLResponse?, completion: @escaping (Bool) -> Void
  ) {
    networkConsecutiveFailures += 1
    updateRetryDelay(response)
    MixpanelLogger.warn(message: "API request to \(path) has failed with reason \(reason)")
    completion(false)
  }

  /// Returns the backup base URL to retry against, or nil when no retry should happen — either
  /// because no backup host is configured, the failure isn't one a different host could fix, or
  /// the host substitution produced no change.
  private func backupBaseURL(forPrimary base: String, failureReason reason: Reason) -> String? {
    guard let backupHost = backupHost, !backupHost.isEmpty else {
      return nil
    }
    guard FlushRequest.shouldFallBackToBackup(reason) else {
      return nil
    }
    guard let backupBase = BasePath.backupBaseURL(base: base, backupHost: backupHost),
      backupBase != base
    else {
      return nil
    }
    return backupBase
  }

  /// Whether a primary-host failure should trigger a backup-host retry. We retry on connection
  /// failures and server-side errors, but not on client errors (4xx) — a different host won't fix
  /// a malformed request — nor on parse errors, where the primary did respond with a 200.
  static func shouldFallBackToBackup(_ reason: Reason) -> Bool {
    switch reason {
    case .other, .noData:
      return true
    case .notOKStatusCode(let statusCode):
      return !(400..<500).contains(statusCode)
    case .parseError:
      return false
    }
  }

  private func updateRetryDelay(_ response: URLResponse?) {
    var retryTime = 0.0
    let retryHeader = (response as? HTTPURLResponse)?.allHeaderFields["Retry-After"] as? String
    if let retryHeader = retryHeader, let retryHeaderParsed = (Double(retryHeader)) {
      retryTime = retryHeaderParsed
    }

    if networkConsecutiveFailures >= APIConstants.failuresTillBackoff {
      retryTime = max(
        retryTime,
        retryBackOffTimeWithConsecutiveFailures(networkConsecutiveFailures))
    }
    let retryDate = Date(timeIntervalSinceNow: retryTime)
    networkRequestsAllowedAfterTime = retryDate.timeIntervalSince1970
  }

  private func retryBackOffTimeWithConsecutiveFailures(_ failureCount: Int) -> TimeInterval {
    let time = pow(2.0, Double(failureCount) - 1) * 60 + Double(arc4random_uniform(30))
    return min(
      max(APIConstants.minRetryBackoff, time),
      APIConstants.maxRetryBackoff)
  }

  func requestNotAllowed() -> Bool {
    return Date().timeIntervalSince1970 < networkRequestsAllowedAfterTime
  }

}
