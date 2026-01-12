//
//  MixpanelOptions.swift
//  Mixpanel
//
//  Created by Jared McFarland on 4/15/25.
//  Copyright © 2025 Mixpanel. All rights reserved.
//

public class MixpanelOptions {
  public let token: String
  public let flushInterval: Double
  public let instanceName: String?
  public let trackAutomaticEvents: Bool
  public let optOutTrackingByDefault: Bool
    
    /// A boolean indicating whether to use a unique distinct ID based on the device's identifierForVendor (IDFV) or a random UUID.
    /// By default, Mixpanel generates a distinct ID using one of the following methods:
    /// - The `identifierForVendor` (IDFV) string if `useUniqueDistinctId` is set to `true`
    /// - A random UUID (default behavior)  if `useUniqueDistinctId` is set to `false`
    /// - Important: If `customDeviceId` property is set, then the SDK will give preference to it instead.
  public let useUniqueDistinctId: Bool
  public let superProperties: Properties?
  public let serverURL: String?
  public let proxyServerConfig: ProxyServerConfig?
  public let useGzipCompression: Bool
  public let featureFlagsEnabled: Bool
  public let featureFlagsContext: [String: Any]
    
    /// A custom device identifier to use instead of the SDK-generated one.
    /// If you set this property, the SDK will give preference to the custom device ID provided here.
    /// - Note: This value can be only set during SDK initialization. You can not change the device Id later on.
    ///
    /// - Important: If set to an empty string, it will be ignored and the SDK will fall back
    ///   to generating a device ID using the default behavior.
  public let customDeviceId: String?

  public init(
    token: String,
    flushInterval: Double = 60,
    instanceName: String? = nil,
    trackAutomaticEvents: Bool = false,
    optOutTrackingByDefault: Bool = false,
    useUniqueDistinctId: Bool = false,
    superProperties: Properties? = nil,
    serverURL: String? = nil,
    proxyServerConfig: ProxyServerConfig? = nil,
    useGzipCompression: Bool = true,  // NOTE: This is a new default value!
    featureFlagsEnabled: Bool = false,
    featureFlagsContext: [String: Any] = [:],
    customDeviceId: String? = nil
  ) {
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
    self.featureFlagsEnabled = featureFlagsEnabled
    self.featureFlagsContext = featureFlagsContext
    self.customDeviceId = customDeviceId
  }
}
