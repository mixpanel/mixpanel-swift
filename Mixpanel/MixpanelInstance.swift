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
#endif // os(iOS

/**
 *  Delegate protocol for controlling the Mixpanel API's network behavior.
 */
public protocol MixpanelDelegate {
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

    /// The a MixpanelDelegate object that gives control over Mixpanel network activity.
    open var delegate: MixpanelDelegate?

    /// distinctId string that uniquely identifies the current user.
    open var distinctId = ""

    /// alias string that uniquely identifies the current user.
    open var alias: String? = nil

    /// Accessor to the Mixpanel People API object.
    open var people: People!

    /// Controls whether to show spinning network activity indicator when flushing
    /// data to the Mixpanel servers. Defaults to true.
    open var showNetworkActivityIndicator = true

    /// Flush timer's interval.
    /// Setting a flush interval of 0 will turn off the flush timer.
    open var flushInterval: Double {
        set {
            flushInstance.flushInterval = newValue
        }
        get {
            return flushInstance.flushInterval
        }
    }

    /// Control whether the library should flush data to Mixpanel when the app
    /// enters the background. Defaults to true.
    open var flushOnBackground: Bool {
        set {
            flushInstance.flushOnBackground = newValue
        }
        get {
            return flushInstance.flushOnBackground
        }
    }

    /// Controls whether to automatically send the client IP Address as part of
    /// event tracking. With an IP address, the Mixpanel Dashboard will show you the users' city.
    /// Defaults to true.
    open var useIPAddressForGeoLocation: Bool {
        set {
            flushInstance.useIPAddressForGeoLocation = newValue
        }
        get {
            return flushInstance.useIPAddressForGeoLocation
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
        + "    Events Queue Count: \(eventsQueue.count),\n"
        + "    People Queue Count: \(people.peopleQueue.count),\n"
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
        }
    }

    /// A unique identifier for this MixpanelInstance
    open let name: String

    #if DECIDE
    /// Controls whether to enable the visual editor for codeless on mixpanel.com
    /// You will be unable to edit codeless events with this disabled, however previously
    /// created codeless events will still be delivered.
    open var enableVisualEditorForCodeless: Bool {
        set {
            decideInstance.enableVisualEditorForCodeless = newValue
            decideInstance.gestureRecognizer?.isEnabled = newValue
            if !newValue {
                decideInstance.webSocketWrapper?.close()
            }
        }
        get {
            return decideInstance.enableVisualEditorForCodeless
        }
    }

    /// Controls whether to automatically check for A/B test variants for the
    /// currently identified user when the application becomes active.
    /// Defaults to true.
    open var checkForVariantsOnActive: Bool {
        set {
            decideInstance.ABTestingInstance.checkForVariantsOnActive = newValue
        }
        get {
            return decideInstance.ABTestingInstance.checkForVariantsOnActive
        }
    }

    /// Controls whether to automatically check for notifications for the
    /// currently identified user when the application becomes active.
    /// Defaults to true.
    open var checkForNotificationOnActive: Bool {
        set {
            decideInstance.notificationsInstance.checkForNotificationOnActive = newValue
        }
        get {
            return decideInstance.notificationsInstance.checkForNotificationOnActive
        }
    }

    /// Controls whether to automatically check for and show in-app notifications
    /// for the currently identified user when the application becomes active.
    /// Defaults to true.
    open var showNotificationOnActive: Bool {
        set {
            decideInstance.notificationsInstance.showNotificationOnActive = newValue
        }
        get {
            return decideInstance.notificationsInstance.showNotificationOnActive
        }
    }

    /// Determines the time, in seconds, that a mini notification will remain on
    /// the screen before automatically hiding itself.
    /// Defaults to 6 (seconds).
    open var miniNotificationPresentationTime: Double {
        set {
            decideInstance.notificationsInstance.miniNotificationPresentationTime = newValue
        }
        get {
            return decideInstance.notificationsInstance.miniNotificationPresentationTime
        }
    }

    /// The minimum session duration (ms) that is tracked in automatic events.
    /// The default value is 10000 (10 seconds).
    open var minimumSessionDuration: UInt64 {
        set {
            automaticEvents.minimumSessionDuration = newValue
        }
        get {
            return automaticEvents.minimumSessionDuration
        }
    }

    /// The maximum session duration (ms) that is tracked in automatic events.
    /// The default value is UINT64_MAX (no maximum session duration).
    open var maximumSessionDuration: UInt64 {
        set {
            automaticEvents.maximumSessionDuration = newValue
        }
        get {
            return automaticEvents.maximumSessionDuration
        }
    }
    #endif // DECIDE

    var apiToken = ""
    var superProperties = InternalProperties()
    var eventsQueue = Queue()
    var flushEventsQueue = Queue()
    var timedEvents = InternalProperties()
    var trackingQueue: DispatchQueue!
    var networkQueue: DispatchQueue!
    var optOutStatus = false
    let readWriteLock: ReadWriteLock
    #if os(iOS)
    var reachability: SCNetworkReachability?
    let telephonyInfo = CTTelephonyNetworkInfo()
    #endif
    #if !os(OSX)
    var taskId = UIBackgroundTaskInvalid
    #endif // os(OSX)
    let sessionMetadata: SessionMetadata
    let flushInstance: Flush
    let trackInstance: Track
    #if DECIDE
    let decideInstance: Decide
    let automaticEvents = AutomaticEvents()
    let connectIntegrations = ConnectIntegrations()
    #endif // DECIDE

