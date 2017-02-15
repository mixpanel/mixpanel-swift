//
//  MiniNotification.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation

class MiniNotification: InAppNotification {
    enum PayloadKey {
        static let imageTintColor = "image_tint_color"
        static let borderColor = "border_color"
        static let callToActionURL = "cta_url"
    }

    let callToActionURL: URL?
    let imageTintColor: UInt
    let borderColor: UInt

    override init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "notification json object should not be nil")
            return nil
        }

        guard let imageTintColor = object[PayloadKey.imageTintColor] as? UInt else {
            Logger.error(message: "invalid notification image tint color")
            return nil
        }

        guard let borderColor = object[PayloadKey.borderColor] as? UInt else {
            Logger.error(message: "invalid notification border color")
            return nil
        }

        var callToActionURL: URL?
        if let URLString = object[PayloadKey.callToActionURL] as? String {
            callToActionURL = URL(string: URLString)
        }

        self.callToActionURL = callToActionURL
        self.imageTintColor = imageTintColor
        self.borderColor = borderColor

        super.init(JSONObject: JSONObject)

        if self.body == nil {
            Logger.error(message: "invalid notification body")
            return nil
        }

    }
    
    override func payload() -> [String : AnyObject] {
        var payload = super.payload()
        
        payload[PayloadKey.imageTintColor] = imageTintColor as AnyObject
        if let urlString = callToActionURL?.absoluteString {
            payload[PayloadKey.callToActionURL] = urlString as AnyObject
        }
        payload[PayloadKey.borderColor] = borderColor as AnyObject
        
        return payload
    }
}
