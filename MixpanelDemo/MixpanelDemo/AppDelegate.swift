//
//  AppDelegate.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var pushDeviceToken: Data?

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        var ADD_YOUR_MIXPANEL_TOKEN_BELOW_🛠🛠🛠🛠🛠🛠: String
        
        Mixpanel.initialize(token: "MIXPANEL_TOKEN")
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().flushInterval = 5
        let allTweaks: [TweakClusterType] = [MixpanelTweaks.floatTweak,
                                             MixpanelTweaks.intTweak,
                                             MixpanelTweaks.boolTweak,
                                             MixpanelTweaks.stringTweak]
        MixpanelTweaks.setTweaks(tweaks: allTweaks)
        registerNotification()

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        pushDeviceToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        debugPrint(error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        debugPrint("did receive remote notification")

        if let message = (userInfo["aps"] as? [String: Any])?["alert"] as? String {
            let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
        completionHandler(.newData)
    }

    func registerNotification() {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: { (granted, error) in
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            })
            UNUserNotificationCenter.current().delegate = self
        } else {
            let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            DispatchQueue.main.async {
                UIApplication.shared.registerUserNotificationSettings(settings)
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }

    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if MixpanelPushNotifications.isMixpanelPushNotification(response.notification.request.content) {
            debugPrint("Handling Mixpanel push notification response...")
            MixpanelPushNotifications.handleResponse(response: response, withCompletionHandler: completionHandler)
        } else {
            // not a Mixpanel push notification
            debugPrint("Not a Mixpanel push notification.")
            completionHandler()
        }
    }

}

extension MixpanelTweaks {
    public static let floatTweak = Tweak<CGFloat>(tweakName: "floatTweak", defaultValue: 20.5, min: 0, max: 30.1)
    public static let intTweak = Tweak<Int>(tweakName: "intTweak", defaultValue: 10, min: 0)
    public static let boolTweak = Tweak(tweakName: "boolTweak", defaultValue: true)
    public static let stringTweak = Tweak(tweakName: "stringTweak", defaultValue: "hello")
}
