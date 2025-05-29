//
//  PeopleViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 7/15/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Mixpanel
import UIKit

class PeopleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

  @IBOutlet weak var tableView: UITableView!
  var tableViewItems = [
    "Set Properties",
    "Set One Property",
    "Set Properties Once",
    "Unset Properties",
    "Incremet Properties",
    "Increment Property",
    "Append Properties",
    "Union Properties",
    "Track Charge w/o Properties",
    "Track Charge w Properties",
    "Clear Charges",
    "Delete User",
    "Identify",
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.delegate = self
    tableView.dataSource = self
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
    cell.textLabel?.text = tableViewItems[indexPath.item]
    cell.textLabel?.textColor = #colorLiteral(
      red: 0.200000003, green: 0.200000003, blue: 0.200000003, alpha: 1)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let actionStr = tableViewItems[indexPath.item]
    var descStr = ""

    switch indexPath.item {
    case 0:
      let p: Properties = [
        "a": 1,
        "b": 2.3,
        "c": ["4", 5] as [Any],
        "d": URL(string: "https://mixpanel.com")!,
        "e": NSNull(),
        "f": Date(),
      ]
      Mixpanel.mainInstance().people.set(properties: p)
      descStr = "Properties: \(p)"
    case 1:
      Mixpanel.mainInstance().people.set(property: "g", to: "yo")
      descStr = "Property key: g, value: yo"
    case 2:
      let p = ["h": "just once"]
      Mixpanel.mainInstance().people.setOnce(properties: p)
      descStr = "Properties: \(p)"
    case 3:
      let p = ["b", "h"]
      Mixpanel.mainInstance().people.unset(properties: p)
      descStr = "Unset Properties: \(p)"
    case 4:
      let p = ["a": 1.2, "b": 3]
      Mixpanel.mainInstance().people.increment(properties: p)
      descStr = "Properties: \(p)"
    case 5:
      Mixpanel.mainInstance().people.increment(property: "b", by: 2.3)
      descStr = "Property key: b, value increment: 2.3"
    case 6:
      let p = ["c": "hello", "d": "goodbye"]
      Mixpanel.mainInstance().people.append(properties: p)
      descStr = "Properties: \(p)"
    case 7:
      let p = ["c": ["goodbye", "hi"], "d": ["hello"]]
      Mixpanel.mainInstance().people.union(properties: p)
      descStr = "Properties: \(p)"
    case 8:
      Mixpanel.mainInstance().people.trackCharge(amount: 20.5)
      descStr = "Amount: 20.5"
    case 9:
      let p = ["sandwich": 1]
      Mixpanel.mainInstance().people.trackCharge(amount: 12.8, properties: p)
      descStr = "Amount: 12.8, Properties: \(p)"
    case 10:
      Mixpanel.mainInstance().people.clearCharges()
      descStr = "Cleared Charges"
    case 11:
      Mixpanel.mainInstance().people.deleteUser()
      descStr = "Deleted User"
    case 12:
      // Mixpanel People requires that you explicitly set a distinct ID for the current user. In this case,
      // we're using the automatically generated distinct ID from event tracking, based on the device's MAC address.
      // It is strongly recommended that you use the same distinct IDs for Mixpanel Engagement and Mixpanel People.
      // Note that the call to Mixpanel People identify: can come after properties have been set. We queue them until
      // identify: is called and flush them at that time. That way, you can set properties before a user is logged in
      // and identify them once you know their user ID.
      Mixpanel.mainInstance().identify(distinctId: "testDistinctId111")
      descStr = "Identified User"
    default:
      break
    }

    let vc =
      storyboard!.instantiateViewController(withIdentifier: "ActionCompleteViewController")
      as! ActionCompleteViewController
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
