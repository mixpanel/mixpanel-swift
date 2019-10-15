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
    let selectorOpt: [String: Any]?
    
    init?(jsonObject: [String: Any]?) {
        guard let object = jsonObject else {
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
        self.selectorOpt = selector
    }
    
    func matchesEvent(eventName: String?, properties: InternalProperties) -> Bool {
        if let event = self.event {
            if (eventName == DisplayTrigger.ANY_EVENT || eventName == "" || eventName?.compare(event) == ComparisonResult.orderedSame) {
                if let selector = selectorOpt {
                    if let value = SelectorEvaluator.evaluate(selector: selector, properties: properties) {
                        return value
                    }
                    return false
                }
                return true
            }
        }
        return false
    }
    
    func payload() -> [String: AnyObject] {
        var payload = [String: AnyObject]()
        payload[PayloadKey.event] = event as AnyObject
        payload[PayloadKey.selector] = selectorOpt as AnyObject
        
        return payload
    }
}
