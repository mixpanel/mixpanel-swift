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
        // var ADD_YOUR_MIXPANEL_TOKEN_BELOW_🛠🛠🛠🛠🛠🛠: String;
        let token = "6d83a31dc1373e3153a5a3d087084721"
        Mixpanel.initialize(token: token, trackAutomaticEvents: true)
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().anonymousId = "myAnonymousId"

        return true
    }
}

