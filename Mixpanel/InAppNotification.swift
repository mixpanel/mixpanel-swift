//
//  InAppNotification.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/9/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct InAppNotification {
    enum PayloadKey {
        static let ID = "id"
        static let messageID = "message_id"
        static let type = "type"
        static let style = "style"
        static let title = "title"
        static let body = "body"
        static let callToAction = "cta"
        static let callToActionURL = "cta_url"
        static let imageURLString = "image_url"
    }
    
    let ID: Int
    let messageID: Int
    let type: String
    let style: String
    let imageURL: URL
    lazy var image: Data? = {
        var data: Data?
        do {
            data = try Data(contentsOf: self.imageURL, options: [.mappedIfSafe])
        } catch {
            Logger.error(message: "image failed to load from url \(self.imageURL)")
        }
        return data
    }()
    let title: String
    let body: String
    let callToAction: String
    let callToActionURL: URL?

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

        guard let type = object[PayloadKey.type] as? String else {
            Logger.error(message: "invalid notification type")
            return nil
        }

        guard let style = object[PayloadKey.style] as? String else {
            Logger.error(message: "invalid notification style")
            return nil
        }

        guard let title = object[PayloadKey.title] as? String, !title.isEmpty else {
            Logger.error(message: "invalid notification title")
            return nil
        }

        guard let body = object[PayloadKey.body] as? String, !body.isEmpty else {
            Logger.error(message: "invalid notification body")
            return nil
        }

        guard let callToAction = object[PayloadKey.callToAction] as? String else {
            Logger.error(message: "invalid notification cta")
            return nil
        }

        var callToActionURL: URL?
        if let URLString = object[PayloadKey.callToActionURL] as? String {
            callToActionURL = URL(string: URLString)
        }

        guard let imageURLString = object[PayloadKey.imageURLString] as? String,
            let escapedImageURLString = imageURLString
                .addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed),
            var imageURLComponents = URLComponents(string: escapedImageURLString) else {
                Logger.error(message: "invalid notification image url")
                return nil
        }

        if type == InAppType.takeover.rawValue {
            imageURLComponents.path = imageURLComponents.path.appendSuffixBeforeExtension(suffix: "@2x")
        }

        guard let imageURLParsed = imageURLComponents.url else {
            Logger.error(message: "invalid notification image url")
            return nil
        }

        self.ID                 = ID
        self.messageID          = messageID
        self.type               = type
        self.style              = style
        self.imageURL           = imageURLParsed
        self.title              = title
        self.body               = body
        self.callToAction       = callToAction
        self.callToActionURL    = callToActionURL
    }
    
    func payload() -> [String: AnyObject] {
        var payload = [String: AnyObject]()
        payload[PayloadKey.ID] = ID as AnyObject
        payload[PayloadKey.messageID] = messageID as AnyObject
        payload[PayloadKey.type] = type as AnyObject
        payload[PayloadKey.style] = style as AnyObject
        payload[PayloadKey.imageURLString] = imageURL.absoluteString as AnyObject
        payload[PayloadKey.title] = title as AnyObject
        payload[PayloadKey.body] = body as AnyObject
        payload[PayloadKey.callToAction] = callToAction as AnyObject
        if let urlString = callToActionURL?.absoluteString {
            payload[PayloadKey.callToActionURL] = urlString as AnyObject
        }
        return payload
    }
}

extension String {
    func appendSuffixBeforeExtension(suffix: String) -> String {
        var newString = suffix
        do {
            let regex = try NSRegularExpression(pattern: "(\\.\\w+$)", options: [])
            newString = regex.stringByReplacingMatches(in: self,
                                                       options: [],
                                                       range: NSRange(location: 0,
                                                                      length: self.characters.count),
                                                       withTemplate: "\(suffix)$1")
        } catch {
            Logger.error(message: "cannot add suffix to URL string")
        }
        return newString
    }
}
