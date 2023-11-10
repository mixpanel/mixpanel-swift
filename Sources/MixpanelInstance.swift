//
//  MixpanelInstance.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
#if !os(OSX)
import UIKit
#else
import Cocoa
#endif // os(OSX)
#if os(iOS)
import SystemConfiguration
#endif

#if os(iOS)
import CoreTelephony
#endif // os(iOS)

private let devicePrefix = "$device:"
/**
 *  Delegate protocol for controlling the Mixpanel API's network behavior.
 */
public protocol MixpanelDelegate: AnyObject {
    /**
     Asks the delegate if data should be uploaded to the server.
     
     - parameter mixpanel: The mixpanel instance
     
     - returns: return true to upload now or false to defer until later
     */
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool
}

public typealias Properties = [String: MixpanelType]
typealias InternalProperties = [String: Any]
typealias Queue = [InternalProperties]

protocol AppLifecycle {
    func applicationDidBecomeActive()
    func applicationWillResignActive()
}

/// The class that represents the Mixpanel Instance
open class MixpanelInstance: CustomDebugStringConvertible, FlushDelegate, AEDelegate {
    
    /// apiToken string that identifies the project to track data to
    open var apiToken = ""
    
    /// The a MixpanelDelegate object that gives control over Mixpanel network activity.
    open weak var delegate: MixpanelDelegate?
    
    /// distinctId string that uniquely identifies the current user.
    open var distinctId = ""
    
    /// anonymousId string that uniquely identifies the device.
    open var anonymousId: String?
    
    /// userId string that identify is called with.
    open var userId: String?
    
    /// hadPersistedDistinctId is a boolean value which specifies that the stored distinct_id
    /// already exists in persistence
    open var hadPersistedDistinctId: Bool?
    
    /// alias string that uniquely identifies the current user.
    open var alias: String?
    
    /// Accessor to the Mixpanel People API object.
    open var people: People!
    
    let mixpanelPersistence: MixpanelPersistence
    
    /// Accessor to the Mixpanel People API object.
    var groups: [String: Group] = [:]
    
    /// Controls whether to show spinning network activity indicator when flushing
    /// data to the Mixpanel servers. Defaults to true.
    open var showNetworkActivityIndicator = true
    
    /// This allows enabling or disabling collecting common mobile events,
    open var trackAutomaticEventsEnabled: Bool
    
    /// Flush timer's interval.
    /// Setting a flush interval of 0 will turn off the flush timer and you need to call the flush() API manually
    /// to upload queued data to the Mixpanel server.
    open var flushInterval: Double {
        get {
            return flushInstance.flushInterval
        }
        set {
            flushInstance.flushInterval = newValue
        }
    }
    
    /// Control whether the library should flush data to Mixpanel when the app
    /// enters the background. Defaults to true.
    open var flushOnBackground: Bool {
        get {
            return flushInstance.flushOnBackground
        }
        set {
            flushInstance.flushOnBackground = newValue
        }
    }
    
    /// Controls whether to automatically send the client IP Address as part of
    /// event tracking. With an IP address, the Mixpanel Dashboard will show you the users' city.
    /// Defaults to true.
    open var useIPAddressForGeoLocation: Bool {
        get {
            return flushInstance.useIPAddressForGeoLocation
        }
        set {
            flushInstance.useIPAddressForGeoLocation = newValue
        }
    }
    
    /// The `flushBatchSize` property determines the number of events sent in a single network request to the Mixpanel server.
    /// By configuring this value, you can optimize network usage and manage the frequency of communication between the client
    /// and the server. The maximum size is 50; any value over 50 will default to 50.
    open var flushBatchSize: Int {
        get {
            return flushInstance.flushBatchSize
        }
        set {
            flushInstance.flushBatchSize = min(newValue, APIConstants.maxBatchSize)
        }
    }
    
    
    /// The base URL used for Mixpanel API requests.
    /// Useful if you need to proxy Mixpanel requests. Defaults to
    /// https://api.mixpanel.com.
    open var serverURL = BasePath.DefaultMixpanelAPI {
        didSet {
            BasePath.namedBasePaths[name] = serverURL
        }
    }
    
    open var debugDescription: String {
        return "Mixpanel(\n"
        + "    Token: \(apiToken),\n"
        + "    Distinct Id: \(distinctId)\n"
        + ")"
    }
    
    /// This allows enabling or disabling of all Mixpanel logs at run time.
    /// - Note: All logging is disabled by default. Usually, this is only required
    ///         if you are running in to issues with the SDK and you need support.
    open var loggingEnabled: Bool = false {
        didSet {
            if loggingEnabled {
                Logger.enableLevel(.debug)
                Logger.enableLevel(.info)
                Logger.enableLevel(.warning)
                Logger.enableLevel(.error)
                Logger.info(message: "Logging Enabled")
            } else {
                Logger.info(message: "Logging Disabled")
                Logger.disableLevel(.debug)
                Logger.disableLevel(.info)
                Logger.disableLevel(.warning)
                Logger.disableLevel(.error)
            }
#if DEBUG
            var trackProps: Properties = ["Logging Enabled": loggingEnabled]
            if (superProperties["mp_lib"] != nil) {
                trackProps["mp_lib"] = self.superProperties["mp_lib"] as! String
            }
            if (superProperties["$lib_version"] != nil) {
                trackProps["$lib_version"] = self.superProperties["$lib_version"] as! String
            }
            Network.sendHttpEvent(serverURL: self.serverURL, eventName: "Toggle SDK Logging", apiToken: "metrics-1", distinctId: apiToken, properties: trackProps)
#endif
        }
    }
    
    /// A unique identifier for this MixpanelInstance
    public let name: String
    
    /// The minimum session duration (ms) that is tracked in automatic events.
    /// The default value is 10000 (10 seconds).
#if os(iOS) || os(tvOS)
    open var minimumSessionDuration: UInt64 {
        get {
            return automaticEvents.minimumSessionDuration
        }
        set {
            automaticEvents.minimumSessionDuration = newValue
        }
    }
    
