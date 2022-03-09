//
//  Decide.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class Decide {

    let decideRequest: DecideRequest
    let lock: ReadWriteLock
    var decideFetched = false
    let mixpanelPersistence: MixpanelPersistence

    required init(basePathIdentifier: String, lock: ReadWriteLock, mixpanelPersistence: MixpanelPersistence) {
        self.decideRequest = DecideRequest(basePathIdentifier: basePathIdentifier)
        self.lock = lock
        self.mixpanelPersistence = mixpanelPersistence
    }

    func checkDecide(forceFetch: Bool = false,
                     distinctId: String,
                     token: String) {

        if !decideFetched || forceFetch {
            let semaphore = DispatchSemaphore(value: 0)
            decideRequest.sendRequest(distinctId: distinctId, token: token) { [weak self] decideResult in
                guard let self = self else {
                    return
                }
                guard let result = decideResult else {
                    semaphore.signal()
                    return
                }

                if let automaticEventsEnabled = result["automatic_events"] as? Bool {
                    MixpanelPersistence.saveAutomacticEventsEnabledFlag(value: automaticEventsEnabled, fromDecide: true, apiToken: token)
                }

                self.decideFetched = true
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        } else {
            Logger.info(message: "decide cache found, skipping network request")
        }
    }

}
