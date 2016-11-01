//
//  TweakMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 10/4/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class TweakRequest: BaseWebSocketMessage {

    init?(payload: [String: AnyObject]?) {
        guard let payload = payload else {
            return nil
        }
        super.init(type: MessageType.tweakRequest.rawValue, payload: payload)
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            var variant = connection.getSessionObjectSynchronized(for: "session_variant") as? Variant
            if variant == nil {
                variant = Variant(ID: 0, experimentID: 0, actions: [], tweaks: [])
                connection.setSessionObjectSynchronized(with: variant!, for: "session_variant")
            }

            if let tweaks = self.payload["tweaks"] as? [[String: Any]] {
                DispatchQueue.main.sync {
                    variant?.addTweaks(JSONObject: tweaks, execute: true)
                }
            }

            let response = TweakResponse()
            response.status = "OK"
            connection.send(message: response)
        }
        return operation
    }
}

class TweakResponse: BaseWebSocketMessage {

    var status: String {
        get {
            return payload["status"] as! String
        }
        set {
            payload["status"] = newValue as AnyObject
        }
    }

    init() {
        super.init(type: MessageType.tweakResponse.rawValue)
    }
}
