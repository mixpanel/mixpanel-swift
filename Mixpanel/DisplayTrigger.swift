//
//  DisplayTrigger.swift
//  Mixpanel
//
//  Created by Madhu Palani on 1/30/19.
//  Copyright © 2019 Mixpanel. All rights reserved.
//

import Foundation

class DisplayTrigger {
    enum PayloadKey {
        static let event = "event"
        static let selector = "selector"
    }
    
    static let ANY_EVENT = "$any_event"
    
    let event: String?
    let selector: [String: Any]?
    
    init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "display trigger json object should not be nil")
            return nil
        }
        
        guard let event = object[PayloadKey.event] as? String else {
            Logger.error(message: "invalid event name type")
            return nil
        }
        
        guard let selector = object[PayloadKey.selector] as? [String: Any]? else {
            Logger.error(message: "invalid selector section")
            return nil
        }
        
        self.event = event
        self.selector = selector
    }
    
    func matchesEvent(eventName: String?, properties: Properties? = nil) -> Bool {
        if let event = self.event {
            if (eventName == DisplayTrigger.ANY_EVENT || eventName == "" || eventName?.caseInsensitiveCompare(event) == ComparisonResult.orderedSame) {
                return true
            }
        }
        
        return false
    }
    
    func payload() -> [String: AnyObject] {
        var payload = [String: AnyObject]()
        payload[PayloadKey.event] = event as AnyObject
        payload[PayloadKey.selector] = selector as AnyObject
        
        return payload
    }
}
