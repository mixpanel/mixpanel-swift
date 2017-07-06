//
//  UtilityViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 7/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel
import StoreKit

class UtilityViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SKProductsRequestDelegate, SKPaymentTransactionObserver {

    @IBOutlet weak var tableView: UITableView!
    var tableViewItems = ["Create Alias",
                          "Reset",
                          "Archive",
                          "Flush",
                          "In-App Purchase"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
        cell.textLabel?.text = tableViewItems[indexPath.item]
        cell.textLabel?.textColor = #colorLiteral(red: 0.200000003, green: 0.200000003, blue: 0.200000003, alpha: 1)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let actionStr = tableViewItems[indexPath.item]
        var descStr = ""

        switch indexPath.item {
        case 0:
            Mixpanel.mainInstance().createAlias("New Alias", distinctId: Mixpanel.mainInstance().distinctId)
            descStr = "Alias: New Alias, from: \(Mixpanel.mainInstance().distinctId)"
        case 1:
            Mixpanel.mainInstance().reset()
            descStr = "Reset Instance"
        case 2:
            Mixpanel.mainInstance().archive()
            descStr = "Archived Data"
        case 3:
            Mixpanel.mainInstance().flush()
            descStr = "Flushed Data"
        case 4:
            IAPFlow()
        default:
            break
        }

        let vc = storyboard!.instantiateViewController(withIdentifier: "ActionCompleteViewController") as! ActionCompleteViewController
        vc.actionStr = actionStr
        vc.descStr = descStr
        vc.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        vc.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        present(vc, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewItems.count
    }

    func IAPFlow() {
        let productIdentifiers = NSSet(objects:
            "com.iaptutorial.fun",
            "com.mixpanel.swiftsdkdemo.fun"
        )
        let productsRequest =  SKProductsRequest(productIdentifiers: productIdentifiers as! Set<String>)
        productsRequest.delegate = self
        productsRequest.start()
    }

    func productsRequest (_ request:SKProductsRequest, didReceive response:SKProductsResponse) {
        if (response.products.count > 0) {
            if let firstProduct = response.products.first {
                let payment = SKPayment(product: firstProduct)
                SKPaymentQueue.default().add(self)
                SKPaymentQueue.default().add(payment)
            }
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction:AnyObject in transactions {
            if let trans = transaction as? SKPaymentTransaction {
                switch trans.transactionState {
                case .purchased:
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    print("IAP purchased")
                    break

                case .failed:
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    print("IAP failed")
                    break
                case .restored:
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    print("IAP restored")
                    break
                    
                default: break
                }
            }
        }
    }

}
