//
//  BindingMessage
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class BindingRequest: BaseWebSocketMessage {
    init() {
        super.init(type: "event_binding_request")
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            DispatchQueue.main.sync {
                var bindingCollection = connection.getSessionObjectSynchronized(key: "event_bindings") as? CodelessBindingCollection
                if bindingCollection == nil {
                    bindingCollection = CodelessBindingCollection()
                    connection.setSessionObjectSynchronized(value: bindingCollection, key: "event_bindings")
                }

                if let payload = self.payload["events"] as? [[String: Any]] {
                    Logger.debug(message: "Loading event bindings: \(payload)")
                    bindingCollection?.updateBindings(payload)
                }
            }

            let response = BindingResponse()
            response.status = "OK"
            connection.sendMessage(message: response)
        }
        return operation
    }
}

class BindingResponse: BaseWebSocketMessage {

    var status: String? {
        get {
            return payload["status"] as? String
        }
        set {
            payload["status"] = newValue as AnyObject
        }
    }

    init() {
        super.init(type: "event_binding_response")
    }
}

class CodelessBindingCollection {
    var bindings: [CodelessBinding] = [CodelessBinding]()

    func updateBindings(_ payload: [[String: Any]]) {
        var newBindings = [CodelessBinding]()
        for bindingInfo in payload {
            if let binding = Codeless.createBinding(object: bindingInfo) {
                newBindings.append(binding)
            }
        }

        for oldBinding in bindings {
            oldBinding.stop()
        }
        bindings = newBindings
        for newBinding in bindings {
            newBinding.execute()
        }
    }

    func cleanup() {
        for oldBinding in bindings {
            oldBinding.stop()
        }
        bindings.removeAll()
    }
}
