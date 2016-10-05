//
//  VariantTweak.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class VariantTweak {
    let name: String
    let encoding: String
    let value: TweakableType?

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

        let value = object["value"] as? TweakableType

        self.init(name: name, encoding: encoding, value: value)
    }

    init(name: String, encoding: String, value: TweakableType?) {
        self.name = name
        self.encoding = encoding
        self.value = value
    }

    func execute() {
        guard let tweak = ExampleTweaks.defaultStore.tweakCollections["General"]?.tweakGroups["General"]?.tweaks[name] else {
            return
        }

        if let value = value {
            let tweakViewData = createViewDataType(value: value)
            ExampleTweaks.defaultStore.setValue(tweakViewData, forTweak: tweak)
        } else {
            ExampleTweaks.defaultStore.setValue(ExampleTweaks.defaultStore.currentViewDataForTweak(tweak), forTweak: tweak)
        }
    }

    func createViewDataType(value: TweakableType) -> TweakViewData {
        if let value = value as? Bool {
            return TweakViewData.boolean(value: value, defaultValue: value)
        } else if let value = value as? Int {
            return TweakViewData.integer(value: value, defaultValue: value, min: value, max: value, stepSize: 0)
        } else if let value = value as? CGFloat {
            return TweakViewData.float(value: value, defaultValue: value, min: value, max: value, stepSize: 0)
        } else if let value = value as? Double {
            return TweakViewData.doubleTweak(value: value, defaultValue: value, min: value, max: value, stepSize: 0)
        } else if let value = value as? UIColor {
            return TweakViewData.color(value: value, defaultValue: value)
        }
        return TweakViewData.boolean(value: false, defaultValue: false)
    }

    func stop() {
        guard let tweak = ExampleTweaks.defaultStore.tweakCollections["General"]?.tweakGroups["General"]?.tweaks[name] else {
            return
        }
        let currentViewData = ExampleTweaks.defaultStore.currentViewDataForTweak(tweak)
        //ExampleTweaks.defaultStore.setValue(, forTweak: tweak)

    }
}

public struct ExampleTweaks: TweakLibraryType {
    public static let colorTint = Tweak("General", "General", "Tint", UIColor.blue)
    public static let marginHorizontal = Tweak<CGFloat>("General", "General", "H. Margins", defaultValue: 15, min: 0)
    public static let marginVertical = Tweak<CGFloat>("General", "General", "V. Margins", defaultValue: 10, min: 0)
    public static let featureFlagMainScreenHelperText = Tweak("General", "General", "Show Body Text", true)


    public static let defaultStore: TweakStore = {
        let allTweaks: [TweakClusterType] = [colorTint, marginHorizontal, marginVertical, featureFlagMainScreenHelperText]

        let tweaksEnabled = true

        return TweakStore(
            tweaks: allTweaks,
            enabled: tweaksEnabled
        )
    }()
}
