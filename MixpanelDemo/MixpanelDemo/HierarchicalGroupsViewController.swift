//
//  HierarchicalGroupsViewController.swift
//  MixpanelDemo
//
//  Copyright (c) Mixpanel. All rights reserved.
//

import Mixpanel
import UIKit

// Hierarchical groups is an init-time option and instances are cached per token, so this page
// uses its own project rather than the one AppDelegate initializes.
let mixpanelHGProjectToken = "0d15128ec05aa2ba0fb3d45185f63a11"

// Filter the console on "HGDemo" to see each button's header line, followed by the SDK's own
// log lines for the call and the flush it triggers.
private let logTag = "HGDemo"

class HierarchicalGroupsViewController: UIViewController, UITableViewDelegate,
    UITableViewDataSource
{

    private struct HGAction {
        let title: String
        let message: String
        let run: () -> Void
    }

    private struct HGSection {
        let title: String
        let actions: [HGAction]
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let userIdField = UITextField()
    private let companyIdField = UITextField()
    private let teamIdField = UITextField()

    private lazy var mixpanel: MixpanelInstance = {
        // Initializing an instance makes it the main instance, so put the app's main one back
        let previousMainInstanceName = Mixpanel.safeMainInstance()?.name
        let options = MixpanelOptions(
            token: mixpanelHGProjectToken,
            // No automatic events, so each flush sends only what the button's call queued
            trackAutomaticEvents: false,
            hierarchicalGroups: true
        )
        let instance = Mixpanel.initialize(options: options)
        instance.loggingEnabled = true
        if let previousMainInstanceName = previousMainInstanceName {
            Mixpanel.setMainInstance(name: previousMainInstanceName)
        }
        return instance
    }()

    private var userId: String { userIdField.text ?? "" }
    private var companyId: String { companyIdField.text ?? "" }
    private var teamId: String { teamIdField.text ?? "" }

    private lazy var sections: [HGSection] = [
        HGSection(title: "Identity", actions: identityActions()),
        HGSection(title: "Opt Out and In", actions: optActions()),
        HGSection(title: "Events", actions: eventActions()),
        HGSection(title: "User Profile", actions: userActions()),
        HGSection(
            title: "Company",
            actions: groupActions(label: "Company", groupKey: "$company_id") { [unowned self] in
                self.mixpanel.getCompany()
            }),
        HGSection(
            title: "Team",
            actions: groupActions(label: "Team", groupKey: "team_id") { [unowned self] in
                self.mixpanel.getGroup(groupKey: "team_id", groupID: self.teamId)
            }),
        HGSection(title: "Utility", actions: utilityActions()),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hierarchical Groups"
        view.backgroundColor = .systemBackground
        _ = mixpanel

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        tableView.tableHeaderView = makeFieldsHeader()
    }

    private func makeFieldsHeader() -> UIView {
        let stack = UIStackView(arrangedSubviews: [
            makeFieldRow(label: "User ID", field: userIdField, value: "tyler_ios"),
            makeFieldRow(label: "Company ID", field: companyIdField, value: "violet_tiger"),
            makeFieldRow(label: "Team ID", field: teamIdField, value: "ios_team"),
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 152))
        header.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
        ])
        return header
    }

    private func makeFieldRow(label: String, field: UITextField, value: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true

        field.text = value
        field.placeholder = label
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        field.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let row = UIStackView(arrangedSubviews: [titleLabel, field])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    // MARK: - Actions

    private func identityActions() -> [HGAction] {
        return [
            HGAction(title: "Identify", message: "Identify: user + company") { [unowned self] in
                print("Identifying \(self.userId) at \(self.companyId)")
                self.mixpanel.identify(
                    identity: MixpanelIdentity(userId: self.userId, companyId: self.companyId))
            },
            HGAction(title: "Invalid: Identify Without Company", message: "Identify: user only") {
                [unowned self] in
                print("Identifying \(self.userId) without a company")
                self.mixpanel.identify(identity: MixpanelIdentity(userId: self.userId))
            },
            HGAction(title: "Invalid: Identify With Distinct ID", message: "identify(distinctId:)") {
                [unowned self] in
                print("Identifying \(self.userId) with identify(distinctId:)")
                self.mixpanel.identify(distinctId: self.userId)
            },
            HGAction(title: "Invalid: Alias", message: "createAlias") { [unowned self] in
                print("Aliasing new_alias")
                self.mixpanel.createAlias("new_alias", distinctId: self.mixpanel.distinctId)
            },
            HGAction(title: "Show Identity", message: "Identity (see console)") { [unowned self] in
                print(
                    "\(logTag): identity=\(self.mixpanel.identity) "
                        + "optedOut=\(self.mixpanel.hasOptedOutTracking()) "
                        + "superProperties=\(self.mixpanel.currentSuperProperties())")
            },
        ]
    }

    private func optActions() -> [HGAction] {
        return [
            HGAction(title: "Opt Out", message: "optOutTracking") { [unowned self] in
                print("Opting out")
                self.mixpanel.optOutTracking()
            },
            HGAction(title: "Opt In", message: "optInTracking") { [unowned self] in
                print("Opting in anonymously")
                self.mixpanel.optInTracking()
            },
            HGAction(title: "Opt In With Identity", message: "optInTracking(identity:)") {
                [unowned self] in
                print("Opting in as \(self.userId) at \(self.companyId)")
                self.mixpanel.optInTracking(
                    identity: MixpanelIdentity(userId: self.userId, companyId: self.companyId))
            },
            HGAction(
                title: "Invalid: Opt In With Distinct ID", message: "optInTracking(distinctId:)"
            ) { [unowned self] in
                print("Opting in as \(self.userId) with optInTracking(distinctId:)")
                self.mixpanel.optInTracking(distinctId: self.userId)
            },
        ]
    }

    private func eventActions() -> [HGAction] {
        return [
            HGAction(title: "Track Event", message: "Event: \"HG Event!\"") { [unowned self] in
                print("Tracking HG event")
                self.mixpanel.track(
                    event: "HG Event!", properties: ["source": "hierarchical_groups_page"])
            },
            HGAction(title: "Set Team Group", message: "setGroup: team_id") { [unowned self] in
                print("Setting team_id to \(self.teamId)")
                self.mixpanel.setGroup(groupKey: "team_id", groupID: self.teamId)
            },
            HGAction(title: "Invalid: Set Team Groups (List)", message: "setGroup: team_id list") {
                [unowned self] in
                print("Setting team_id to a list of \(self.teamId)")
                self.mixpanel.setGroup(groupKey: "team_id", groupIDs: [self.teamId])
            },
            HGAction(title: "Invalid: Add Team Group", message: "addGroup: team_id") {
                [unowned self] in
                print("Adding team_id \(self.teamId)")
                self.mixpanel.addGroup(groupKey: "team_id", groupID: self.teamId)
            },
            HGAction(title: "Remove Team Group", message: "removeGroup: team_id") {
                [unowned self] in
                print("Removing team_id \(self.teamId)")
                self.mixpanel.removeGroup(groupKey: "team_id", groupID: self.teamId)
            },
            HGAction(title: "Track With Team Group", message: "Event: \"HG Team Event!\"") {
                [unowned self] in
                print("Tracking HG event with team_id \(self.teamId)")
                self.mixpanel.trackWithGroups(
                    event: "HG Team Event!", properties: nil, groups: ["team_id": self.teamId])
            },
        ]
    }

    // The user profile is the $user_id group profile within the company
    private func userActions() -> [HGAction] {
        return [
            HGAction(title: "User: Set Property", message: "People: set \"plan\"") {
                [unowned self] in
                print("Setting a user property")
                self.mixpanel.people.set(property: "plan", to: "enterprise")
            },
            HGAction(title: "User: Set Properties (Map)", message: "People: set properties") {
                [unowned self] in
                print("Setting multiple user properties")
                self.mixpanel.people.set(properties: ["role": "admin", "seats": 5])
            },
            HGAction(title: "User: Set Property Once", message: "People: setOnce \"first_seen\"") {
                [unowned self] in
                print("Setting a user property once")
                self.mixpanel.people.setOnce(properties: ["first_seen": "2026-10-27"])
            },
            HGAction(title: "User: Union Property", message: "People: union \"devices\"") {
                [unowned self] in
                print("Union user property")
                self.mixpanel.people.union(properties: ["devices": ["ios", "android"]])
            },
            HGAction(title: "User: Remove Property", message: "People: remove from \"devices\"") {
                [unowned self] in
                print("Removing from user property")
                self.mixpanel.people.remove(properties: ["devices": "android"])
            },
            HGAction(title: "User: Unset Property", message: "People: unset \"plan\"") {
                [unowned self] in
                print("Unsetting a user property")
                self.mixpanel.people.unset(properties: ["plan"])
            },
            HGAction(title: "Invalid: User Clear Charges", message: "People: clearCharges") {
                [unowned self] in
                print("Clearing charges")
                self.mixpanel.people.clearCharges()
            },
            HGAction(title: "User: Delete User", message: "People: deleteUser") { [unowned self] in
                print("Deleting user")
                self.mixpanel.people.deleteUser()
            },

            // User profile operations /groups has no equivalent for, dropped with an error log
            HGAction(title: "Invalid: User Increment", message: "People: increment \"logins\"") {
                [unowned self] in
                print("Incrementing a user property")
                self.mixpanel.people.increment(property: "logins", by: 1)
            },
            HGAction(title: "Invalid: User Increment (Map)", message: "People: increment properties")
            { [unowned self] in
                print("Incrementing multiple user properties")
                self.mixpanel.people.increment(properties: ["logins": 1, "sessions": 2])
            },
            HGAction(title: "Invalid: User Append", message: "People: append \"history\"") {
                [unowned self] in
                print("Appending to a user property")
                self.mixpanel.people.append(properties: ["history": "opened_hg_page"])
            },
            HGAction(title: "Invalid: User Track Charge", message: "People: trackCharge 9.99") {
                [unowned self] in
                print("Tracking a charge")
                self.mixpanel.people.trackCharge(amount: 9.99)
            },
        ]
    }

    // The same group profile operations, for the company and for the custom team_id group
    private func groupActions(label: String, groupKey: String, group: @escaping () -> Group?)
        -> [HGAction]
    {
        return [
            HGAction(title: "\(label): Set Property", message: "Group: set \"tier\" on \(groupKey)")
            {
                print("Setting a \(label) property")
                group()?.set(property: "tier", to: "enterprise")
            },
            HGAction(
                title: "\(label): Set Properties (Map)",
                message: "Group: set properties on \(groupKey)"
            ) {
                print("Setting multiple \(label) properties")
                group()?.set(properties: ["size": 12, "region": "us"])
            },
            HGAction(
                title: "\(label): Set Property Once",
                message: "Group: setOnce \"created\" on \(groupKey)"
            ) {
                print("Setting a \(label) property once")
                group()?.setOnce(properties: ["created": "2026-10-27"])
            },
            HGAction(
                title: "\(label): Union Property", message: "Group: union \"tags\" on \(groupKey)"
            ) {
                print("Union \(label) property")
                group()?.union(key: "tags", values: ["ios"])
            },
            HGAction(
                title: "\(label): Remove Property",
                message: "Group: remove from \"tags\" on \(groupKey)"
            ) {
                print("Removing from \(label) property")
                group()?.remove(key: "tags", value: "ios")
            },
            HGAction(
                title: "\(label): Unset Property", message: "Group: unset \"tier\" on \(groupKey)"
            ) {
                print("Unsetting a \(label) property")
                group()?.unset(property: "tier")
            },
            HGAction(title: "\(label): Delete Group", message: "Group: delete \(groupKey)") {
                print("Deleting \(label) group")
                group()?.deleteGroup()
            },
        ]
    }

    private func utilityActions() -> [HGAction] {
        return [
            HGAction(title: "Flush", message: "Flush queued data") { [unowned self] in
                print("Flushing")
                self.mixpanel.flush()
            },
            HGAction(title: "Reset", message: "Reset identity") { [unowned self] in
                print("Resetting")
                self.mixpanel.reset()
            },
        ]
    }

    // MARK: - UITableView

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].actions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = sections[indexPath.section].actions[indexPath.row].title
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        view.endEditing(true)

        let action = sections[indexPath.section].actions[indexPath.row]
        print("\(logTag): ===== \(action.title) =====")
        action.run()
        // Flush after every call so its requests show up on their own
        mixpanel.flush()

        guard
            let vc = storyboard?.instantiateViewController(
                withIdentifier: "ActionCompleteViewController") as? ActionCompleteViewController
        else {
            return
        }
        vc.actionStr = action.title
        vc.descStr = action.message
        vc.modalTransitionStyle = .crossDissolve
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }
}
