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
  public let useUniqueDistinctId: Bool
  public let superProperties: Properties?
  public let serverURL: String?
  public let proxyServerConfig: ProxyServerConfig?
  public let useGzipCompression: Bool
  public let featureFlagsEnabled: Bool
  public let featureFlagsContext: [String: Any]

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
    featureFlagsContext: [String: Any] = [:]
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
  }
}
