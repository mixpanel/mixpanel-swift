//
//  AutomaticEvents.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 3/8/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

protocol TrackDelegate {
    func track(event: String?, properties: Properties?)
    func time(event: String)
}

class AutomaticEvents: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {

    var _minimumSessionDuration: UInt64 = 10000
    var minimumSessionDuration: UInt64 {
        set {
            _minimumSessionDuration = newValue
        }
        get {
            return _minimumSessionDuration
        }
    }
    var _sessionTimeout: UInt64 = 1800000
    var sessionTimeout: UInt64 {
        set {
            _sessionTimeout = newValue
        }
        get {
            return _sessionTimeout
        }
    }
    var awaitingTransactions = [String: SKPaymentTransaction]()
    let defaults = UserDefaults(suiteName: "Mixpanel")
    var delegate: TrackDelegate?
    static var appStartTime = DispatchTime.now()
    var appLoadSpeed: UInt64 = 0
    var sessionLength: Float = 0
    var sessionStartTime: UInt64 = 0

    override init() {
        super.init()
        let firstOpenKey = "MPfirstOpen"
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            delegate?.track(event: "MP: First App Open", properties: nil)
            defaults.set(true, forKey: firstOpenKey)
            defaults.synchronize()
        }

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

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive(_:)),
                                               name: .UIApplicationDidBecomeActive,
                                               object: nil)

        SKPaymentQueue.default().add(self)

        Swizzler.swizzleSelector(NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:"),
                                 withSelector: #selector(UIResponder.application(_:newDidReceiveRemoteNotification:fetchCompletionHandler:)),
                                 for: type(of: UIApplication.shared.delegate!), name: "notification opened",
                                 block: { _ in
            self.delegate?.track(event: "MP: Notification Opened", properties: nil)
        })
    }

    @objc private func appEnteredBackground(_ notification: Notification) {
        sessionLength = Float(DispatchTime.now().uptimeNanoseconds - sessionStartTime) / 1000000000
        if sessionLength > Float(minimumSessionDuration) / 1000 {
            delegate?.track(event: "MP: App Open", properties: ["Session Length": sessionLength,
                                                                "App Load Speed (ms)": UInt(appLoadSpeed)])
        }
//        if let defaults = defaults {
//            let sessionTimeoutKey = "MPSessionTimeoutKey"
//            defaults.set(Date(), forKey: sessionTimeoutKey)
//            defaults.synchronize()
//        }
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        let nowTime = DispatchTime.now().uptimeNanoseconds
        appLoadSpeed = (nowTime -
            AutomaticEvents.appStartTime.uptimeNanoseconds) / 1000000
        sessionStartTime = nowTime
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        var productsRequest = SKProductsRequest()
        var productIdentifiers: Set<String> = []
        objc_sync_enter(awaitingTransactions)
        for transaction:AnyObject in transactions {
            if let trans = transaction as? SKPaymentTransaction {
                switch trans.transactionState {
                case .purchased:
                    productIdentifiers.insert(trans.payment.productIdentifier)
                    awaitingTransactions[trans.payment.productIdentifier] = trans
                    break
                case .failed: break
                case .restored: break
                default: break
                }
            }
        }
        objc_sync_exit(awaitingTransactions)
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest.delegate = self
        productsRequest.start()
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        objc_sync_enter(awaitingTransactions)
        for product in response.products {
            if let trans = awaitingTransactions[product.productIdentifier] {
                delegate?.track(event: "MP: In-App Purchase", properties: ["Price": "\(product.price)",
                    "Quantity": trans.payment.quantity,
                    "Product Name": product.productIdentifier])
                awaitingTransactions.removeValue(forKey: product.productIdentifier)
            }
        }
        objc_sync_exit(awaitingTransactions)
    }

}

extension UIApplication {
    private static let runOnce: Void = {
        AutomaticEvents.appStartTime = DispatchTime.now()
    }()

    override open var next: UIResponder? {
        // Called before applicationDidFinishLaunching
        UIApplication.runOnce
        return super.next
    }
}

extension UIResponder {

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

    func application(_ application: UIApplication, newDidFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        let originalSelector = NSSelectorFromString("application:didFinishLaunchingWithOptions:")
        var retValue = true
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary?) -> Bool
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            retValue = curriedImplementation(self, originalSelector, application, launchOptions as NSDictionary?)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, application as AnyObject?, launchOptions as AnyObject?)
            }
        }
        return retValue
    }
}
