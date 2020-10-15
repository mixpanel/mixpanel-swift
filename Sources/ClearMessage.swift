//
//  ClearMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 10/7/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ClearRequest: BaseWebSocketMessage {

    init?(payload: [String: AnyObject]?) {
        guard let payload = payload else {
            return nil
        }
        super.init(type: MessageType.clearRequest.rawValue, payload: payload)
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            let variant = connection.getSessionObjectSynchronized(for: "session_variant") as? Variant
            if let variant = variant {
                if let actions = self.payload["actions"] as? [String] {
                    DispatchQueue.main.sync {
                        for name in actions {
                            variant.removeAction(name: name)
                        }
                    }
                }
            }

            let response = ClearRespone()
            response.status = "OK"
            connection.send(message: response)
        }
        return operation
    }
}

class ClearRespone: BaseWebSocketMessage {

    var status: String {
        get {
            return payload["status"] as! String
        }
        set {
            payload["status"] = newValue as AnyObject
        }
    }

    init() {
        super.init(type: MessageType.clearResponse.rawValue)
    }
}
