//
//  AppDelegate.swift
//  MixpanelDemoMac
//
//  Created by ZIHE JIA on 12/15/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

import Cocoa
import Mixpanel

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        var ADD_YOUR_MIXPANEL_TOKEN_BELOW_🛠🛠🛠🛠🛠🛠: String
        
        Mixpanel.initialize(token: "MIXPANEL_TOKEN")
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().track(event: "Tracked Event")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