    /// The maximum session duration (ms) that is tracked in automatic events.
    /// The default value is UINT64_MAX (no maximum session duration).
    open var maximumSessionDuration: UInt64 {
        get {
            return automaticEvents.maximumSessionDuration
        }
        set {
            automaticEvents.maximumSessionDuration = newValue
        }
    }
#endif
    var superProperties = InternalProperties()
    var trackingQueue: DispatchQueue
    var networkQueue: DispatchQueue
    var optOutStatus: Bool?
    var useUniqueDistinctId: Bool
    var timedEvents = InternalProperties()
    
    let readWriteLock: ReadWriteLock
#if os(iOS) && !targetEnvironment(macCatalyst)
    static let reachability = SCNetworkReachabilityCreateWithName(nil, "api.mixpanel.com")
    static let telephonyInfo = CTTelephonyNetworkInfo()
#endif
#if !os(OSX) && !os(watchOS)
    var taskId = UIBackgroundTaskIdentifier.invalid
#endif // os(OSX)
    let sessionMetadata: SessionMetadata
    let flushInstance: Flush
    let trackInstance: Track
#if os(iOS) || os(tvOS)
    let automaticEvents = AutomaticEvents()
#endif
    init(apiToken: String?, flushInterval: Double, name: String, trackAutomaticEvents: Bool, optOutTrackingByDefault: Bool = false,
         useUniqueDistinctId: Bool = false, superProperties: Properties? = nil,
         serverURL: String? = nil) {
        if let apiToken = apiToken, !apiToken.isEmpty {
            self.apiToken = apiToken
        }
        trackAutomaticEventsEnabled = trackAutomaticEvents
        if let serverURL = serverURL {
            self.serverURL = serverURL
            BasePath.namedBasePaths[name] = serverURL
        }
#if DEBUG
        MixpanelInstance.didDebugInit(
            serverURL: self.serverURL,
            distinctId: self.apiToken,
            libName: superProperties?.get(key: "mp_lib", defaultValue: nil),
            libVersion: superProperties?.get(key: "$lib_version", defaultValue: nil)
        )
#endif
        let label = "com.mixpanel.\(self.apiToken)"
        trackingQueue = DispatchQueue(label: "\(label).tracking)", qos: .utility, autoreleaseFrequency: .workItem)
        networkQueue = DispatchQueue(label: "\(label).network)", qos: .utility, autoreleaseFrequency: .workItem)
        self.name = name
        
        mixpanelPersistence = MixpanelPersistence.init(instanceName: name)
        mixpanelPersistence.migrate()
        self.useUniqueDistinctId = useUniqueDistinctId
        
        readWriteLock = ReadWriteLock(label: "com.mixpanel.globallock")
        flushInstance = Flush(basePathIdentifier: name)
        sessionMetadata = SessionMetadata(trackingQueue: trackingQueue)
        trackInstance = Track(apiToken: self.apiToken,
                              instanceName: self.name,
                              lock: self.readWriteLock,
                              metadata: sessionMetadata, mixpanelPersistence: mixpanelPersistence)
        trackInstance.mixpanelInstance = self
#if os(iOS) && !targetEnvironment(macCatalyst)
        if let reachability = MixpanelInstance.reachability {
            var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
            func reachabilityCallback(reachability: SCNetworkReachability,
                                      flags: SCNetworkReachabilityFlags,
                                      unsafePointer: UnsafeMutableRawPointer?) {
                let wifi = flags.contains(SCNetworkReachabilityFlags.reachable) && !flags.contains(SCNetworkReachabilityFlags.isWWAN)
                AutomaticProperties.automaticPropertiesLock.write {
                    AutomaticProperties.properties["$wifi"] = wifi
                }
                Logger.info(message: "reachability changed, wifi=\(wifi)")
            }
            if SCNetworkReachabilitySetCallback(reachability, reachabilityCallback, &context) {
                if !SCNetworkReachabilitySetDispatchQueue(reachability, trackingQueue) {
                    // cleanup callback if setting dispatch queue failed
                    SCNetworkReachabilitySetCallback(reachability, nil, nil)
                }
            }
        }
#endif
        flushInstance.delegate = self
        distinctId = devicePrefix + defaultDeviceId()
        people = People(apiToken: self.apiToken,
                        serialQueue: trackingQueue,
                        lock: self.readWriteLock,
                        metadata: sessionMetadata, mixpanelPersistence: mixpanelPersistence)
        people.mixpanelInstance = self
        people.delegate = self
        flushInstance.flushInterval = flushInterval
#if !os(watchOS)
        setupListeners()
#endif
        unarchive()
        
        // check whether we should opt out by default
        // note: we don't override opt out persistence here since opt-out default state is often
        // used as an initial state while GDPR information is being collected
        if optOutTrackingByDefault && (hasOptedOutTracking() || optOutStatus == nil) {
            optOutTracking()
        }
        
        if let superProperties = superProperties {
            registerSuperProperties(superProperties)
        }
        
#if os(iOS) || os(tvOS)
        if !MixpanelInstance.isiOSAppExtension() && trackAutomaticEvents {
            automaticEvents.delegate = self
            automaticEvents.initializeEvents(instanceName: self.name)
        }
#endif
    }
    
#if !os(OSX) && !os(watchOS)
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
        trackIntegration()
#if os(iOS) && !targetEnvironment(macCatalyst)
        setCurrentRadio()
        // Temporarily remove the ability to monitor the radio change due to a crash issue might relate to the api from Apple
        // https://openradar.appspot.com/46873673
        //    notificationCenter.addObserver(self,
        //                                   selector: #selector(setCurrentRadio),
        //                                   name: .CTRadioAccessTechnologyDidChange,
        //                                   object: nil)
#endif // os(iOS)
        if !MixpanelInstance.isiOSAppExtension() {
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillResignActive(_:)),
                                           name: UIApplication.willResignActiveNotification,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationDidBecomeActive(_:)),
                                           name: UIApplication.didBecomeActiveNotification,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationDidEnterBackground(_:)),
                                           name: UIApplication.didEnterBackgroundNotification,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillEnterForeground(_:)),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
        }
    }
