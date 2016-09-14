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
public class People {

    /// controls the $ignore_time property in any subsequent MixpanelPeople operation.
    /// If the $ignore_time property is present and true in your request,
    /// Mixpanel will not automatically update the "Last Seen" property of the profile.
    /// Otherwise, Mixpanel will add a "Last Seen" property associated with the
    /// current time for all $set, $append, and $add operations
    public var ignoreTime = false

    let apiToken: String
    let serialQueue: dispatch_queue_t
    var peopleQueue = Queue()
    var unidentifiedQueue = Queue()
    var distinctId: String? = nil

    init(apiToken: String, serialQueue: dispatch_queue_t) {
        self.apiToken = apiToken
        self.serialQueue = serialQueue
    }

    func addPeopleRecordToQueueWithAction(action: String, properties: Properties) {
        let epochMilliseconds = round(NSDate().timeIntervalSince1970 * 1000)
        let ignoreTimeCopy = ignoreTime

        dispatch_async(serialQueue) {
            var r = Properties()
            var p = Properties()
            r["$token"] = self.apiToken
            r["$time"] = epochMilliseconds
            if ignoreTimeCopy {
                r["$ignore_time"] = Int(ignoreTimeCopy)
            }
            if action == "$unset" {
                // $unset takes an array of property names which is supplied to this method
                // in the properties parameter under the key "$properties"
                r[action] = properties["$properties"]
            } else {
                if action == "$set" || action == "$set_once" {
                    p += AutomaticProperties.peopleProperties
                }
                p += properties
                r[action] = p
            }

            if let distinctId = self.distinctId {
                r["$distinct_id"] = distinctId
                self.addPeopleObject(r)
            } else {
                self.unidentifiedQueue.append(r)
                if self.unidentifiedQueue.count > QueueConstants.queueSize {
                    self.unidentifiedQueue.removeAtIndex(0)
                }
            }
            Persistence.archivePeople(self.peopleQueue, token: self.apiToken)
        }
    }

    func addPeopleObject(r: Properties) {
        peopleQueue.append(r)
        if peopleQueue.count > QueueConstants.queueSize {
            peopleQueue.removeAtIndex(0)
        }
    }

    func merge(properties properties: Properties) {
        addPeopleRecordToQueueWithAction("$merge", properties: properties)
    }

    private func deviceTokenDataToString(deviceToken: NSData) -> String {
        let tokenChars = UnsafePointer<CChar>((deviceToken as NSData).bytes)
        var tokenString = ""

        for i in 0..<deviceToken.length {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }

        return tokenString
    }

    // MARK: - People Public API

    /**
     Register the given device to receive push notifications.

     This will associate the device token with the current user in Mixpanel People,
     which will allow you to send push notifications to the user from the Mixpanel
     People web interface. You should call this method with the `Data`
     token passed to
     `application:didRegisterForRemoteNotificationsWithDeviceToken:`.

     - parameter deviceToken: device token as returned from
     `application:didRegisterForRemoteNotificationsWithDeviceToken:`
     */
    public func addPushDeviceToken(deviceToken: NSData) {
        let properties = ["$ios_devices": [deviceTokenDataToString(deviceToken)]]
        addPeopleRecordToQueueWithAction("$union", properties: properties)
    }

    /**
     Unregister a specific device token from the ability to receive push notifications.
     This will remove the provided push token saved to this people profile. This is useful
     in conjunction with a call to `reset`, or when a user is logging out.
     - parameter deviceToken: device token as returned from
     `application:didRegisterForRemoteNotificationsWithDeviceToken:`
     */
    public func removePushDeviceToken(deviceToken: NSData) {
        let properties = ["$ios_devices": deviceTokenDataToString(deviceToken)]
        addPeopleRecordToQueueWithAction("$remove", properties: properties)
    }