    #if !os(OSX)
    init(apiToken: String?, launchOptions: [UIApplicationLaunchOptionsKey : Any]?, flushInterval: Double, name: String, automaticPushTracking: Bool = true, optOutTrackingByDefault: Bool = false) {
        if let apiToken = apiToken, !apiToken.isEmpty {
            self.apiToken = apiToken
        }
        self.name = name
        self.readWriteLock = ReadWriteLock(label: "globalLock")
        flushInstance = Flush(basePathIdentifier: name, lock: self.readWriteLock)
        #if DECIDE
            decideInstance = Decide(basePathIdentifier: name, lock: self.readWriteLock)
        #endif // DECIDE
        let label = "com.mixpanel.\(self.apiToken)"
        trackingQueue = DispatchQueue(label: label)
        sessionMetadata = SessionMetadata(trackingQueue: trackingQueue)
        trackInstance = Track(apiToken: self.apiToken,
                              lock: self.readWriteLock,
                              metadata: sessionMetadata)
        networkQueue = DispatchQueue(label: label)
        
        #if os(iOS)
            reachability = SCNetworkReachabilityCreateWithName(nil, "api.mixpanel.com")
            if let reachability = reachability {
                var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
                func reachabilityCallback(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, unsafePointer: UnsafeMutableRawPointer?) -> Void {
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
        distinctId = defaultDistinctId()
        people = People(apiToken: self.apiToken,
                        serialQueue: trackingQueue,
                        lock: self.readWriteLock,
                        metadata: sessionMetadata)
        people.delegate = self
        flushInstance._flushInterval = flushInterval
        setupListeners()
        unarchive()
        
        if optOutTrackingByDefault {
            self.optOutTracking()
        }
        
        #if DECIDE
            if !MixpanelInstance.isiOSAppExtension() {
                automaticEvents.delegate = self
                automaticEvents.automaticPushTracking = automaticPushTracking
                automaticEvents.initializeEvents()
                decideInstance.inAppDelegate = self
                executeCachedVariants()
                executeCachedCodelessBindings()
                if let notification =
                    launchOptions?[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
                    trackPushNotification(notification, event: "$app_open")
                }
            }
            connectIntegrations.mixpanel = self
        #endif // DECIDE
    }
    #else
    init(apiToken: String?, flushInterval: Double, name: String, optOutTrackingByDefault: Bool = false) {
        if let apiToken = apiToken, !apiToken.isEmpty {
            self.apiToken = apiToken
        }
        self.name = name
        self.readWriteLock = ReadWriteLock(label: "globalLock")
        flushInstance = Flush(basePathIdentifier: name, lock: self.readWriteLock)
        let label = "com.mixpanel.\(self.apiToken)"
        trackingQueue = DispatchQueue(label: label)
        sessionMetadata = SessionMetadata(trackingQueue: trackingQueue)
        trackInstance = Track(apiToken: self.apiToken,
                              lock: self.readWriteLock,
                              metadata: sessionMetadata)
        flushInstance.delegate = self
        networkQueue = DispatchQueue(label: label)
        distinctId = defaultDistinctId()
        people = People(apiToken: self.apiToken,
                        serialQueue: trackingQueue,
                        lock: self.readWriteLock,
                        metadata: sessionMetadata)
        flushInstance._flushInterval = flushInterval
        setupListeners()
        unarchive()
        if optOutTrackingByDefault {
            self.optOutTracking()
        }
    }
    #endif // os(OSX)

    #if !os(OSX)
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
        trackIntegration()
        #if os(iOS)
            setCurrentRadio()
            notificationCenter.addObserver(self,
                                           selector: #selector(setCurrentRadio),
                                           name: .CTRadioAccessTechnologyDidChange,
                                           object: nil)
            #if DECIDE
                notificationCenter.addObserver(self,
                                               selector: #selector(executeTweaks),
                                               name: Notification.Name("MPExecuteTweaks"),
                                               object: nil)
            #endif
        #endif // os(iOS)
        if !MixpanelInstance.isiOSAppExtension() {
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillTerminate(_:)),
                                           name: .UIApplicationWillTerminate,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillResignActive(_:)),
                                           name: .UIApplicationWillResignActive,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationDidBecomeActive(_:)),
                                           name: .UIApplicationDidBecomeActive,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationDidEnterBackground(_:)),
                                           name: .UIApplicationDidEnterBackground,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillEnterForeground(_:)),
                                           name: .UIApplicationWillEnterForeground,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(appLinksNotificationRaised(_:)),
                                           name: NSNotification.Name("com.parse.bolts.measurement_event"),
                                           object: nil)
            #if os(iOS) && DECIDE
                initializeGestureRecognizer()
            #endif // os(iOS) && DECIDE
        }
    }
    #else
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillTerminate(_:)),
                                       name: NSApplication.willTerminateNotification,
                                       object: nil)
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
        #if os(iOS)
            if let reachability = reachability {
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
        #if os(iOS)
            return Bundle.main.bundlePath.hasSuffix(".appex")
        #else
            return false
        #endif
    }

    #if !os(OSX)
    static func sharedUIApplication() -> UIApplication? {
        guard let sharedApplication = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication else {
            return nil
        }
        return sharedApplication
    }
    #endif // !os(OSX)

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        flushInstance.applicationDidBecomeActive()
        #if DECIDE
            if checkForVariantsOnActive || checkForNotificationOnActive {
                checkDecide { decideResponse in
                    if let decideResponse = decideResponse {
                        DispatchQueue.main.sync {
                            decideResponse.toFinishVariants.forEach { $0.finish() }
                        }

                        if self.showNotificationOnActive && !decideResponse.unshownInAppNotifications.isEmpty {
                            self.decideInstance.notificationsInstance.showNotification(decideResponse.unshownInAppNotifications.first!)
                        }

                        DispatchQueue.main.sync {
                            for binding in decideResponse.newCodelessBindings {
                                binding.execute()
                            }
                        }

                        DispatchQueue.main.sync {
                            for variant in decideResponse.newVariants {
                                variant.execute()
                                self.markVariantRun(variant)
                            }
                        }

                        if decideResponse.integrations.count > 0 {
                            self.connectIntegrations.setupIntegrations(decideResponse.integrations)
                        }
                    }
                }
            }
        #endif // DECIDE
    }

    @objc private func applicationWillResignActive(_ notification: Notification) {
        flushInstance.applicationWillResignActive()
        #if os(OSX)
        if flushOnBackground {
            flush()
        }

        networkQueue.async {
            self.archive()
        }
        #endif
    }

    #if !os(OSX)
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return
        }
        
        if self.hasOptedOutTracking() {
            return
        }
        
        taskId = sharedApplication.beginBackgroundTask() {
            self.taskId = UIBackgroundTaskInvalid
        }

        if flushOnBackground {
            flush()
        }

        networkQueue.async {
            self.archive()
            #if DECIDE
            self.readWriteLock.write {
                self.decideInstance.decideFetched = false
            }
            #endif // DECIDE
            if self.taskId != UIBackgroundTaskInvalid {
                sharedApplication.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
            }
        }
    }

    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return
        }
        sessionMetadata.applicationWillEnterForeground()
        trackingQueue.async {
            if self.taskId != UIBackgroundTaskInvalid {
                sharedApplication.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
                #if os(iOS)
                    self.updateNetworkActivityIndicator(false)
                #endif // os(iOS)
            }
        }
    }

    @objc private func appLinksNotificationRaised(_ notification: Notification) {
        let eventMap = ["al_nav_out": "$al_nav_out",
                        "al_nav_in": "$al_nav_in",
                        "al_ref_back_out": "$al_ref_back_out"]
        let userInfo = (notification as Notification).userInfo

        if let eventName = userInfo?["event_name"] as? String,
           let eventArgs = userInfo?["event_args"] as? Properties,
           let eventNameMap = eventMap[eventName] {
            track(event: eventNameMap, properties:eventArgs)
        }
    }
    #endif // os(OSX)

    @objc private func applicationWillTerminate(_ notification: Notification) {
        networkQueue.async {
            self.archive()
        }
    }

    func defaultDistinctId() -> String {
        #if !os(OSX)
        var distinctId: String? = IFA()
        if distinctId == nil && NSClassFromString("UIDevice") != nil {
            distinctId = UIDevice.current.identifierForVendor?.uuidString
        }
        #else
        let distinctId = MixpanelInstance.macOSIdentifier()
        #endif // os(OSX)
        guard let distId = distinctId else {
            return UUID().uuidString
        }
        return distId
    }

    #if !os(OSX)
    func IFA() -> String? {
        var ifa: String? = nil
        if let ASIdentifierManagerClass = NSClassFromString("ASIdentifierManager") {
            let sharedManagerSelector = NSSelectorFromString("sharedManager")
            if let sharedManagerIMP = ASIdentifierManagerClass.method(for: sharedManagerSelector) {
                typealias sharedManagerFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
                let curriedImplementation = unsafeBitCast(sharedManagerIMP, to: sharedManagerFunc.self)
                if let sharedManager = curriedImplementation(ASIdentifierManagerClass.self, sharedManagerSelector) {
                    let advertisingTrackingEnabledSelector = NSSelectorFromString("isAdvertisingTrackingEnabled")
                    if let isTrackingEnabledIMP = sharedManager.method(for: advertisingTrackingEnabledSelector) {
                        typealias isTrackingEnabledFunc = @convention(c) (AnyObject, Selector) -> Bool
                        let curriedImplementation2 = unsafeBitCast(isTrackingEnabledIMP, to: isTrackingEnabledFunc.self)
                        let isTrackingEnabled = curriedImplementation2(self, advertisingTrackingEnabledSelector)
                        if isTrackingEnabled {
                            let advertisingIdentifierSelector = NSSelectorFromString("advertisingIdentifier")
                            if let advertisingIdentifierIMP = sharedManager.method(for: advertisingIdentifierSelector) {
                                typealias adIdentifierFunc = @convention(c) (AnyObject, Selector) -> NSUUID
                                let curriedImplementation3 = unsafeBitCast(advertisingIdentifierIMP, to: adIdentifierFunc.self)
                                ifa = curriedImplementation3(self, advertisingIdentifierSelector).uuidString
                            }
                        }
                    }
                }
            }
        }
        return ifa
    }
    #else
    static func macOSIdentifier() -> String? {
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString!, kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
        return (serialNumberAsCFString?.takeUnretainedValue() as? String)
    }
    #endif // os(OSX)

    #if os(iOS)
    func updateNetworkActivityIndicator(_ on: Bool) {
        if showNetworkActivityIndicator {
            DispatchQueue.main.async {
                MixpanelInstance.sharedUIApplication()?.isNetworkActivityIndicatorVisible = on
            }
        }
    }
    #if os(iOS)
    @objc func setCurrentRadio() {
        var radio = telephonyInfo.currentRadioAccessTechnology ?? "None"
        let prefix = "CTRadioAccessTechnology"
        if radio.hasPrefix(prefix) {
            radio = (radio as NSString).substring(from: prefix.count)
        }
        trackingQueue.async {
            AutomaticProperties.automaticPropertiesLock.write {
                [unowned self] in
                AutomaticProperties.properties["$radio"] = radio
                if self.telephonyInfo.subscriberCellularProvider?.carrierName == nil {
                    AutomaticProperties.properties["$carrier"] = ""
                }
                else {
                    AutomaticProperties.properties["$carrier"] = self.telephonyInfo.subscriberCellularProvider?.carrierName
                }
            }
        }
    }
    #endif

    #if DECIDE
    func initializeGestureRecognizer() {
        DispatchQueue.main.async {
            self.decideInstance.gestureRecognizer = UILongPressGestureRecognizer(target: self,
                                                                                 action: #selector(self.connectGestureRecognized(gesture:)))
            self.decideInstance.gestureRecognizer?.minimumPressDuration = 3
            self.decideInstance.gestureRecognizer?.cancelsTouchesInView = false
            #if (arch(i386) || arch(x86_64)) && DECIDE
                self.decideInstance.gestureRecognizer?.numberOfTouchesRequired = 2
            #else
                self.decideInstance.gestureRecognizer?.numberOfTouchesRequired = 4
            #endif // (arch(i386) || arch(x86_64)) && DECIDE
            self.decideInstance.gestureRecognizer?.isEnabled = self.enableVisualEditorForCodeless
            MixpanelInstance.sharedUIApplication()?.keyWindow?.addGestureRecognizer(self.decideInstance.gestureRecognizer!)
        }
    }

    @objc func connectGestureRecognized(gesture: UILongPressGestureRecognizer) {
        if gesture.state == UIGestureRecognizerState.began && enableVisualEditorForCodeless {
            connectToWebSocket()
        }
    }
    #endif // DECIDE
    #endif // os(iOS)

}

