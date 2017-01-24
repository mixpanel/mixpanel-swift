//
//  MiniNotification.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation

class MiniNotification: InAppNotification {
    let callToActionURL: URL?
    let imageTintColor: Int
    let borderColor: Int
    
    override init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "notification json object should not be nil")
            return nil
        }

        guard let imageTintColor = object["image_tint_color"] as? Int else {
            Logger.error(message: "invalid notification image tint color")
            return nil
        }

        guard let borderColor = object["border_color"] as? Int else {
            Logger.error(message: "invalid notification border color")
            return nil
        }

        var callToActionURL: URL?
        if let URLString = object["cta_url"] as? String {
            callToActionURL = URL(string: URLString)
        }

        self.callToActionURL = callToActionURL
        self.imageTintColor = imageTintColor
        self.borderColor = borderColor

        super.init(JSONObject: JSONObject)

    }
}
