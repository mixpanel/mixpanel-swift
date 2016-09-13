//
//  MixpanelInstance.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import CoreTelephony

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

public typealias Properties = [String: Any]
public typealias Queue = [Properties]

protocol AppLifecycle {
    func applicationDidBecomeActive()
    func applicationWillResignActive()
}

/// The class that represents the Mixpanel Instance
open class MixpanelInstance: CustomDebugStringConvertible, FlushDelegate {

    /// The a MixpanelDelegate object that gives control over Mixpanel network activity.
    open var delegate: MixpanelDelegate?

    /// distinctId string that uniquely identifies the current user.
    open var distinctId = ""

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
    open var serverURL: String {
        set {
            BasePath.MixpanelAPI = newValue
        }
        get {
            return BasePath.MixpanelAPI
        }
    }

    /// This allows enabling or disabling of all Mixpanel logs at run time.
    /// - note: All logging is disabled by default. Usually, this is only required
    ///         if you are running in to issues with the SDK and you need support.
    open var loggingEnabled: Bool = false {
        didSet {
            if loggingEnabled {
                Logger.enableLevel(.Debug)
                Logger.enableLevel(.Info)
                Logger.enableLevel(.Warning)
                Logger.enableLevel(.Error)

                Logger.info("Logging Enabled")
            } else {
                Logger.info("Logging Disabled")

                Logger.disableLevel(.Debug)
                Logger.disableLevel(.Info)
                Logger.disableLevel(.Warning)
                Logger.disableLevel(.Error)
            }
        }
    }

    /// A textual representation of MixpanelInstance, suitable for debugging
    open var debugDescription: String {
        return "Mixpanel(\n"
        + "    Token: \(apiToken),\n"
        + "    Events Queue Count: \(eventsQueue.count),\n"
        + "    People Queue Count: \(people.peopleQueue.count),\n"
        + "    Distinct Id: \(distinctId)\n"
        + ")"
    }
    var apiToken = ""
    var superProperties = Properties()
    var eventsQueue = Queue()
    var timedEvents = Properties()
    var serialQueue: DispatchQueue!
    var taskId = UIBackgroundTaskInvalid
    let flushInstance = Flush()
    let trackInstance: Track

    init(apiToken: String?, launchOptions: [AnyHashable: Any]?, flushInterval: Double) {
        if let apiToken = apiToken , !apiToken.isEmpty {
            self.apiToken = apiToken
        }
        trackInstance = Track(apiToken: self.apiToken)
        flushInstance.delegate = self
        let label = "com.mixpanel.\(self.apiToken)"
        serialQueue = DispatchQueue(label: label, attributes: [])
        distinctId = defaultDistinctId()
        people = People(apiToken: self.apiToken,
                        serialQueue: serialQueue)
        flushInstance._flushInterval = flushInterval

        setupListeners()
        unarchive()

        if let notification =
            launchOptions?[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            trackPushNotification(notification, event: "$app_open")
        }
    }

    fileprivate func setupListeners() {
        let notificationCenter = NotificationCenter.default

        trackIntegration()
        setCurrentRadio()
        notificationCenter.addObserver(self,
                                       selector: #selector(setCurrentRadio),
                                       name: NSNotification.Name.CTRadioAccessTechnologyDidChange,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillTerminate(_:)),
                                       name: NSNotification.Name.UIApplicationWillTerminate,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive(_:)),
                                       name: NSNotification.Name.UIApplicationWillResignActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidBecomeActive(_:)),
                                       name: NSNotification.Name.UIApplicationDidBecomeActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidEnterBackground(_:)),
                                       name: NSNotification.Name.UIApplicationDidEnterBackground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground(_:)),
                                       name: NSNotification.Name.UIApplicationWillEnterForeground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(appLinksNotificationRaised(_:)),
                                       name: NSNotification.Name(rawValue: "com.parse.bolts.measurement_event"),
                                       object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc fileprivate func applicationDidBecomeActive(_ notification: Notification) {
        flushInstance.applicationDidBecomeActive()
    }

    @objc fileprivate func applicationWillResignActive(_ notification: Notification) {
        flushInstance.applicationWillResignActive()
    }

    @objc fileprivate func applicationDidEnterBackground(_ notification: Notification) {
        let sharedApplication = UIApplication.shared

        taskId = sharedApplication.beginBackgroundTask {
            self.taskId = UIBackgroundTaskInvalid
        }

        if flushOnBackground {
            flush()
        }

        serialQueue.async {
            self.archive()

            if self.taskId != UIBackgroundTaskInvalid {
                sharedApplication.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
            }
        }
    }

    @objc fileprivate func applicationWillEnterForeground(_ notification: Notification) {
        serialQueue.async {
            if self.taskId != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
                self.updateNetworkActivityIndicator(false)
            }
        }
    }

    @objc fileprivate func applicationWillTerminate(_ notification: Notification) {
        serialQueue.async {
            self.archive()
        }
    }

    @objc fileprivate func appLinksNotificationRaised(_ notification: Notification) {
        let eventMap = ["al_nav_out": "$al_nav_out",
                        "al_nav_in": "$al_nav_in",
                        "al_ref_back_out": "$al_ref_back_out"]
        let userInfo = (notification as NSNotification).userInfo

        if let eventName = userInfo?["event_name"] as? String,
            let eventArgs = userInfo?["event_args"] as? Properties,
            let eventNameMap = eventMap[eventName] {
            track(event: eventNameMap, properties:eventArgs)
        }
    }

    func defaultDistinctId() -> String {
        var distinctId: String?
        if NSClassFromString("UIDevice") != nil {
            distinctId = UIDevice.current.identifierForVendor?.uuidString
        }

        guard let distId = distinctId else {
            return UUID().uuidString
        }

        return distId
    }

    func updateNetworkActivityIndicator(_ on: Bool) {
        if showNetworkActivityIndicator {
            UIApplication.shared.isNetworkActivityIndicatorVisible = on
        }
    }

    @objc func setCurrentRadio() {
        let currentRadio = AutomaticProperties.getCurrentRadio()
        serialQueue.async {
            AutomaticProperties.properties["$radio"] = currentRadio
        }
    }

}

