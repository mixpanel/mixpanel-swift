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
#endif  // os(OSX)

/// The primary class for integrating Mixpanel with your app.
open class Mixpanel {

  @discardableResult
  open class func initialize(options: MixpanelOptions) -> MixpanelInstance {
    return MixpanelManager.sharedInstance.initialize(options: options)
  }

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
     - parameter useUniqueDistinctId:       Optional. whether or not to use the unique device identifier as the distinct_id
     - parameter superProperties:           Optional. Super properties dictionary to register during initialization
     - parameter serverURL:                 Optional. Mixpanel cluster URL
     - parameter useGzipCompression:        Optional. Whether to use gzip compression for network requests.

     - important: If you have more than one Mixpanel instance, it is beneficial to initialize
     the instances with an instanceName. Then they can be reached by calling getInstance with name.

     - returns: returns a mixpanel instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */
    @discardableResult
    open class func initialize(
      token apiToken: String,
      trackAutomaticEvents: Bool,
      flushInterval: Double = 60,
      instanceName: String? = nil,
      optOutTrackingByDefault: Bool = false,
      useUniqueDistinctId: Bool = false,
      superProperties: Properties? = nil,
      serverURL: String? = nil,
      useGzipCompression: Bool = false
    ) -> MixpanelInstance {
      return MixpanelManager.sharedInstance.initialize(
        token: apiToken,
        flushInterval: flushInterval,
        instanceName: ((instanceName != nil) ? instanceName! : apiToken),
        trackAutomaticEvents: trackAutomaticEvents,
        optOutTrackingByDefault: optOutTrackingByDefault,
        useUniqueDistinctId: useUniqueDistinctId,
        superProperties: superProperties,
        serverURL: serverURL,
        useGzipCompression: useGzipCompression)
    }

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
     - parameter useUniqueDistinctId:       Optional. whether or not to use the unique device identifier as the distinct_id
     - parameter superProperties:           Optional. Super properties dictionary to register during initialization
     - parameter proxyServerConfig:         Optional. Setup for proxy server.
     - parameter useGzipCompression:        Optional. Whether to use gzip compression for network requests.

     - important: If you have more than one Mixpanel instance, it is beneficial to initialize
     the instances with an instanceName. Then they can be reached by calling getInstance with name.

     - returns: returns a mixpanel instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */

    @discardableResult
    open class func initialize(
      token apiToken: String,
      trackAutomaticEvents: Bool,
      flushInterval: Double = 60,
      instanceName: String? = nil,
      optOutTrackingByDefault: Bool = false,
      useUniqueDistinctId: Bool = false,
      superProperties: Properties? = nil,
      proxyServerConfig: ProxyServerConfig,
      useGzipCompression: Bool = false
    ) -> MixpanelInstance {
      return MixpanelManager.sharedInstance.initialize(
        token: apiToken,
        flushInterval: flushInterval,
        instanceName: ((instanceName != nil) ? instanceName! : apiToken),
        trackAutomaticEvents: trackAutomaticEvents,
        optOutTrackingByDefault: optOutTrackingByDefault,
        useUniqueDistinctId: useUniqueDistinctId,
        superProperties: superProperties,
        proxyServerConfig: proxyServerConfig,
        useGzipCompression: useGzipCompression)
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
     - parameter useUniqueDistinctId:       Optional. whether or not to use the unique device identifier as the distinct_id
     - parameter superProperties:           Optional. Super properties dictionary to register during initialization
     - parameter serverURL:                 Optional. Mixpanel cluster URL
     - parameter useGzipCompression:        Optional. Whether to use gzip compression for network requests.

     - important: If you have more than one Mixpanel instance, it is beneficial to initialize
     the instances with an instanceName. Then they can be reached by calling getInstance with name.

     - returns: returns a mixpanel instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */

    @discardableResult
    open class func initialize(
      token apiToken: String,
      flushInterval: Double = 60,
      instanceName: String? = nil,
      optOutTrackingByDefault: Bool = false,
      useUniqueDistinctId: Bool = false,
      superProperties: Properties? = nil,
      serverURL: String? = nil,
      useGzipCompression: Bool = false
    ) -> MixpanelInstance {
      return MixpanelManager.sharedInstance.initialize(
        token: apiToken,
        flushInterval: flushInterval,
        instanceName: ((instanceName != nil) ? instanceName! : apiToken),
        trackAutomaticEvents: false,
        optOutTrackingByDefault: optOutTrackingByDefault,
        useUniqueDistinctId: useUniqueDistinctId,
        superProperties: superProperties,
        serverURL: serverURL,
        useGzipCompression: useGzipCompression)
    }

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
     - parameter useUniqueDistinctId:       Optional. whether or not to use the unique device identifier as the distinct_id
     - parameter superProperties:           Optional. Super properties dictionary to register during initialization
     - parameter proxyServerConfig:         Optional. Setup for proxy server.
     - parameter useGzipCompression:        Optional. Whether to use gzip compression for network requests.

     - important: If you have more than one Mixpanel instance, it is beneficial to initialize
     the instances with an instanceName. Then they can be reached by calling getInstance with name.

     - returns: returns a mixpanel instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */

    @discardableResult
    open class func initialize(
      token apiToken: String,
      flushInterval: Double = 60,
      instanceName: String? = nil,
      optOutTrackingByDefault: Bool = false,
      useUniqueDistinctId: Bool = false,
      superProperties: Properties? = nil,
      proxyServerConfig: ProxyServerConfig,
      useGzipCompression: Bool = false
    ) -> MixpanelInstance {
      return MixpanelManager.sharedInstance.initialize(
        token: apiToken,
        flushInterval: flushInterval,
        instanceName: ((instanceName != nil) ? instanceName! : apiToken),
        trackAutomaticEvents: false,
        optOutTrackingByDefault: optOutTrackingByDefault,
        useUniqueDistinctId: useUniqueDistinctId,
        superProperties: superProperties,
        proxyServerConfig: proxyServerConfig,
        useGzipCompression: useGzipCompression)
    }
  #endif  // os(OSX)

  /**
     Gets the mixpanel instance with the given name

     - parameter name: the instance name

     - returns: returns the mixpanel instance
     */
  open class func getInstance(name: String) -> MixpanelInstance? {
    return MixpanelManager.sharedInstance.getInstance(name: name)
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
      #if !targetEnvironment(simulator)
        assert(
          false,
          "You have to call initialize(token:trackAutomaticEvents:) before calling the main instance, "
            + "or define a new main instance if removing the main one")
      #endif

      #if !os(OSX) && !os(watchOS)
        return Mixpanel.initialize(token: "", trackAutomaticEvents: true)
      #else
        return Mixpanel.initialize(token: "")
      #endif

    }
  }

