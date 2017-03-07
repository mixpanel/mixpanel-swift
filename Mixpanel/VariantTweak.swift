//
//  VariantTweak.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class VariantTweak: NSObject, NSCoding {
    let name: String
    let encoding: String
    let value: AnyObject
    let type: String?

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

        guard let type = object["type"] as? String else {
            Logger.error(message: "no type")
            return nil
        }

        guard let value = object["value"] else {
            Logger.error(message: "bad value")
            return nil
        }

        self.init(name: name, encoding: encoding, value: value as AnyObject, type: type)
    }

    init(name: String, encoding: String, value: AnyObject, type: String) {
        self.name = name
        self.encoding = encoding
        self.value = value
        self.type = type
    }

    func execute() {
        guard let tweak = MixpanelTweaks.defaultStore.tweakCollections["Mixpanel"]?.tweakGroups["Mixpanel"]?.tweaks[name] else {
            return
        }

        let currentViewData = MixpanelTweaks.defaultStore.currentViewDataForTweak(tweak)
        let tweakViewData = createViewDataType(value: value, viewData: currentViewData)
        MixpanelTweaks.defaultStore.setValue(tweakViewData, forTweak: tweak)
    }

    func createViewDataType(value: AnyObject, viewData: TweakViewData) -> TweakViewData {
        let (_, def, min, max) = viewData.getValueDefaultMinMax()

        if type == "number" {
            if let value = value as? Double, let def = def as? Double {
                return TweakViewData.doubleTweak(value: value, defaultValue: def, min: min as? Double, max: max as? Double, stepSize: 0)
            } else if let value = value as? CGFloat, let def = def as? CGFloat {
                return TweakViewData.float(value: value, defaultValue: def, min: min as? CGFloat, max: max as? CGFloat, stepSize: 0)
            } else if let value = value as? Int, let def = def as? Int {
                return TweakViewData.integer(value: value, defaultValue: def, min: min as? Int, max: max as? Int, stepSize: 0)
            }
        } else if type == "string" {
            if let value = value as? String, let def = def as? String {
                return TweakViewData.string(value: value, defaultValue: def)
            }
        } else {
            if let value = value as? Bool, let def = def as? Bool {
                return TweakViewData.boolean(value: value, defaultValue: def)
            }
        }

        return TweakViewData.boolean(value: false, defaultValue: false)
    }

    func stop() {
        guard let tweak = MixpanelTweaks.defaultStore.tweakCollections["Mixpanel"]?.tweakGroups["Mixpanel"]?.tweaks[name] else {
            return
        }
        let currentViewData = MixpanelTweaks.defaultStore.currentViewDataForTweak(tweak)
        let value = currentViewData.getValueDefaultMinMax()
        MixpanelTweaks.defaultStore.setValue(createViewDataType(value: value.1 as AnyObject, viewData: currentViewData), forTweak: tweak)

    }

    required init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(forKey: "name") as? String,
            let encoding = aDecoder.decodeObject(forKey: "encoding") as? String,
            let type = aDecoder.decodeObject(forKey: "type") as? String,
            let value = aDecoder.decodeObject(forKey: "value")
            else {
                return nil
        }

        self.name = name
        self.encoding = encoding
        self.value = value as AnyObject
        self.type = type
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(encoding, forKey: "encoding")
        aCoder.encode(value, forKey: "value")
        aCoder.encode(type, forKey: "type")
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? VariantTweak else {
            return false
        }

        if object === self {
            return true
        } else {
            return self.name == object.name
        }
    }

    override var hash: Int {
        return self.name.hash
    }

}

/// The MixpanelTweaks struct that needs to be extended to define new Tweaks for A/B testing
public struct MixpanelTweaks: TweakLibraryType {
    /// The default store that holds the Tweaks
    public static var defaultStore: TweakStore = TweakStore(enabled: true)
    /**
     setTweaks needs to be called to add the defined Tweaks into the environment.

     - parameter tweaks:    the tweaks to set
     */
    public static func setTweaks(tweaks: [TweakClusterType]) {
        defaultStore.addTweaks(tweaks)
    }
}
