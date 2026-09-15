//
//  AutocaptureMenuViewController.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-07-28.
//  Copyright (c) Mixpanel. All rights reserved.
//

import UIKit

class AutocaptureMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let items = [
        "UIKit Autocapture Tests",
        "SwiftUI Autocapture Tests",
        "Stress Test UIKit (500+ views)",
        "Stress Test SwiftUI (500+ views)",
        "UIKit Walk-Up Tests",
        "SwiftUI Walk-Up Tests",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Autocapture"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.row {
            case 0:
                let vc = UIKitAutocaptureTestViewController()
                navigationController?.pushViewController(vc, animated: true)
            case 1:
                if #available(iOS 14.0, *) {
                    let vc = SwiftUIAutocaptureTestHostingController()
                    navigationController?.pushViewController(vc, animated: true)
                }
            case 2:
                let vc = ComplexUIKitStressTestViewController()
                navigationController?.pushViewController(vc, animated: true)
            case 3:
                if #available(iOS 14.0, *) {
                    let vc = ComplexSwiftUIStressTestHostingController()
                    navigationController?.pushViewController(vc, animated: true)
                }
            case 4:
                let vc = UIKitWalkUpTestViewController()
                navigationController?.pushViewController(vc, animated: true)
            case 5:
                if #available(iOS 14.0, *) {
                    let vc = SwiftUIWalkUpTestHostingController()
                    navigationController?.pushViewController(vc, animated: true)
                }
            default:
                break
        }
    }
}
