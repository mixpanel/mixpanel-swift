//
//  ActionCompleteViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 7/18/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

class ActionCompleteViewController: UIViewController {
    @IBOutlet weak var popupView: UIView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    var actionStr: String?
    var descStr: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        popupView.clipsToBounds = true
        popupView.layer.cornerRadius = 6

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)

        actionLabel.text = actionStr
        descLabel.text = descStr
    }

    override func viewDidAppear(animated: Bool) {
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func handleTap(gesture: UITapGestureRecognizer) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

}
