//
//  Track.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

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
  weak var mixpanelInstance: MixpanelInstance?

  init(
    apiToken: String, instanceName: String, lock: ReadWriteLock, metadata: SessionMetadata,
    mixpanelPersistence: MixpanelPersistence
  ) {
    self.instanceName = instanceName
    self.apiToken = apiToken
    self.lock = lock
    self.metadata = metadata
    self.mixpanelPersistence = mixpanelPersistence
  }

  func track(
    event: String?,
    timedEventID: UUID?,
    properties: Properties? = nil,
    timedEvents: TimedEvents,
    superProperties: InternalProperties,
    mixpanelIdentity: MixpanelIdentity,
    epochInterval: Double
  ) -> TimedEvents {
    var eventName = "mp_event"
    if let event = event {
      eventName = event
    } else {
      MixpanelLogger.info(
        message: "mixpanel track called with empty event parameter. using 'mp_event'")
    }
    if !(mixpanelInstance?.trackAutomaticEventsEnabled ?? false) && eventName.hasPrefix("$ae_") {
      return timedEvents
    }
    let eventID = timedEventID?.uuidString ?? eventName
    assertPropertyTypes(properties)
    let epochMilliseconds = round(epochInterval * 1000)
    let eventStartTime = timedEvents[eventID]
    var p = InternalProperties()
    AutomaticProperties.automaticPropertiesLock.read {
      p += AutomaticProperties.properties
    }
    p["token"] = apiToken
    p["time"] = epochMilliseconds
    var shadowTimedEvents = timedEvents
    if let eventStartTime = eventStartTime {
      print("shadowTimedEvents before removing \(eventID): \(shadowTimedEvents as AnyObject)")
      shadowTimedEvents.removeValue(forKey: eventID)
      p["$duration"] = Double(String(format: "%.3f", epochInterval - eventStartTime))
    }
    p["distinct_id"] = mixpanelIdentity.distinctID
    if mixpanelIdentity.anonymousId != nil {
      p["$device_id"] = mixpanelIdentity.anonymousId
    }
    if mixpanelIdentity.userId != nil {
      p["$user_id"] = mixpanelIdentity.userId
    }
    if mixpanelIdentity.hadPersistedDistinctId != nil {
      p["$had_persisted_distinct_id"] = mixpanelIdentity.hadPersistedDistinctId
    }

    p += superProperties
    if let properties = properties {
      p += properties
    }

    var trackEvent: InternalProperties = ["event": eventName, "properties": p]
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

  func time(eventID: TimedEventID, timedEvents: TimedEvents, startTime: TimeInterval)
    -> TimedEvents
  {
    if mixpanelInstance?.hasOptedOutTracking() ?? false {
      return timedEvents
    }
    var updatedTimedEvents = timedEvents
    guard !eventID.isEmpty else {
      MixpanelLogger.error(message: "mixpanel cannot time an empty event")
      return updatedTimedEvents
    }
    updatedTimedEvents[eventID] = startTime
    return updatedTimedEvents
  }

  func clearTimedEvents(_ timedEvents: TimedEvents) -> TimedEvents {
    var updatedTimedEvents = timedEvents
    updatedTimedEvents.removeAll()
    return updatedTimedEvents
  }

  func clearTimedEvent(eventID: TimedEventID, timedEvents: TimedEvents) -> TimedEvents {
    var updatedTimedEvents = timedEvents
    guard !eventID.isEmpty else {
      MixpanelLogger.error(message: "mixpanel cannot clear an empty timed event")
      return updatedTimedEvents
    }
    print("updatedTimedEvents before removing \(eventID): \(updatedTimedEvents as AnyObject)")
    updatedTimedEvents.removeValue(forKey: eventID)
    return updatedTimedEvents
  }
}
