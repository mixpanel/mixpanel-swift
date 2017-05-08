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
import Mixpanel.ObjectiveCTools

protocol AEDelegate {
    func track(event: String?, properties: Properties?)
}

class AutomaticEvents: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {

    var _minimumSessionDuration: UInt64 = 2000
    var minimumSessionDuration: UInt64 {
        set {
            _minimumSessionDuration = newValue
        }
        get {
            return _minimumSessionDuration
        }
    }
    var _maximumSessionDuration: UInt64 = UINT64_MAX
    var maximumSessionDuration: UInt64 {
        set {
            _maximumSessionDuration = newValue
        }
        get {
            return _maximumSessionDuration
        }
    }
    var awaitingTransactions = [String: SKPaymentTransaction]()
    let defaults = UserDefaults(suiteName: "Mixpanel")
    var delegate: AEDelegate?
    static var appStartTime = Date().timeIntervalSince1970
    var sessionLength: TimeInterval = 0
    var sessionStartTime: TimeInterval = 0
    var people: People? = nil

    func initializeEvents(people: People) {
        self.people = people
        let firstOpenKey = "MPfirstOpen"
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            if !isExistingUser() {
                delegate?.track(event: "$ae_first_open", properties: nil)
                self.people!.setOnce(properties: ["$ae_first_app_open_date": Date()])
            }
            defaults.set(true, forKey: firstOpenKey)
            defaults.synchronize()
        }

        if let defaults = defaults, let infoDict = Bundle.main.infoDictionary {
            let appVersionKey = "MPAppVersion"
            let appVersionValue = infoDict["CFBundleShortVersionString"]
            let savedVersionValue = defaults.string(forKey: appVersionKey)
            if let appVersionValue = appVersionValue as? String,
                let savedVersionValue = savedVersionValue,
                appVersionValue != savedVersionValue {
                delegate?.track(event: "$ae_updated", properties: ["$ae_updated_version": appVersionValue])
                defaults.set(appVersionValue, forKey: appVersionKey)
                defaults.synchronize()
            } else if savedVersionValue == nil {
                defaults.set(appVersionValue, forKey: appVersionKey)
                defaults.synchronize()
            }
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillResignActive(_:)),
                                               name: .UIApplicationWillResignActive,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive(_:)),
                                               name: .UIApplicationDidBecomeActive,
                                               object: nil)

        SKPaymentQueue.default().add(self)

        guard let appDelegate = UIApplication.shared.delegate else {
            return
        }
        var selector: Selector? = nil
        let aClass: AnyClass = type(of: appDelegate)
        if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:")
        }

        if let selector = selector {
            Swizzler.swizzleSelector(selector,
                                     withSelector: #selector(UIResponder.application(_:newDidReceiveRemoteNotification:fetchCompletionHandler:)),
                                     for: aClass,
                                     name: "notification opened",
                                     block: { _ in
                                        self.delegate?.track(event: "$ae_notif_opened", properties: nil)
            })
        }

    }

    @objc private func appWillResignActive(_ notification: Notification) {
        sessionLength = roundOneDigit(num: Date().timeIntervalSince1970 - sessionStartTime)
        if sessionLength > Double(minimumSessionDuration / 1000) &&
           sessionLength < Double(maximumSessionDuration / 1000) {
            let properties: Properties = ["$ae_session_length": sessionLength]
            delegate?.track(event: "$ae_session", properties: properties)
            people!.increment(property: "$ae_total_app_sessions", by: 1)
            people!.increment(property: "$ae_total_app_session_length", by: sessionLength)
        }
        AutomaticEvents.appStartTime = 0
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        let nowTime = Date().timeIntervalSince1970
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

    func roundOneDigit(num: TimeInterval) -> TimeInterval {
        return round(num * 10.0) / 10.0
    }

    func isExistingUser() -> Bool {
        do {
            if let searchPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last {
                let pathContents = try FileManager.default.contentsOfDirectory(atPath: searchPath)
                for path in pathContents {
                    if path.hasPrefix("mixpanel-") {
                        return true
                    }
                }
            }
        } catch {
            return false
        }
        return false
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        objc_sync_enter(awaitingTransactions)
        for product in response.products {
            if let trans = awaitingTransactions[product.productIdentifier] {
                delegate?.track(event: "$ae_iap", properties: ["$ae_iap_price": "\(product.price)",
                    "$ae_iap_quantity": trans.payment.quantity,
                    "$ae_iap_name": product.productIdentifier])
                awaitingTransactions.removeValue(forKey: product.productIdentifier)
            }
        }
        objc_sync_exit(awaitingTransactions)
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

    func application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        let originalSelector = NSSelectorFromString("application:didReceiveRemoteNotification:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, application, userInfo as NSDictionary)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, application as AnyObject?, userInfo as AnyObject?)
            }
        }
    }
}
