//
//  Mixpanel.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
#if !os(OSX)
import UIKit
#endif // os(OSX)

/// The primary class for integrating Mixpanel with your app.
open class Mixpanel {

    #if !os(OSX) && !os(watchOS)
    /**
     Initializes an instance of the API with the given project token.

     Returns a new Mixpanel instance API object. This allows you to create more than one instance
     of the API object, which is convenient if you'd like to send data to more than
     one Mixpanel project from a single app.

     - parameter token:                     your project token
     - parameter trackAutomaticEvents:      Whether or not to collect common mobile events
     - parameter flushInterval:             Optional. Interval to run background flushing
     - parameter instanceName:              Optional. The name you want to uniquely identify the Mixpanel Instance.
                                            It is useful when you want more than one Mixpanel instance under the same project token.
     - parameter optOutTrackingByDefault:   Optional. Whether or not to be opted out from tracking by default
     - parameter trackAutomaticEvents:      Optional. Whether or not to collect common mobile events, it takes precedence over Autotrack settings from the Mixpanel server.
     - parameter useUniqueDistinctId:       Optional. Whether or not to use the unique device identifier as the distinct_id
     - parameter superProperties:           Optional. Super properties dictionary to register during initialization
     - parameter serverURL:                 Optional. Mixpanel cluster URL
     
     - parameter isMain:                    Whether to make the new instance primary.

     - important: If you have more than one Mixpanel instance, it is beneficial to initialize
     the instances with an instanceName. Then they can be reached by calling getInstance with name.

     - returns: returns a mixpanel instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */
    @discardableResult
    open class func initialize(token apiToken: String,
                               trackAutomaticEvents: Bool,
                               flushInterval: Double = 60,
                               instanceName: String? = nil,
                               optOutTrackingByDefault: Bool = false,
                               useUniqueDistinctId: Bool = false,
                               superProperties: Properties? = nil,
                               serverURL: String? = nil,
                               isMain: Bool = true) -> MixpanelInstance {
        #if DEBUG
        didDebugInit(
            distinctId: apiToken,
            libName: superProperties?.get(key: "mp_lib", defaultValue: nil),
            libVersion: superProperties?.get(key: "$lib_version", defaultValue: nil)
        )
        #endif
        return MixpanelManager.sharedInstance.initialize(token: apiToken,
                                                         flushInterval: flushInterval,
                                                         instanceName: ((instanceName != nil) ? instanceName! : apiToken),
                                                         trackAutomaticEvents: trackAutomaticEvents,
                                                         optOutTrackingByDefault: optOutTrackingByDefault,
                                                         useUniqueDistinctId: useUniqueDistinctId,
                                                         superProperties: superProperties,
                                                         serverURL: serverURL,
                                                         isMain: isMain)
    }
    #else
    /**
     Initializes an instance of the API with the given project token (MAC OS ONLY).

     Returns a new Mixpanel instance API object. This allows you to create more than one instance
     of the API object, which is convenient if you'd like to send data to more than
     one Mixpanel project from a single app.

     - parameter token:                     your project token
     - parameter flushInterval:             Optional. Interval to run background flushing
     - parameter instanceName:              Optional. The name you want to uniquely identify the Mixpanel Instance.
                                            It is useful when you want more than one Mixpanel instance under the same project token.
     - parameter optOutTrackingByDefault:   Optional. Whether or not to be opted out from tracking by default
     - parameter useUniqueDistinctId:       Optional. Whether or not to use the unique device identifier as the distinct_id
     - parameter superProperties:           Optional. Super properties dictionary to register during initialization
     - parameter serverURL:                 Optional. Mixpanel cluster URL
     
     - parameter isMain:                    Whether to make the new instance primary.

     - important: If you have more than one Mixpanel instance, it is beneficial to initialize
     the instances with an instanceName. Then they can be reached by calling getInstance with name.

     - returns: returns a mixpanel instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */

