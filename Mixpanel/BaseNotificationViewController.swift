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
    func notificationShouldDismiss(controller: BaseNotificationViewController,
                                   callToActionURL: URL?,
                                   shouldTrack: Bool,
                                   additionalTrackingProperties: Properties?) -> Bool
}

class BaseNotificationViewController: UIViewController {

    var notification: InAppNotification!
    var delegate: NotificationViewControllerDelegate?
    var window: UIWindow?
    var panStartPoint: CGPoint!

    convenience init(notification: InAppNotification, nameOfClass: String) {
        self.init(nibName: nameOfClass, bundle: Bundle(for: type(of: self)))
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

extension UIColor {
    /**
     The shorthand four-digit hexadecimal representation of color with alpha.
     #RGBA defines to the color #AARRGGBB.

     - parameter MPHex: hexadecimal value.
     */
    public convenience init(MPHex: UInt) {
        let divisor = CGFloat(255)
        let alpha   = CGFloat((MPHex & 0xFF000000) >> 24) / divisor
        let red     = CGFloat((MPHex & 0x00FF0000) >> 16) / divisor
        let green   = CGFloat((MPHex & 0x0000FF00) >>  8) / divisor
        let blue    = CGFloat( MPHex & 0x000000FF       ) / divisor
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /**
     Add two colors together
    */
    func add(overlay: UIColor) -> UIColor {
        var bgR: CGFloat = 0
        var bgG: CGFloat = 0
        var bgB: CGFloat = 0
        var bgA: CGFloat = 0

        var fgR: CGFloat = 0
        var fgG: CGFloat = 0
        var fgB: CGFloat = 0
        var fgA: CGFloat = 0

        self.getRed(&bgR, green: &bgG, blue: &bgB, alpha: &bgA)
        overlay.getRed(&fgR, green: &fgG, blue: &fgB, alpha: &fgA)

        let r = fgA * fgR + (1 - fgA) * bgR
        let g = fgA * fgG + (1 - fgA) * bgG
        let b = fgA * fgB + (1 - fgA) * bgB

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
