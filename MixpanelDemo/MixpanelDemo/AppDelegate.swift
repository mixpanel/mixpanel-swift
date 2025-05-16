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
        let mixpanelOptions = MixpanelOptions(token: "metrics-1", trackAutomaticEvents: false, featureFlagsEnabled: true, featureFlagsContext: ["key": "value"])
        Mixpanel.initialize(options: mixpanelOptions)
        Mixpanel.mainInstance().loggingEnabled = true

        return true
    }
}

