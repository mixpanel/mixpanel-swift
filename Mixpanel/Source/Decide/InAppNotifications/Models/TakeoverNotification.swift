//
//  TakeoverNotification.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 1/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation

class TakeoverNotification: InAppNotification {
    enum PayloadKey {
        static let buttons = "buttons"
        static let closeColor = "close_color"
        static let title = "title"
        static let titleColor = "title_color"
        static let imageFade = "image_fade"
    }

    let buttons: [InAppButton]
    let closeButtonColor: UInt
    var title: String? = nil
    let titleColor: UInt
    var shouldFadeImage: Bool = false

    override init?(JSONObject: [String: Any]?) {

        guard let object = JSONObject else {
            Logger.error(message: "notification json object should not be nil")
            return nil
        }

        guard let unparsedButtons = object[PayloadKey.buttons] as? [[String: Any]] else {
            Logger.error(message: "invalid notification buttons list")
            return nil
        }

        var parsedButtons = [InAppButton]()
        for unparsedButton in unparsedButtons {
            guard let button = InAppButton(JSONObject: unparsedButton) else {
                Logger.error(message: "invalid notification button")
                return nil
            }
            parsedButtons.append(button)
        }

        guard let closeButtonColor = object[PayloadKey.closeColor] as? UInt else {
            Logger.error(message: "invalid notification close button color")
            return nil
        }

        if let title = object[PayloadKey.title] as? String {
            self.title = title
        }

        guard let titleColor = object[PayloadKey.titleColor] as? UInt else {
            Logger.error(message: "invalid notification title color")
            return nil
        }

        self.buttons            = parsedButtons
        self.closeButtonColor   = closeButtonColor
        self.titleColor         = titleColor

        super.init(JSONObject: JSONObject)

        guard let shouldFadeImage = extras[PayloadKey.imageFade] as? Bool else {
            Logger.error(message: "invalid notification fade image boolean")
            return nil
        }
        self.shouldFadeImage    = shouldFadeImage
        imageURL = URL(string: imageURL.absoluteString.appendSuffixBeforeExtension(suffix: "@2x"))!

    }
    
    override func payload() -> [String : AnyObject] {
        var payload = super.payload()
        
        payload[PayloadKey.buttons] = buttons.map({ $0.payload() }) as AnyObject
        payload[PayloadKey.closeColor] = closeButtonColor as AnyObject
        payload[PayloadKey.title] = title as AnyObject
        payload[PayloadKey.titleColor] = titleColor as AnyObject
        payload[PayloadKey.imageFade] = shouldFadeImage as AnyObject
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