    @discardableResult
    open class func initialize(token apiToken: String,
                               flushInterval: Double = 60,
                               instanceName: String? = nil,
                               optOutTrackingByDefault: Bool = false,
                               useUniqueDistinctId: Bool = false,
                               superProperties: Properties? = nil,
                               serverURL: String? = nil,
                               isMain: Bool = true) -> MixpanelInstance {
        #if DEBUG
        didDebugInit(
            distinctId: apiToken,
            libName: superProperties?.get(key: "mp_lib", defaultValue: nil),
            libVersion: superProperties?.get(key: "$lib_version", defaultValue: nil)
        )
        #endif
        return MixpanelManager.sharedInstance.initialize(token: apiToken,
                                                         flushInterval: flushInterval,
                                                         instanceName: ((instanceName != nil) ? instanceName! : apiToken),
                                                         trackAutomaticEvents: false,
                                                         optOutTrackingByDefault: optOutTrackingByDefault,
                                                         useUniqueDistinctId: useUniqueDistinctId,
                                                         superProperties: superProperties,
                                                         serverURL: serverURL,
                                                         isMain: isMain)
    }
    #endif // os(OSX)

    /**
     Gets the mixpanel instance with the given name

     - parameter name: the instance name

     - returns: returns the mixpanel instance
     */
    open class func getInstance(name: String) -> MixpanelInstance? {
        return MixpanelManager.sharedInstance.getInstance(name: name)
    }
    
    /**
     Gets all mixpanel instances

     - returns: returns the array of mixpanel instances
     */
    public class func getAllInstances() -> [MixpanelInstance]? {
        return MixpanelManager.sharedInstance.getAllInstances()
    }

    /**
     Returns the main instance that was initialized.

     If not specified explicitly, the main instance is always the last instance added

     - returns: returns the main Mixpanel instance
     */
    open class func mainInstance() -> MixpanelInstance {
        if let instance = MixpanelManager.sharedInstance.getMainInstance() {
            return instance
        } else {
            assert(false, "You have to call initialize(token:trackAutomaticEvents:) before calling the main instance, " +
                "or define a new main instance if removing the main one")
            #if !os(OSX) && !os(watchOS)
            return Mixpanel.initialize(token: "", trackAutomaticEvents: true)
            #else
            return Mixpanel.initialize(token: "")
            #endif
            
        }
    }

    /**
     Sets the main instance based on the instance name

     - parameter name: the instance name
     */
    open class func setMainInstance(name: String) {
        MixpanelManager.sharedInstance.setMainInstance(name: name)
    }

    /**
     Removes an unneeded Mixpanel instance based on its name

     - parameter name: the instance name
     */
    open class func removeInstance(name: String) {
        MixpanelManager.sharedInstance.removeInstance(name: name)
    }
    
