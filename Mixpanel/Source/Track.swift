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

    func track(event: String?,
               properties: Properties? = nil,
               eventsQueue: inout Queue,
               timedEvents: inout InternalProperties,
               superProperties: InternalProperties,
               distinctId: String,
               epochInterval: Double) {
        var ev = event
        if ev == nil || ev!.characters.isEmpty {
            Logger.info(message: "mixpanel track called with empty event parameter. using 'mp_event'")
            ev = "mp_event"
        }

        assertPropertyTypes(properties)
        let epochSeconds = Int(round(epochInterval))
        let eventStartTime = timedEvents[ev!] as? Double
        var p = InternalProperties()
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

        let trackEvent: InternalProperties = ["event": ev!, "properties": p]
        eventsQueue.append(trackEvent)

        if eventsQueue.count > QueueConstants.queueSize {
            eventsQueue.remove(at: 0)
        }
    }

    func registerSuperProperties(_ properties: Properties, superProperties: inout InternalProperties) {
        assertPropertyTypes(properties)
        superProperties += properties
    }

    func registerSuperPropertiesOnce(_ properties: Properties,
                                     superProperties: inout InternalProperties,
                                     defaultValue: MixpanelType?) {
        assertPropertyTypes(properties)
            _ = properties.map() {
                let val = superProperties[$0.key]
                if val == nil ||
                    (defaultValue != nil && (val as? NSObject == defaultValue as? NSObject)) {
                    superProperties[$0.key] = $0.value
                }
            }
    }

    func unregisterSuperProperty(_ propertyName: String, superProperties: inout InternalProperties) {
        superProperties.removeValue(forKey: propertyName)
    }

    func clearSuperProperties(_ superProperties: inout InternalProperties) {
        superProperties.removeAll()
    }

    func time(event: String?, timedEvents: inout InternalProperties, startTime: Double) {
        guard let event = event, !event.isEmpty else {
            Logger.error(message: "mixpanel cannot time an empty event")
            return
        }
        timedEvents[event] = startTime
    }

    func clearTimedEvents(_ timedEvents: inout InternalProperties) {
        timedEvents.removeAll()
    }
}