#elseif os(OSX)
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive(_:)),
                                       name: NSApplication.willResignActiveNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidBecomeActive(_:)),
                                       name: NSApplication.didBecomeActiveNotification,
                                       object: nil)
    }
#endif // os(OSX)
    
    deinit {
        NotificationCenter.default.removeObserver(self)
#if os(iOS) && !os(watchOS) && !targetEnvironment(macCatalyst)
        if let reachability = MixpanelInstance.reachability {
            if !SCNetworkReachabilitySetCallback(reachability, nil, nil) {
                Logger.error(message: "\(self) error unsetting reachability callback")
            }
            if !SCNetworkReachabilitySetDispatchQueue(reachability, nil) {
                Logger.error(message: "\(self) error unsetting reachability dispatch queue")
            }
        }
#endif
    }
    
    static func isiOSAppExtension() -> Bool {
        return Bundle.main.bundlePath.hasSuffix(".appex")
    }
    
#if !os(OSX) && !os(watchOS)
    static func sharedUIApplication() -> UIApplication? {
        guard let sharedApplication =
                UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication else {
            return nil
        }
        return sharedApplication
    }
#endif // !os(OSX)
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        flushInstance.applicationDidBecomeActive()
    }
    
    @objc private func applicationWillResignActive(_ notification: Notification) {
        flushInstance.applicationWillResignActive()
#if os(OSX)
        if flushOnBackground {
            flush()
        }
        
#endif
    }
    
#if !os(OSX) && !os(watchOS)
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return
        }
        
        if hasOptedOutTracking() {
            return
        }
        
        let completionHandler: () -> Void = { [weak self] in
            guard let self = self else { return }
            
            if self.taskId != UIBackgroundTaskIdentifier.invalid {
                sharedApplication.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskIdentifier.invalid
            }
        }
        
        taskId = sharedApplication.beginBackgroundTask(expirationHandler: completionHandler)
        
        if flushOnBackground {
            flush(performFullFlush: true, completion: completionHandler)
        }
    }
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return
        }
        sessionMetadata.applicationWillEnterForeground()
        
        if taskId != UIBackgroundTaskIdentifier.invalid {
            sharedApplication.endBackgroundTask(taskId)
            taskId = UIBackgroundTaskIdentifier.invalid
#if os(iOS)
            self.updateNetworkActivityIndicator(false)
#endif // os(iOS)
        }
        
    }
#endif
    
    func addPrefixToDeviceId(deviceId: String?) -> String {
        if let temp = deviceId {
            return devicePrefix + temp
        }
        return ""
    }
    
    func defaultDeviceId() -> String {
        let distinctId: String?
        if useUniqueDistinctId {
            distinctId = uniqueIdentifierForDevice()
        } else {
#if MIXPANEL_UNIQUE_DISTINCT_ID
            distinctId = uniqueIdentifierForDevice()
#else
            distinctId = nil
#endif
        }
        return distinctId ?? UUID().uuidString // use a random UUID by default
    }
    
    func uniqueIdentifierForDevice() -> String? {
        var distinctId: String?
#if os(OSX)
        distinctId = MixpanelInstance.macOSIdentifier()
#elseif !os(watchOS)
        if NSClassFromString("UIDevice") != nil {
            distinctId = UIDevice.current.identifierForVendor?.uuidString
        } else {
            distinctId = nil
        }
#else
        distinctId = nil
#endif
        return distinctId
    }
    
#if os(OSX)
    static func macOSIdentifier() -> String? {
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        let serialNumberAsCFString =
        IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return (serialNumberAsCFString?.takeUnretainedValue() as? String)
    }
#endif // os(OSX)
    
#if os(iOS)
    func updateNetworkActivityIndicator(_ on: Bool) {
        if showNetworkActivityIndicator {
            DispatchQueue.main.async { [on] in
                MixpanelInstance.sharedUIApplication()?.isNetworkActivityIndicatorVisible = on
            }
        }
    }
#if os(iOS) && !targetEnvironment(macCatalyst)
    @objc func setCurrentRadio() {
        var radio = ""
        let prefix = "CTRadioAccessTechnology"
        if #available(iOS 12.0, *) {
            if let radioDict = MixpanelInstance.telephonyInfo.serviceCurrentRadioAccessTechnology {
                for (_, value) in radioDict where !value.isEmpty && value.hasPrefix(prefix) {
                    // the first should be the prefix, second the target
                    let components = value.components(separatedBy: prefix)
                    
                    // Something went wrong and we have more than prefix:target
                    guard components.count == 2 else {
                        continue
                    }
                    
                    // Safe to directly access by index since we confirmed count == 2 above
                    let radioValue = components[1]
                    
                    // Send to parent
                    radio += radio.isEmpty ? radioValue : ", \(radioValue)"
                }
                
                radio = radio.isEmpty ? "None": radio
            }
        } else {
            radio = MixpanelInstance.telephonyInfo.currentRadioAccessTechnology ?? "None"
            if radio.hasPrefix(prefix) {
                radio = (radio as NSString).substring(from: prefix.count)
            }
        }
        
        trackingQueue.async {
            AutomaticProperties.automaticPropertiesLock.write { [weak self, radio] in
                AutomaticProperties.properties["$radio"] = radio
                
                guard self != nil else {
                    return
                }
                
                AutomaticProperties.properties["$carrier"] = ""
                if #available(iOS 12.0, *) {
                    if let carrierName = MixpanelInstance.telephonyInfo.serviceSubscriberCellularProviders?.first?.value.carrierName {
                        AutomaticProperties.properties["$carrier"] = carrierName
                    }
                } else {
                    if let carrierName = MixpanelInstance.telephonyInfo.subscriberCellularProvider?.carrierName {
                        AutomaticProperties.properties["$carrier"] = carrierName
                    }
                }
            }
        }
    }