    private class func didDebugInit(distinctId: String, libName: String?, libVersion: String?) {
        if distinctId.count == 32 {
            let debugInitCount = UserDefaults.standard.integer(forKey: InternalKeys.mpDebugInitCountKey) + 1
            var properties: Properties = ["Debug Launch Count": debugInitCount]
            if let libName = libName {
                properties["mp_lib"] = libName
            }
            if let libVersion = libVersion {
                properties["$lib_version"] = libVersion
            }
            Network.sendHttpEvent(eventName: "SDK Debug Launch", apiToken: "metrics-1", distinctId: distinctId, properties: properties) { (_) in }
            checkIfImplemented(distinctId: distinctId, properties: properties)
            UserDefaults.standard.set(debugInitCount, forKey: InternalKeys.mpDebugInitCountKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private class func checkIfImplemented(distinctId: String, properties: Properties) {
        let hasImplemented: Bool = UserDefaults.standard.bool(forKey: InternalKeys.mpDebugImplementedKey)
        if !hasImplemented {
            var completed = 0
            let hasTracked: Bool = UserDefaults.standard.bool(forKey: InternalKeys.mpDebugTrackedKey)
            completed += hasTracked ? 1 : 0
            let hasIdentified: Bool = UserDefaults.standard.bool(forKey: InternalKeys.mpDebugIdentifiedKey)
            completed += hasIdentified ? 1 : 0
            let hasAliased: Bool = UserDefaults.standard.bool(forKey: InternalKeys.mpDebugAliasedKey)
            completed += hasAliased ? 1 : 0
            let hasUsedPeople: Bool = UserDefaults.standard.bool(forKey: InternalKeys.mpDebugUsedPeopleKey)
            completed += hasUsedPeople ? 1 : 0
            if (completed >= 3) {
                let trackProps = properties.merging([
                    "Tracked": hasTracked,
                    "Identified": hasIdentified,
                    "Aliased": hasAliased,
                    "Used People": hasUsedPeople,
                ]) {(_,new) in new}
                Network.sendHttpEvent(
                    eventName: "SDK Implemented",
                    apiToken: "metrics-1",
                    distinctId: distinctId,
                    properties: trackProps) { (_) in }
                UserDefaults.standard.set(true, forKey: InternalKeys.mpDebugImplementedKey)
            }
        }
    }
}

class MixpanelManager {

    static let sharedInstance = MixpanelManager()
    private var instances: [String: MixpanelInstance]
    private var mainInstance: MixpanelInstance?
    private let readWriteLock: ReadWriteLock
    private let instanceQueue: DispatchQueue

    init() {
        instances = [String: MixpanelInstance]()
        Logger.addLogging(PrintLogging())
        readWriteLock = ReadWriteLock(label: "com.mixpanel.instance.manager.lock")
        instanceQueue = DispatchQueue(label: "com.mixpanel.instance.manager.instance", qos: .utility)
    }

    func initialize(token apiToken: String,
                    flushInterval: Double,
                    instanceName: String,
                    trackAutomaticEvents: Bool,
                    optOutTrackingByDefault: Bool = false,
                    useUniqueDistinctId: Bool = false,
                    superProperties: Properties? = nil,
                    serverURL: String? = nil,
                    isMain: Bool
    ) -> MixpanelInstance {
        instanceQueue.sync {
            var instance: MixpanelInstance?
            if let instance = instances[instanceName] {
                if isMain || mainInstance == nil {
                    mainInstance = instance
                }
                return
            }
            instance = MixpanelInstance(apiToken: apiToken,
                                        flushInterval: flushInterval,
                                        name: instanceName,
                                        optOutTrackingByDefault: optOutTrackingByDefault,
                                        trackAutomaticEvents: trackAutomaticEvents,
                                        useUniqueDistinctId: useUniqueDistinctId,
                                        superProperties: superProperties,
                                        serverURL: serverURL)
            readWriteLock.write {
                instances[instanceName] = instance!
                if isMain || mainInstance == nil {
                    mainInstance = instance!
                }
            }
        }
        return mainInstance!
    }

    func getInstance(name instanceName: String) -> MixpanelInstance? {
        var instance: MixpanelInstance?
        readWriteLock.read {
            instance = instances[instanceName]
        }
        if instance == nil {
            Logger.warn(message: "no such instance: \(instanceName)")
            return nil
        }
        return instance
    }

    func getMainInstance() -> MixpanelInstance? {
        return mainInstance
    }
    
    func getAllInstances() -> [MixpanelInstance]? {
        var allInstances: [MixpanelInstance]?
        readWriteLock.read {
            allInstances = Array(instances.values)
        }
        return allInstances
    }

    func setMainInstance(name instanceName: String) {
        var instance: MixpanelInstance?
        readWriteLock.read {
            instance = instances[instanceName]
        }
        if instance == nil {
            return
        }
        mainInstance = instance
    }

    func removeInstance(name instanceName: String) {
        readWriteLock.write {
            if instances[instanceName] === mainInstance {
                mainInstance = nil
            }
            instances[instanceName] = nil
        }
    }

}
