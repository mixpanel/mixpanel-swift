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
                     didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        var ADD_YOUR_MIXPANEL_TOKEN_BELOW_🛠🛠🛠🛠🛠🛠: String
        Mixpanel.initialize(token: "MIXPANEL_TOKEN")
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().flushInterval = 5

        let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        UIApplication.shared.registerUserNotificationSettings(settings)
        UIApplication.shared.registerForRemoteNotifications()

        Mixpanel.mainInstance().identify(
            distinctId: Mixpanel.mainInstance().distinctId)
        Mixpanel.mainInstance().people.set(properties: ["$name": "Max Panelle"])

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Mixpanel.mainInstance().time(event: "session length")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Mixpanel.mainInstance().track(event: "session length")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        debugPrint("did register for remote notification with token")
        Mixpanel.mainInstance().people.addPushDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        debugPrint(error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        debugPrint("did receive remote notificaiton")
        if let message = userInfo["aps"]?["alert"] as? String {
            let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
        Mixpanel.mainInstance().trackPushNotification(userInfo)
    }

}
