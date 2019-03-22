//
//  InterfaceController.swift
//  MixpanelDemoWatch Extension
//
//  Created by Zihe Jia on 3/21/19.
//  Copyright © 2019 Mixpanel. All rights reserved.
//

import WatchKit
import Foundation
import Mixpanel

class InterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    @IBAction func trackButtonTapped() {
        print("trackButtonTapped")
        Mixpanel.mainInstance().track(event: "trackButtonTapped")
    }
    
    
    @IBAction func timeButtonTapped() {
        print("timeButtonTapped")
    }
    
    @IBAction func identifyButtonTapped() {
        print("identifyButtonTapped")
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
