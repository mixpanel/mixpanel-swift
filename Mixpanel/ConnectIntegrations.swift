//
//  ConnectIntegrations.swift
//  Mixpanel
//
//  Created by Peter Chien on 10/10/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

class ConnectIntegrations {
    open var mixpanel: MixpanelInstance?
    var urbanAirshipRetries = 0
    var savedUrbanAirshipChannelID: String?

    open func setupIntegrations(_ integrations:[String]) {
        if integrations.contains("urbanairship") {
            self.setUrbanAirshipPeopleProp()
        }
    }

    func setUrbanAirshipPeopleProp() {
        if let urbanAirship = NSClassFromString("UAirship") {
            let pushSelector = NSSelectorFromString("push")
            if let pushIMP = urbanAirship.method(for: pushSelector) {
                typealias pushFunc = @convention(c) (AnyObject, Selector) -> AnyObject!
                let curriedImplementation = unsafeBitCast(pushIMP, to: pushFunc.self)
                if let push = curriedImplementation(urbanAirship.self, pushSelector) {
                    if let channelID = push.perform(NSSelectorFromString("channelID"))?.takeUnretainedValue() as? String {
                        self.urbanAirshipRetries = 0
                        if (channelID != self.savedUrbanAirshipChannelID) {
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

    open func reset() {
        self.savedUrbanAirshipChannelID = nil
        self.urbanAirshipRetries = 0
    }
}