// MARK: - Identity
extension MixpanelInstance {

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
     */
    public func identify(distinctId: String) {
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            return
        }

        serialQueue.async {
            self.distinctId = distinctId
            self.people.distinctId = distinctId
            if !self.people.unidentifiedQueue.isEmpty {
                for var r in self.people.unidentifiedQueue {
                    r["$distinct_id"] = distinctId
                    self.people.peopleQueue.append(r)
                }
                self.people.unidentifiedQueue.removeAll()
                Persistence.archivePeople(self.people.peopleQueue, token: self.apiToken)
            }

            self.archiveProperties()
        }
    }

    /**
     Creates a distinctId alias from alias to the current id.

     This method is used to map an identifier called an alias to the existing Mixpanel
     distinct id. This causes all events and people requests sent with the alias to be
     mapped back to the original distinct id. The recommended usage pattern is to call
     both createAlias: and identify: when the user signs up, and only identify: (with
     their new user ID) when they log in. This will keep your signup funnels working
     correctly.

     This makes the current id and 'Alias' interchangeable distinct ids.
     Mixpanel.
     mixpanelInstance.createAlias("Alias", mixpanelInstance.distinctId)

     - precondition: You must call identify if you haven't already
     (e.g. when your app launches)

     - parameter alias:      the new distinct id that should represent the original
     - parameter distinctId: the old distinct id that alias will be mapped to
     */
    public func createAlias(_ alias: String, distinctId: String) {
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            return
        }

        if alias.isEmpty {
            Logger.error(message: "\(self) create alias called with empty alias")
            return
        }

        let properties = ["distinct_id": distinctId, "alias": alias]
        track(event: "$create_alias",
              properties: properties as Properties?)
        flush()
    }

    /**
     Clears all stored properties including the distinct Id.
     Useful if your app's user logs out.
     */
    public func reset() {
        serialQueue.async {
            self.distinctId = self.defaultDistinctId()
            self.superProperties = Properties()
            self.eventsQueue = Queue()
            self.timedEvents = Properties()
            self.people.distinctId = nil
            self.people.peopleQueue = Queue()
            self.people.unidentifiedQueue = Queue()
            self.archive()
        }
    }
}

// MARK: - Persistence
extension MixpanelInstance {

    /**
     Writes current project info including the distinct Id, super properties,
     and pending event and People record queues to disk.

     This state will be recovered when the app is launched again if the Mixpanel
     library is initialized with the same project token.
     **You do not need to call this method.**
     The library listens for app state changes and handles
     persisting data as needed.

     - important: You do not need to call this method.
     */
    public func archive() {
        let properties = ArchivedProperties(superProperties: superProperties,
                                            timedEvents: timedEvents,
                                            distinctId: distinctId,
                                            peopleDistinctId: people.distinctId,
                                            peopleUnidentifiedQueue: people.unidentifiedQueue)
        Persistence.archive(eventsQueue,
                            peopleQueue: people.peopleQueue,
                            properties: properties,
                            token: self.apiToken)
    }

    func unarchive() {
        (eventsQueue,
         people.peopleQueue,
         superProperties,
         timedEvents,
         distinctId,
         people.distinctId,
         people.unidentifiedQueue) = Persistence.unarchive(token: self.apiToken)

        if distinctId == "" {
            distinctId = defaultDistinctId()
        }
    }

    func archiveProperties() {
        let properties = ArchivedProperties(superProperties: superProperties,
                                            timedEvents: timedEvents,
                                            distinctId: distinctId,
                                            peopleDistinctId: people.distinctId,
                                            peopleUnidentifiedQueue: people.unidentifiedQueue)
        Persistence.archiveProperties(properties, token: self.apiToken)
    }

