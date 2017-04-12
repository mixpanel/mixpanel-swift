//
//  AutomaticEvents.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 3/8/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class AutomaticEvents {
    let defaults = UserDefaults(suiteName: "Mixpanel")
    init(serialQueue: DispatchQueue, trackInstance: Track) {

        let firstOpenKey = "MPfirstOpen"
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            Mixpanel.mainInstance().track(event: "MP: First App Open", properties: nil)
            defaults.set(true, forKey: firstOpenKey)
            defaults.synchronize()
        }
        Mixpanel.mainInstance().time(event: "MP: App Open")

        if let defaults = defaults, let infoDict = Bundle.main.infoDictionary {
            let appVersionKey = "MPAppVersion"
            let appVersionValue = infoDict["CFBundleShortVersionString"]
            if let appVersionValue = appVersionValue as? String,
                appVersionValue != defaults.string(forKey: appVersionKey) {
                Mixpanel.mainInstance().track(event: "MP: App Updated", properties: ["App Version": appVersionValue])
                defaults.set(appVersionValue, forKey: appVersionKey)
                defaults.synchronize()
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appEnteredBackground(_:)),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
    }
    
    @objc private func appEnteredBackground(_ notification: Notification) {
        Mixpanel.mainInstance().track(event: "MP: App Open", properties: nil)
    }

}
