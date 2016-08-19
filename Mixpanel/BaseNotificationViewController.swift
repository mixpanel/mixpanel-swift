//
//  BaseNotificationViewController.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/11/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

protocol NotificationViewControllerDelegate {
    @discardableResult
    func notificationShouldDismiss(controller: BaseNotificationViewController, status: Bool) -> Bool
}

class BaseNotificationViewController: UIViewController {

    var notification: InAppNotification!
    var delegate: NotificationViewControllerDelegate?
    var window: UIWindow?
    var panStartPoint: CGPoint!

    enum Style: String {
        case Dark = "dark"
        case Light = "light"
    }

    convenience init(notification: InAppNotification, nameOfClass: String) {
        self.init(nibName: nameOfClass, bundle: Bundle(identifier: BundleConstants.ID))
        self.notification = notification
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }

    func show(animated: Bool) {}
    func hide(animated: Bool, completion: @escaping () -> Void) {}

}
