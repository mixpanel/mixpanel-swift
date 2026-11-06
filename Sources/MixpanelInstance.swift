//
//  MixpanelInstance.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import MixpanelSwiftCommon

#if !os(OSX)
import UIKit
#else
import Cocoa
#endif  // os(OSX)
#if os(iOS)
import SystemConfiguration
#endif

#if os(iOS)
import CoreTelephony
#endif  // os(iOS)

private let devicePrefix = "$device:"
let companyIdGroupKey = "$company_id"

/// Delegate protocol for updating the Proxy Server API's network behavior.
public protocol MixpanelProxyServerDelegate: AnyObject {
    /**
       Asks the delegate to return API resource items like query params & headers for proxy Server.

       - parameter mixpanel: The mixpanel instance

       - returns: return ServerProxyResource to give custom headers and query params.
       */
    func mixpanelResourceForProxyServer(_ name: String) -> ServerProxyResource?
}

/// Delegate protocol for controlling the Mixpanel API's network behavior.
public protocol MixpanelDelegate: AnyObject {
    /**
       Asks the delegate if data should be uploaded to the server.

       - parameter mixpanel: The mixpanel instance

       - returns: return true to upload now or false to defer until later
       */
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool
}

public typealias Properties = [String: MixpanelType]

/// Names who events, profile updates and replays belong to: a user, their company on a
/// hierarchical groups project, and the device. Defined in MixpanelSwiftCommon so other Mixpanel
/// SDKs, such as Session Replay, share it, and available with `import Mixpanel` alone.
public typealias MixpanelIdentity = MixpanelSwiftCommon.MixpanelIdentity

typealias InternalProperties = [String: Any]
typealias Queue = [InternalProperties]

protocol AppLifecycle {
    func applicationDidBecomeActive()
    func applicationWillResignActive()
}

public struct ProxyServerConfig {
    public init?(serverUrl: String, delegate: MixpanelProxyServerDelegate? = nil) {
        /// check if proxy server is not same as default mixpanel API
        /// if same, then fail the initializer
        /// this is to avoid case where client might inadvertently use headers intended for the proxy server
        /// on Mixpanel's default server, leading to unexpected behavior.
        guard serverUrl != BasePath.DefaultMixpanelAPI else { return nil }
        self.serverUrl = serverUrl
        self.delegate = delegate
    }

    let serverUrl: String
    let delegate: MixpanelProxyServerDelegate?
}

