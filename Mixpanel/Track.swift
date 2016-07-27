//
//  Track.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

func += <K, V> (inout left: [K:V], right: [K:V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

class Track {
    let apiToken: String

    init(apiToken: String) {
        self.apiToken = apiToken
    }

    class func assertPropertyTypes(properties: Properties?) {
        if let properties = properties {
            for (_, v) in properties {
                MPAssert(
                    v is String ||
                    v is Int ||
                    v is UInt ||
                    v is Double ||
                    v is Float ||
                    v is [AnyObject] ||
                    v is [String: AnyObject] ||
                    v is NSDate ||
                    v is NSURL ||
                    v is NSNull,
                    message: "Property values must be of valid type. Got \(v.dynamicType)")
            }
        }
    }

    func track(event event: String?,
               properties: Properties? = nil,
               inout eventsQueue: Queue,
               inout timedEvents: Properties,
               superProperties: Properties,
               distinctId: String,
               epochInterval: Double) {
        var ev = event
        if ev == nil || ev!.isEmpty {
            Logger.info(message: "mixpanel track called with empty event parameter. using 'mp_event'")
            ev = "mp_event"
        }

        Track.assertPropertyTypes(properties)
        let epochSeconds = Int(round(epochInterval))
        let eventStartTime = timedEvents[ev!] as? Double
        var p = Properties()
        p += AutomaticProperties.properties
        p["token"] = apiToken
        p["time"] = epochSeconds
        if let eventStartTime = eventStartTime {
            timedEvents.removeValueForKey(ev!)
            p["$duration"] = Double(String(format: "%.3f", epochInterval - eventStartTime))
        }
        p["distinct_id"] = distinctId
        p += superProperties
        if let properties = properties {
            p += properties
        }

        let trackEvent: Properties = ["event": ev!, "properties": p]
        eventsQueue.append(trackEvent)

        if eventsQueue.count > QueueConstants.queueSize {
            eventsQueue.removeAtIndex(0)
        }
    }

    func registerSuperProperties(properties: Properties, inout superProperties: Properties) {
        Track.assertPropertyTypes(properties)
        superProperties += properties
    }

    func registerSuperPropertiesOnce(properties: Properties,
                                     inout superProperties: Properties,
                                     defaultValue: AnyObject?) {
        Track.assertPropertyTypes(properties)
            _ = properties.map() {
                let val = superProperties[$0.0]
                if val == nil ||
                    (defaultValue != nil && (val as? NSObject == defaultValue as? NSObject)) {
                    superProperties[$0.0] = $0.1
                }
            }
    }

    func unregisterSuperProperty(propertyName: String, inout superProperties: Properties) {
        superProperties.removeValueForKey(propertyName)
    }

    func clearSuperProperties(inout superProperties: Properties) {
        superProperties.removeAll()
    }

    func time(event event: String?, inout timedEvents: Properties, startTime: Double) {
        guard let event = event where !event.isEmpty else {
            Logger.error(message: "mixpanel cannot time an empty event")
            return
        }
        timedEvents[event] = startTime
    }

    func clearTimedEvents(inout timedEvents: Properties) {
        timedEvents.removeAll()
    }
}