extension MixpanelInstance {
    // MARK: - Identity

    /**
     Sets the distinct ID of the current user.

     Mixpanel uses the IFV String (`UIDevice.current().identifierForVendor`)
     as the default distinct ID. This ID will identify a user across all apps by the same
     vendor, but cannot be used to link the same user across apps from different
     vendors. If we are unable to get the IFV, we will fall back to generating a
     random persistent UUID

     For tracking events, you do not need to call `identify:` if you
     want to use the default. However,
     **Mixpanel People always requires an explicit call to `identify:`.**
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
     */
    open func identify(distinctId: String, usePeople: Bool = true) {
        if self.hasOptedOutTracking() {
            return
        }
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            return
        }

        trackingQueue.async {
            // identify only changes the distinct id if it doesn't match either the existing or the alias;
            // if it's new, blow away the alias as well.
            if distinctId != self.alias {
                if distinctId != self.distinctId {
                    self.alias = nil
                    self.distinctId = distinctId
                }
                if usePeople {
                    self.people.distinctId = distinctId
                    if !self.people.unidentifiedQueue.isEmpty {
                        self.readWriteLock.write {
                            for var r in self.people.unidentifiedQueue {
                                r["$distinct_id"] = self.distinctId
                                self.people.peopleQueue.append(r)
                            }
                            self.people.unidentifiedQueue.removeAll()
                        }
                        self.readWriteLock.read {
                            Persistence.archivePeople(self.people.peopleQueue, token: self.apiToken)
                        }
                    }
                } else {
                    self.people.distinctId = nil
                }
            }
            self.archiveProperties()
            Persistence.storeIdentity(token: self.apiToken,
                                      distinctID: self.distinctId,
                                      peopleDistinctID: self.people.distinctId,
                                      alias: self.alias)
        }