/// The class that represents the Mixpanel Instance
open class MixpanelInstance: CustomDebugStringConvertible, FlushDelegate, AEDelegate,
    MixpanelFlagDelegate
{

    private let options: MixpanelOptions

    /// apiToken string that identifies the project to track data to
    open var apiToken = ""

    /// The a MixpanelDelegate object that gives control over Mixpanel network activity.
    open weak var delegate: MixpanelDelegate?

    /// The distinct id Mixpanel resolves the current user to. Before any calls to `identify`,
    /// this is `$device:` followed by the device id.
    ///
    /// On a hierarchical groups project Mixpanel builds the distinct id from the company and the
    /// user, so once both are known this returns `$company:{companyId}|$user:{userId}`. Until a
    /// company is known, Mixpanel ignores the user id and keeps the user under the device, so
    /// this returns the device form. The combined form is Mixpanel's own format, and it cannot be
    /// parsed back when either id contains `|`. Events always send the id passed to `identify`.
    ///
    /// Don't use this on a hierarchical groups project, where setting it is a no-op with an error
    /// log. Prefer ``identity``, whose user, company and device ids every Mixpanel SDK accepts
    /// directly.
    open var distinctId: String {
        get {
            return resolvedDistinctId()
        }
        set {
            guard !hierarchicalGroups else {
                MixpanelLogger.error(
                    message:
                        "Setting distinctId is not supported for hierarchical groups projects, which identify a "
                        + "user by company and user id. Use identify(identity: MixpanelIdentity(userId:companyId:)). "
                        + "The distinct id was not changed.")
                return
            }
            readWriteLock.write {
                eventsDistinctId = newValue
            }
        }
    }

    /// The distinct id events are sent with: the id passed to `identify`, or the device form
    /// before that.
    var eventsDistinctId = ""

    /// anonymousId string that uniquely identifies the device.
    open var anonymousId: String?

    /// userId string that identify is called with.
    open var userId: String?

    /// The company identify was called with, on a hierarchical groups project.
    var companyId: String?

    /// hadPersistedDistinctId is a boolean value which specifies that the stored distinct_id
    /// already exists in persistence
    open var hadPersistedDistinctId: Bool?

    /// alias string that uniquely identifies the current user.
    open var alias: String?

    /// Accessor to the Mixpanel People API object.
    open var people: People!

    /// Accessor to the Mixpanel Autocapture API object.
    open var autocapture: Autocapture!

    #if os(iOS) && !targetEnvironment(macCatalyst)
    /// Autocapture manager for click, rage click, and dead click detection.
    /// Not available on Mac Catalyst, where automatic capture is unsupported.
    var autocaptureManager: AutocaptureManager?
    #endif

    /// Accessor the Mixpanel Feature Flags API object.
    open var flags: MixpanelFlags!

    let mixpanelPersistence: MixpanelPersistence

    /// Accessor to the Mixpanel People API object.
    var groups: [String: Group] = [:]

    /// Controls whether to show spinning network activity indicator when flushing
    /// data to the Mixpanel servers. Defaults to true.
    open var showNetworkActivityIndicator = true

    /// This allows enabling or disabling collecting common mobile events,
    @available(
        *, deprecated,
        message:
            "Automatic Events are deprecated and will be removed in a future major version. Use autocaptureOptions instead."
    )
    open var trackAutomaticEventsEnabled: Bool

    /// Flush timer's interval.
    /// Setting a flush interval of 0 will turn off the flush timer and you need to call the flush() API manually
    /// to upload queued data to the Mixpanel server.
    /// As of SDK version 6.8.0, setting an interval of 0 no longer triggers a flush.
    ///
    /// Deprecated as of SDK version 6.8.0: set the interval with `MixpanelOptions.flushInterval`
    /// when initializing instead.
    @available(
        *, deprecated,
        message:
            "Configure flushInterval through MixpanelOptions during initialization. This property will become private in a future release."
    )
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
            flushInstance.serverURL = serverURL
        }
    }

    /// Optional fallback host used only when a request to the primary ``serverURL`` fails to
    /// connect (or the server returns an error other than a 4xx client error). Defaults to `nil`
    /// (no fallback). Mirrors the Android SDK's `setBackupHost`.
    ///
    /// **How It Works:**
    /// When the primary request fails, the SDK automatically retries the **same request** against
    /// the backup host, preserving:
    /// - The original request path (e.g., `/track/`, `/engage/`)
    /// - All HTTP headers (including authentication headers from proxy configuration)
    /// - All query parameters
    /// - The request body
    /// - The primary URL's scheme (http/https) and port
    ///
    /// Only the **hostname** is replaced. The backup host receives an identical request to what
    /// the primary host would have received.
    ///
    /// **Authentication & Proxy Behavior:**
    /// - **Standard Mixpanel API**: If `serverURL` is `https://api.mixpanel.com`, both primary
    ///   and backup requests use Mixpanel's standard authentication (token in the request body).
    /// - **Proxy Server**: If `serverURL` points to your proxy (configured via `proxyServerConfig`),
    ///   both primary and backup requests include your proxy's custom authentication headers
    ///   (provided by `MixpanelProxyServerDelegate.mixpanelResourceForProxyServer`).
    ///
    /// The backup host must support the same API contract and authentication scheme as your
    /// primary `serverURL`.
    ///
    /// **When Backup is Used:**
    /// - Network failures (connection timeout, DNS resolution failure, etc.)
    /// - Non-4xx HTTP errors
    ///
    /// **When Backup is NOT Used:**
    /// - Client errors (4xx status codes) — these indicate a problem with the request itself,
    ///   so retrying against a different host won't help
    /// - Successful responses (200 OK)
    /// - Parse errors (response received but couldn't be parsed)
    ///
    /// **Example 1 — Standard Mixpanel with Backup:**
    /// ```swift
    /// let mixpanel = Mixpanel.initialize(token: "YOUR_TOKEN")
    /// mixpanel.backupHost = "api-backup.mixpanel.com"
    /// // Primary: https://api.mixpanel.com/track/
    /// // Backup:  https://api-backup.yourcompany.com/track/
    /// // Both use token-based auth from the request body
    /// ```
    ///
    /// **Example 2 — Proxy Server with Backup:**
    /// ```swift
    /// class MyProxyDelegate: MixpanelProxyServerDelegate {
    ///     func mixpanelResourceForProxyServer(_ name: String) -> ServerProxyResource? {
    ///         return ServerProxyResource(headers: ["Authorization": "Bearer YOUR_TOKEN"])
    ///     }
    /// }
    ///
    /// let proxyConfig = ProxyServerConfig(
    ///     serverUrl: "https://proxy.yourcompany.com",
    ///     delegate: MyProxyDelegate()
    /// )
    /// let options = MixpanelOptions(
    ///     token: "YOUR_TOKEN",
    ///     proxyServerConfig: proxyConfig
    /// )
    /// let mixpanel = Mixpanel.initialize(options: options)
    /// mixpanel.backupHost = "proxy-backup.yourcompany.com"
    /// // Primary: https://proxy.yourcompany.com/track/
    /// //          Headers: Authorization: Bearer YOUR_TOKEN
    /// // Backup:  https://proxy-backup.yourcompany.com/track/
    /// //          Headers: Authorization: Bearer YOUR_TOKEN (same auth headers)
    /// ```
    ///
    /// - Note: Provide just the hostname (e.g., `"api-backup.mixpanel.com"`). If you provide
    ///   a full URL (e.g., `"https://api-backup.mixpanel.com"`), only the hostname portion
    ///   will be extracted and used.
    open var backupHost: String? = nil {
        didSet {
            flushInstance.backupHost = backupHost
        }
    }

    open var useGzipCompression: Bool = false {
        didSet {
            flushInstance.useGzipCompression = useGzipCompression
        }
    }

    /// The a MixpanelProxyServerDelegate object that gives config control over Proxy Server's network activity.
    open weak var proxyServerDelegate: MixpanelProxyServerDelegate? = nil

    open var debugDescription: String {
        return "Mixpanel(\n"
            + "    Token: \(apiToken),\n"
            + "    Distinct Id: \(eventsDistinctId)\n"
            + ")"
    }

    /// This allows enabling or disabling of all Mixpanel logs at run time.
    /// - Note: All logging is disabled by default. Usually, this is only required
    ///         if you are running in to issues with the SDK and you need support.
    open var loggingEnabled: Bool = false {
        didSet {
            if loggingEnabled {
                MixpanelLogger.enableLevel(.debug)
                MixpanelLogger.enableLevel(.info)
                MixpanelLogger.enableLevel(.warning)
                MixpanelLogger.enableLevel(.error)
                MixpanelLogger.info(message: "MixpanelLogging Enabled")
            } else {
                MixpanelLogger.info(message: "MixpanelLogging Disabled")
                MixpanelLogger.disableLevel(.debug)
                MixpanelLogger.disableLevel(.info)
                MixpanelLogger.disableLevel(.warning)
                MixpanelLogger.disableLevel(.error)
            }
            #if DEBUG
            var trackProps: Properties = ["MixpanelLogging Enabled": loggingEnabled]
            if superProperties["mp_lib"] != nil {
                trackProps["mp_lib"] = self.superProperties["mp_lib"] as! String
            }
            if superProperties["$lib_version"] != nil {
                trackProps["$lib_version"] = self.superProperties["$lib_version"] as! String
            }
            #endif
        }
    }

    /// A unique identifier for this MixpanelInstance
    public let name: String

    /// The minimum session duration (ms) that is tracked in automatic events.
    /// The default value is 10000 (10 seconds).
    #if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
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

    // Flush loop state. Read and written only on `trackingQueue`.
    private var isFlushing = false
    private var hasPendingFlush = false
    private var pendingFlushCompletion: (() -> Void)?

    var optOutStatus: Bool?
    var useUniqueDistinctId: Bool
    var timedEvents = InternalProperties()

    let readWriteLock: ReadWriteLock
    #if os(iOS) && !targetEnvironment(macCatalyst)
    var reachability: SCNetworkReachability?
    static let telephonyInfo = CTTelephonyNetworkInfo()
    #endif
    #if !os(OSX) && !os(watchOS)
    var taskId = UIBackgroundTaskIdentifier.invalid
    #endif  // os(OSX)
    let sessionMetadata: SessionMetadata
    let flushInstance: Flush
    let trackInstance: Track
    #if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
    let automaticEvents = AutomaticEvents()
    #endif
    private let registerSuperPropertiesNotificationName = Notification.Name(
        "com.mixpanel.properties.register")
    private let unregisterSuperPropertiesNotificationName = Notification.Name(
        "com.mixpanel.properties.unregister")

    convenience init(options: MixpanelOptions) {
        self.init(
            apiToken: options.token,
            flushInterval: options.flushInterval,
            name: options.instanceName ?? options.token,
            trackAutomaticEvents: options.trackAutomaticEvents,
            optOutTrackingByDefault: options.optOutTrackingByDefault,
            useUniqueDistinctId: options.useUniqueDistinctId,
            superProperties: options.superProperties,
            serverURL: options.serverURL,
            proxyServerDelegate: options.proxyServerConfig?.delegate,
            useGzipCompression: options.useGzipCompression,
            options: options)
    }

    convenience init(
        apiToken: String?,
        flushInterval: Double,
        name: String,
        trackAutomaticEvents: Bool,
        optOutTrackingByDefault: Bool = false,
        useUniqueDistinctId: Bool = false,
        superProperties: Properties? = nil,
        proxyServerConfig: ProxyServerConfig,
        useGzipCompression: Bool = false
    ) {
        self.init(
            apiToken: apiToken,
            flushInterval: flushInterval,
            name: name,
            trackAutomaticEvents: trackAutomaticEvents,
            optOutTrackingByDefault: optOutTrackingByDefault,
            useUniqueDistinctId: useUniqueDistinctId,
            superProperties: superProperties,
            serverURL: proxyServerConfig.serverUrl,
            proxyServerDelegate: proxyServerConfig.delegate,
            useGzipCompression: useGzipCompression)
    }

    convenience init(
        apiToken: String?,
        flushInterval: Double,
        name: String,
        trackAutomaticEvents: Bool,
        optOutTrackingByDefault: Bool = false,
        useUniqueDistinctId: Bool = false,
        superProperties: Properties? = nil,
        serverURL: String? = nil,
        useGzipCompression: Bool = false
    ) {
        self.init(
            apiToken: apiToken,
            flushInterval: flushInterval,
            name: name,
            trackAutomaticEvents: trackAutomaticEvents,
            optOutTrackingByDefault: optOutTrackingByDefault,
            useUniqueDistinctId: useUniqueDistinctId,
            superProperties: superProperties,
            serverURL: serverURL,
            proxyServerDelegate: nil,
            useGzipCompression: useGzipCompression)
    }

    private init(
        apiToken: String?,
        flushInterval: Double,
        name: String,
        trackAutomaticEvents: Bool,
        optOutTrackingByDefault: Bool = false,
        useUniqueDistinctId: Bool = false,
        superProperties: Properties? = nil,
        serverURL: String? = nil,
        proxyServerDelegate: MixpanelProxyServerDelegate? = nil,
        useGzipCompression: Bool = false,
        options: MixpanelOptions? = nil
    ) {
        // Store the config if provided, otherwise create one with the current values
        self.options =
            options
            ?? MixpanelOptions(
                token: apiToken ?? "",
                flushInterval: flushInterval,
                instanceName: name,
                trackAutomaticEvents: trackAutomaticEvents,
                optOutTrackingByDefault: optOutTrackingByDefault,
                useUniqueDistinctId: useUniqueDistinctId,
                superProperties: superProperties,
                serverURL: serverURL,
                useGzipCompression: useGzipCompression
            )

        if let apiToken = apiToken, !apiToken.isEmpty {
            self.apiToken = apiToken
        }
        trackAutomaticEventsEnabled = trackAutomaticEvents
        // Capture UI properties (screen size) that require main thread access.
        // This is called here to ensure $ae_first_open event includes screen size.
        AutomaticProperties.setUIProperties()

        if let serverURL = serverURL {
            self.serverURL = serverURL
        }
        self.useGzipCompression = useGzipCompression
        self.proxyServerDelegate = proxyServerDelegate
        let label = "com.mixpanel.\(self.apiToken)"
        trackingQueue = DispatchQueue(
            label: "\(label).tracking)", qos: .utility, autoreleaseFrequency: .workItem)
        networkQueue = DispatchQueue(
            label: "\(label).network)", qos: .utility, autoreleaseFrequency: .workItem)
        self.name = name

        mixpanelPersistence = MixpanelPersistence.init(instanceName: name)
        mixpanelPersistence.migrate()
        self.useUniqueDistinctId = useUniqueDistinctId

        readWriteLock = ReadWriteLock(label: "com.mixpanel.globallock")
        flushInstance = Flush(serverURL: self.serverURL, useGzipCompression: useGzipCompression)
        sessionMetadata = SessionMetadata(trackingQueue: trackingQueue)
        // Hierarchical groups ingestion requires $company_id, so it is never stripped there
        var excludeProperties = self.options.excludeProperties
        if self.options.hierarchicalGroups {
            excludeProperties.remove(companyIdGroupKey)
        }
        MixpanelInstance.warnIfStrippingLibProperties(excludeProperties)
        trackInstance = Track(
            apiToken: self.apiToken,
            instanceName: self.name,
            lock: self.readWriteLock,
            metadata: sessionMetadata,
            mixpanelPersistence: mixpanelPersistence,
            excludeProperties: excludeProperties)
        trackInstance.mixpanelInstance = self
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Extract hostname from serverURL and create reachability
        if let url = URL(string: self.serverURL),
            let host = url.host
        {
            self.reachability = SCNetworkReachabilityCreateWithName(nil, host)
        }
        if let reachability = self.reachability {
            var context = SCNetworkReachabilityContext(
                version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
            func reachabilityCallback(
                reachability: SCNetworkReachability,
                flags: SCNetworkReachabilityFlags,
                unsafePointer: UnsafeMutableRawPointer?
            ) {
                let wifi =
                    flags.contains(SCNetworkReachabilityFlags.reachable)
                    && !flags.contains(SCNetworkReachabilityFlags.isWWAN)
                AutomaticProperties.automaticPropertiesLock.write {
                    AutomaticProperties.properties["$wifi"] = wifi
                }
                MixpanelLogger.info(message: "reachability changed, wifi=\(wifi)")
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
        eventsDistinctId = devicePrefix + defaultDeviceId()
        people = People(
            apiToken: self.apiToken,
            serialQueue: trackingQueue,
            lock: self.readWriteLock,
            metadata: sessionMetadata, mixpanelPersistence: mixpanelPersistence,
            excludeProperties: excludeProperties)
        people.mixpanelInstance = self
        people.delegate = self
        autocapture = Autocapture()
        autocapture.mixpanelInstance = self
        #if !os(watchOS)
        setupListeners()
        #endif
        unarchive()

        // Construct FeatureFlagManager AFTER unarchive() so the on-disk cache load (dispatched
        // async by FeatureFlagManager.init when a caching policy is configured) reads the
        // correct distinctId via `delegate.getDistinctId()`. Constructing earlier would race the
        // async cache load against the synchronous distinctId initialization in unarchive() —
        // a worker thread could pick up the cache-load block and read distinctId == "", computing
        // the wrong fingerprint and silently ignoring an otherwise-valid cache. Nothing between
        // here and `flags.loadFlags()` below references `flags`.
        flags = FeatureFlagManager(
            serverURL: self.serverURL,
            trackingQueue: self.trackingQueue,
            instanceName: self.name,
            delegate: self
        )

        // check whether we should opt out by default
        // note: we don't override opt out persistence here since opt-out default state is often
        // used as an initial state while GDPR information is being collected
        if optOutTrackingByDefault && (hasOptedOutTracking() || optOutStatus == nil) {
            optOutTracking()
        }

        flushInstance.flushInterval = flushInterval

        // Initialize autocapture if enabled (iOS only, excluding Mac Catalyst)
        // Done after opt-out check so autocapture is not started when tracking is opted out.
        // Note: optOutTracking() runs async on trackingQueue, so hasOptedOutTracking() may
        // not reflect the default yet. Check optOutTrackingByDefault directly as well.
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if let autocaptureOpts = self.options.autocaptureOptions, autocaptureOpts.isEnabled {
            if optOutTrackingByDefault || hasOptedOutTracking() {
                MixpanelLogger.info(message: "Autocapture disabled: tracking is opted out")
            } else if MixpanelInstance.isiOSAppExtension() {
                MixpanelLogger.info(message: "Autocapture disabled in app extension")
            } else {
                autocaptureManager = AutocaptureManager(
                    options: autocaptureOpts,
                    autocapture: autocapture
                )
                autocaptureManager?.start()
                MixpanelLogger.info(message: "AutocaptureManager started")
            }
        }
        #elseif os(iOS) && targetEnvironment(macCatalyst)
        if let autocaptureOpts = self.options.autocaptureOptions, autocaptureOpts.isEnabled {
            MixpanelLogger.info(message: "Autocapture is not supported on Mac Catalyst")
        }
        #endif

        if let superProperties = superProperties {
            registerSuperProperties(superProperties)
        }

        #if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
        if !MixpanelInstance.isiOSAppExtension() && trackAutomaticEvents {
            automaticEvents.delegate = self
            // Defer automatic events initialization to the next run loop iteration
            // to avoid interfering with SwiftUI's accent color setup when
            // Mixpanel.initialize() is called from a SwiftUI App's init().
            // See: https://github.com/mixpanel/mixpanel-swift/issues/522
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.automaticEvents.initializeEvents(instanceName: self.name)
            }
        }
        #endif
        if self.options.featureFlagOptions.prefetchFlags {
            flags.loadFlags()
        }

    }

    public func getOptions() -> MixpanelOptions {
        return options
    }

    /// Returns the distinct id Mixpanel resolves the current user to. See ``distinctId``. Don't use
    /// this on a hierarchical groups project; prefer ``identity``.
    public func getDistinctId() -> String {
        return resolvedDistinctId()
    }

    /// Whether this instance tracks for a hierarchical groups project. Fixed for the life of the
    /// instance.
    var hierarchicalGroups: Bool {
        return options.hierarchicalGroups
    }

    func resolvedDistinctId() -> String {
        var resolved = ""
        readWriteLock.read {
            resolved = eventsDistinctId
            guard hierarchicalGroups, let userId = userId else {
                // Anonymous, so already $device:{deviceId}
                return
            }
            if let companyId = companyId {
                resolved = "$company:\(companyId)|$user:\(userId)"
            } else if let anonymousId = anonymousId {
                // Mixpanel ignores a user id without a company while the event carries a device id
                resolved = devicePrefix + anonymousId
            }
        }
        return resolved
    }

    /// Who events are currently attributed to: the identified user, their company on a
    /// hierarchical groups project, and the device id. Pass it to other Mixpanel SDKs, such as
    /// Session Replay, so their data resolves to the same user.
    ///
    /// Before `identify` the user id is nil and only the device id is set. The returned identity
    /// is a snapshot and does not change after a later `identify` or `reset()`.
    open var identity: MixpanelIdentity {
        var snapshot = MixpanelIdentity(userId: nil)
        readWriteLock.read {
            snapshot = MixpanelIdentity(userId: userId, companyId: companyId, deviceId: anonymousId)
        }
        return snapshot
    }

    public func getAnonymousId() -> String? {
        return anonymousId
    }

    #if !os(OSX) && !os(watchOS)
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
        #if os(iOS) && !targetEnvironment(macCatalyst)
        setCurrentRadio()
        // Temporarily remove the ability to monitor the radio change due to a crash issue might relate to the api from Apple
        // https://openradar.appspot.com/46873673
        //    notificationCenter.addObserver(self,
        //                                   selector: #selector(setCurrentRadio),
        //                                   name: .CTRadioAccessTechnologyDidChange,
        //                                   object: nil)
        #endif  // os(iOS)
        if !MixpanelInstance.isiOSAppExtension() {
            notificationCenter.addObserver(
                self,
                selector: #selector(applicationWillResignActive(_:)),
                name: UIApplication.willResignActiveNotification,
                object: nil)
            notificationCenter.addObserver(
                self,
                selector: #selector(applicationDidBecomeActive(_:)),
                name: UIApplication.didBecomeActiveNotification,
                object: nil)
            notificationCenter.addObserver(
                self,
                selector: #selector(applicationDidEnterBackground(_:)),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil)
            notificationCenter.addObserver(
                self,
                selector: #selector(applicationWillEnterForeground(_:)),
                name: UIApplication.willEnterForegroundNotification,
                object: nil)
            notificationCenter.addObserver(
                self,
                selector: #selector(handleSuperPropertiesRegistrationNotification(_:)),
                name: registerSuperPropertiesNotificationName,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(handleSuperPropertiesRegistrationNotification(_:)),
                name: unregisterSuperPropertiesNotificationName,
                object: nil
            )
        }
    }
    #elseif os(OSX)
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillResignActive(_:)),
            name: NSApplication.willResignActiveNotification,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil)
    }
    #endif  // os(OSX)

    deinit {
        NotificationCenter.default.removeObserver(self)
        #if os(iOS) && !targetEnvironment(macCatalyst)
        autocaptureManager?.stop()
        #endif
        #if os(iOS) && !os(watchOS) && !targetEnvironment(macCatalyst)
        if let reachability = self.reachability {
            if !SCNetworkReachabilitySetCallback(reachability, nil, nil) {
                MixpanelLogger.error(message: "\(self) error unsetting reachability callback")
            }
            if !SCNetworkReachabilitySetDispatchQueue(reachability, nil) {
                MixpanelLogger.error(message: "\(self) error unsetting reachability dispatch queue")
            }
        }
        #endif
    }

    static func isiOSAppExtension() -> Bool {
        return Bundle.main.bundlePath.hasSuffix(".appex")
    }

    private static func warnIfStrippingLibProperties(_ excludeProperties: Set<String>) {
        if excludeProperties.contains("mp_lib") || excludeProperties.contains("$lib_version") {
            MixpanelLogger.warn(
                message:
                    "MixpanelOptions.excludeProperties is stripping 'mp_lib' and/or '$lib_version'. "
                    + "These are not required for ingestion or identity, but Mixpanel uses them to "
                    + "identify the SDK source and version of each event — stripping them is not "
                    + "recommended.")
        }
    }

    #if !os(OSX) && !os(watchOS)
    static func sharedUIApplication() -> UIApplication? {
        guard
            let sharedApplication =
                UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue()
                as? UIApplication
        else {
            return nil
        }
        return sharedApplication
    }
    #endif  // !os(OSX)

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

        // Ensure that any session replay ID is cleared when the app enters the background
        unregisterSuperProperty("$mp_replay_id")

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
            #endif  // os(iOS)
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
        // Check if a custom device ID provider is set
        if let provider = options.deviceIdProvider {
            if let providedId = provider()?.trimmingCharacters(in: .whitespacesAndNewlines),
                !providedId.isEmpty
            {
                return providedId
            }
            // Fall through to default behavior if nil or empty
            MixpanelLogger.warn(
                message: "deviceIdProvider returned nil or empty string, using default device ID")
        }

        // Default behavior: use IDFV or random UUID
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
        return distinctId ?? UUID().uuidString  // use a random UUID by default
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
        let platformExpert: io_service_t = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        let serialNumberAsCFString =
            IORegistryEntryCreateCFProperty(
                platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return (serialNumberAsCFString?.takeUnretainedValue() as? String)
    }
    #endif  // os(OSX)

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

            radio = radio.isEmpty ? "None" : radio
        }

        trackingQueue.async {
            AutomaticProperties.automaticPropertiesLock.write { [weak self, radio] in
                AutomaticProperties.properties["$radio"] = radio

                guard self != nil else {
                    return
                }

                AutomaticProperties.properties["$carrier"] = ""
                if let carrierName = MixpanelInstance.telephonyInfo
                    .serviceSubscriberCellularProviders?.first?.value.carrierName, carrierName != "--"
                {
                    AutomaticProperties.properties["$carrier"] = carrierName
                }
            }
        }
    }
    #endif
    #endif  // os(iOS)

    @objc func handleSuperPropertiesRegistrationNotification(_ notification: Notification) {
        guard let data = notification.userInfo else { return }

        if notification.name.rawValue == registerSuperPropertiesNotificationName.rawValue {
            guard let properties = data as? Properties else { return }
            registerSuperProperties(properties)
        } else {
            for (key, _) in data {
                if let keyToUnregister = key as? String {
                    unregisterSuperProperty(keyToUnregister)
                }
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

       When the distinct ID actually changes, this method also resets feature-flag state
       (in-memory variants, on-disk cache, and activated first-time-event set) before fetching
       flags under the new identity. Any `flags.loadFlags(completion:)` callbacks pending from
       a fetch that was in flight at the moment identify was called will fire with `false`
       (so callers don't hang) — they will *not* receive the result of the new identity's fetch.

       Not supported on a hierarchical groups project, which identifies a user by company and user
       id, so it is logged and ignored there. Use `identify(identity:)` instead.

       - parameter distinctId: string that uniquely identifies the current user
       - parameter usePeople: boolean that controls whether or not to set the people distinctId to the event distinctId.
       This should only be set to false if you wish to prevent people profile updates for that user.
       - parameter completion: an optional completion handler for when the identify has completed.
       */
    public func identify(distinctId: String, usePeople: Bool = true, completion: (() -> Void)? = nil) {
        if hierarchicalGroups {
            MixpanelLogger.error(
                message:
                    "identify(distinctId:) is not supported for hierarchical groups projects, which identify a "
                    + "user by company and user id. Use identify(identity: MixpanelIdentity(userId:companyId:)). "
                    + "Nothing was identified.")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        identify(distinctId: distinctId, companyId: nil, usePeople: usePeople, completion: completion)
    }

    /**
       Associates all future events and `People` updates with the given identity.

       On a project that uses hierarchical groups, enabled with `MixpanelOptions.hierarchicalGroups`,
       identify with both a user and a company. Mixpanel builds the user's distinct id from
       `$company_id` and `$user_id`, so the company is part of the user's identity: the same user id
       in two companies is two users. Every later event carries `$company_id` beside `$user_id` and
       `$device_id`, and `People` updates go to that company's `$user_id` group profile. Both ids
       persist across restarts until the next identify or `reset()`.

       ```swift
       mixpanel.identify(identity: MixpanelIdentity(userId: "user_123", companyId: "acme"))
       ```

       Calling this with the current user and a different company is an identity change, as switching
       users is. No `$identify` event is tracked: Mixpanel ties the device to the user from the
       `$device_id`, `$user_id` and `$company_id` on later events. An identity without both a user id
       and a company id is logged and ignored.

       On any other project Mixpanel ignores `$company_id`, so an identity that names a company is
       logged and ignored rather than attributed without it. An identity with a nil or empty user id
       is also logged and ignored.

       The SDK owns the device id, which stays the same across identifies so earlier anonymous
       activity follows the user. A `deviceId` on the identity is ignored, with a warning when it
       differs from `anonymousId`; set the device id with `MixpanelOptions.deviceIdProvider`.

       - parameter identity: the user, and on a hierarchical groups project their company
       - parameter completion: an optional completion handler for when the identify has completed.
       */
    public func identify(identity: MixpanelIdentity, completion: (() -> Void)? = nil) {
        let finish = {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
        if hasOptedOutTracking() {
            finish()
            return
        }
        let userId = identity.userId ?? ""
        let companyId = identity.companyId
        if hierarchicalGroups {
            if userId.isEmpty || (companyId ?? "").isEmpty {
                MixpanelLogger.error(
                    message:
                        "Can't identify \(identity): hierarchical groups projects identify a user by "
                        + "company and user id, so both are required. Nothing was identified.")
                finish()
                return
            }
        } else {
            if userId.isEmpty {
                MixpanelLogger.error(
                    message: "Can't identify \(identity) without a user id. Nothing was identified.")
                finish()
                return
            }
            if companyId != nil {
                MixpanelLogger.error(
                    message:
                        "Can't identify \(identity): a company requires hierarchicalGroups: true in "
                        + "MixpanelOptions. Mixpanel ignores $company_id on other projects, so nothing "
                        + "was identified.")
                finish()
                return
            }
        }
        let currentDeviceId = getAnonymousId()
        if let deviceId = identity.deviceId, deviceId != currentDeviceId {
            MixpanelLogger.warn(
                message:
                    "Ignoring deviceId \(deviceId) on \(identity). The SDK owns the device id "
                    + "(\(currentDeviceId ?? "none")) so earlier anonymous events follow the user; set it "
                    + "with MixpanelOptions.deviceIdProvider.")
        }
        identify(distinctId: userId, companyId: companyId, usePeople: true, completion: completion)
    }

    private func identify(
        distinctId: String, companyId: String?, usePeople: Bool, completion: (() -> Void)?
    ) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        if distinctId.isEmpty {
            MixpanelLogger.error(message: "\(self) cannot identify blank distinct id")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        trackingQueue.async { [weak self, distinctId, companyId, usePeople] in
            guard let self = self else { return }

            // If there's no anonymousId assigned yet, that means distinctId is stored in the storage. Assigning already stored
            // distinctId as anonymousId on identify and also setting a flag to notify that it might be previously logged in user
            if self.anonymousId == nil {
                self.anonymousId = self.eventsDistinctId
                self.hadPersistedDistinctId = true
            }

            if self.userId == nil {
                self.readWriteLock.write {
                    self.userId = distinctId
                }
            }

            let userChanged = distinctId != self.eventsDistinctId
            // A user in another company is another user, so a new company is an identity change.
            let companyChanged = self.hierarchicalGroups && companyId != nil && companyId != self.companyId
            if userChanged || companyChanged {
                let oldDistinctId = self.eventsDistinctId
                self.readWriteLock.write {
                    self.alias = nil
                    self.eventsDistinctId = distinctId
                    self.userId = distinctId
                    if self.hierarchicalGroups {
                        self.companyId = companyId
                    }
                }
                // Distinct ID just changed — clear in-memory feature-flag state and the on-disk
                // cache from the prior identity (and bump the fetch generation so any in-flight
                // fetch is discarded) before loading flags under the new identity. trackingQueue
                // FIFO guarantees the reset runs before the loadFlags-driven fetch.
                if let flagManager = self.flags as? FeatureFlagManager {
                    flagManager.reset()
                }
                self.flags.loadFlags()
                // A hierarchical groups project ties the device to the user from the identity keys on
                // later events, so it has no $identify
                if !self.hierarchicalGroups {
                    self.track(event: "$identify", properties: ["$anon_distinct_id": oldDistinctId])
                }
            }

            if usePeople {
                self.readWriteLock.write {
                    self.people.distinctId = distinctId
                }
                self.mixpanelPersistence.identifyPeople(distinctId: distinctId)
            } else {
                self.people.distinctId = nil
            }

            MixpanelPersistence.saveIdentity(
                StoredIdentity.init(
                    distinctID: self.eventsDistinctId,
                    peopleDistinctID: self.people.distinctId,
                    anonymousId: self.anonymousId,
                    userId: self.userId,
                    alias: self.alias,
                    hadPersistedDistinctId: self.hadPersistedDistinctId,
                    companyId: self.companyId), instanceName: self.name)
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

       A hierarchical groups project identifies a user by their company and user id, which an alias
       of one distinct id to another can't express, so this is dropped with an error log there. Use
       `identify(identity:)` instead.
       */
    public func createAlias(
        _ alias: String, distinctId: String, usePeople: Bool = true, andIdentify: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

        if hierarchicalGroups {
            MixpanelLogger.error(
                message:
                    "createAlias is not supported for hierarchical groups projects, which identify a user by "
                    + "company and user id. Use identify(identity: MixpanelIdentity(userId:companyId:)). "
                    + "The alias was dropped.")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

        if distinctId.isEmpty {
            MixpanelLogger.error(message: "\(self) cannot identify blank distinct id")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

        if alias.isEmpty {
            MixpanelLogger.error(message: "\(self) create alias called with empty alias")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }

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
                var companyIdSnapshot: String?

                self.readWriteLock.read {
                    distinctIdSnapshot = self.eventsDistinctId
                    peopleDistinctIDSnapshot = self.people.distinctId
                    anonymousIdSnapshot = self.anonymousId
                    userIdSnapshot = self.userId
                    aliasSnapshot = self.alias
                    hadPersistedDistinctIdSnapshot = self.hadPersistedDistinctId
                    companyIdSnapshot = self.companyId
                }

                MixpanelPersistence.saveIdentity(
                    StoredIdentity.init(
                        distinctID: distinctIdSnapshot!,
                        peopleDistinctID: peopleDistinctIDSnapshot,
                        anonymousId: anonymousIdSnapshot,
                        userId: userIdSnapshot,
                        alias: aliasSnapshot,
                        hadPersistedDistinctId: hadPersistedDistinctIdSnapshot,
                        companyId: companyIdSnapshot), instanceName: self.name)
            }

            let properties = ["distinct_id": distinctId, "alias": alias]
            track(event: "$create_alias", properties: properties)
            if andIdentify {
                identify(distinctId: distinctId, usePeople: usePeople)
            }
            flush(completion: completion)
        } else {
            MixpanelLogger.error(
                message: "alias: \(alias) matches distinctId: \(distinctId) - skipping api call.")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    /**
       Clears all stored properties including the distinct Id.
       Useful if your app's user logs out.

       As of SDK version 6.8.0, queued events and identified people updates are kept and sent
       under the identity they were tracked with. People updates queued before `identify()` are
       discarded.

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
                self.eventsDistinctId = self.addPrefixToDeviceId(deviceId: self.anonymousId)
                self.hadPersistedDistinctId = true
                self.userId = nil
                self.companyId = nil
                self.superProperties = InternalProperties()
                self.people.distinctId = nil
                self.alias = nil
            }

            // Queued events and identified people/group updates already carry their identity and
            // are sent by later flushes. Only people updates queued before identify are dropped:
            // their target identity was never known.
            self.mixpanelPersistence.removeUnidentifiedPeople()
            self.archive()

            // reset() does not call identify(), so the loadFlags() call inside identify() never
            // fires. Clear feature-flag state explicitly and refetch under the new identity if
            // prefetching is enabled. Defer the user-facing completion until the flag-manager
            // reset has actually drained — otherwise a customer calling a sync flag API from
            // their completion handler could observe pre-reset variants (the inner reset is
            // async on the same trackingQueue, so it'd run AFTER the outer block dispatched
            // completion to main).
            let flagManager = self.flags as? FeatureFlagManager
            let fireUserCompletion: () -> Void = {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
            }
            if let flagManager = flagManager {
                flagManager.reset {
                    if self.options.featureFlagOptions.prefetchFlags {
                        flagManager.loadFlags()
                    }
                    fireUserCompletion()
                }
            } else {
                fireUserCompletion()
            }
        }
    }
}

extension MixpanelInstance {
    // MARK: - Persistence

    public func archive() {
        self.readWriteLock.read {
            MixpanelPersistence.saveTimedEvents(timedEvents: timedEvents, instanceName: self.name)
            MixpanelPersistence.saveSuperProperties(
                superProperties: superProperties, instanceName: self.name)
            MixpanelPersistence.saveIdentity(
                StoredIdentity.init(
                    distinctID: eventsDistinctId,
                    peopleDistinctID: people.distinctId,
                    anonymousId: anonymousId,
                    userId: userId,
                    alias: alias,
                    hadPersistedDistinctId: hadPersistedDistinctId,
                    companyId: companyId), instanceName: self.name)
        }
    }

    func unarchive() {
        let didCreateIdentity = self.readWriteLock.write {
            optOutStatus = MixpanelPersistence.loadOptOutStatusFlag(instanceName: self.name)
            superProperties = MixpanelPersistence.loadSuperProperties(instanceName: self.name)
            timedEvents = MixpanelPersistence.loadTimedEvents(instanceName: self.name)
            let storedIdentity = MixpanelPersistence.loadIdentity(instanceName: self.name)
            (eventsDistinctId, people.distinctId, anonymousId, userId, alias, hadPersistedDistinctId) = (
                storedIdentity.distinctID,
                storedIdentity.peopleDistinctID,
                storedIdentity.anonymousId,
                storedIdentity.userId,
                storedIdentity.alias,
                storedIdentity.hadPersistedDistinctId
            )
            // Only a hierarchical groups project identifies with a company
            companyId = hierarchicalGroups ? storedIdentity.companyId : nil
            if eventsDistinctId.isEmpty {
                anonymousId = defaultDeviceId()
                eventsDistinctId = addPrefixToDeviceId(deviceId: anonymousId)
                hadPersistedDistinctId = true
                userId = nil
                companyId = nil
                return true
            } else {
                // Check if a deviceIdProvider is set and would return a different value
                // than the persisted anonymousId. This helps detect potential identity
                // discontinuity when adding a provider to an existing app.
                if options.deviceIdProvider != nil,
                    let existingId = anonymousId,
                    !existingId.isEmpty
                {
                    let providerValue = defaultDeviceId()
                    if providerValue != existingId {
                        MixpanelLogger.error(
                            message:
                                "deviceIdProvider returned '\(providerValue)' but existing anonymousId is '\(existingId)'. "
                                + "Using persisted value to preserve identity continuity. "
                                + "If you intended to change the device ID, call reset() after initialization.")
                    }
                }
                return false
            }
        }

        if didCreateIdentity {
            self.readWriteLock.read {
                MixpanelPersistence.saveIdentity(
                    StoredIdentity.init(
                        distinctID: eventsDistinctId,
                        peopleDistinctID: people.distinctId,
                        anonymousId: anonymousId,
                        userId: userId,
                        alias: alias,
                        hadPersistedDistinctId: hadPersistedDistinctId,
                        companyId: companyId), instanceName: self.name)
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

       As of SDK version 6.8.0, every flush sends the whole queue in batches of `flushBatchSize`,
       holding one batch in memory at a time. A flush requested while one is running is merged
       into a single follow-up flush.

       - parameter performFullFlush: Kept for compatibility. As of SDK version 6.8.0 it has no effect.
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
            if self.isFlushing {
                // One follow-up pass covers every flush requested meanwhile, but every caller's
                // completion must still fire, so completions are chained rather than replaced.
                self.hasPendingFlush = true
                if let completion = completion {
                    let earlier = self.pendingFlushCompletion
                    self.pendingFlushCompletion = {
                        earlier?()
                        completion()
                    }
                }
                return
            }
            self.startFlushPass(completion: completion)
        }
    }

    /// Must be called on `trackingQueue`.
    private func startFlushPass(completion: (() -> Void)?) {
        if let shouldFlush = delegate?.mixpanelWillFlush(self), !shouldFlush {
            finishFlushPass(completion: completion)
            return
        }
        isFlushing = true
        flushNextBatch([.events, .people, .groups], completion: completion)
    }

    /// Must be called on `trackingQueue`.
    private func finishFlushPass(completion: (() -> Void)?) {
        isFlushing = false
        if let completion = completion {
            DispatchQueue.main.async(execute: completion)
        }
        if hasPendingFlush {
            hasPendingFlush = false
            let pendingCompletion = pendingFlushCompletion
            pendingFlushCompletion = nil
            startFlushPass(completion: pendingCompletion)
        }
    }

    /// Reads one batch of the first remaining type on `trackingQueue`, sends it on `networkQueue`,
    /// then returns to `trackingQueue` to delete what was sent and read the next batch. Deleting
    /// and reading in the same block guarantees a batch is never read twice.
    /// Must be called on `trackingQueue`.
    private func flushNextBatch(_ types: ArraySlice<FlushType>, completion: (() -> Void)?) {
        guard let type = types.first, !hasOptedOutTracking() else {
            finishFlushPass(completion: completion)
            return
        }
        let batchSize = flushBatchSize
        let batch = mixpanelPersistence.loadEntitiesInBatch(
            type: persistenceTypeFromFlushType(type), batchSize: batchSize)
        if batch.isEmpty {
            MixpanelLogger.info(message: "No records found for \(type), moving to the next type")
            flushNextBatch(types.dropFirst(), completion: completion)
            return
        }
        let ids: [Int32] = batch.map { ($0["id"] as? Int32) ?? 0 }
        let isLastBatch = batch.count < batchSize

        networkQueue.async { [weak self] in
            guard let self = self else {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
                return
            }
            let result = self.sendBatch(batch, type: type)
            self.trackingQueue.async { [weak self] in
                guard let self = self else {
                    if let completion = completion {
                        DispatchQueue.main.async(execute: completion)
                    }
                    return
                }
                switch result {
                    case .sent, .dropped:
                        self.mixpanelPersistence.removeEntitiesInBatch(
                            type: self.persistenceTypeFromFlushType(type), ids: ids)
                        self.flushNextBatch(
                            isLastBatch ? types.dropFirst() : types, completion: completion)
                    case .failed:
                        // Keep the rows and try the remaining types, as before.
                        MixpanelLogger.info(message: "Flush failed for \(type), moving to the next type")
                        self.flushNextBatch(types.dropFirst(), completion: completion)
                    case .notAllowed:
                        self.finishFlushPass(completion: completion)
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

    /// Must be called on `networkQueue`.
    func sendBatch(_ batch: Queue, type: FlushType) -> FlushBatchResult {
        if hasOptedOutTracking() {
            return .notAllowed
        }
        let proxyServerResource = proxyServerDelegate?.mixpanelResourceForProxyServer(name)
        let headers: [String: String] = proxyServerResource?.headers ?? [:]
        let queryItems = proxyServerResource?.queryItems ?? []

        return flushInstance.sendBatch(batch, type: type, headers: headers, queryItems: queryItems)
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
        let epochInterval = Date().timeIntervalSince1970

        trackingQueue.async { [weak self, event, properties, epochInterval] in
            guard let self else {
                return
            }
            if self.hasOptedOutTracking() {
                return
            }
            var shadowTimedEvents = InternalProperties()
            var shadowSuperProperties = InternalProperties()

            self.readWriteLock.read {
                shadowTimedEvents = self.timedEvents
                shadowSuperProperties = self.superProperties
            }

            let storedIdentity = StoredIdentity.init(
                distinctID: self.eventsDistinctId,
                peopleDistinctID: nil,
                anonymousId: self.anonymousId,
                userId: self.userId,
                alias: nil,
                hadPersistedDistinctId: self.hadPersistedDistinctId,
                companyId: self.companyId)
            let timedEventsSnapshot = self.trackInstance.track(
                event: event,
                properties: properties,
                timedEvents: shadowTimedEvents,
                superProperties: shadowSuperProperties,
                storedIdentity: storedIdentity,
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

       A hierarchical groups project allows one group per group key, so a call with a list
       group value is dropped with an error log there.

       - parameter event:      event name
       - parameter properties: properties dictionary
       - parameter groups:     groups dictionary
       */
    public func trackWithGroups(event: String?, properties: Properties? = nil, groups: Properties?) {
        if hasOptedOutTracking() {
            return
        }

        if hierarchicalGroups, let groups = groups {
            // Hierarchical groups read a list as the name of one group, not as membership in each
            for (groupKey, groupID) in groups where groupID is [MixpanelType] || groupID is NSArray {
                MixpanelLogger.error(
                    message:
                        "trackWithGroups with a list is not supported for hierarchical groups projects, "
                        + "which allow one \(groupKey) per user. Use one group id per key. The event was dropped.")
                return
            }
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
                groups[key] = Group(
                    apiToken: apiToken,
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
            MixpanelLogger.info(message: "groups dictionary key collision: \(key)")
            let newGroup = Group(
                apiToken: apiToken,
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

    /**
       Returns the identified user's company profile on a hierarchical groups project, as a `Group`
       to set properties on. This is `getGroup(groupKey: "$company_id", groupID: companyId)` with
       the company from the last `identify(identity:)`.

       ```swift
       mixpanel.identify(identity: MixpanelIdentity(userId: "user_123", companyId: "acme")) {
           mixpanel.getCompany()?.set(property: "tier", to: "enterprise")
       }
       ```

       Only for projects that use hierarchical groups, enabled with
       `MixpanelOptions.hierarchicalGroups`. On any other project, or before a company is
       identified, this returns nil with an error log.

       The company is read when this is called, so a group kept across `reset()` or a new identify
       still updates the earlier company. `identify` completes asynchronously, so call this from its
       completion handler, or later, to see a company identified just before.

       - returns: the identified company's `Group`, or nil when there is no company
       */
    public func getCompany() -> Group? {
        guard hierarchicalGroups else {
            MixpanelLogger.error(
                message:
                    "getCompany() is only for hierarchical groups projects, enabled with "
                    + "hierarchicalGroups: true in MixpanelOptions.")
            return nil
        }
        guard let companyId = identity.companyId else {
            MixpanelLogger.error(
                message:
                    "getCompany() needs a company. Call identify(identity: MixpanelIdentity(userId:companyId:)) "
                    + "first.")
            return nil
        }
        return getGroup(groupKey: companyIdGroupKey, groupID: companyId)
    }

    func removeCachedGroup(groupKey: String, groupID: MixpanelType) {
        _ = readWriteLock.write {
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
            let timedEvents = self.trackInstance.time(
                event: event, timedEvents: self.timedEvents, startTime: startTime)
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
            MixpanelPersistence.saveTimedEvents(
                timedEvents: InternalProperties(), instanceName: self.name)
        }
    }

    /**
       Clears the event timer for the named event.

       - parameter event: the name of the event to clear the timer for
       */
    public func clearTimedEvent(event: String) {
        trackingQueue.async { [weak self, event] in
            guard let self = self else { return }

            let updatedTimedEvents = self.trackInstance.clearTimedEvent(
                event: event, timedEvents: self.timedEvents)
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
            MixpanelPersistence.saveSuperProperties(
                superProperties: self.superProperties, instanceName: self.name)
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
            let updatedSuperProperties = self.trackInstance.registerSuperProperties(
                properties,
                superProperties: self.superProperties)
            self.readWriteLock.write {
                self.superProperties = updatedSuperProperties
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveSuperProperties(
                    superProperties: self.superProperties, instanceName: self.name)
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
    public func registerSuperPropertiesOnce(
        _ properties: Properties,
        defaultValue: MixpanelType? = nil
    ) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            let updatedSuperProperties = self.trackInstance.registerSuperPropertiesOnce(
                properties,
                superProperties: self.superProperties,
                defaultValue: defaultValue)
            self.readWriteLock.write {
                self.superProperties = updatedSuperProperties
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveSuperProperties(
                    superProperties: self.superProperties, instanceName: self.name)
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
            let updatedSuperProperties = self.trackInstance.unregisterSuperProperty(
                propertyName,
                superProperties: self.superProperties)
            self.readWriteLock.write {
                self.superProperties = updatedSuperProperties
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveSuperProperties(
                    superProperties: self.superProperties, instanceName: self.name)
            }
        }
    }

    /**
       Updates a super property atomically. The update function

       - parameter update: closure to apply to super properties
       */
    func updateSuperProperty(
        _ update: @escaping (_ superproperties: inout InternalProperties) -> Void
    ) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            var superPropertiesShadow = self.superProperties
            self.trackInstance.updateSuperProperty(
                update,
                superProperties: &superPropertiesShadow)
            self.readWriteLock.write {
                self.superProperties = superPropertiesShadow
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveSuperProperties(
                    superProperties: self.superProperties, instanceName: self.name)
            }
        }
    }

    /**
       Convenience method to set a single group the user belongs to.

       On a hierarchical groups project a user belongs to one group per group key, so the group is
       stored as a single value rather than a list, and an array `groupID` is dropped with an error
       log.

       - parameter groupKey: The property name associated with this group type (must already have been set up).
       - parameter groupID: The group the user belongs to.
       */
    public func setGroup(groupKey: String, groupID: MixpanelType) {
        if hasOptedOutTracking() {
            return
        }

        if hierarchicalGroups {
            setHierarchicalGroup(groupKey: groupKey, groupID: groupID)
            return
        }

        setGroup(groupKey: groupKey, groupIDs: [groupID])
    }

    /**
       Set the groups this user belongs to.

       A hierarchical groups project allows one group per group key, so this is dropped with an
       error log there. Use `setGroup(groupKey:groupID:)` instead.

       - parameter groupKey: The property name associated with this group type (must already have been set up).
       - parameter groupIDs: The list of groups the user belongs to.
       */
    public func setGroup(groupKey: String, groupIDs: [MixpanelType]) {
        if hasOptedOutTracking() {
            return
        }

        if hierarchicalGroups {
            logSingleGroupOnly(operation: "setGroup with a list", groupKey: groupKey)
            return
        }

        let properties = [groupKey: groupIDs]
        self.registerSuperProperties(properties)
        people.set(properties: properties)
    }

    /**
       Add a group to this user's membership for a particular group key

       A hierarchical groups project allows one group per group key, so this is dropped with an
       error log there. Use `setGroup(groupKey:groupID:)` instead.

       - parameter groupKey: The property name associated with this group type (must already have been set up).
       - parameter groupID: The new group the user belongs to.
       */
    public func addGroup(groupKey: String, groupID: MixpanelType) {
        if hasOptedOutTracking() {
            return
        }

        if hierarchicalGroups {
            logSingleGroupOnly(operation: "addGroup", groupKey: groupKey)
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

       On a hierarchical groups project this clears the group key when the user belongs to
       `groupID`, and does nothing otherwise.

       - parameter groupKey: The property name associated with this group type (must already have been set up).
       - parameter groupID: The group value to remove.
       */
    public func removeGroup(groupKey: String, groupID: MixpanelType) {
        if hasOptedOutTracking() {
            return
        }

        if hierarchicalGroups {
            removeHierarchicalGroup(groupKey: groupKey, groupID: groupID)
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

            superProperties[groupKey] = vals.filter { !$0.equals(rhs: groupID) }
            self.people.remove(properties: [groupKey: groupID])
        }
    }

    private func setHierarchicalGroup(groupKey: String, groupID: MixpanelType) {
        // Hierarchical groups read a list as the name of one group, not as membership in each
        if groupID is [MixpanelType] || groupID is NSArray {
            logSingleGroupOnly(operation: "setGroup with a list", groupKey: groupKey)
            return
        }
        registerSuperProperties([groupKey: groupID])
        people.set(properties: [groupKey: groupID])
    }

    private func logSingleGroupOnly(operation: String, groupKey: String) {
        MixpanelLogger.error(
            message:
                "\(operation) is not supported for hierarchical groups projects, which allow one \(groupKey) "
                + "per user. Use setGroup(groupKey:groupID:). The update was dropped.")
    }

    private func removeHierarchicalGroup(groupKey: String, groupID: MixpanelType) {
        updateSuperProperty { superProperties in
            // Read the identity now, so an identify called after this cannot move the update to
            // another user
            let identity = self.identity
            // A one-item list, stored by an earlier version or before hierarchical groups was
            // enabled, counts as that item.
            var current = superProperties[groupKey]
            if let list = current as? [MixpanelType], list.count == 1 {
                current = list[0]
            }
            guard let value = current as? MixpanelType, value.equals(rhs: groupID) else {
                return
            }
            superProperties.removeValue(forKey: groupKey)
            guard let userId = identity.userId, let companyId = identity.companyId else {
                MixpanelLogger.error(
                    message:
                        "User profile updates for hierarchical groups projects need a user and a company. "
                        + "Call identify(identity: MixpanelIdentity(userId:companyId:)) first. The $unset "
                        + "update was dropped.")
                return
            }
            self.people.saveHierarchicalGroupsRecord(
                "$unset", properties: ["$properties": [groupKey]], userId: userId, companyId: companyId)
        }

        if MixpanelInstance.isiOSAppExtension() {
            flush()
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
            if self.hierarchicalGroups {
                // Delete the user profile while the identity is still known. Never delete the
                // company or team group profiles, which other users share.
                let identity = self.identity
                if let userId = identity.userId, let companyId = identity.companyId {
                    self.people.saveHierarchicalGroupsRecord(
                        "$delete", properties: [:], userId: userId, companyId: companyId)
                    self.flush()
                }
            } else if self.people.distinctId != nil {
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
                self.companyId = nil
                self.anonymousId = self.defaultDeviceId()
                self.eventsDistinctId = self.addPrefixToDeviceId(deviceId: self.anonymousId)
                self.hadPersistedDistinctId = true
                self.superProperties = InternalProperties()
                MixpanelPersistence.saveTimedEvents(
                    timedEvents: InternalProperties(), instanceName: self.name)
            }
            self.archive()
            self.readWriteLock.write {
                self.optOutStatus = true
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveOptOutStatusFlag(value: self.optOutStatus!, instanceName: self.name)
            }

            // Identity just changed (distinctId was regenerated above). Clear in-memory feature
            // flag state and the on-disk cache from the prior identity so subsequent lookups
            // don't serve stale variants. Mirrors `identify()` and `setContext()`. We deliberately
            // do NOT call `loadFlags()` here — opt-out semantically means "stop tracking", and
            // re-fetching flags under the new anon identity would defeat that intent. The next
            // `optInTracking()` will restore the normal fetch flow.
            if let flagManager = self.flags as? FeatureFlagManager {
                flagManager.reset()
            }

            #if os(iOS) && !targetEnvironment(macCatalyst)
            self.autocaptureManager?.stop()
            #endif
        }
    }

    /**
       Opt in tracking.

       Use this method to opt in an already opted out user from tracking. People updates and track calls will be
       sent to Mixpanel after using this method.

       This method will internally track an opt in event to your project.

       A distinct ID is not supported on a hierarchical groups project, where it is logged and
       ignored and the user stays opted out. Use `optInTracking(identity:properties:)` instead.

       - parameter distinctId: an optional string to use as the distinct ID for events
       - parameter properties: an optional properties dictionary that could be passed to add properties to the opt-in event
       that is sent to Mixpanel
       */
    public func optInTracking(distinctId: String? = nil, properties: Properties? = nil) {
        if distinctId != nil && hierarchicalGroups {
            MixpanelLogger.error(
                message:
                    "optInTracking(distinctId:) is not supported for hierarchical groups projects, which "
                    + "identify a user by company and user id. Use optInTracking(identity: "
                    + "MixpanelIdentity(userId:companyId:)). The user is still opted out.")
            return
        }
        performOptIn(properties: properties) {
            if let distinctId = distinctId {
                self.identify(distinctId: distinctId)
            }
        }
    }

    /**
       Opt in tracking and identify the user.

       Use this method to opt in an already opted out user from tracking and identify them. People
       updates and track calls will be sent to Mixpanel after using this method.

       This method will internally track an opt in event to your project.

       Opting out clears the user's identity, so on a hierarchical groups project use this to opt
       back in with the user's company: the opt-in event and every event after it carry the user
       and company, which `optInTracking(distinctId:properties:)` can't express.

       - parameter identity: the user, and on a hierarchical groups project their company. This
       calls `identify(identity:)`.
       - parameter properties: an optional properties dictionary that could be passed to add properties to the opt-in event
       that is sent to Mixpanel
       */
    public func optInTracking(identity: MixpanelIdentity, properties: Properties? = nil) {
        performOptIn(properties: properties) {
            self.identify(identity: identity)
        }
    }

    private func performOptIn(properties: Properties?, identify: @escaping () -> Void) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.write {
                self.optOutStatus = false
            }
            self.readWriteLock.read {
                MixpanelPersistence.saveOptOutStatusFlag(value: self.optOutStatus!, instanceName: self.name)
            }
            identify()
            self.track(event: "$opt_in", properties: properties)

            #if os(iOS) && !targetEnvironment(macCatalyst)
            // Restart autocapture if it was configured but stopped due to opt-out
            if self.autocaptureManager == nil,
                let autocaptureOpts = self.options.autocaptureOptions,
                autocaptureOpts.isEnabled,
                !MixpanelInstance.isiOSAppExtension()
            {
                let manager = AutocaptureManager(
                    options: autocaptureOpts,
                    autocapture: self.autocapture
                )
                self.autocaptureManager = manager
                DispatchQueue.main.async {
                    manager.start()
                }
                MixpanelLogger.info(message: "AutocaptureManager started after opt-in")
            } else {
                self.autocaptureManager?.start()
            }
            #endif
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