  /// Returns the main Mixpanel instance if it has been initialized.
  /// - Returns: An optional MixpanelInstance, or nil if not yet initialized.
  public class func safeMainInstance() -> MixpanelInstance? {
    if let instance = MixpanelManager.sharedInstance.getMainInstance() {
      return instance
    } else {
      MixpanelLogger.warn(
        message:
          "WARNING: Mixpanel main instance is NOT initialized. Call Mixpanel.initialize(...) first."
      )
      return nil
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
}

final class MixpanelManager {

  static let sharedInstance = MixpanelManager()
  private var instances: [String: MixpanelInstance]
  private var mainInstance: MixpanelInstance?
  private let readWriteLock: ReadWriteLock
  private let instanceQueue: DispatchQueue

  init() {
    instances = [String: MixpanelInstance]()
    MixpanelLogger.addLogging(PrintLogging())
    readWriteLock = ReadWriteLock(label: "com.mixpanel.instance.manager.lock")
    instanceQueue = DispatchQueue(
      label: "com.mixpanel.instance.manager.instance", qos: .utility,
      autoreleaseFrequency: .workItem)
  }

  func initialize(options: MixpanelOptions) -> MixpanelInstance {
    let instanceName = options.instanceName ?? options.token
    return dequeueInstance(instanceName: instanceName) {
      return MixpanelInstance(options: options)
    }
  }

  func initialize(
    token apiToken: String,
    flushInterval: Double,
    instanceName: String,
    trackAutomaticEvents: Bool,
    optOutTrackingByDefault: Bool = false,
    useUniqueDistinctId: Bool = false,
    superProperties: Properties? = nil,
    serverURL: String? = nil,
    useGzipCompression: Bool = false
  ) -> MixpanelInstance {
    return dequeueInstance(instanceName: instanceName) {
      return MixpanelInstance(
        apiToken: apiToken,
        flushInterval: flushInterval,
        name: instanceName,
        trackAutomaticEvents: trackAutomaticEvents,
        optOutTrackingByDefault: optOutTrackingByDefault,
        useUniqueDistinctId: useUniqueDistinctId,
        superProperties: superProperties,
        serverURL: serverURL,
        useGzipCompression: useGzipCompression)
    }
  }

  func initialize(
    token apiToken: String,
    flushInterval: Double,
    instanceName: String,
    trackAutomaticEvents: Bool,
    optOutTrackingByDefault: Bool = false,
    useUniqueDistinctId: Bool = false,
    superProperties: Properties? = nil,
    proxyServerConfig: ProxyServerConfig,
    useGzipCompression: Bool = false
  ) -> MixpanelInstance {
    return dequeueInstance(instanceName: instanceName) {
      return MixpanelInstance(
        apiToken: apiToken,
        flushInterval: flushInterval,
        name: instanceName,
        trackAutomaticEvents: trackAutomaticEvents,
        optOutTrackingByDefault: optOutTrackingByDefault,
        useUniqueDistinctId: useUniqueDistinctId,
        superProperties: superProperties,
        proxyServerConfig: proxyServerConfig,
        useGzipCompression: useGzipCompression)
    }
  }

  private func dequeueInstance(instanceName: String, instanceCreation: () -> MixpanelInstance)
    -> MixpanelInstance
  {
    instanceQueue.sync {
      var instance: MixpanelInstance?
      if let instance = instances[instanceName] {
        mainInstance = instance
        return
      }

      instance = instanceCreation()
      readWriteLock.write {
        instances[instanceName] = instance!
        mainInstance = instance!
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
      MixpanelLogger.warn(message: "no such instance: \(instanceName)")
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
