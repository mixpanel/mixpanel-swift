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

  /// Builds complete event properties for tracking.
  /// This is the single source of truth for property building to ensure consistency
  /// between persistence and first-time event checks.
  ///
  /// - Parameters:
  ///   - eventName: The event name (after defaulting to "mp_event" if nil)
  ///   - userProperties: User-provided properties
  ///   - timedEvents: Timed events dictionary for duration calculation
  ///   - superProperties: Super properties from MixpanelInstance
  ///   - mixpanelIdentity: Identity information
  ///   - epochInterval: Epoch timestamp in seconds
  /// - Returns: Complete event properties dictionary with all standard fields
  func buildTrackEventProperties(
    eventName: String,
    userProperties: Properties?,
    timedEvents: InternalProperties,
    superProperties: InternalProperties,
    mixpanelIdentity: MixpanelIdentity,
    epochInterval: Double
  ) -> InternalProperties {
    var p = InternalProperties()

    // Add automatic properties first (lowest priority)
    AutomaticProperties.automaticPropertiesLock.read {
      p += AutomaticProperties.properties
    }

    // Add SDK-specific properties
    p["token"] = apiToken

    // Add timestamp (milliseconds)
    let epochMilliseconds = round(epochInterval * 1000)
    p["time"] = epochMilliseconds

    // Add duration if this is a timed event
    if let eventStartTime = timedEvents[eventName] as? Double {
      p["$duration"] = Double(String(format: "%.3f", epochInterval - eventStartTime))
    }

    // Add identity properties
    p["distinct_id"] = mixpanelIdentity.distinctID

    if let anonymousId = mixpanelIdentity.anonymousId {
      p["$device_id"] = anonymousId
    }

    if let userId = mixpanelIdentity.userId {
      p["$user_id"] = userId
    }

    if let hadPersistedDistinctId = mixpanelIdentity.hadPersistedDistinctId {
      p["$had_persisted_distinct_id"] = hadPersistedDistinctId
    }

    // Add super properties (can override automatic properties)
    p += superProperties

    // Add user properties (highest priority - can override everything)
    if let userProperties = userProperties {
      p += userProperties
    }

    return p
  }

    func track(
        event: String,
        properties: InternalProperties,
        timedEvents: InternalProperties,
    ) -> InternalProperties {
        // Update timed events (remove the event if it was timed)
        var shadowTimedEvents = timedEvents
        if timedEvents[event] != nil {
            shadowTimedEvents.removeValue(forKey: event)
        }

        // Notify event bridge listeners (non-blocking)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            MixpanelEventBridge.shared.notifyListeners(
                eventName: event,
                properties: properties
            )
        }

        // Note: First-time event checking is now done in MixpanelInstance.track().
        // This ensures proper ordering when
        // track() and getVariantSync() are called sequentially.

        var trackEvent: InternalProperties = ["event": event, "properties": properties]
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