#endif
#endif // os(iOS)
    private class func didDebugInit(serverURL: String, distinctId: String, libName: String?, libVersion: String?) {
        if distinctId.count == 32 {
            let debugInitCount = UserDefaults.standard.integer(forKey: InternalKeys.mpDebugInitCountKey) + 1
            var properties: Properties = ["Debug Launch Count": debugInitCount]
            if let libName = libName {
                properties["mp_lib"] = libName
            }
            if let libVersion = libVersion {
                properties["$lib_version"] = libVersion
            }
            Network.sendHttpEvent(serverURL: serverURL, eventName: "SDK Debug Launch", apiToken: "metrics-1", distinctId: distinctId, properties: properties) { (_) in }
            checkIfImplemented(serverURL: serverURL, distinctId: distinctId, properties: properties)
            UserDefaults.standard.set(debugInitCount, forKey: InternalKeys.mpDebugInitCountKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private class func checkIfImplemented(serverURL: String, distinctId: String, properties: Properties) {
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
                    serverURL: serverURL,
                    eventName: "SDK Implemented",
                    apiToken: "metrics-1",
                    distinctId: distinctId,
                    properties: trackProps) { (_) in }
                UserDefaults.standard.set(true, forKey: InternalKeys.mpDebugImplementedKey)
            }
        }
    }
    
}

extension MixpanelInstance {
    // MARK: - Identity
    
    /**
     Sets the distinct ID of the current user.
     
     Mixpanel uses a randomly generated persistent UUID  as the default local distinct ID.
     
     If you want to  use a unique persistent UUID, you can define the
     <code>MIXPANEL_UNIQUE_DISTINCT_ID</code> flag in your <code>Active Compilation Conditions</code>
     build settings. It then uses the IFV String (`UIDevice.current().identifierForVendor`) as
     the default local distinct ID. This ID will identify a user across all apps by the same vendor, but cannot be
     used to link the same user across apps from different vendors. If we are unable to get an IFV, we will fall
     back to generating a random persistent UUID.
     
     For tracking events, you do not need to call `identify:`. However,
     **Mixpanel User profiles always requires an explicit call to `identify:`.**
     If calls are made to
     `set:`, `increment` or other `People`
     methods prior to calling `identify:`, then they are queued up and
     flushed once `identify:` is called.
     
     If you'd like to use the default distinct ID for Mixpanel People as well
     (recommended), call `identify:` using the current distinct ID:
     `mixpanelInstance.identify(mixpanelInstance.distinctId)`.
     
     - parameter distinctId: string that uniquely identifies the current user
     - parameter usePeople: boolean that controls whether or not to set the people distinctId to the event distinctId.
     This should only be set to false if you wish to prevent people profile updates for that user.
     - parameter completion: an optional completion handler for when the identify has completed.
     */
    public func identify(distinctId: String, usePeople: Bool = true, completion: (() -> Void)? = nil) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
#if DEBUG
        UserDefaults.standard.set(true, forKey: InternalKeys.mpDebugIdentifiedKey)
#endif
        trackingQueue.async { [weak self, distinctId, usePeople] in
            guard let self = self else { return }
            
            // If there's no anonymousId assigned yet, that means distinctId is stored in the storage. Assigning already stored
            // distinctId as anonymousId on identify and also setting a flag to notify that it might be previously logged in user
            if self.anonymousId == nil {
                self.anonymousId = self.distinctId
                self.hadPersistedDistinctId = true
            }
            
            if self.userId == nil {
                self.readWriteLock.write {
                    self.userId = distinctId
                }
            }
            
            if distinctId != self.distinctId {
                let oldDistinctId = self.distinctId
                self.readWriteLock.write {
                    self.alias = nil
                    self.distinctId = distinctId
                    self.userId = distinctId
                }
                self.track(event: "$identify", properties: ["$anon_distinct_id": oldDistinctId])
            }
            
            if usePeople {
                self.readWriteLock.write {
                    self.people.distinctId = distinctId
                }
                self.mixpanelPersistence.identifyPeople(token: self.apiToken)
            } else {
                self.people.distinctId = nil
            }
            
            MixpanelPersistence.saveIdentity(MixpanelIdentity.init(
                distinctID: self.distinctId,
                peopleDistinctID: self.people.distinctId,
                anonymousId: self.anonymousId,
                userId: self.userId,
                alias: self.alias,
                hadPersistedDistinctId: self.hadPersistedDistinctId), instanceName: self.name)
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
        
        if MixpanelInstance.isiOSAppExtension() {
            flush()
        }
    }
    
