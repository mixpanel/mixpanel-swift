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
        case dark = "dark"
        case light = "light"
    }

    convenience init(notification: InAppNotification, nameOfClass: String) {
        self.init(nibName: nameOfClass, bundle: Bundle(for: type(of: self)))
        self.notification = notification
    }

    #if os(iOS)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }
    #endif

    func show(animated: Bool) {}
    func hide(animated: Bool, completion: @escaping () -> Void) {}

}
