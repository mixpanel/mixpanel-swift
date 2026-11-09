//
//  Track.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import MixpanelSwiftCommon

func += <K, V>(left: inout [K: V], right: [K: V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

class Track {
    let instanceName: String
    let apiToken: String
    let lock: ReadWriteLock
    let metadata: SessionMetadata
    let mixpanelPersistence: MixpanelPersistence
    let excludeProperties: Set<String>
    weak var mixpanelInstance: MixpanelInstance?

    init(
        apiToken: String, instanceName: String, lock: ReadWriteLock, metadata: SessionMetadata,
        mixpanelPersistence: MixpanelPersistence, excludeProperties: Set<String> = []
    ) {
        self.instanceName = instanceName
        self.apiToken = apiToken
        self.lock = lock
        self.metadata = metadata
        self.mixpanelPersistence = mixpanelPersistence
        self.excludeProperties = excludeProperties
    }

    /// Removes any key in `exclude` from `properties`, skipping keys in
    /// ``MixpanelOptions/reservedPropertyKeys`` that ingestion or identity require.
    /// `internal` so it can be unit-tested directly. No-op on an empty exclude set.
    static func applyExcludeProperties(
        _ properties: inout InternalProperties, exclude: Set<String>
    ) {
        if exclude.isEmpty { return }
        for key in exclude {
            if MixpanelOptions.reservedPropertyKeys.contains(key) { continue }
            properties.removeValue(forKey: key)
        }
    }

    /// On a hierarchical groups project an event's `$company_id` is always the identified company,
    /// so one passed with the event or its groups is replaced, or removed before a company is
    /// identified, with a warning.
    static func applyIdentifiedCompany(
        _ properties: inout InternalProperties, companyId: String?, callerCompanyId: MixpanelType?,
        event: String
    ) {
        if let companyId = companyId {
            properties[companyIdGroupKey] = companyId
            if let callerCompanyId = callerCompanyId, !callerCompanyId.equals(rhs: companyId) {
                MixpanelLogger.warn(
                    message:
                        "Replaced \(companyIdGroupKey) \(callerCompanyId) on event \(event) with the "
                        + "identified company \(companyId). Set the company with identify(identity:).")
            }
        } else if properties.removeValue(forKey: companyIdGroupKey) != nil, let callerCompanyId = callerCompanyId {
            MixpanelLogger.warn(
                message:
                    "Removed \(companyIdGroupKey) \(callerCompanyId) from event \(event): no company is "
                    + "identified yet. Set the company with identify(identity:).")
        }
    }

    func track(
        event: String?,
        properties: Properties? = nil,
        timedEvents: InternalProperties,
        superProperties: InternalProperties,
        storedIdentity: StoredIdentity,
        epochInterval: Double
    ) -> InternalProperties {
        var ev = "mp_event"
        if let event = event {
            ev = event
        } else {
            MixpanelLogger.info(
                message: "mixpanel track called with empty event parameter. using 'mp_event'")
        }
        if !(mixpanelInstance?.trackAutomaticEventsEnabled ?? false) && ev.hasPrefix("$ae_") {
            return timedEvents
        }
        assertPropertyTypes(properties)
        let epochMilliseconds = round(epochInterval * 1000)
        let eventStartTime = timedEvents[ev] as? Double
        var p = InternalProperties()
        AutomaticProperties.automaticPropertiesLock.read {
            p += AutomaticProperties.properties
        }
        p["token"] = apiToken
        p["time"] = epochMilliseconds
        var shadowTimedEvents = timedEvents
        if let eventStartTime = eventStartTime {
            shadowTimedEvents.removeValue(forKey: ev)
            p["$duration"] = Double(String(format: "%.3f", epochInterval - eventStartTime))
        }
        // On a hierarchical groups project the user is $user_id and $company_id, so no distinct_id
        if storedIdentity.userId == nil || storedIdentity.companyId == nil {
            p["distinct_id"] = storedIdentity.distinctID
        }
        if storedIdentity.anonymousId != nil {
            p["$device_id"] = storedIdentity.anonymousId
        }
        if storedIdentity.userId != nil {
            p["$user_id"] = storedIdentity.userId
        }
        if storedIdentity.hadPersistedDistinctId != nil {
            p["$had_persisted_distinct_id"] = storedIdentity.hadPersistedDistinctId
        }

        p += superProperties
        if mixpanelInstance?.hierarchicalGroups ?? false {
            if let properties = properties {
                p += properties
            }
            Track.applyIdentifiedCompany(
                &p, companyId: storedIdentity.companyId, callerCompanyId: properties?[companyIdGroupKey],
                event: ev)
        } else if let properties = properties {
            p += properties
        }

        // Notify event bridge listeners (non-blocking)
        MixpanelEventBridge.shared.notifyListeners(
            eventName: ev,
            properties: p
        )

        // Check for first-time event matches
        if let mixpanelInstance = mixpanelInstance,
            let flagManager = mixpanelInstance.flags as? FeatureFlagManager
        {
            flagManager.checkFirstTimeEvents(eventName: ev, properties: p)
        }

        // Filter just before persistence so internal observers above (event bridge,
        // first-time-events check) still see the full property set, matching Android's
        // network-send chokepoint.
        Track.applyExcludeProperties(&p, exclude: excludeProperties)

        var trackEvent: InternalProperties = ["event": ev, "properties": p]
        metadata.toDict().forEach { (k, v) in trackEvent[k] = v }

        self.mixpanelPersistence.saveEntity(trackEvent, type: .events)
        MixpanelPersistence.saveTimedEvents(timedEvents: shadowTimedEvents, instanceName: instanceName)
        return shadowTimedEvents
    }

    func registerSuperProperties(
        _ properties: Properties,
        superProperties: InternalProperties
    ) -> InternalProperties {
        if mixpanelInstance?.hasOptedOutTracking() ?? false {
            return superProperties
        }

        var updatedSuperProperties = superProperties
        assertPropertyTypes(properties)
        updatedSuperProperties += properties

        return updatedSuperProperties
    }

    func registerSuperPropertiesOnce(
        _ properties: Properties,
        superProperties: InternalProperties,
        defaultValue: MixpanelType?
    ) -> InternalProperties {
        if mixpanelInstance?.hasOptedOutTracking() ?? false {
            return superProperties
        }

        var updatedSuperProperties = superProperties
        assertPropertyTypes(properties)
        _ = properties.map {
            let val = updatedSuperProperties[$0.key]
            if val == nil || (defaultValue != nil && (val as? NSObject == defaultValue as? NSObject)) {
                updatedSuperProperties[$0.key] = $0.value
            }
        }

        return updatedSuperProperties
    }

    func unregisterSuperProperty(
        _ propertyName: String,
        superProperties: InternalProperties
    ) -> InternalProperties {
        var updatedSuperProperties = superProperties
        updatedSuperProperties.removeValue(forKey: propertyName)
        return updatedSuperProperties
    }

    func clearSuperProperties(_ superProperties: InternalProperties) -> InternalProperties {
        var updatedSuperProperties = superProperties
        updatedSuperProperties.removeAll()
        return updatedSuperProperties
    }

    func updateSuperProperty(
        _ update: (_ superProperties: inout InternalProperties) -> Void,
        superProperties: inout InternalProperties
    ) {
        update(&superProperties)
    }

    func time(event: String?, timedEvents: InternalProperties, startTime: Double)
        -> InternalProperties
    {
        if mixpanelInstance?.hasOptedOutTracking() ?? false {
            return timedEvents
        }
        var updatedTimedEvents = timedEvents
        guard let event = event, !event.isEmpty else {
            MixpanelLogger.error(message: "mixpanel cannot time an empty event")
            return updatedTimedEvents
        }
        updatedTimedEvents[event] = startTime
        return updatedTimedEvents
    }

    func clearTimedEvents(_ timedEvents: InternalProperties) -> InternalProperties {
        var updatedTimedEvents = timedEvents
        updatedTimedEvents.removeAll()
        return updatedTimedEvents
    }

    func clearTimedEvent(event: String?, timedEvents: InternalProperties) -> InternalProperties {
        var updatedTimedEvents = timedEvents
        guard let event = event, !event.isEmpty else {
            MixpanelLogger.error(message: "mixpanel cannot clear an empty timed event")
            return updatedTimedEvents
        }
        updatedTimedEvents.removeValue(forKey: event)
        return updatedTimedEvents
    }
}