    /**
     The alias method creates an alias which Mixpanel will use to remap one id to another.
     Multiple aliases can point to the same identifier.
     
     Please note: With Mixpanel Identity Merge enabled, calling alias is no longer required
     but can be used to merge two IDs in scenarios where identify() would fail
     
     
     `mixpanelInstance.createAlias("New ID", distinctId: mixpanelInstance.distinctId)`
     
     You can add multiple id aliases to the existing id
     
     `mixpanelInstance.createAlias("Newer ID", distinctId: mixpanelInstance.distinctId)`
     
     
     - parameter alias:      A unique identifier that you want to use as an identifier for this user.
     - parameter distinctId: The current user identifier.
     - parameter usePeople: boolean that controls whether or not to set the people distinctId to the event distinctId.
     - parameter andIdentify: an optional boolean that controls whether or not to call 'identify' with your current
     user identifier(not alias). Default to true for keeping your signup funnels working correctly in most cases.
     - parameter completion: an optional completion handler for when the createAlias has completed.
     This should only be set to false if you wish to prevent people profile updates for that user.
     */
    public func createAlias(_ alias: String, distinctId: String, usePeople: Bool = true, andIdentify: Bool = true, completion: (() -> Void)? = nil) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        
        if alias.isEmpty {
            Logger.error(message: "\(self) create alias called with empty alias")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
#if DEBUG
        UserDefaults.standard.set(true, forKey: InternalKeys.mpDebugAliasedKey)
#endif
        if alias != distinctId {
            trackingQueue.async { [weak self, alias] in
                guard let self = self else {
                    if let completion = completion {
                        DispatchQueue.main.async(execute: completion)
                    }
                    return
                }
                self.readWriteLock.write {
                    self.alias = alias
                }
                
                var distinctIdSnapshot: String?
                var peopleDistinctIDSnapshot: String?
                var anonymousIdSnapshot: String?
                var userIdSnapshot: String?
                var aliasSnapshot: String?
                var hadPersistedDistinctIdSnapshot: Bool?
                
                self.readWriteLock.read {
                    distinctIdSnapshot = self.distinctId
                    peopleDistinctIDSnapshot = self.people.distinctId
                    anonymousIdSnapshot = self.anonymousId
                    userIdSnapshot = self.userId
                    aliasSnapshot = self.alias
                    hadPersistedDistinctIdSnapshot = self.hadPersistedDistinctId
                }
                
                MixpanelPersistence.saveIdentity(MixpanelIdentity.init(
                    distinctID: distinctIdSnapshot!,
                    peopleDistinctID: peopleDistinctIDSnapshot,
                    anonymousId: anonymousIdSnapshot,
                    userId: userIdSnapshot,
                    alias: aliasSnapshot,
                    hadPersistedDistinctId: hadPersistedDistinctIdSnapshot), instanceName: self.name)
            }
            
            let properties = ["distinct_id": distinctId, "alias": alias]
            track(event: "$create_alias", properties: properties)
            if andIdentify {
                identify(distinctId: distinctId, usePeople: usePeople)
            }
            flush(completion: completion)
        } else {
            Logger.error(message: "alias: \(alias) matches distinctId: \(distinctId) - skipping api call.")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
    
    /**
     Clears all stored properties including the distinct Id.
     Useful if your app's user logs out.
     
     - parameter completion: an optional completion handler for when the reset has completed.
     */
    public func reset(completion: (() -> Void)? = nil) {
        flush()
        trackingQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            MixpanelPersistence.deleteMPUserDefaultsData(instanceName: self.name)
            self.readWriteLock.write {
                self.timedEvents = InternalProperties()
                self.anonymousId = self.defaultDeviceId()
                self.distinctId = self.addPrefixToDeviceId(deviceId: self.anonymousId)
                self.hadPersistedDistinctId = true
                self.userId = nil
                self.superProperties = InternalProperties()
                self.people.distinctId = nil
                self.alias = nil
            }
            
            self.mixpanelPersistence.resetEntities()
            self.archive()
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}

extension MixpanelInstance {
    // MARK: - Persistence
    
    public func archive() {
        self.readWriteLock.read {
            MixpanelPersistence.saveTimedEvents(timedEvents: timedEvents, instanceName: self.name)
            MixpanelPersistence.saveSuperProperties(superProperties: superProperties, instanceName: self.name)
            MixpanelPersistence.saveIdentity(MixpanelIdentity.init(
                distinctID: distinctId,
                peopleDistinctID: people.distinctId,
                anonymousId: anonymousId,
                userId: userId,
                alias: alias,
                hadPersistedDistinctId: hadPersistedDistinctId), instanceName: self.name)
        }
    }
    
    func unarchive() {
        self.readWriteLock.write {
            optOutStatus = MixpanelPersistence.loadOptOutStatusFlag(instanceName: self.name)
            superProperties = MixpanelPersistence.loadSuperProperties(instanceName: self.name)
            timedEvents = MixpanelPersistence.loadTimedEvents(instanceName: self.name)
            let mixpanelIdentity = MixpanelPersistence.loadIdentity(instanceName: self.name)
            (distinctId, people.distinctId, anonymousId, userId, alias, hadPersistedDistinctId) = (
                mixpanelIdentity.distinctID,
                mixpanelIdentity.peopleDistinctID,
                mixpanelIdentity.anonymousId,
                mixpanelIdentity.userId,
                mixpanelIdentity.alias,
                mixpanelIdentity.hadPersistedDistinctId
            )
            if distinctId.isEmpty {
                anonymousId = defaultDeviceId()
                distinctId = addPrefixToDeviceId(deviceId: anonymousId)
                hadPersistedDistinctId = true
                userId = nil
                MixpanelPersistence.saveIdentity(MixpanelIdentity.init(
                    distinctID: distinctId,
                    peopleDistinctID: people.distinctId,
                    anonymousId: anonymousId,
                    userId: userId,
                    alias: alias,
                    hadPersistedDistinctId: hadPersistedDistinctId), instanceName: self.name)
            }
        }
    }
    
    func trackIntegration() {
        if hasOptedOutTracking() {
            return
        }
        let defaultsKey = "trackedKey"
        if !UserDefaults.standard.bool(forKey: defaultsKey) {
            trackingQueue.async { [apiToken, defaultsKey, serverURL] in
                Network.sendHttpEvent(serverURL: serverURL, eventName: "Integration", apiToken: "85053bf24bba75239b16a601d9387e17", distinctId: apiToken, updatePeople: false) { [defaultsKey] (success) in
                    if success {
                        UserDefaults.standard.set(true, forKey: defaultsKey)
                        UserDefaults.standard.synchronize()
                    }
                }
            }
        }
    }
}

extension MixpanelInstance {
    // MARK: - Flush
    
    /**
     Uploads queued data to the Mixpanel server.
     
     By default, queued data is flushed to the Mixpanel servers every minute (the
     default for `flushInterval`), and on background (since
     `flushOnBackground` is on by default). You only need to call this
     method manually if you want to force a flush at a particular moment.
     
     - parameter performFullFlush: A optional boolean value indicating whether a full flush should be performed. If `true`, a full flush will be triggered, sending all events to the server. Default to `false`, a partial flush will be executed for reducing memory footprint.
     - parameter completion: an optional completion handler for when the flush has completed.
     */
    public func flush(performFullFlush: Bool = false, completion: (() -> Void)? = nil) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        trackingQueue.async { [weak self, completion] in
            guard let self = self else {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
                return
            }
            
            if let shouldFlush = self.delegate?.mixpanelWillFlush(self), !shouldFlush {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
                return
            }
            
            // automatic events will NOT be flushed until one of the flags is non-nil
            let eventQueue = self.mixpanelPersistence.loadEntitiesInBatch(
                type: self.persistenceTypeFromFlushType(.events),
                batchSize: performFullFlush ? Int.max : self.flushBatchSize,
                excludeAutomaticEvents: !self.trackAutomaticEventsEnabled
            )
            let peopleQueue = self.mixpanelPersistence.loadEntitiesInBatch(
                type: self.persistenceTypeFromFlushType(.people),
                batchSize: performFullFlush ? Int.max : self.flushBatchSize
            )
            let groupsQueue = self.mixpanelPersistence.loadEntitiesInBatch(
                type: self.persistenceTypeFromFlushType(.groups),
                batchSize: performFullFlush ? Int.max : self.flushBatchSize
            )
            
            self.networkQueue.async { [weak self, completion] in
                guard let self = self else {
                    if let completion = completion {
                        DispatchQueue.main.async(execute: completion)
                    }
                    return
                }
                self.flushQueue(eventQueue, type: .events)
                self.flushQueue(peopleQueue, type: .people)
                self.flushQueue(groupsQueue, type: .groups)
                
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
            }
        }
    }
    
    private func persistenceTypeFromFlushType(_ type: FlushType) -> PersistenceType {
        switch type {
        case .events:
            return PersistenceType.events
        case .people:
            return PersistenceType.people
        case .groups:
            return PersistenceType.groups
        }
    }
    
    func flushQueue(_ queue: Queue, type: FlushType) {
        if hasOptedOutTracking() {
            return
        }
        self.flushInstance.flushQueue(queue, type: type)
    }
    
    func flushSuccess(type: FlushType, ids: [Int32]) {
        trackingQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.mixpanelPersistence.removeEntitiesInBatch(type: self.persistenceTypeFromFlushType(type), ids: ids)
        }
    }
    
}

extension MixpanelInstance {
    // MARK: - Track
    
