//
//  InAppNotification.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/9/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class InAppNotification {
    let ID: Int
    let messageID: Int
    var imageURL: URL
    lazy var image: Data? = {
        var data: Data?
        do {
            data = try Data(contentsOf: self.imageURL, options: [.mappedIfSafe])
        } catch {
            Logger.error(message: "image failed to load from url \(self.imageURL)")
        }
        return data
    }()
    let extras: [String: Any]
    let backgroundColor: Int
    let bodyColor: Int
    let type: String
    var body: String? = nil

    init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "notification json object should not be nil")
            return nil
        }

        guard let ID = object["id"] as? Int, ID > 0 else {
            Logger.error(message: "invalid notification id")
            return nil
        }

        guard let messageID = object["message_id"] as? Int, messageID > 0 else {
            Logger.error(message: "invalid notification message id")
            return nil
        }

        guard let extras = object["extras"] as? [String: Any] else {
            Logger.error(message: "invalid notification extra section")
            return nil
        }

        guard let backgroundColor = object["bg_color"] as? Int else {
            Logger.error(message: "invalid notification bg_color")
            return nil
        }

        guard let bodyColor = object["body_color"] as? Int else {
            Logger.error(message: "invalid notification body_color")
            return nil
        }

        guard let imageURLString = object["image_url"] as? String,
            let escapedImageURLString = imageURLString
                .addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed),
            let imageURLComponents = URLComponents(string: escapedImageURLString) else {
                Logger.error(message: "invalid notification image url")
                return nil
        }

        guard let imageURLParsed = imageURLComponents.url else {
            Logger.error(message: "invalid notification image url")
            return nil
        }

        guard let type = object["type"] as? String else {
            Logger.error(message: "invalid notification type")
            return nil
        }

        if let body = object["body"] as? String, !body.isEmpty {
            self.body = body
        }

        self.ID                 = ID
        self.messageID          = messageID
        self.imageURL           = imageURLParsed
        self.extras             = extras
        self.backgroundColor    = backgroundColor
        self.bodyColor          = bodyColor
        self.type               = type
    }
}
