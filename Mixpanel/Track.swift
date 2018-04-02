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
    let lock: ReadWriteLock
    let metadata: SessionMetadata

    init(apiToken: String, lock: ReadWriteLock, metadata: SessionMetadata) {
        self.apiToken = apiToken
        self.lock = lock
        self.metadata = metadata
    }

    func track(event: String?,
               properties: Properties? = nil,
               eventsQueue: inout Queue,
               timedEvents: inout InternalProperties,
               superProperties: InternalProperties,
               distinctId: String,
               epochInterval: Double) {
        var ev = event
        if ev == nil || ev!.isEmpty {
            Logger.info(message: "mixpanel track called with empty event parameter. using 'mp_event'")
            ev = "mp_event"
        }

        assertPropertyTypes(properties)
        let epochSeconds = Int(round(epochInterval))
        let eventStartTime = timedEvents[ev!] as? Double
        var p = InternalProperties()
        AutomaticProperties.automaticPropertiesLock.read {
            p += AutomaticProperties.properties
        }
        p["token"] = apiToken
        p["time"] = epochSeconds
        if let eventStartTime = eventStartTime {
            self.lock.write {
                timedEvents.removeValue(forKey: ev!)
            }
            p["$duration"] = Double(String(format: "%.3f", epochInterval - eventStartTime))
        }
        p["distinct_id"] = distinctId
        p += superProperties
        if let properties = properties {
            p += properties
        }

        var trackEvent: InternalProperties = ["event": ev!, "properties": p]
        metadata.toDict().forEach { (k,v) in trackEvent[k] = v }
        
        self.lock.write {
            eventsQueue.append(trackEvent)
            if eventsQueue.count > QueueConstants.queueSize {
                eventsQueue.remove(at: 0)
            }
        }

    }

    func registerSuperProperties(_ properties: Properties, superProperties: inout InternalProperties) {
        if Mixpanel.mainInstance().hasOptedOutTracking() {
            return
        }
        self.lock.write {
            assertPropertyTypes(properties)
            superProperties += properties
        }
    }

    func registerSuperPropertiesOnce(_ properties: Properties,
                                     superProperties: inout InternalProperties,
                                     defaultValue: MixpanelType?) {
        if Mixpanel.mainInstance().hasOptedOutTracking() {
            return
        }
        self.lock.write {
            assertPropertyTypes(properties)
                _ = properties.map() {
                    let val = superProperties[$0.key]
                    if val == nil ||
                        (defaultValue != nil && (val as? NSObject == defaultValue as? NSObject)) {
                        superProperties[$0.key] = $0.value
                    }
                }
        }
    }

    func unregisterSuperProperty(_ propertyName: String, superProperties: inout InternalProperties) {
        self.lock.write {
            superProperties.removeValue(forKey: propertyName)
        }
    }

    func clearSuperProperties(_ superProperties: inout InternalProperties) {
        self.lock.write {
            superProperties.removeAll()
        }
    }

    func time(event: String?, timedEvents: inout InternalProperties, startTime: Double) {
        if Mixpanel.mainInstance().hasOptedOutTracking() {
            return
        }
        self.lock.write {
            guard let event = event, !event.isEmpty else {
                Logger.error(message: "mixpanel cannot time an empty event")
                return
            }
            timedEvents[event] = startTime
        }
    }

    func clearTimedEvents(_ timedEvents: inout InternalProperties) {
        self.lock.write {
            timedEvents.removeAll()
        }
    }
}