    /**
     Tracks an event with properties.
     Properties are optional and can be added only if needed.
     
     Properties will allow you to segment your events in your Mixpanel reports.
     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
     If the event is being timed, the timer will stop and be added as a property.
     
     - parameter event:      event name
     - parameter properties: properties dictionary
     */
    public func track(event: String?, properties: Properties? = nil) {
        if hasOptedOutTracking() {
            return
        }
        
        let epochInterval = Date().timeIntervalSince1970
        
        trackingQueue.async { [weak self, event, properties, epochInterval] in
            guard let self = self else {
                return
            }
            var shadowTimedEvents = InternalProperties()
            var shadowSuperProperties = InternalProperties()
            
            self.readWriteLock.read {
                shadowTimedEvents = self.timedEvents
                shadowSuperProperties = self.superProperties
            }
            
            let mixpanelIdentity = MixpanelIdentity.init(distinctID: self.distinctId,
                                                         peopleDistinctID: nil,
                                                         anonymousId: self.anonymousId,
                                                         userId: self.userId,
                                                         alias: nil,
                                                         hadPersistedDistinctId: self.hadPersistedDistinctId)
            let timedEventsSnapshot = self.trackInstance.track(event: event,
                                                               properties: properties,
                                                               timedEvents: shadowTimedEvents,
                                                               superProperties: shadowSuperProperties,
                                                               mixpanelIdentity: mixpanelIdentity,
                                                               epochInterval: epochInterval)
            
            self.readWriteLock.write {
                self.timedEvents = timedEventsSnapshot
            }
        }
        
        if MixpanelInstance.isiOSAppExtension() {
            flush()
        }
    }
    
    /**
     Tracks an event with properties and to specific groups.
     Properties and groups are optional and can be added only if needed.
     
     Properties will allow you to segment your events in your Mixpanel reports.
     Property and group keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
     If the event is being timed, the timer will stop and be added as a property.
     
     - parameter event:      event name
     - parameter properties: properties dictionary
     - parameter groups:     groups dictionary
     */
    public func trackWithGroups(event: String?, properties: Properties? = nil, groups: Properties?) {
        if hasOptedOutTracking() {
            return
        }
        
        guard let properties = properties else {
            self.track(event: event, properties: groups)
            return
        }
        
        guard let groups = groups else {
            self.track(event: event, properties: properties)
            return
        }
        
        var mergedProperties = properties
        for (groupKey, groupID) in groups {
            mergedProperties[groupKey] = groupID
        }
        self.track(event: event, properties: mergedProperties)
    }
    
