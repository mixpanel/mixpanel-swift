//
//  GDPRViewController.swift
//  MixpanelDemo
//
//  Created by Zihe Jia on 4/5/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

class GDPRViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    var tableViewItems = ["Opt Out",
                          "Check Opted Out Flag",
                          "Opt In",
                          "Opt In w DistinctId",
                          "Opt In w DistinctId & Properties",
                          "Init with default opt-out",
                          "Init with default opt-in"
                          ]
    
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
            Mixpanel.mainInstance().optOutTracking()
            descStr = "Opted out"
        case 1:
            descStr = "Opt-out flag is \(Mixpanel.mainInstance().hasOptedOutTracking())"
        case 2:
            Mixpanel.mainInstance().optInTracking()
            descStr = "Opted In"
        case 3:
            Mixpanel.mainInstance().optInTracking(distinctId: "aDistinctIdForOptIn")
            descStr = "Opt In with distinctId 'aDistinctIdForOptIn'"
        case 4:
            let p: Properties = ["a": 1,
                                 "b": 2.3,
                                 "c": ["4", 5],
                                 "d": URL(string:"https://mixpanel.com")!,
                                 "e": NSNull(),
                                 "f": Date()]
            Mixpanel.mainInstance().optInTracking(distinctId: "aDistinctIdForOptIn", properties: p)
            descStr = "Opt In with distinctId 'aDistinctIdForOptIn' and \(p)"
        case 5:
            Mixpanel.initialize(token: "a token id", optOutTrackingByDefault: true)
            descStr = "Init Mixpanel with default opt-out(sample only), to make it work, place it in your startup stage of your app"
        case 6:
            Mixpanel.initialize(token: "a token id", optOutTrackingByDefault: false)
            descStr = "Init Mixpanel with default opt-in(sample only), to make it work, place it in your startup stage of your app"
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
}
