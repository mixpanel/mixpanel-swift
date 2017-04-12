//
//  AutomaticEvents.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 3/8/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

protocol TrackDelegate {
    func track(event: String?, properties: Properties?)
    func time(event: String)
}

class AutomaticEvents {
    let defaults = UserDefaults(suiteName: "Mixpanel")
    var delegate: TrackDelegate?

    init() {
        let firstOpenKey = "MPfirstOpen"
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            delegate?.track(event: "MP: First App Open", properties: nil)
            defaults.set(true, forKey: firstOpenKey)
            defaults.synchronize()
        }
        delegate?.time(event: "MP: App Open")

        if let defaults = defaults, let infoDict = Bundle.main.infoDictionary {
            let appVersionKey = "MPAppVersion"
            let appVersionValue = infoDict["CFBundleShortVersionString"]
            if let appVersionValue = appVersionValue as? String,
                appVersionValue != defaults.string(forKey: appVersionKey) {
                delegate?.track(event: "MP: App Updated", properties: ["App Version": appVersionValue])
                defaults.set(appVersionValue, forKey: appVersionKey)
                defaults.synchronize()
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appEnteredBackground(_:)),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        Swizzler.swizzleSelector(NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:"), withSelector: #selector(UIResponder.application(_:newDidReceiveRemoteNotification:fetchCompletionHandler:)), for: type(of: UIApplication.shared.delegate!), name: "notification opened", block: { _ in
                self.delegate?.track(event: "MP: Notification Opened", properties: nil)
        })

    }

    @objc private func appEnteredBackground(_ notification: Notification) {
        delegate?.track(event: "MP: App Open", properties: nil)
    }

}


extension UIResponder {

    //    optional public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool
    //application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    //    @objc func newDidFinishLaunchingWithOptions(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    //        let originalSelector = NSSelectorFromString("application(_:didFinishLaunchingWithOptions:)")
    //        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
    //            let swizzle = Swizzler.swizzles[originalMethod] {
    //            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary) -> Bool
    //            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
    //            let ret = curriedImplementation(self, originalSelector, application, launchOptions! as NSDictionary)
    //
    //            for (_, block) in swizzle.blocks {
    //                block(self, swizzle.selector, application as AnyObject?, launchOptions as AnyObject?)
    //            }
    //
    //            return ret
    //        }
    //        return true
    //    }

    func application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        let originalSelector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary, (UIBackgroundFetchResult) -> Void) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, application, userInfo as NSDictionary, completionHandler)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, application as AnyObject?, userInfo as AnyObject?)
            }
            
        }
    }
    
}
