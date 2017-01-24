//
//  InAppButton.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation

class InAppButton {

    let text: String
    let textColor: Int
    let backgroundColor: Int
    let borderColor: Int
    let callToActionURL: URL?

    init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "notification button json object should not be nil")
            return nil
        }

        guard let text = object["text"] as? String else {
            Logger.error(message: "invalid notification button text")
            return nil
        }

        guard let textColor = object["text_color"] as? Int else {
            Logger.error(message: "invalid notification button text color")
            return nil
        }

        guard let backgroundColor = object["bg_color"] as? Int else {
            Logger.error(message: "invalid notification button background color")
            return nil
        }

        guard let borderColor = object["border_color"] as? Int else {
            Logger.error(message: "invalid notification button border color")
            return nil
        }

        var callToActionURL: URL?
        if let URLString = object["cta_url"] as? String {
            callToActionURL = URL(string: URLString)
        }

        self.text               = text
        self.textColor          = textColor
        self.backgroundColor    = backgroundColor
        self.borderColor        = borderColor
        self.callToActionURL    = callToActionURL

    }
}
