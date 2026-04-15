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

  /// Builds event properties for tracking and first-time event checking.
  /// This is the single source of truth for property building to ensure consistency.
  ///
  /// - Parameters:
  ///   - userProperties: User-provided properties
  ///   - superProperties: Super properties from MixpanelInstance
  ///   - mixpanelIdentity: Identity information
  ///   - epochInterval: Epoch timestamp
  /// - Returns: Complete event properties dictionary
  func buildEventProperties(
    userProperties: Properties?,
    superProperties: InternalProperties,
    mixpanelIdentity: MixpanelIdentity,
    epochInterval: Double
  ) -> [String: Any] {
    var p: [String: Any] = [:]

    // Add timestamp (milliseconds)
    let epochMilliseconds = round(epochInterval * 1000)
    p["time"] = epochMilliseconds

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

    // Add super properties
    p += superProperties

    // Add user properties (override super properties if keys conflict)
    if let userProperties = userProperties {
      p += userProperties
    }

    return p
  }

  func track(
    event: String?,
    properties: Properties? = nil,
    timedEvents: InternalProperties,
    superProperties: InternalProperties,
    mixpanelIdentity: MixpanelIdentity,
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

    // Use shared property builder for consistency
    var p = buildEventProperties(
      userProperties: properties,
      superProperties: superProperties,
      mixpanelIdentity: mixpanelIdentity,
      epochInterval: epochInterval
    )

    // Add SDK-specific properties for persistence
    AutomaticProperties.automaticPropertiesLock.read {
      p += AutomaticProperties.properties
    }
    p["token"] = apiToken

    // Handle timed events
    let eventStartTime = timedEvents[ev] as? Double
    var shadowTimedEvents = timedEvents
    if let eventStartTime = eventStartTime {
      shadowTimedEvents.removeValue(forKey: ev)
      p["$duration"] = Double(String(format: "%.3f", epochInterval - eventStartTime))
    }

    // Notify event bridge listeners (non-blocking)
    if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
      MixpanelEventBridge.shared.notifyListeners(
        eventName: ev,
        properties: p
      )
    }

    // Note: First-time event checking is now done synchronously in MixpanelInstance.track()
    // before dispatching to trackingQueue. This ensures proper ordering when track() and
    // getVariantSync() are called sequentially. The check was removed from here to avoid
    // duplicate work and matches the Android SDK fix in PR #936.

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
