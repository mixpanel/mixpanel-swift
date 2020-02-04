//
//  AutomaticEvents.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 3/8/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

protocol AEDelegate {
    func track(event: String?, properties: Properties?)
    func setOnce(properties: Properties)
    func increment(property: String, by: Double)
    #if DECIDE
    func trackPushNotification(_ userInfo: [AnyHashable: Any], event: String, properties: Properties)
    #endif
}

#if DECIDE || TV_AUTO_EVENTS
import Foundation
import UIKit
import StoreKit
import UserNotifications

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
    var sessionLength: TimeInterval = 0
    var sessionStartTime: TimeInterval = Date().timeIntervalSince1970
    var hasAddedObserver = false
    var automaticPushTracking = true
    var firstAppOpen = false

    func initializeEvents() {
        let firstOpenKey = "MPFirstOpen"
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            if !isExistingUser() {
                firstAppOpen = true
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
                appVersionValue.compare(savedVersionValue, options: .numeric, range: nil, locale: nil) == .orderedDescending {
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
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive(_:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        #if DECIDE
        SKPaymentQueue.default().add(self)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.automaticPushTracking {
                self.setupAutomaticPushTracking()
            }
        }
        #endif
    }

    @objc func appWillResignActive(_ notification: Notification) {
        sessionLength = roundOneDigit(num: Date().timeIntervalSince1970 - sessionStartTime)
        if sessionLength >= Double(minimumSessionDuration / 1000) &&
           sessionLength <= Double(maximumSessionDuration / 1000) {
            delegate?.track(event: "$ae_session", properties: ["$ae_session_length": sessionLength])
            delegate?.increment(property: "$ae_total_app_sessions", by: 1)
            delegate?.increment(property: "$ae_total_app_session_length", by: sessionLength)
        }
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        sessionStartTime = Date().timeIntervalSince1970
        if firstAppOpen {
            delegate?.track(event: "$ae_first_open", properties: nil)
            delegate?.setOnce(properties: ["$ae_first_app_open_date": Date()])
            firstAppOpen = false
        }
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
        if productIdentifiers.count > 0 {
            productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
            productsRequest.delegate = self
            productsRequest.start()
        }
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

    #if DECIDE
    func setupAutomaticPushTracking() {
        guard let appDelegate = MixpanelInstance.sharedUIApplication()?.delegate else {
            return
        }
        var selector: Selector? = nil
        var newSelector: Selector? = nil
        let aClass: AnyClass = type(of: appDelegate)
        var newClass: AnyClass?
        if #available(iOS 10.0, *), let UNDelegate = UNUserNotificationCenter.current().delegate {
            newClass = type(of: UNDelegate)
        } else if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().addDelegateObserver(ae: self)
            hasAddedObserver = true
        }

        if let newClass = newClass,
            #available(iOS 10.0, *),
            class_getInstanceMethod(newClass,
                NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")) != nil {
            selector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
            newSelector = #selector(NSObject.mp_userNotificationCenter(_:newDidReceive:withCompletionHandler:))
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
            newSelector = #selector(UIResponder.mp_application(_:newDidReceiveRemoteNotification:fetchCompletionHandler:))
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:")
            newSelector = #selector(UIResponder.mp_application(_:newDidReceiveRemoteNotification:))
        }

        if let selector = selector, let newSelector = newSelector {
            let block = { (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
                if let param2 = param2 as? [AnyHashable: Any] {
                    self.delegate?.trackPushNotification(param2, event: "$campaign_received", properties: [:])
                }
            }
            Swizzler.swizzleSelector(selector,
                                     withSelector: newSelector,
                                     for: newClass ?? aClass,
                                     name: "notification opened",
                                     block: block)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if #available(iOS 10.0, *),
            keyPath == "delegate",
            let UNDelegate = UNUserNotificationCenter.current().delegate {
            let delegateClass: AnyClass = type(of: UNDelegate)
            if class_getInstanceMethod(delegateClass,
                    NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")) != nil {
                let selector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
                let newSelector = #selector(NSObject.mp_userNotificationCenter(_:newDidReceive:withCompletionHandler:))
                let block = { (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
                    if let param2 = param2 as? [AnyHashable: Any] {
                        self.delegate?.trackPushNotification(param2, event: "$campaign_received", properties: [:])
                    }
                }
                Swizzler.swizzleSelector(selector,
                                         withSelector: newSelector,
                                         for: delegateClass,
                                         name: "notification opened",
                                         block: block)
            }
        }
    }

    deinit {
        if #available(iOS 10.0, *), hasAddedObserver {
            UNUserNotificationCenter.current().removeDelegateObserver(ae: self)
        }
    }
    #endif // DECIDE
}

#if DECIDE
@available(iOS 10.0, *)
extension UNUserNotificationCenter {
    func addDelegateObserver(ae: AutomaticEvents) {
        addObserver(ae, forKeyPath: #keyPath(delegate), options: [.old, .new], context: nil)
    }

    func removeDelegateObserver(ae: AutomaticEvents) {
        removeObserver(ae, forKeyPath: #keyPath(delegate))
    }
}

extension UIResponder {
    @objc func mp_application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        let originalSelector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary, @escaping (UIBackgroundFetchResult) -> Void) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, application, userInfo as NSDictionary, completionHandler)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, application as AnyObject?, userInfo as AnyObject?)
            }
        }
    }

    @objc func mp_application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
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

@available(iOS 10.0, *)
extension NSObject {
    @objc func mp_userNotificationCenter(_ center: UNUserNotificationCenter,
                                      newDidReceive response: UNNotificationResponse,
                                      withCompletionHandler completionHandler: @escaping () -> Void) {
        let originalSelector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, center, response, completionHandler)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, center as AnyObject?, response.notification.request.content.userInfo as AnyObject?)
            }
        }
    }
}
#endif // DECIDE

#endif
