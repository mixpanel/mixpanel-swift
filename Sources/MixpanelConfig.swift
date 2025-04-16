//
//  public.swift
//  Mixpanel
//
//  Created by Jared McFarland on 4/15/25.
//  Copyright © 2025 Mixpanel. All rights reserved.
//


// New MixpanelConfig class
public class MixpanelConfig {
    public let token: String
    public let flushInterval: Double
    public let instanceName: String?
    public let trackAutomaticEvents: Bool
    public let optOutTrackingByDefault: Bool
    public let useUniqueDistinctId: Bool
    public let superProperties: Properties?
    public let serverURL: String?
    public let proxyServerConfig: ProxyServerConfig?
    public let useGzipCompression: Bool
    public let flagsEnabled: Bool
    public let flagsContext: Dictionary<String, Any>?
    
    public init(token: String,
                flushInterval: Double = 60,
                instanceName: String? = nil,
                trackAutomaticEvents: Bool = false,
                optOutTrackingByDefault: Bool = false,
                useUniqueDistinctId: Bool = false,
                superProperties: Properties? = nil,
                serverURL: String? = nil,
                proxyServerConfig: ProxyServerConfig? = nil,
                useGzipCompression: Bool = true, // NOTE: This is a new default value!
                flagsEnabled: Bool = false,
                flagsContext: Dictionary<String, Any>? = nil) {
        self.token = token
        self.flushInterval = flushInterval
        self.instanceName = instanceName
        self.trackAutomaticEvents = trackAutomaticEvents
        self.optOutTrackingByDefault = optOutTrackingByDefault
        self.useUniqueDistinctId = useUniqueDistinctId
        self.superProperties = superProperties
        self.serverURL = serverURL
        self.proxyServerConfig = proxyServerConfig
        self.useGzipCompression = useGzipCompression
        self.flagsEnabled = flagsEnabled
        self.flagsContext = flagsContext
    }
}
