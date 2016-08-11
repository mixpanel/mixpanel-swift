//
//  Decide.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct DecideResponse {
    var unshownInAppNotifications: [InAppNotification]

    init() {
        unshownInAppNotifications = []
    }
}

class Decide {

    var decideRequest = DecideRequest()
    var decideFetched = false
    var notificationsInstance = InAppNotifications()

    func checkDecide(forceFetch: Bool = false, distinctId: String, token: String, completion: ((response: DecideResponse?) -> Void)) {
        var decideResponse = DecideResponse()

        if !decideFetched || forceFetch {
            let semaphore = DispatchSemaphore(value: 0)
            decideRequest.sendRequest(distinctId: distinctId, token: token) { decideResult in
                guard let result = decideResult else {
                    semaphore.signal()
                    completion(response: nil)
                    return
                }

                var parsedNotifications = [InAppNotification]()
                if let rawNotifications = result["notifications"] as? [[String: AnyObject]] {
                    for rawNotif in rawNotifications {
                        if let notification = InAppNotification(JSONObject: rawNotif) {
                            parsedNotifications.append(notification)
                        }
                    }
                } else {
                    Logger.error(message: "in-app notifications check response format error")
                }

                self.notificationsInstance.inAppNotifications = parsedNotifications
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        } else {
            Logger.info(message: "decide cache found, skipping network request")
        }

        decideResponse.unshownInAppNotifications = self.notificationsInstance.inAppNotifications.filter {
            !notificationsInstance.shownNotifications.contains($0.ID)
        }

        Logger.info(message: "decide check found \(decideResponse.unshownInAppNotifications.count) " +
            "available notifications out of " +
            "\(self.notificationsInstance.inAppNotifications.count) total")

        completion(response: decideResponse)
    }

}
