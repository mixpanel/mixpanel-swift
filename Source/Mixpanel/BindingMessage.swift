//
//  BindingMessage
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class BindingRequest: BaseWebSocketMessage {
    init?(payload: [String: AnyObject]?) {
        guard let payload = payload else {
            return nil
        }
        super.init(type: MessageType.bindingRequest.rawValue, payload: payload)
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            DispatchQueue.main.sync {
                var bindingCollection = connection.getSessionObjectSynchronized(for: "event_bindings") as? CodelessBindingCollection
                if bindingCollection == nil {
                    bindingCollection = CodelessBindingCollection()
                    connection.setSessionObjectSynchronized(with: bindingCollection!, for: "event_bindings")
                }

                if let payload = self.payload["events"] as? [[String: Any]] {
                    Logger.debug(message: "Loading event bindings: \(payload)")
                    bindingCollection?.updateBindings(payload)
                }
            }

            let response = BindingResponse()
            response.status = "OK"
            connection.send(message: response)
        }
        return operation
    }
}

class BindingResponse: BaseWebSocketMessage {

    var status: String {
        get {
            return payload["status"] as! String
        }
        set {
            payload["status"] = newValue as AnyObject
        }
    }

    init() {
        super.init(type: MessageType.bindingResponse.rawValue)
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
