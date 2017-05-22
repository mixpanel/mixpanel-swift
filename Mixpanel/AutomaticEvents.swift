//
//  AutomaticEvents.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 3/8/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//


protocol AEDelegate {
    func track(event: String?, properties: Properties?)
}

#if DECIDE
import Foundation
import UIKit
import StoreKit

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

    func initializeEvents() {
        let firstOpenKey = "MPFirstOpen"
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            if !isExistingUser() {
                delegate?.track(event: "$ae_first_open", properties: nil)
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
                                               name: .UIApplicationWillResignActive,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive(_:)),
                                               name: .UIApplicationDidBecomeActive,
                                               object: nil)

        SKPaymentQueue.default().add(self)

    }

    @objc func appWillResignActive(_ notification: Notification) {
        sessionLength = roundOneDigit(num: Date().timeIntervalSince1970 - sessionStartTime)
        if sessionLength >= Double(minimumSessionDuration / 1000) &&
           sessionLength <= Double(maximumSessionDuration / 1000) {
            let properties: Properties = ["$ae_session_length": sessionLength]
            delegate?.track(event: "$ae_session", properties: properties)
        }
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        sessionStartTime = Date().timeIntervalSince1970
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

}

#endif
