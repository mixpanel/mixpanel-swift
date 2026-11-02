//
//  Groups.swift
//  Mixpanel
//
//  Created by Iris McLeary on 8/28/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import Foundation

/// Access to the Mixpanel Groups API, available through the getGroup function from
/// the main Mixpanel instance.
open class Group {

    let apiToken: String
    let serialQueue: DispatchQueue
    let lock: ReadWriteLock
    let groupKey: String
    let groupID: MixpanelType
    weak var delegate: FlushDelegate?
    let metadata: SessionMetadata
    let mixpanelPersistence: MixpanelPersistence
    weak var mixpanelInstance: MixpanelInstance?
    // Set on a group with nothing to update, from getCompany() when there is no company
    let unavailableReason: String?

    init(
        apiToken: String,
        serialQueue: DispatchQueue,
        lock: ReadWriteLock,
        groupKey: String,
        groupID: MixpanelType,
        metadata: SessionMetadata,
        mixpanelPersistence: MixpanelPersistence,
        mixpanelInstance: MixpanelInstance,
        unavailableReason: String? = nil
    ) {
        self.apiToken = apiToken
        self.serialQueue = serialQueue
        self.lock = lock
        self.groupKey = groupKey
        self.groupID = groupID
        self.metadata = metadata
        self.mixpanelPersistence = mixpanelPersistence
        self.mixpanelInstance = mixpanelInstance
        self.unavailableReason = unavailableReason
    }

    func addGroupRecordToQueueWithAction(_ action: String, properties: InternalProperties) {
        if let unavailableReason = unavailableReason {
            MixpanelLogger.error(message: "\(unavailableReason) The update was dropped.")
            return
        }
        if mixpanelInstance?.hasOptedOutTracking() ?? false {
            return
        }
        let epochMilliseconds = round(Date().timeIntervalSince1970 * 1000)

        serialQueue.async {
            // Hierarchical groups require $company_id at the top level of every /groups write
            var companyId: String?
            if let mixpanelInstance = self.mixpanelInstance, mixpanelInstance.hierarchicalGroups {
                companyId = mixpanelInstance.identity.companyId
                if companyId == nil {
                    MixpanelLogger.error(
                        message:
                            "Group profile updates for hierarchical groups projects require a company. Call "
                            + "identify(identity: MixpanelIdentity(userId:companyId:)) first. The update to "
                            + "\(self.groupKey)=\(self.groupID) was dropped.")
                    return
                }
            }
            var r = InternalProperties()
            var p = InternalProperties()
            r["$token"] = self.apiToken
            r["$time"] = epochMilliseconds
            if action == "$unset" {
                // $unset takes an array of property names which is supplied to this method
                // in the properties parameter under the key "$properties"
                r[action] = properties["$properties"]
            } else {
                p += properties
                r[action] = p
            }
            self.metadata.toDict(isEvent: false).forEach { (k, v) in r[k] = v }

            r["$group_key"] = self.groupKey
            r["$group_id"] = self.groupID
            if let companyId = companyId {
                r["$company_id"] = companyId
            }
            self.mixpanelPersistence.saveEntity(r, type: .groups)
        }

        if MixpanelInstance.isiOSAppExtension() {
            delegate?.flush(performFullFlush: false, completion: nil)
        }
    }

    // MARK: - Group

    /**
       Sets properties on this group.
    
       Property keys must be String objects and the supported value types need to conform to MixpanelType.
       MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
       If the existing group record on the server already has a value for a given property, the old
       value is overwritten. Other existing properties will not be affected.
    
       - parameter properties: properties dictionary
       */
    open func set(properties: Properties) {
        assertPropertyTypes(properties)
        addGroupRecordToQueueWithAction("$set", properties: properties)
    }

    /**
       Convenience method for setting a single property in Mixpanel Groups.
    
       Property keys must be String objects and the supported value types need to conform to MixpanelType.
       MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
    
       - parameter property: property name
       - parameter to:       property value
       */
    open func set(property: String, to: MixpanelType) {
        set(properties: [property: to])
    }

    /**
       Sets properties on the current Mixpanel Group, but doesn't overwrite if
       there is an existing value.
    
       This method is identical to `set:` except it will only set
       properties that are not already set. It is particularly useful for collecting
       data about dates representing the first time something happened.
    
       - parameter properties: properties dictionary
       */
    open func setOnce(properties: Properties) {
        assertPropertyTypes(properties)
        addGroupRecordToQueueWithAction("$set_once", properties: properties)
    }

    /**
       Remove a property and its value from a group's profile in Mixpanel Groups.
    
       For properties that don't exist there will be no effect.
    
       - parameter property: name of the property to unset
       */
    open func unset(property: String) {
        addGroupRecordToQueueWithAction("$unset", properties: ["$properties": [property]])
    }

    /**
       Removes list properties.
    
       Property keys must be String objects and the supported value types need to conform to MixpanelType.
       MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
    
       - parameter properties: mapping of list property names to values to remove
       */
    open func remove(key: String, value: MixpanelType) {
        let properties = [key: value]
        assertPropertyTypes(properties)
        addGroupRecordToQueueWithAction("$remove", properties: properties)
    }

    /**
       Union list properties.
    
       Property values must be array objects.
    
       - parameter properties: mapping of list property names to lists to union
       */
    open func union(key: String, values: [MixpanelType]) {
        let properties = [key: values]
        addGroupRecordToQueueWithAction("$union", properties: properties)
    }

    /**
       Delete group's record from Mixpanel Groups.
       */
    open func deleteGroup() {
        addGroupRecordToQueueWithAction("$delete", properties: [:])
        if unavailableReason == nil {
            mixpanelInstance?.removeCachedGroup(groupKey: groupKey, groupID: groupID)
        }
    }
}
