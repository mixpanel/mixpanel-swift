//
//  FeatureFlagPersistenceViewController.swift
//  MixpanelDemo
//
//  UIKit wrapper for the Feature Flag Persistence test screen
//

import UIKit
import SwiftUI

class FeatureFlagPersistenceViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create SwiftUI view
        let swiftUIView = FeatureFlagPersistenceTestView()

        // Wrap in UIHostingController
        if #available(iOS 13.0, *) {
            let hostingController = UIHostingController(rootView: swiftUIView)
            
            // Add as child view controller
            addChild(hostingController)
            view.addSubview(hostingController.view)
            
            // Setup constraints
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            hostingController.didMove(toParent: self)
        } else {
            // Fallback on earlier versions
        }


        // Set navigation title
        title = "Flag Persistence Test"
    }
}