        if MixpanelInstance.isiOSAppExtension() {
            self.flush()
        }
    }

    /**
     Creates a distinctId alias from alias to the current id.

     This method is used to map an identifier called an alias to the existing Mixpanel
     distinct id. This causes all events and people requests sent with the alias to be
     mapped back to the original distinct id. The recommended usage pattern is to call
     createAlias: and then identify: (with their new user ID)
     when they log in the next time. This will keep your signup funnels working
     correctly.
     This makes the current id and 'Alias' interchangeable distinct ids.
     Mixpanel.
     mixpanelInstance.createAlias("Alias", mixpanelInstance.distinctId)

     - precondition: You must call identify if you haven't already
     (e.g. when your app launches)

     - parameter alias:      the new distinct id that should represent the original
     - parameter distinctId: the old distinct id that alias will be mapped to
     - parameter usePeople: boolean that controls whether or not to set the people distinctId to the event distinctId.
     This should only be set to false if you wish to prevent people profile updates for that user.
     */
    open func createAlias(_ alias: String, distinctId: String, usePeople: Bool = true) {
        if self.hasOptedOutTracking() {
            return
        }
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            return
        }

        if alias.isEmpty {
            Logger.error(message: "\(self) create alias called with empty alias")
            return
        }

        if alias != distinctId {
            trackingQueue.async {
                self.alias = alias
                self.archiveProperties()
                Persistence.storeIdentity(token: self.apiToken,
                                          distinctID: self.distinctId,
                                          peopleDistinctID: self.people.distinctId,
                                          alias: self.alias)
            }
            let properties = ["distinct_id": distinctId, "alias": alias]
            track(event: "$create_alias", properties: properties)
            identify(distinctId: distinctId, usePeople: usePeople)
            flush()
        } else {
            Logger.error(message: "alias: \(alias) matches distinctId: \(distinctId) - skipping api call.")
        }
    }

    /**
     Clears all stored properties including the distinct Id.
     Useful if your app's user logs out.
     */
    open func reset() {
        flush();
        trackingQueue.async {
            self.networkQueue.sync {
                self.readWriteLock.write {
                    Persistence.deleteMPUserDefaultsData(token: self.apiToken)
                    self.distinctId = self.defaultDistinctId()
                    self.superProperties = InternalProperties()
                    self.eventsQueue = Queue()
                    self.timedEvents = InternalProperties()
                    self.people.distinctId = nil
                    self.alias = nil
                    self.people.peopleQueue = Queue()
                    self.people.unidentifiedQueue = Queue()
                    #if DECIDE
                    self.decideInstance.notificationsInstance.shownNotifications = Set()
                    self.decideInstance.decideFetched = false
                    self.decideInstance.ABTestingInstance.variants = Set()
                    self.decideInstance.codelessInstance.codelessBindings = Set()
                    self.connectIntegrations.reset()
                    MixpanelTweaks.defaultStore.reset()
                    #endif // DECIDE
                }
                self.archive()
            }
        }
    }
}

