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
    func notificationShouldDismiss(controller: BaseNotificationViewController, callToActionURL: URL?) -> Bool
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

extension UIColor {
    /**
     The shorthand four-digit hexadecimal representation of color with alpha.
     #RGBA defines to the color #AARRGGBB.

     - parameter hex4: Four-digit hexadecimal value.
     */
    public convenience init(hex4: Int) {
        let divisor = CGFloat(15)
        let alpha   = CGFloat((hex4 & 0xF000) >> 12) / divisor
        let red     = CGFloat((hex4 & 0x0F00) >>  8) / divisor
        let green   = CGFloat((hex4 & 0x00F0) >>  4) / divisor
        let blue    = CGFloat( hex4 & 0x000F       ) / divisor
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
