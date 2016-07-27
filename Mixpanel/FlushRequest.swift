//
//  FlushRequest.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

enum FlushType: String {
    case Events = "/track/"
    case People = "/engage/"
}

class FlushRequest: Network {

    var networkRequestsAllowedAfterTime = 0.0
    var networkConsecutiveFailures = 0

    func sendRequest(requestData: String,
                     type: FlushType,
                     useIP: Bool,
                     completion: (Bool) -> Void) {

        let responseParser: (NSData) -> Int? = { data in
            let response = String(data: data, encoding: NSUTF8StringEncoding)
            if let response = response {
                return Int(response) ?? 0
            }
            return nil
        }

        let requestBody = "ip=\(Int(useIP))&data=\(requestData)"
            .dataUsingEncoding(NSUTF8StringEncoding)

        let resource = Network.buildResource(path: type.rawValue,
                                             method: Method.POST,
                                             requestBody: requestBody,
                                             headers: ["Accept-Encoding": "gzip"],
                                             parse: responseParser)

        flushRequestHandler(BasePath.MixpanelAPI,
                            resource: resource,
                            completion: { success in
                                completion(success)
        })
    }

    private func flushRequestHandler(base: String,
                                     resource: Resource<Int>,
                                     completion: (Bool) -> Void) {

        Network.apiRequest(base: base,
                           resource: resource,
                           failure: { (reason, data, response) in
                            self.networkConsecutiveFailures += 1
                            self.updateRetryDelay(response)
                            completion(false)
            },
                           success: { (result, response) in
                            self.networkConsecutiveFailures = 0
                            self.updateRetryDelay(response)
                            if result == 0 {
                                Logger.info(message: "\(base) api rejected some items")
                            }
                            completion(true)
            }
        )
    }

    private func updateRetryDelay(response: NSURLResponse?) {
        var retryTime = 0.0
        let retryHeader = (response as? NSHTTPURLResponse)?.allHeaderFields["Retry-After"] as? String
        if let retryHeader = retryHeader, retryHeaderParsed = (Double(retryHeader)) {
            retryTime = retryHeaderParsed
        }

        if networkConsecutiveFailures >= APIConstants.failuresTillBackoff {
            retryTime = max(retryTime,
                            retryBackOffTimeWithConsecutiveFailures(
                                self.networkConsecutiveFailures))
        }
        let retryDate = NSDate(timeIntervalSinceNow: retryTime)
        networkRequestsAllowedAfterTime = retryDate.timeIntervalSince1970
    }

    private func retryBackOffTimeWithConsecutiveFailures(failureCount: Int) -> NSTimeInterval {
        let time = pow(2.0, Double(failureCount) - 1) * 60 + Double(arc4random_uniform(30))
        return min(max(APIConstants.minRetryBackoff, time),
                   APIConstants.maxRetryBackoff)
    }

    func requestNotAllowed() -> Bool {
        return NSDate().timeIntervalSince1970 < networkRequestsAllowedAfterTime
    }

}
