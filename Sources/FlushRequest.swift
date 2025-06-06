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
        self.networkConsecutiveFailures += 1
        self.updateRetryDelay(response)
        MixpanelLogger.warn(
          message: "API request to \(resource.path) has failed with reason \(reason)")
        completion(false)
      },
      success: { (result, response) in
        self.networkConsecutiveFailures = 0
        self.updateRetryDelay(response)
        if result == 0 {
          MixpanelLogger.info(message: "\(base) api rejected some items")
        }
        completion(true)
      })
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
