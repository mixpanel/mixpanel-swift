//
//  TakeoverNotificationViewController.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/11/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

class TakeoverNotificationViewController: UIViewController {
    var notification: InAppNotification!

    convenience init(notification: InAppNotification) {
        self.init(nibName: "TakeoverNotificationViewController", bundle: Bundle(identifier: BundleConstants.ID))
        self.notification = notification
    }

    override func viewDidLoad() {
        super.viewDidLoad()

    }


}