extension MixpanelInstance {
    // MARK: - Persistence

    #if DECIDE
    /**
     Writes current project info including the distinct Id, super properties,
     and pending event and People record queues to disk.

     This state will be recovered when the app is launched again if the Mixpanel
     library is initialized with the same project token.
     The library listens for app state changes and handles
     persisting data as needed.

     - important: You do not need to call this method.**
     */
    open func archive() {
        self.readWriteLock.read {
            let properties = ArchivedProperties(superProperties: superProperties,
                                                timedEvents: timedEvents,
                                                distinctId: distinctId,
                                                alias: alias,
                                                peopleDistinctId: people.distinctId,
                                                peopleUnidentifiedQueue: people.unidentifiedQueue,
                                                shownNotifications: decideInstance.notificationsInstance.shownNotifications,
                                                automaticEventsEnabled: decideInstance.automaticEventsEnabled)
            Persistence.archive(eventsQueue: flushEventsQueue + eventsQueue,
                                peopleQueue: people.flushPeopleQueue + people.peopleQueue,
                                properties: properties,
                                codelessBindings: decideInstance.codelessInstance.codelessBindings,
                                variants: decideInstance.ABTestingInstance.variants,
                                token: apiToken)
        }
    }
    #else
    /**
     Writes current project info including the distinct Id, super properties,
     and pending event and People record queues to disk.

     This state will be recovered when the app is launched again if the Mixpanel
     library is initialized with the same project token.
     The library listens for app state changes and handles
     persisting data as needed.

     - important: You do not need to call this method.**
     */
    open func archive() {
        self.readWriteLock.read {
            let properties = ArchivedProperties(superProperties: superProperties,
                                                timedEvents: timedEvents,
                                                distinctId: distinctId,
                                                alias: alias,
                                                peopleDistinctId: people.distinctId,
                                                peopleUnidentifiedQueue: people.unidentifiedQueue)
            Persistence.archive(eventsQueue: flushEventsQueue + eventsQueue,
                                peopleQueue: people.flushPeopleQueue + people.peopleQueue,
                                properties: properties,
                                token: apiToken)
        }
    }
    #endif // DECIDE