    public func getGroup(groupKey: String, groupID: MixpanelType) -> Group {
        let key = makeMapKey(groupKey: groupKey, groupID: groupID)
        
        var groupsShadow: [String: Group] = [:]
        
        readWriteLock.read {
            groupsShadow = groups
        }
        
        guard let group = groupsShadow[key] else {
            readWriteLock.write {
                groups[key] = Group(apiToken: apiToken,
                                    serialQueue: trackingQueue,
                                    lock: self.readWriteLock,
                                    groupKey: groupKey,
                                    groupID: groupID,
                                    metadata: sessionMetadata,
                                    mixpanelPersistence: mixpanelPersistence,
                                    mixpanelInstance: self)
                groupsShadow = groups
            }
            return groupsShadow[key]!
        }
        
        if !(group.groupKey == groupKey && group.groupID.equals(rhs: groupID)) {
            // we somehow hit a collision on the map key, return a new group with the correct key and ID
            Logger.info(message: "groups dictionary key collision: \(key)")
            let newGroup = Group(apiToken: apiToken,
                                 serialQueue: trackingQueue,
                                 lock: self.readWriteLock,
                                 groupKey: groupKey,
                                 groupID: groupID,
                                 metadata: sessionMetadata,
                                 mixpanelPersistence: mixpanelPersistence,
                                 mixpanelInstance: self)
            readWriteLock.write {
                groups[key] = newGroup
            }
            return newGroup
        }
        
        return group
    }
    
    func removeCachedGroup(groupKey: String, groupID: MixpanelType) {
        readWriteLock.write {
            groups.removeValue(forKey: makeMapKey(groupKey: groupKey, groupID: groupID))
        }
    }
    
    func makeMapKey(groupKey: String, groupID: MixpanelType) -> String {
        return "\(groupKey)_\(groupID)"
    }
    
    /**
     Starts a timer that will be stopped and added as a property when a
     corresponding event is tracked.
     
     This method is intended to be used in advance of events that have
     a duration. For example, if a developer were to track an "Image Upload" event
     she might want to also know how long the upload took. Calling this method
     before the upload code would implicitly cause the `track`
     call to record its duration.
     
     - precondition:
     // begin timing the image upload:
     mixpanelInstance.time(event:"Image Upload")
     // upload the image:
     self.uploadImageWithSuccessHandler() { _ in
     // track the event
     mixpanelInstance.track("Image Upload")
     }
     
     - parameter event: the event name to be timed
     
     */
    public func time(event: String) {
        let startTime = Date().timeIntervalSince1970
        trackingQueue.async { [weak self, startTime, event] in
            guard let self = self else { return }
            let timedEvents = self.trackInstance.time(event: event, timedEvents: self.timedEvents, startTime: startTime)
            self.readWriteLock.write {
                self.timedEvents = timedEvents
            }
            MixpanelPersistence.saveTimedEvents(timedEvents: timedEvents, instanceName: self.name)
        }
    }
    
    /**
     Retrieves the time elapsed for the named event since time(event:) was called.
     
     - parameter event: the name of the event to be tracked that was passed to time(event:)
     */
    public func eventElapsedTime(event: String) -> Double {
        var timedEvents = InternalProperties()
        self.readWriteLock.read {
            timedEvents = self.timedEvents
        }
        
        if let startTime = timedEvents[event] as? TimeInterval {
            return Date().timeIntervalSince1970 - startTime
        }
        return 0
    }
    
