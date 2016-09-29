//
//  VariantTweak.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

typealias TweakValue = Any

class VariantTweak {
    let name: String
    let encoding: String
    let value: TweakValue

    convenience init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "variant action json object should not be nil")
            return nil
        }

        guard let name = object["name"] as? String else {
            Logger.error(message: "invalid tweak name")
            return nil
        }

        guard let encoding = object["encoding"] as? String else {
            Logger.error(message: "invalid tweak encoding")
            return nil
        }

        guard let value = object["value"] as? TweakValue else {
            Logger.error(message: "invalid tweak value")
            return nil
        }

        self.init(name: name, encoding: encoding, value: value)
    }

    init(name: String, encoding: String, value: TweakValue) {
        self.name = name
        self.encoding = encoding
        self.value = value
    }

    func execute() {

    }

    func stop() {

    }
}
