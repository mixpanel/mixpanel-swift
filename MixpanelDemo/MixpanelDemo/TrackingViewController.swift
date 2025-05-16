//
//  TrackingViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 7/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

class TrackingViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var tableViewItems = ["Track w/o Properties",
                          "Track w Properties",
                          "Time Event 5secs",
                          "Clear Timed Events",
                          "Get Current SuperProperties",
                          "Clear SuperProperties",
                          "Register SuperProperties",
                          "Register SuperProperties Once",
                          "Register SP Once w Default Value",
                          "Unregister SuperProperty",
                          "Load Flags",
                          "Are Features Ready",
                          "Get Feature",
                          "Get Feature Sync",
                          "Get Feature Data",
                          "Get Feature Data Sync",
                          "Is Feature Enabled",
                          "Is Feature Enabled Sync"]

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

        let actionStr = self.tableViewItems[indexPath.item]
        var descStr = ""

        switch indexPath.item {
        case 0:
            let ev = "Track Event!"
            Mixpanel.mainInstance().track(event: ev)
            descStr = "Event: \"\(ev)\""
        case 1:
            let ev = "Track Event With Properties!"
            let p = ["Cool Property": "Property Value"]
            Mixpanel.mainInstance().track(event: ev, properties: p)
            descStr = "Event: \"\(ev)\"\n Properties: \(p)"
        case 2:
            let ev = "Timed Event"
            Mixpanel.mainInstance().time(event: ev)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Mixpanel.mainInstance().track(event: ev)
            }
            descStr = "Timed Event: \"\(ev)\""
        case 3:
            Mixpanel.mainInstance().clearTimedEvents()
            descStr = "Timed Events Cleared"
        case 4:
            descStr = "Super Properties:\n"
            descStr += "\(Mixpanel.mainInstance().currentSuperProperties())"
        case 5:
            Mixpanel.mainInstance().clearSuperProperties()
            descStr = "Cleared Super Properties"
        case 6:
            let p: Properties = ["Super Property 1": 1,
                     "Super Property 2": "p2",
                     "Super Property 3": Date(),
                     "Super Property 4": ["a":"b"],
                                 "Super Property 5": [3, "a", Date()] as [Any],
                     "Super Property 6":
                        URL(string: "https://mixpanel.com")!,
                     "Super Property 7": NSNull()]
            Mixpanel.mainInstance().registerSuperProperties(p)
            descStr = "Properties: \(p)"
        case 7:
            let p = ["Super Property 1": 2.3]
            Mixpanel.mainInstance().registerSuperPropertiesOnce(p)
            descStr = "Properties: \(p)"
        case 8:
            let p = ["Super Property 1": 1.2]
            Mixpanel.mainInstance().registerSuperPropertiesOnce(p, defaultValue: 2.3)
            descStr = "Properties: \(p) with Default Value: 2.3"
        case 9:
            let p = "Super Property 2"
            Mixpanel.mainInstance().unregisterSuperProperty(p)
            descStr = "Properties: \(p)"
        case 10:
            Mixpanel.mainInstance().flags.loadFlags()
            descStr = "Flags Loaded"
        case 11:
            let ready = Mixpanel.mainInstance().flags.areFlagsReady()
            descStr = "Features Ready: \(ready)"
        case 12:
            var flagData = MixpanelFlagVariant(key: "super-neat")
            Mixpanel.mainInstance().flags.getVariant("marks_nifty_feature_flag", fallback: flagData) { data in
                flagData = data
                print("Feature: \(flagData.key), Value: \(String(describing: flagData.value))")
            }
            descStr = "Feature: \(flagData.key), Value: \(String(describing: flagData.value))"
        case 13:
            var flagData = MixpanelFlagVariant(key: "enabled")
            flagData = Mixpanel.mainInstance().flags.getVariantSync("jb_qa_flag", fallback: flagData)
            descStr = "Feature: \(flagData.key), Value: \(String(describing: flagData.value))"
        case 14:
            var flagValue = "NOT_donnaqacontrol"
            Mixpanel.mainInstance().flags.getVariantValue("new_feature_flag_1744737773860", fallbackValue: flagValue) { value in
                flagValue = value as! String
                print("Feature Value: \(flagValue)")
            }
            descStr = "Feature Value: \(flagValue)"
        case 15:
            var flagValue = "NOT_donnaqacontrol"
            flagValue = Mixpanel.mainInstance().flags.getVariantValueSync("new_feature_flag_1744737773860", fallbackValue: flagValue) as! String
            descStr = "Feature Value: \(flagValue)"
        case 16:
            var enabled = false
            Mixpanel.mainInstance().flags.isFlagEnabled("jared_boolean_flag", fallbackValue: enabled) { isEnabled in
                enabled = isEnabled
                print("Feature Enabled: \(enabled)")
            }
            descStr = "Feature Enabled: \(enabled)"
        case 17:
            var enabled = false
            enabled = Mixpanel.mainInstance().flags.isFlagEnabledSync("jared_boolean_flag", fallbackValue: enabled)
            descStr = "Feature Enabled: \(enabled)"
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
