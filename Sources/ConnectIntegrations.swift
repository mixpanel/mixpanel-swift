//
//  ConnectIntegrations.swift
//  Mixpanel
//
//  Created by Peter Chien on 10/10/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//
import Foundation

class ConnectIntegrations {
    open var mixpanel: MixpanelInstance?
    var urbanAirshipRetries = 0
    var savedUrbanAirshipChannelID: String?
    var savedBrazeID: String?
    var savedDeviceId: String?

    open func setupIntegrations(_ integrations: [String]) {
        if integrations.contains("urbanairship") {
            self.setUrbanAirshipPeopleProp()
        }
        if integrations.contains("braze") {
            self.setBrazePeopleProp()
        }
    }

    func setUrbanAirshipPeopleProp() {
        if let urbanAirship = NSClassFromString("UAirship") {
            let channelSelector = NSSelectorFromString("channel")
            if let channelIMP = urbanAirship.method(for: channelSelector) {
                typealias ChannelFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
                let curriedImplementation = unsafeBitCast(channelIMP, to: ChannelFunc.self)
                if let channel = curriedImplementation(urbanAirship.self, channelSelector) {
                    if let channelID = channel.perform(NSSelectorFromString("identifier"))?.takeUnretainedValue() as? String {
                        self.urbanAirshipRetries = 0
                        if channelID != self.savedUrbanAirshipChannelID {
                            self.mixpanel?.people.set(property: "$ios_urban_airship_channel_id", to: channelID)
                            self.savedUrbanAirshipChannelID = channelID
                        }
                    } else {
                        self.urbanAirshipRetries += 1
                        if self.urbanAirshipRetries <= ConnectIntegrationsConstants.uaMaxRetries {
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                                self.setUrbanAirshipPeopleProp()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func setBrazePeopleProp() {
        if let brazeClass = NSClassFromString("Appboy") {
            let shareInstanceSel = NSSelectorFromString("sharedInstance")
            if let appBoyShareInstanceIMP = brazeClass.method(for: shareInstanceSel) {
                typealias ShareInstanceFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
                let curriedImplementation = unsafeBitCast(appBoyShareInstanceIMP, to: ShareInstanceFunc.self)
                if let instance = curriedImplementation(brazeClass.self, shareInstanceSel) {
                    if let deviceId = instance.perform(NSSelectorFromString("getDeviceId"))?.takeUnretainedValue() as? String {
                        if deviceId != self.savedDeviceId {
                            self.mixpanel?.createAlias(deviceId, distinctId: (self.mixpanel?.distinctId)!)
                            self.mixpanel?.people.set(property: "$braze_device_id", to: deviceId)
                            self.savedDeviceId = deviceId
                        }
                    }
                    if let user = instance.perform(NSSelectorFromString("user"))?.takeUnretainedValue() {
                        if let userId = user.perform(NSSelectorFromString("userID"))?.takeUnretainedValue() as? String {
                            if userId != self.savedBrazeID {
                                self.mixpanel?.createAlias(userId, distinctId: (self.mixpanel?.distinctId)!)
                                self.mixpanel?.people.set(property: "$braze_external_id", to: userId)
                                self.savedBrazeID = userId
                            }
                        }
                    }
                }
            }
        }
    }

    open func reset() {
        self.savedUrbanAirshipChannelID = nil
        self.savedBrazeID = nil
        self.savedDeviceId = nil
        self.urbanAirshipRetries = 0
    }
}