    /**
     Set properties on the current user in Mixpanel People.

     The properties will be set on the current user. The property keys must be String
     objects and the supported property value types are:
     String, Int, UInt, Double, Float, [AnyObject], [String: AnyObject], Date, URL, and NSNull.
     You can override the current project token and distinct Id by
     including the special properties: $token and $distinct_id. If the existing
     user record on the server already has a value for a given property, the old
     value is overwritten. Other existing properties will not be affected.

     - precondition: You must identify for the set information to be linked to that user

     - parameter properties: properties dictionary
     */
    public func set(properties properties: Properties) {
        Track.assertPropertyTypes(properties)
        addPeopleRecordToQueueWithAction("$set", properties: properties)
    }

    /**
     Convenience method for setting a single property in Mixpanel People.

     The property keys must be String objects and the supported property value types are:
     String, Int, UInt, Double, Float, [AnyObject], [String: AnyObject], Date, URL, and NSNull.

     - parameter property: property name
     - parameter to:       property value
     */
    public func set(property property: String, to: AnyObject) {
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
    public func setOnce(properties properties: Properties) {
        Track.assertPropertyTypes(properties)
        addPeopleRecordToQueueWithAction("$set_once", properties: properties)
    }

    /**
     Remove a list of properties and their values from the current user's profile
     in Mixpanel People.

     The properties array must ony contain String names of properties. For properties
     that don't exist there will be no effect.

     - parameter properties: properties array
     */
    public func unset(properties properties: [String]) {
        addPeopleRecordToQueueWithAction("$unset", properties: ["$properties":properties])
    }

    /**
     Increment the given numeric properties by the given values.

     Property keys must be String names of numeric properties. A property is
     numeric if its current value is a number. If a property does not exist, it
     will be set to the increment amount. Property values must be number objects.

     - parameter properties: properties array
     */
    public func increment(properties properties: Properties) {
        let filtered = properties.values.filter() {
            !($0 is Int || $0 is UInt || $0 is Double || $0 is Float) }
        if !filtered.isEmpty {
            MPAssert(false, message: "increment property values should be numbers")
            return
        }
        addPeopleRecordToQueueWithAction("$add", properties: properties)
    }

    /**
     Convenience method for incrementing a single numeric property by the specified
     amount.

     - parameter property: property name
     - parameter by:       amount to increment by
     */
    public func increment(property property: String, by: Double) {
        increment(properties: [property: by])
    }

    /**
     Append values to list properties.

     The property keys must be String objects and the supported property value types are:
     String, Int, UInt, Double, Float, [AnyObject], [String: AnyObject], Date, URL, and NSNull.

     - parameter properties: mapping of list property names to values to append
     */
    public func append(properties properties: Properties) {
        Track.assertPropertyTypes(properties)
        addPeopleRecordToQueueWithAction("$append", properties: properties)
    }

    /**
     Removes list properties.
     The property keys must be String objects and the supported property value types are:
     String, Int, UInt, Double, Float, [AnyObject], [String: AnyObject], Date, URL, and NSNull.
     - parameter properties: mapping of list property names to values to remove
     */
    public func remove(properties: Properties) {
        Track.assertPropertyTypes(properties)
        addPeopleRecordToQueueWithAction("$remove", properties: properties)
    }

    /**
     Union list properties.

     Property keys must be array objects.

     - parameter properties: mapping of list property names to lists to union
     */
    public func union(properties properties: Properties) {
        let filtered = properties.values.filter() {
            !($0 is [AnyObject]) }
        if !filtered.isEmpty {
            MPAssert(false, message: "union property values should be an array")
            return
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
    public func trackCharge(amount amount: Double, properties: Properties? = nil) {
        var transaction: Properties = ["$amount": amount, "$time": NSDate()]
        if let properties = properties {
            transaction += properties
        }
        append(properties: ["$transactions": transaction])
    }

    /**
     Delete current user's revenue history.
     */
    public func clearCharges() {
        set(properties: ["$transactions": []])
    }

    /**
     Delete current user's record from Mixpanel People.
     */
    public func deleteUser() {
        addPeopleRecordToQueueWithAction("$delete", properties: [:])
    }
}