    #if DECIDE
    func unarchive() {
        (eventsQueue,
         people.peopleQueue,
         superProperties,
         timedEvents,
         distinctId,
         alias,
         people.distinctId,
         people.unidentifiedQueue,
         decideInstance.notificationsInstance.shownNotifications,
         decideInstance.codelessInstance.codelessBindings,
         decideInstance.ABTestingInstance.variants,
         optOutStatus,
         decideInstance.automaticEventsEnabled) = Persistence.unarchive(token: apiToken)

        if distinctId == "" {
            distinctId = defaultDistinctId()
        }
    }

    func archiveProperties() {
        self.readWriteLock.read {
            let properties = ArchivedProperties(superProperties: superProperties,
                                                timedEvents: timedEvents,
                                                distinctId: distinctId,
                                                alias: alias,
                                                peopleDistinctId: people.distinctId,
                                                peopleUnidentifiedQueue: people.unidentifiedQueue,
                                                shownNotifications: decideInstance.notificationsInstance.shownNotifications,
                                                automaticEventsEnabled: decideInstance.automaticEventsEnabled)
            Persistence.archiveProperties(properties, token: apiToken)
        }
    }
    #else
    func unarchive() {
        (eventsQueue,
         people.peopleQueue,
         superProperties,
         timedEvents,
         distinctId,
         alias,
         people.distinctId,
         people.unidentifiedQueue) = Persistence.unarchive(token: apiToken)

        if distinctId == "" {
            distinctId = defaultDistinctId()
        }
    }

    func archiveProperties() {
        self.readWriteLock.read {
            let properties = ArchivedProperties(superProperties: superProperties,
                                                timedEvents: timedEvents,
                                                distinctId: distinctId,
                                                alias: alias,
                                                peopleDistinctId: people.distinctId,
                                                peopleUnidentifiedQueue: people.unidentifiedQueue)
            Persistence.archiveProperties(properties, token: apiToken)
        }
    }
    #endif // DECIDE

