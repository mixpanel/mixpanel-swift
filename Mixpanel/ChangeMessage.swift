//
//  ChangeMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 10/4/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ChangeRequest: BaseWebSocketMessage {

    init?(payload: [String: AnyObject]?) {
        guard let payload = payload else {
            return nil
        }
        super.init(type: MessageType.changeRequest.rawValue, payload: payload)
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

            if let actions = self.payload["actions"] as? [[String: Any]] {
                DispatchQueue.main.sync {
                    variant?.addActions(JSONObject: actions, execute: true)
                }
            }

            let response = ChangeResponse()
            response.status = "OK"
            connection.send(message: response)
        }
        return operation
    }
}

class ChangeResponse: BaseWebSocketMessage {

    var status: String {
        get {
            return payload["status"] as! String
        }
        set {
            payload["status"] = newValue as AnyObject
        }
    }

    init() {
        super.init(type: MessageType.changeResponse.rawValue)
    }
}
