//
//  AppDelegate.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // var ADD_YOUR_MIXPANEL_TOKEN_BELOW_🛠🛠🛠🛠🛠🛠: String
        Mixpanel.initialize(token: "6d83a31dc1373e3153a5a3d087084721")
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().identify(distinctId: "jared")
        
        Mixpanel.mainInstance().people.set(properties: ["prop 1": "value 1", "prop 2": "value 1", "prop 3": "value 1", "prop x": "value y"])
        Mixpanel.mainInstance().people.set(properties: ["prop 1": "value 2", "prop 2": "value 2", "prop 3": "value 2", "prop z": "value a"])
        Mixpanel.mainInstance().people.set(properties: ["prop 1": "value 3", "prop 2": "value 3", "prop 3": "value 3", "prop j": "value j"])
        Mixpanel.mainInstance().people.set(properties: ["prop 1": "value 4", "prop 2": "value 4", "prop 3": "value 4", "prop j": "value i"])
        Mixpanel.mainInstance().people.set(properties: ["prop 1": "value 5", "prop 2": "value 5", "prop 3": "value 5", "prop z": "value w"])
        Mixpanel.mainInstance().people.set(properties: ["prop 1": "value 6", "prop 2": "value 6", "prop 3": "value 6", "prop r": "value r"])
        
        Mixpanel.mainInstance().flush()

        return true
    }
}