    /**
     Clears all current event timers.
     */
    public func clearTimedEvents() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.write {
                self.timedEvents = InternalProperties()
            }
            MixpanelPersistence.saveTimedEvents(timedEvents: InternalProperties(), instanceName: self.name)
        }
    }
    
    /**
     Clears the event timer for the named event.
     
     - parameter event: the name of the event to clear the timer for
     */
    public func clearTimedEvent(event: String) {
        trackingQueue.async { [weak self, event] in
            guard let self = self else { return }
            
            let updatedTimedEvents = self.trackInstance.clearTimedEvent(event: event, timedEvents: self.timedEvents)
            MixpanelPersistence.saveTimedEvents(timedEvents: updatedTimedEvents, instanceName: self.name)
        }
    }
    
    /**
     Returns the currently set super properties.
     
     - returns: the current super properties
     */
    public func currentSuperProperties() -> [String: Any] {
        var properties = InternalProperties()
        self.readWriteLock.read {
            properties = superProperties
        }
        return properties
    }
    
    /**
     Clears all currently set super properties.
     */
    public func clearSuperProperties() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.superProperties = self.trackInstance.clearSuperProperties(self.superProperties)
            MixpanelPersistence.saveSuperProperties(superProperties: self.superProperties, instanceName: self.name)
        }
    }
    
    /**
     Registers super properties, overwriting ones that have already been set.
     
     Super properties, once registered, are automatically sent as properties for
     all event tracking calls. They save you having to maintain and add a common
     set of properties to your events.
     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
     
     - parameter properties: properties dictionary
     */
    public func registerSuperProperties(_ properties: Properties) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            let updatedSuperProperties = self.trackInstance.registerSuperProperties(properties,
                                                                                    superProperties: self.superProperties)
            self.readWriteLock.write {
                self.superProperties = updatedSuperProperties
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveSuperProperties(superProperties: self.superProperties, instanceName: self.name)
            }
        }
    }
    
    
    
    
    
    /**
     Registers super properties without overwriting ones that have already been set,
     unless the existing value is equal to defaultValue. defaultValue is optional.
     
     Property keys must be String objects and the supported value types need to conform to MixpanelType.
     MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
     
     - parameter properties:   properties dictionary
     - parameter defaultValue: Optional. overwrite existing properties that have this value
     */
    public func registerSuperPropertiesOnce(_ properties: Properties,
                                          defaultValue: MixpanelType? = nil) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            let updatedSuperProperties = self.trackInstance.registerSuperPropertiesOnce(properties,
                                                                                        superProperties: self.superProperties,
                                                                                        defaultValue: defaultValue)
            self.readWriteLock.write {
                self.superProperties = updatedSuperProperties
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveSuperProperties(superProperties: self.superProperties, instanceName: self.name)
            }
        }
    }
    
    /**
     Removes a previously registered super property.
     
     As an alternative to clearing all properties, unregistering specific super
     properties prevents them from being recorded on future events. This operation
     does not affect the value of other super properties. Any property name that is
     not registered is ignored.
     Note that after removing a super property, events will show the attribute as
     having the value `undefined` in Mixpanel until a new value is
     registered.
     
     - parameter propertyName: array of property name strings to remove
     */
    public func unregisterSuperProperty(_ propertyName: String) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.superProperties = self.trackInstance.unregisterSuperProperty(propertyName,
                                                                              superProperties: self.superProperties)
            MixpanelPersistence.saveSuperProperties(superProperties: self.superProperties, instanceName: self.name)
        }
    }
    
    /**
     Updates a super property atomically. The update function
     
     - parameter update: closure to apply to super properties
     */
    func updateSuperProperty(_ update: @escaping (_ superproperties: inout InternalProperties) -> Void) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            var superPropertiesShadow = self.superProperties
            self.trackInstance.updateSuperProperty(update,
                                                   superProperties: &superPropertiesShadow)
            self.superProperties = superPropertiesShadow
            MixpanelPersistence.saveSuperProperties(superProperties: self.superProperties, instanceName: self.name)
        }
    }
    
    /**
     Convenience method to set a single group the user belongs to.
     
     - parameter groupKey: The property name associated with this group type (must already have been set up).
     - parameter groupID: The group the user belongs to.
     */
    public func setGroup(groupKey: String, groupID: MixpanelType) {
        if hasOptedOutTracking() {
            return
        }
        
        setGroup(groupKey: groupKey, groupIDs: [groupID])
    }
    
    /**
     Set the groups this user belongs to.
     
     - parameter groupKey: The property name associated with this group type (must already have been set up).
     - parameter groupIDs: The list of groups the user belongs to.
     */
    public func setGroup(groupKey: String, groupIDs: [MixpanelType]) {
        if hasOptedOutTracking() {
            return
        }
        
        let properties = [groupKey: groupIDs]
        self.registerSuperProperties(properties)
        people.set(properties: properties)
    }
    
    /**
     Add a group to this user's membership for a particular group key
     
     - parameter groupKey: The property name associated with this group type (must already have been set up).
     - parameter groupID: The new group the user belongs to.
     */
    public func addGroup(groupKey: String, groupID: MixpanelType) {
        if hasOptedOutTracking() {
            return
        }
        
        updateSuperProperty { superProperties in
            guard let oldValue = superProperties[groupKey] else {
                superProperties[groupKey] = [groupID]
                self.people.set(properties: [groupKey: [groupID]])
                return
            }
            
            if let oldValue = oldValue as? [MixpanelType] {
                var vals = oldValue
                if !vals.contains(where: { $0.equals(rhs: groupID) }) {
                    vals.append(groupID)
                    superProperties[groupKey] = vals
                }
            } else {
                superProperties[groupKey] = [oldValue, groupID]
            }
            
            // This is a best effort--if the people property is not already a list, this call does nothing.
            self.people.union(properties: [groupKey: [groupID]])
        }
    }
    
    /**
     Remove a group from this user's membership for a particular group key
     
     - parameter groupKey: The property name associated with this group type (must already have been set up).
     - parameter groupID: The group value to remove.
     */
    public func removeGroup(groupKey: String, groupID: MixpanelType) {
        if hasOptedOutTracking() {
            return
        }
        
        updateSuperProperty { (superProperties) -> Void in
            guard let oldValue = superProperties[groupKey] else {
                return
            }
            
            guard let vals = oldValue as? [MixpanelType] else {
                superProperties.removeValue(forKey: groupKey)
                self.people.unset(properties: [groupKey])
                return
            }
            
            if vals.count < 2 {
                superProperties.removeValue(forKey: groupKey)
                self.people.unset(properties: [groupKey])
                return
            }
            
            superProperties[groupKey] = vals.filter {!$0.equals(rhs: groupID)}
            self.people.remove(properties: [groupKey: groupID])
        }
    }
    
    /**
     Opt out tracking.
     
     This method is used to opt out tracking. This causes all events and people request no longer
     to be sent back to the Mixpanel server.
     */
    public func optOutTracking() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            if self.people.distinctId != nil {
                self.people.deleteUser()
                self.people.clearCharges()
                self.flush()
            }
            self.readWriteLock.write { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.alias = nil
                self.people.distinctId = nil
                self.userId = nil
                self.anonymousId = self.defaultDeviceId()
                self.distinctId = self.addPrefixToDeviceId(deviceId: self.anonymousId)
                self.hadPersistedDistinctId = true
                self.superProperties = InternalProperties()
                MixpanelPersistence.saveTimedEvents(timedEvents: InternalProperties(), instanceName: self.name)
            }
            self.archive()
            self.readWriteLock.write {
                self.optOutStatus = true
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveOptOutStatusFlag(value: self.optOutStatus!, instanceName: self.name)
            }
            
        }
    }
    
    /**
     Opt in tracking.
     
     Use this method to opt in an already opted out user from tracking. People updates and track calls will be
     sent to Mixpanel after using this method.
     
     This method will internally track an opt in event to your project.
     
     - parameter distintId: an optional string to use as the distinct ID for events
     - parameter properties: an optional properties dictionary that could be passed to add properties to the opt-in event
     that is sent to Mixpanel
     */
    public func optInTracking(distinctId: String? = nil, properties: Properties? = nil) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.write {
                self.optOutStatus = false
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveOptOutStatusFlag(value: self.optOutStatus!, instanceName: self.name)
            }
            if let distinctId = distinctId {
                self.identify(distinctId: distinctId)
            }
            self.track(event: "$opt_in", properties: properties)
        }
        
        
    }
    
    /**
     Returns if the current user has opted out tracking.
     
     - returns: the current super opted out tracking status
     */
    public func hasOptedOutTracking() -> Bool {
        var optOutStatusShadow: Bool?
        readWriteLock.read {
            optOutStatusShadow = optOutStatus
        }
        return optOutStatusShadow ?? false
    }
    
    // MARK: - AEDelegate
    func increment(property: String, by: Double) {
        people?.increment(property: property, by: by)
    }
    
    func setOnce(properties: Properties) {
        people?.setOnce(properties: properties)
    }
    
}
