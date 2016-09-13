//
//  Track.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

func += <K, V> (left: inout [K:V], right: [K:V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

class Track {
    let apiToken: String

    init(apiToken: String) {
        self.apiToken = apiToken
    }

    class func assertPropertyTypes(_ properties: Properties?) {
        if let properties = properties {
            for (_, v) in properties {
                MPAssert(
                    v is String ||
                    v is Int ||
                    v is UInt ||
                    v is Double ||
                    v is Float ||
                    v is [Any] ||
                    v is [String: Any] ||
                    v is Date ||
                    v is URL ||
                    v is NSNull,
                    message: "Property values must be of valid type. Got \(type(of: v))")
            }
        }
    }

    func track(event: String?,
               properties: Properties? = nil,
               eventsQueue: inout Queue,
               timedEvents: inout Properties,
               superProperties: Properties,
               distinctId: String,
               epochInterval: Double) {
        var ev = event
        if ev == nil || ev!.isEmpty {
            Logger.info("mixpanel track called with empty event parameter. using 'mp_event'")
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
            timedEvents.removeValue(forKey: ev!)
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
            eventsQueue.remove(at: 0)
        }
    }

    func registerSuperProperties(_ properties: Properties, superProperties: inout Properties) {
        Track.assertPropertyTypes(properties)
        superProperties += properties
    }

    func registerSuperPropertiesOnce(_ properties: Properties,
                                     superProperties: inout Properties,
                                     defaultValue: Any?) {
        Track.assertPropertyTypes(properties)
            _ = properties.map() {
                let val = superProperties[$0.0]
                if val == nil ||
                    (defaultValue != nil && (val as? NSObject == defaultValue as? NSObject)) {
                    superProperties[$0.0] = $0.1
                }
            }
    }

    func unregisterSuperProperty(_ propertyName: String, superProperties: inout Properties) {
        superProperties.removeValue(forKey: propertyName)
    }

    func clearSuperProperties(_ superProperties: inout Properties) {
        superProperties.removeAll()
    }

    func time(event: String?, timedEvents: inout Properties, startTime: Double) {
        guard let event = event , !event.isEmpty else {
            Logger.error(message: "mixpanel cannot time an empty event")
            return
        }
        timedEvents[event] = startTime
    }

    func clearTimedEvents(_ timedEvents: inout Properties) {
        timedEvents.removeAll()
    }
}
