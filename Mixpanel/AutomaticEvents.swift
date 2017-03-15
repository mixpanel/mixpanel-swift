//
//  AutomaticEvents.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 3/8/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
//    optional public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool
    //application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    @objc func newDidFinishLaunchingWithOptions(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        let originalSelector = NSSelectorFromString("application:didFinishLaunchingWithOptions:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary) -> Bool
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, application, launchOptions)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, tableView, indexPath as AnyObject?)
            }
        }
    }
    
}