    func trackIntegration() {
        let defaultsKey = "trackedKey"
        if !UserDefaults.standard.bool(forKey: defaultsKey) {
            serialQueue.async {
                Network.trackIntegration(apiToken: self.apiToken) {
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

// MARK: - Flush
extension MixpanelInstance {

    /**
     Uploads queued data to the Mixpanel server.

     By default, queued data is flushed to the Mixpanel servers every minute (the
     default for `flushInterval`), and on background (since
     `flushOnBackground` is on by default). You only need to call this
     method manually if you want to force a flush at a particular moment.

     - parameter completion: an optional completion handler for when the flush has completed.
     */
    public func flush(completion: (() -> Void)? = nil) {
        serialQueue.async {
            if let shouldFlush = self.delegate?.mixpanelWillFlush(self) , !shouldFlush {
                return
            }

            self.flushInstance.flushEventsQueue(&self.eventsQueue)
            self.flushInstance.flushPeopleQueue(&self.people.peopleQueue)
            self.archive()

            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}

// MARK: - Track
extension MixpanelInstance {

    /**
     Tracks an event with properties.
     Properties are optional and can be added only if needed.

     Properties will allow you to segment your events in your Mixpanel reports.
     Property keys must be String objects and the supported value types are:
     String, Int, UInt, Double, Float, [Any], [String: Any], Date, URL, and NSNull.
     If the event is being timed, the timer will stop and be added as a property.

     - parameter event:      event name
     - parameter properties: properties dictionary
     */
    public func track(event: String?, properties: Properties? = nil) {
        let epochInterval = Date().timeIntervalSince1970
        serialQueue.async {
            self.trackInstance.track(event: event,
                                     properties: properties,
                                     eventsQueue: &self.eventsQueue,
                                     timedEvents: &self.timedEvents,
                                     superProperties: self.superProperties,
                                     distinctId: self.distinctId,
                                     epochInterval: epochInterval)

            Persistence.archiveEvents(self.eventsQueue, token: self.apiToken)
        }
    }

    /**
     Track a push notification using its payload sent from Mixpanel.

     To simplify user interaction tracking, Mixpanel
     automatically sends IDs for the relevant notification of each push.
     This method parses the standard payload and queues a track call using this information.

     - parameter userInfo: remote notification payload dictionary
     - parameter event:    optional, and usually shouldn't be used,
     unless the results is needed to be tracked elsewhere.
     */
    public func trackPushNotification(_ userInfo: [AnyHashable: Any],
                                      event: String = "$campaign_received") {
        if let mpPayload = userInfo["mp"] as? Properties {
            if let m = mpPayload["m"], let c = mpPayload["c"] {
                let properties = ["campaign_id": c,
                                  "message_id": m,
                                  "message_type": "push"] as [String : Any]
                self.track(event: event,
                           properties: properties as Properties?)
            } else {
                Logger.error(message: "malformed mixpanel push payload")
            }
        }
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
        (serialQueue).async {
            self.trackInstance.time(event: event,
                                    timedEvents: &self.timedEvents,
                                    startTime: startTime)
        }
    }

    /**
     Clears all current event timers.
     */
    public func clearTimedEvents() {
        (serialQueue).async {
            self.trackInstance.clearTimedEvents(&self.timedEvents)
        }
    }

    /**
     Returns the currently set super properties.

     - returns: the current super properties
     */
    public func currentSuperProperties() -> Properties {
        return superProperties
    }

    /**
     Clears all currently set super properties.
     */
    public func clearSuperProperties() {
        dispatchAndTrack() {
            self.trackInstance.clearSuperProperties(&self.superProperties)
        }
    }

    /**
     Registers super properties, overwriting ones that have already been set.

     Super properties, once registered, are automatically sent as properties for
     all event tracking calls. They save you having to maintain and add a common
     set of properties to your events.
     Property keys must be String objects and the supported value types are:
     String, Int, UInt, Double, Float, [Any], [String: Any], Date, URL, and NSNull.

     - parameter properties: properties dictionary
     */
    public func registerSuperProperties(_ properties: Properties) {
        dispatchAndTrack() {
            self.trackInstance.registerSuperProperties(properties,
                                                       superProperties: &self.superProperties)
        }
    }

    /**
     Registers super properties without overwriting ones that have already been set,
     unless the existing value is equal to defaultValue. defaultValue is optional.

     Property keys must be String objects and the supported value types are:
     String, Int, UInt, Double, Float, [Any], [String: Any], Date, URL, and NSNull.

     - parameter properties:   properties dictionary
     - parameter defaultValue: Optional. overwrite existing properties that have this value
     */
    public func registerSuperPropertiesOnce(_ properties: Properties,
                                            defaultValue: Any? = nil) {
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
    public func unregisterSuperProperty(_ propertyName: String) {
        dispatchAndTrack() {
            self.trackInstance.unregisterSuperProperty(propertyName,
                                                       superProperties: &self.superProperties)
        }
    }

    func dispatchAndTrack(_ closure: @escaping () -> ()) {
        serialQueue.async {
            closure()
            self.archiveProperties()
        }
    }
}
