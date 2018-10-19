//
//  GroupsViewController.swift
//  MixpanelDemo
//
//  Created by Iris McLeary on 9/7/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

class GroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var tableViewItems = ["Set Properties",
                          "Set One Property",
                          "Set Properties Once",
                          "Unset Property",
                          "Remove Property",
                          "Union Properties",
                          "Delete Group",
                          "Set Group",
                          "Set One Group",
                          "Add Group",
                          "Remove Group",
                          "Track with Groups"]

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
        
        let groupKey = "Cool Property"
        let groupID = 12345

        switch indexPath.item {
        case 0:
            let p: Properties = ["a": 1,
                                 "b": 2.3,
                                 "c": ["4", 5],
                                 "d": URL(string:"https://mixpanel.com")!,
                                 "e": NSNull(),
                                 "f": Date()]
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).set(properties: p)
            descStr = "Properties: \(p)"
        case 1:
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).set(property: "g", to: "yo")
            descStr = "Property key: g, value: yo"
        case 2:
            let p = ["h": "just once"]
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).setOnce(properties: p)
            descStr = "Properties: \(p)"
        case 3:
            let p = "b"
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).unset(property: p)
            descStr = "Unset Property: \(p)"
        case 4:
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).remove(key: "c", value: 5)
            descStr = "Remove Property: [\"c\" : 5]"
        case 5:
            let p = ["c": [5, 4]]
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).union(key: "c", values: p["c"]!)
            descStr = "Properties: \(p)"
        case 6:
            Mixpanel.mainInstance().getGroup(groupKey: groupKey, groupID: groupID).deleteGroup()
            descStr = "Deleted Group"
        case 7:
            let groupIDs = [groupID, 301]
            Mixpanel.mainInstance().setGroup(groupKey: groupKey, groupIDs: groupIDs)
            descStr = "Set Group \(groupKey) to \(groupIDs)"
        case 8:
            Mixpanel.mainInstance().setGroup(groupKey: groupKey, groupID: groupID)
            descStr = "Set Group \(groupKey) to \(groupID)"
        case 9:
            let newID = "iris_test3"
            Mixpanel.mainInstance().addGroup(groupKey: groupKey, groupID: newID)
            descStr = "Add Group \(groupKey), ID \(newID)"
        case 10:
            Mixpanel.mainInstance().removeGroup(groupKey: groupKey, groupID: groupID)
            descStr = "Remove Group \(groupKey), ID \(groupID)"
        case 11:
            let p: Properties = ["a": 1,
                                 "b": 2.3,
                                 "c": ["4", 5],
                                 "d": URL(string:"https://mixpanel.com")!,
                                 "e": NSNull(),
                                 "f": Date(),
                                 "Cool Property": "foo"]
            let groups: Properties = ["Cool Property": "actual group value"]
            Mixpanel.mainInstance().trackWithGroups(event: "tracked with groups", properties: p, groups: groups)
            descStr = "Track with groups: properties \(p), groups \(groups)"
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
