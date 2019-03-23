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
    
    
    @IBOutlet weak var timeSomethingButton: WKInterfaceButton!
    
    var currentlyTiming = false

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    @IBAction func trackButtonTapped() {
        Mixpanel.mainInstance().track(event: "trackButtonTapped")
    }
    
    
    @IBAction func timeButtonTapped() {
        if !currentlyTiming {
            Mixpanel.mainInstance().time(event: "time something")
            timeSomethingButton.setTitle("Finish Timing")
        } else {
            Mixpanel.mainInstance().track(event: "time something")
            timeSomethingButton.setTitle("Time Something")
        }
        currentlyTiming = !currentlyTiming
    }
    
    @IBAction func identifyButtonTapped() {
        let watchName = WKInterfaceDevice.current().systemName
        Mixpanel.mainInstance().people.set(properties: ["watch": watchName])
        Mixpanel.mainInstance().identify(distinctId: Mixpanel.mainInstance().distinctId)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
