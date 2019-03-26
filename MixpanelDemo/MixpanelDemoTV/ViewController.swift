//
//  ViewController.swift
//  MixpanelDemoTV
//
//  Created by Zihe Jia on 3/22/19.
//  Copyright © 2019 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func timeEventClicked(_ sender: Any) {
        Mixpanel.mainInstance().time(event: "time something")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Mixpanel.mainInstance().track(event: "time something")
        }
    }
    
    @IBAction func TrackEventClicked(_ sender: Any) {
        Mixpanel.mainInstance().track(event: "Player Create", properties: ["gender": "Male", "weapon": "Pistol"])
    }
    
    @IBAction func peopleClicked(_ sender: Any) {
        let mixpanel = Mixpanel.mainInstance()
        mixpanel.people.set(properties: ["gender": "Male", "weapon": "Pistol"])
        mixpanel.identify(distinctId: mixpanel.distinctId)
    }
}

