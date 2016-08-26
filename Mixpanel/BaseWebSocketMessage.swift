//
//  BaseWebSocketMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol BaseWebSocketMessage: CustomDebugStringConvertible {
    var type: String { get set }

    func setPayload(object: AnyObject, key: String)
    func payloadObject(key: String) -> AnyObject
    func JSONData() -> Data
    func responseCommand(connection: WebSocketWrapper) -> Operation

}
