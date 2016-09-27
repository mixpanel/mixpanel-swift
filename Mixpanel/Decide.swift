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
    var unshownInAppNotifications: [InAppNotification]
    var newCodelessBindings: Set<CodelessBinding>

    init() {
        unshownInAppNotifications = []
        newCodelessBindings = Set()
    }
}

class Decide {

    var decideRequest = DecideRequest()
    var decideFetched = false
    var notificationsInstance = InAppNotifications()
    var codelessInstance = Codeless()
    var webSocketWrapper: WebSocketWrapper?

    var inAppDelegate: InAppNotificationsDelegate? {
        set {
            notificationsInstance.delegate = newValue
        }
        get {
            return notificationsInstance.delegate
        }
    }
    var enableVisualEditorForCodeless = true

    let switchboardURL = "wss://switchboard.mixpanel.com"

    func checkDecide(forceFetch: Bool = false,
                     distinctId: String,
                     token: String,
                     completion: @escaping ((_ response: DecideResponse?) -> Void)) {
        var decideResponse = DecideResponse()

        if !decideFetched || forceFetch {
            let semaphore = DispatchSemaphore(value: 0)
            decideRequest.sendRequest(distinctId: distinctId, token: token) { decideResult in
                guard let result = decideResult else {
                    semaphore.signal()
                    completion(nil)
                    return
                }

                var parsedNotifications = [InAppNotification]()
                if let rawNotifications = result["notifications"] as? [[String: Any]] {
                    for rawNotif in rawNotifications {
                        if let notification = InAppNotification(JSONObject: rawNotif) {
                            parsedNotifications.append(notification)
                        }
                    }
                } else {
                    Logger.error(message: "in-app notifications check response format error")
                }
                self.notificationsInstance.inAppNotifications = parsedNotifications

                var parsedCodelessBindings = Set<CodelessBinding>()
                if let rawCodelessBindings = result["event_bindings"] as? [[String: Any]] {
                    for rawBinding in rawCodelessBindings {
                        if let binding = Codeless.createBinding(object: rawBinding) {
                            parsedCodelessBindings.insert(binding)
                        }
                    }
                } else {
                    Logger.debug(message: "codeless event bindings check response format error")
                }

                let finishedCodelessBindings = self.codelessInstance.codelessBindings.subtracting(parsedCodelessBindings)
                for finishedBinding in finishedCodelessBindings {
                    finishedBinding.stop()
                }

                let newCodelessBindings = parsedCodelessBindings.subtracting(self.codelessInstance.codelessBindings)
                decideResponse.newCodelessBindings = newCodelessBindings

                self.codelessInstance.codelessBindings.formUnion(newCodelessBindings)
                self.codelessInstance.codelessBindings.subtract(finishedCodelessBindings)

                self.decideFetched = true
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        } else {
            Logger.info(message: "decide cache found, skipping network request")
        }

        decideResponse.unshownInAppNotifications = notificationsInstance.inAppNotifications.filter {
            !notificationsInstance.shownNotifications.contains($0.ID)
        }

        Logger.info(message: "decide check found \(decideResponse.unshownInAppNotifications.count) " +
            "available notifications out of " +
            "\(notificationsInstance.inAppNotifications.count) total")
        Logger.info(message: "decide check found \(decideResponse.newCodelessBindings.count) " +
            "new codeless bindings our of \(codelessInstance.codelessBindings)")

        completion(decideResponse)
    }

    func connectToWebSocket(token: String, mixpanelInstance: MixpanelInstance, reconnect: Bool = false) {
        var oldInterval = 0.0
        let webSocketURL = "\(switchboardURL)/connect?key=\(token)&type=device"
        guard let url = URL(string: webSocketURL) else {
            Logger.error(message: "bad URL to connect to websocket \(webSocketURL)")
            return
        }
        let connectCallback = { [weak mixpanelInstance] in
            guard let mixpanelInstance = mixpanelInstance else {
                return
            }
            oldInterval = mixpanelInstance.flushInterval
            mixpanelInstance.flushInterval = 1
            UIApplication.shared.isIdleTimerDisabled = true

            for binding in self.codelessInstance.codelessBindings {
                binding.stop()
            }

        }

        let disconnectCallback = { [weak mixpanelInstance] in
            guard let mixpanelInstance = mixpanelInstance else {
                return
            }
            mixpanelInstance.flushInterval = oldInterval
            UIApplication.shared.isIdleTimerDisabled = false

            for binding in self.codelessInstance.codelessBindings {
                binding.execute()
            }
        }

        webSocketWrapper = WebSocketWrapper(url: url,
                                            keepTrying: reconnect,
                                            connectCallback: connectCallback,
                                            disconnectCallback: disconnectCallback)
    }

}
