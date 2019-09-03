//
//  InAppNotification.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/9/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class InAppNotification {
    enum PayloadKey {
        static let ID = "id"
        static let messageID = "message_id"
        static let type = "type"
        static let body = "body"
        static let imageURLString = "image_url"
        static let extras = "extras"
        static let backgroundColor = "bg_color"
        static let bodyColor = "body_color"
        static let displayTriggers = "display_triggers"
    }
    
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
    let backgroundColor: UInt
    let bodyColor: UInt
    let type: String
    var body: String? = nil
    var displayTriggers = [DisplayTrigger]()

    init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "notification json object should not be nil")
            return nil
        }

        guard let ID = object[PayloadKey.ID] as? Int, ID > 0 else {
            Logger.error(message: "invalid notification id")
            return nil
        }

        guard let messageID = object[PayloadKey.messageID] as? Int, messageID > 0 else {
            Logger.error(message: "invalid notification message id")
            return nil
        }

        guard let extras = object[PayloadKey.extras] as? [String: Any] else {
            Logger.error(message: "invalid notification extra section \(object)")
            return nil
        }
        
        if let rawDisplayTriggersOpt = object[PayloadKey.displayTriggers] as? [[String: Any]]? {
            if let rawDisplayTriggers = rawDisplayTriggersOpt {
                for rawDisplayTrigger in rawDisplayTriggers {
                    if let displayTrigger = DisplayTrigger(jsonObject: rawDisplayTrigger) {
                        displayTriggers.append(displayTrigger)
                    } else {
                        Logger.error(message: "invalid display trigger \(rawDisplayTrigger)")
                        return nil
                    }
                }
            }
        } else {
            Logger.error(message: "invalid display triggers section \(object)")
            return nil
        }

        guard let backgroundColor = object[PayloadKey.backgroundColor] as? UInt else {
            Logger.error(message: "invalid notification bg_color")
            return nil
        }

        guard let bodyColor = object[PayloadKey.bodyColor] as? UInt else {
            Logger.error(message: "invalid notification body_color")
            return nil
        }

        guard let imageURLString = object[PayloadKey.imageURLString] as? String,
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
        
        guard let type = object[PayloadKey.type] as? String else {
            Logger.error(message: "invalid notification type")
            return nil
        }

        if let body = object[PayloadKey.body] as? String, !body.isEmpty {
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
    
    func hasDisplayTriggers() -> Bool {
        return displayTriggers.count > 0
    }
    
    func matchesEvent(event: String?, properties: InternalProperties) -> Bool {
        for displayTrigger in displayTriggers {
            if (displayTrigger.matchesEvent(eventName: event, properties: properties)) {
                return true
            }
        }
        return false
    }
    
    func payload() -> [String: AnyObject] {
        var payload = [String: AnyObject]()
        payload[PayloadKey.ID] = ID as AnyObject
        payload[PayloadKey.messageID] = messageID as AnyObject
        payload[PayloadKey.imageURLString] = imageURL.absoluteString as AnyObject
        payload[PayloadKey.extras] = extras as AnyObject
        payload[PayloadKey.backgroundColor] = backgroundColor as AnyObject
        payload[PayloadKey.bodyColor] = bodyColor as AnyObject
        payload[PayloadKey.type] = type as AnyObject
        payload[PayloadKey.body] = body as AnyObject
        var payloadDisplayTriggers = [[String: AnyObject]]()
        for displayTrigger in displayTriggers {
            payloadDisplayTriggers.append(displayTrigger.payload())
        }
        payload[PayloadKey.displayTriggers] = payloadDisplayTriggers as AnyObject
        
        return payload
    }
}