    func trackIntegration() {
        if self.hasOptedOutTracking() {
            return
        }
        let defaultsKey = "trackedKey"
        if !UserDefaults.standard.bool(forKey: defaultsKey) {
            trackingQueue.async {
                Network.trackIntegration(apiToken: self.apiToken, serverURL: BasePath.DefaultMixpanelAPI) {
                    (success) in
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

     - parameter completion: an optional completion handler for when the flush has completed.
     */
    open func flush(completion: (() -> Void)? = nil) {
        if self.hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        trackingQueue.async {
            self.networkQueue.async {
                if let shouldFlush = self.delegate?.mixpanelWillFlush(self), !shouldFlush {
                    return
                }
                
                self.readWriteLock.write {
                    self.flushEventsQueue = self.eventsQueue
                    self.people.flushPeopleQueue = self.people.peopleQueue
                    
                    self.eventsQueue.removeAll()
                    self.people.peopleQueue.removeAll()
                }
                
                #if DECIDE
                self.flushInstance.flushEventsQueue(&self.flushEventsQueue,
                                                    automaticEventsEnabled: self.decideInstance.automaticEventsEnabled)
                #else
                self.flushInstance.flushEventsQueue(&self.flushEventsQueue,
                                                    automaticEventsEnabled: false)
                #endif
                self.flushInstance.flushPeopleQueue(&self.people.flushPeopleQueue)
                
                self.readWriteLock.write {
                    self.eventsQueue = self.flushEventsQueue + self.eventsQueue
                    self.people.peopleQueue = self.people.flushPeopleQueue + self.people.peopleQueue
                    self.flushEventsQueue.removeAll()
                    self.people.flushPeopleQueue.removeAll()
                }
                
                self.archive()
                
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
            }
        }}
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
    open func track(event: String?, properties: Properties? = nil) {
        if self.hasOptedOutTracking() {
            return
        }
        let epochInterval = Date().timeIntervalSince1970
        trackingQueue.async {
            self.trackInstance.track(event: event,
                                     properties: properties,
                                     eventsQueue: &self.eventsQueue,
                                     timedEvents: &self.timedEvents,
                                     superProperties: self.superProperties,
                                     distinctId: self.distinctId,
                                     epochInterval: epochInterval)
            self.readWriteLock.read {
                Persistence.archiveEvents(self.flushEventsQueue + self.eventsQueue, token: self.apiToken)
            }
        }

        if MixpanelInstance.isiOSAppExtension() {
            self.flush()
        }
    }


    #if DECIDE
    func trackPushNotification(_ userInfo: [AnyHashable: Any],
                                      event: String = "$campaign_received") {
        if self.hasOptedOutTracking() {
            return
        }
        if let mpPayload = userInfo["mp"] as? InternalProperties {
            if let m = mpPayload["m"], let c = mpPayload["c"] {
                var properties = Properties()
                for (key, value) in mpPayload {
                    if key != "m" && key != "c" {
                        // Check Int first, since a number in the push payload is parsed as __NCSFNumber
                        // which fails to convert to MixpanelType.
                        if let typedValue = value as? Int { properties[key] = typedValue }
                        if let typedValue = value as? MixpanelType { properties[key] = typedValue }
                    }
                }
                properties["campaign_id"]  = c as? Int
                properties["message_id"]   = m as? Int
                properties["message_type"] = "push"
                track(event: event,
                      properties: properties)
            } else {
                Logger.info(message: "malformed mixpanel push payload")
            }
        }
    }
    #endif

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
    open func time(event: String) {
        let startTime = Date().timeIntervalSince1970
        trackingQueue.async {
            self.trackInstance.time(event: event, timedEvents: &self.timedEvents, startTime: startTime)
        }
    }

    /**
     Retrieves the time elapsed for the named event since time(event:) was called.

     - parameter event: the name of the event to be tracked that was passed to time(event:)
     */
    open func eventElapsedTime(event: String) -> Double {
        if let startTime = self.timedEvents[event] as? TimeInterval {
            return Date().timeIntervalSince1970 - startTime
        }
        return 0
    }

    /**
     Clears all current event timers.
     */
    open func clearTimedEvents() {
        trackingQueue.async {
            self.trackInstance.clearTimedEvents(&self.timedEvents)
        }
    }

    /**
     Returns the currently set super properties.

     - returns: the current super properties
     */
    open func currentSuperProperties() -> [String: Any] {
        return superProperties
    }

    /**
     Clears all currently set super properties.
     */
    open func clearSuperProperties() {
        dispatchAndTrack() {
            self.trackInstance.clearSuperProperties(&self.superProperties)
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
    open func registerSuperProperties(_ properties: Properties) {
        dispatchAndTrack() {
            self.trackInstance.registerSuperProperties(properties,
                                                       superProperties: &self.superProperties)
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
    open func registerSuperPropertiesOnce(_ properties: Properties,
                                            defaultValue: MixpanelType? = nil) {
        dispatchAndTrack() {
            self.trackInstance.registerSuperPropertiesOnce(properties,
                                                           superProperties: &self.superProperties,
                                                           defaultValue: defaultValue)
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
    open func unregisterSuperProperty(_ propertyName: String) {
        dispatchAndTrack() {
            self.trackInstance.unregisterSuperProperty(propertyName,
                                                       superProperties: &self.superProperties)
        }
    }
    
    /**
     Opt out tracking.
     
     This method is used to opt out tracking. This causes all events and people request no longer
     to be sent back to the Mixpanel server.
     */
    open func optOutTracking() {
        trackingQueue.async {
            self.readWriteLock.write {
                self.eventsQueue = Queue()
                self.people.peopleQueue = Queue()
            }
        }
        
        if self.people.distinctId != nil {
            self.people.deleteUser()
            self.people.clearCharges()
            self.flush()
        }
        
        trackingQueue.async {
            self.readWriteLock.write {
                self.alias = nil
                self.people.distinctId = nil
                self.distinctId = self.defaultDistinctId()
                self.superProperties = InternalProperties()
                self.people.unidentifiedQueue = Queue()
                self.timedEvents = InternalProperties()
            }
            self.archive()
        }
        
        self.optOutStatus = true
        Persistence.archiveOptOutStatus(self.optOutStatus, token: self.apiToken)
    }
    
    /**
     Opt in tracking.
     
     Use this method to opt in an already opted out user from tracking. People updates and track calls will be
     sent to Mixpanel after using this method.
     
     This method will internally track an opt in event to your project.
     
     - parameter distintId: an optional string to use as the distinct ID for events
     - parameter properties: an optional properties dictionary that could be passed to add properties to the opt-in event that is sent to Mixpanel
     */
    open func optInTracking(distinctId: String? = nil, properties: Properties? = nil) {
        self.optOutStatus = false
        Persistence.archiveOptOutStatus(self.optOutStatus, token: self.apiToken)
        
        if let distinctId = distinctId {
            identify(distinctId: distinctId)
        }
        track(event: "$opt_in", properties: properties)
    }
    
    /**
     Returns if the current user has opted out tracking.

     - returns: the current super opted out tracking status
     */
    open func hasOptedOutTracking() -> Bool {
        return self.optOutStatus
    }

    func dispatchAndTrack(closure: @escaping () -> Void) {
        trackingQueue.async {
            closure()
            self.archiveProperties()
        }
    }
}

#if DECIDE
extension MixpanelInstance: InAppNotificationsDelegate {

    // MARK: - Decide
    func checkDecide(forceFetch: Bool = false, completion: @escaping ((_ response: DecideResponse?) -> Void)) {
        self.trackingQueue.async {
            self.networkQueue.async {
                self.decideInstance.checkDecide(forceFetch: forceFetch,
                                                distinctId: self.people.distinctId ?? self.distinctId,
                                                token: self.apiToken,
                                                completion: completion)
            }
        }
    }

    // MARK: - WebSocket
    func connectToWebSocket() {
        decideInstance.connectToWebSocket(token: apiToken, mixpanelInstance: self)
    }

    // MARK: - Codeless
    func executeCachedCodelessBindings() {
        for binding in decideInstance.codelessInstance.codelessBindings {
            binding.execute()
        }
    }

    // MARK: - A/B Testing
    func markVariantRun(_ variant: Variant) {
        Logger.info(message: "Marking variant \(variant.ID) shown for experiment \(variant.experimentID)")
        let shownVariant = ["\(variant.experimentID)": variant.ID]
        people.merge(properties: ["$experiments": shownVariant])
        trackingQueue.async {
            var superPropertiesCopy = self.superProperties
            var shownVariants = superPropertiesCopy["$experiments"] as? [String: Any] ?? [:]
            shownVariants += shownVariant
            superPropertiesCopy += ["$experiments": shownVariants]
            self.superProperties = superPropertiesCopy
            self.archiveProperties()
        }
        track(event: "$experiment_started", properties: ["$experiment_id": variant.experimentID,
                                                         "$variant_id": variant.ID])
    }

    func executeCachedVariants() {
        for variant in decideInstance.ABTestingInstance.variants {
            variant.execute()
        }
    }

    @objc func executeTweaks() {
        for variant in decideInstance.ABTestingInstance.variants {
            variant.executeTweaks()
        }
    }

    func checkForVariants(completion: @escaping (_ variants: Set<Variant>?) -> Void) {
        checkDecide(forceFetch: true) { response in
            DispatchQueue.main.sync {
                response?.toFinishVariants.forEach { $0.finish() }
            }
            completion(response?.newVariants)
        }
    }

    /**
     Join any experiments (A/B tests) that are available for the current user.

     Mixpanel will check for A/B tests automatically when your app enters
     the foreground. Call this method if you would like to to check for,
     and join, any experiments are newly available for the current user.

     - parameter callback:  Optional callback for after the experiments have been loaded and applied
     */
    open func joinExperiments(callback: (() -> Void)? = nil) {
        checkForVariants { newVariants in
            guard let newVariants = newVariants else {
                return
            }

            DispatchQueue.main.sync {
                for variant in newVariants {
                    variant.execute()
                    self.markVariantRun(variant)
                }
            }
            DispatchQueue.main.async {
                if let callback = callback {
                    callback()
                }
            }
        }
    }

    // MARK: - In App Notifications

    /**
     Shows a notification if one is available.

     - note: You do not need to call this method on the main thread.
    */
    open func showNotification() {
        checkForNotifications { (notifications) in
            if let notifications = notifications, !notifications.isEmpty {
                self.decideInstance.notificationsInstance.showNotification(notifications.first!)
            }
        }
    }

    /**
     Shows a notification with the given type if one is available.

     - note: You do not need to call this method on the main thread.
     - parameter type: The type of notification to show, either "mini" or "takeover"
    */
    open func showNotification(type: String) {
        checkForNotifications { (notifications) in
            if let notifications = notifications {
                for notification in notifications {
                    if type == notification.type {
                        self.decideInstance.notificationsInstance.showNotification(notification)
                    }
                }
            }
        }
    }

    /**
     Shows a notification with the given ID

     - note: You do not need to call this method on the main thread.
     - parameter ID: The notification ID you want to present
     */
    open func showNotification(ID: Int) {
        checkForNotifications { (notifications) in
            if let notifications = notifications {
                for notification in notifications {
                    if ID == notification.ID {
                        self.decideInstance.notificationsInstance.showNotification(notification)
                    }
                }
            }
        }
    }

    /**
     Returns the payload of a notification if available

     - note: You do not need to call this method on the main thread.
     */
    open func fetchNotificationPayload(completion: @escaping ([String: AnyObject]?) -> Void){
        checkForNotifications { (notifications) in
            if let notifications = notifications, !notifications.isEmpty {
                if let notification = notifications.first {
                    completion(notification.payload())
                    self.notificationDidShow(notification)
                }
            } else {
                completion(nil)
            }
        }
    }

    func checkForNotifications(completion: @escaping (_ notifications: [InAppNotification]?) -> Void) {
        checkDecide(forceFetch: true) { response in
            DispatchQueue.main.sync {
                response?.toFinishVariants.forEach { $0.finish() }
            }
            completion(response?.unshownInAppNotifications)
        }
    }

    func notificationDidShow(_ notification: InAppNotification) {
        let properties: Properties = ["$campaigns": notification.ID,
                          "$notifications": [
                            "campaign_id": notification.ID,
                            "message_id": notification.messageID,
                            "type": "inapp",
                            "time": Date()]]
        people.append(properties: properties)
        trackNotification(notification, event: "$campaign_delivery", properties: nil)
    }

    func trackNotification(_ notification: InAppNotification, event: String, properties: Properties?) {
        var notificationProperties: Properties = ["campaign_id": notification.ID,
                                                  "message_id": notification.messageID,
                                                  "message_type": "inapp",
                                                  "message_subtype": notification.type]
        if let properties = properties {
            for (k, v) in properties {
                notificationProperties[k] = v
            }
        }
        track(event: event, properties: notificationProperties)
    }
}
#endif // DECIDE
