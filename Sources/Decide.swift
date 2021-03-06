//
//  Decide.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

struct DecideResponse {
    var integrations: [String]

    init() {
        integrations = []
    }
}

class Decide {

    let decideRequest: DecideRequest
    let lock: ReadWriteLock
    var decideFetched = false
    var automaticEventsEnabled: Bool?

    required init(basePathIdentifier: String, lock: ReadWriteLock) {
        self.decideRequest = DecideRequest(basePathIdentifier: basePathIdentifier)
        self.lock = lock
    }

    func checkDecide(forceFetch: Bool = false,
                     distinctId: String,
                     token: String,
                     completion: @escaping ((_ response: DecideResponse?) -> Void)) {
        var decideResponse = DecideResponse()

        if !decideFetched || forceFetch {
            let semaphore = DispatchSemaphore(value: 0)
            decideRequest.sendRequest(distinctId: distinctId, token: token) { [weak self] decideResult in
                guard let self = self else {
                    return
                }
                guard let result = decideResult else {
                    semaphore.signal()
                    completion(nil)
                    return
                }

                if let automaticEvents = result["automatic_events"] as? Bool {
                    self.automaticEventsEnabled = automaticEvents
                }

                if let integrations = result["integrations"] as? [String] {
                    decideResponse.integrations = integrations
                }

                self.decideFetched = true
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        } else {
            Logger.info(message: "decide cache found, skipping network request")
        }

        completion(decideResponse)
    }

}
