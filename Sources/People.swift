//
//  People.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// Access to the Mixpanel People API, available as an accessible variable from
/// the main Mixpanel instance.
open class People {

  /// controls the $ignore_time property in any subsequent MixpanelPeople operation.
  /// If the $ignore_time property is present and true in your request,
  /// Mixpanel will not automatically update the "Last Seen" property of the profile.
  /// Otherwise, Mixpanel will add a "Last Seen" property associated with the
  /// current time for all $set, $append, and $add operations
  open var ignoreTime = false

  let apiToken: String
  let serialQueue: DispatchQueue
  let lock: ReadWriteLock
  var distinctId: String?
  weak var delegate: FlushDelegate?
  let metadata: SessionMetadata
  let mixpanelPersistence: MixpanelPersistence
  weak var mixpanelInstance: MixpanelInstance?

  init(
    apiToken: String,
    serialQueue: DispatchQueue,
    lock: ReadWriteLock,
    metadata: SessionMetadata,
    mixpanelPersistence: MixpanelPersistence
  ) {
    self.apiToken = apiToken
    self.serialQueue = serialQueue
    self.lock = lock
    self.metadata = metadata
    self.mixpanelPersistence = mixpanelPersistence
  }

  func addPeopleRecordToQueueWithAction(_ action: String, properties: InternalProperties) {
    if mixpanelInstance?.hasOptedOutTracking() ?? false {
      return
    }
    let epochMilliseconds = round(Date().timeIntervalSince1970 * 1000)
    let ignoreTimeCopy = ignoreTime

    serialQueue.async { [weak self, action, properties] in
      guard let self = self else { return }

      var r = InternalProperties()
      var p = InternalProperties()
      r["$token"] = self.apiToken
      r["$time"] = epochMilliseconds
      if ignoreTimeCopy {
        r["$ignore_time"] = ignoreTimeCopy ? 1 : 0
      }
      if action == "$unset" {
        // $unset takes an array of property names which is supplied to this method
        // in the properties parameter under the key "$properties"
        r[action] = properties["$properties"]
      } else {
        if action == "$set" || action == "$set_once" {
          AutomaticProperties.automaticPropertiesLock.read {
            p += AutomaticProperties.peopleProperties
          }
        }
        p += properties
        r[action] = p
      }
      self.metadata.toDict(isEvent: false).forEach { (k, v) in r[k] = v }

      if let anonymousId = self.mixpanelInstance?.anonymousId {
        r["$device_id"] = anonymousId
      }

      if let userId = self.mixpanelInstance?.userId {
        r["$user_id"] = userId
      }

      if let hadPersistedDistinctId = self.mixpanelInstance?.hadPersistedDistinctId {
        r["$had_persisted_distinct_id"] = hadPersistedDistinctId
      }

      if let distinctId = self.distinctId {
        r["$distinct_id"] = distinctId
        // identified
        self.mixpanelPersistence.saveEntity(
          r, type: .people, flag: !PersistenceConstant.unIdentifiedFlag)
      } else {
        self.mixpanelPersistence.saveEntity(
          r, type: .people, flag: PersistenceConstant.unIdentifiedFlag)
      }
    }

    if MixpanelInstance.isiOSAppExtension() {
      delegate?.flush(performFullFlush: false, completion: nil)
    }
  }

  func merge(properties: InternalProperties) {
    addPeopleRecordToQueueWithAction("$merge", properties: properties)
  }

  // MARK: - People

  /**
     Set properties on the current user in Mixpanel People.

     The properties will be set on the current user.
     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
     You can override the current project token and distinct Id by
     including the special properties: $token and $distinct_id. If the existing
     user record on the server already has a value for a given property, the old
     value is overwritten. Other existing properties will not be affected.

     - precondition: You must identify for the set information to be linked to that user

     - parameter properties: properties dictionary
     */
  open func set(properties: Properties) {
    assertPropertyTypes(properties)
    addPeopleRecordToQueueWithAction("$set", properties: properties)
  }

  /**
     Convenience method for setting a single property in Mixpanel People.

     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.

     - parameter property: property name
     - parameter to:       property value
     */
  open func set(property: String, to: MixpanelType) {
    set(properties: [property: to])
  }

  /**
     Set properties on the current user in Mixpanel People, but doesn't overwrite if
     there is an existing value.

     This method is identical to `set:` except it will only set
     properties that are not already set. It is particularly useful for collecting
     data about the user's initial experience and source, as well as dates
     representing the first time something happened.

     - parameter properties: properties dictionary
     */
  open func setOnce(properties: Properties) {
    assertPropertyTypes(properties)
    addPeopleRecordToQueueWithAction("$set_once", properties: properties)
  }

  /**
     Remove a list of properties and their values from the current user's profile
     in Mixpanel People.

     The properties array must ony contain String names of properties. For properties
     that don't exist there will be no effect.

     - parameter properties: properties array
     */
  open func unset(properties: [String]) {
    addPeopleRecordToQueueWithAction("$unset", properties: ["$properties": properties])
  }

  /**
     Increment the given numeric properties by the given values.

     Property keys must be String names of numeric properties. A property is
     numeric if its current value is a number. If a property does not exist, it
     will be set to the increment amount. Property values must be number objects.

     - parameter properties: properties array
     */
  open func increment(properties: Properties) {
    let filtered = properties.values.filter {
      !($0 is Int || $0 is UInt || $0 is Double || $0 is Float)
    }
    if !filtered.isEmpty {
      MPAssert(false, "increment property values should be numbers")
    }
    addPeopleRecordToQueueWithAction("$add", properties: properties)
  }

  /**
     Convenience method for incrementing a single numeric property by the specified
     amount.

     - parameter property: property name
     - parameter by:       amount to increment by
     */
  open func increment(property: String, by: Double) {
    increment(properties: [property: by])
  }

  /**
     Append values to list properties.

     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.

     - parameter properties: mapping of list property names to values to append
     */
  open func append(properties: Properties) {
    assertPropertyTypes(properties)
    addPeopleRecordToQueueWithAction("$append", properties: properties)
  }

  /**
     Removes list properties.

     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.

     - parameter properties: mapping of list property names to values to remove
     */
  open func remove(properties: Properties) {
    assertPropertyTypes(properties)
    addPeopleRecordToQueueWithAction("$remove", properties: properties)
  }

  /**
     Union list properties.

     Property values must be array objects.

     - parameter properties: mapping of list property names to lists to union
     */
  open func union(properties: Properties) {
    let filtered = properties.values.filter {
      !($0 is [MixpanelType])
    }
    if !filtered.isEmpty {
      MPAssert(false, "union property values should be an array")
    }
    addPeopleRecordToQueueWithAction("$union", properties: properties)
  }

  /**
     Track money spent by the current user for revenue analytics and associate
     properties with the charge. Properties is optional.

     Charge properties allow you to segment on types of revenue. For instance, you
     could record a product ID with each charge so that you could segement on it in
     revenue analytics to see which products are generating the most revenue.

     - parameter amount:     amount of revenue received
     - parameter properties: Optional. properties dictionary
     */
  open func trackCharge(amount: Double, properties: Properties? = nil) {
    var transaction: InternalProperties = ["$amount": amount, "$time": Date()]
    if let properties = properties {
      transaction += properties
    }
    append(properties: ["$transactions": transaction])
  }

  /**
     Delete current user's revenue history.
     */
  open func clearCharges() {
    set(properties: ["$transactions": [] as [Any]])
  }

  /**
     Delete current user's record from Mixpanel People.
     */
  open func deleteUser() {
    addPeopleRecordToQueueWithAction("$delete", properties: [:])
  }
}
