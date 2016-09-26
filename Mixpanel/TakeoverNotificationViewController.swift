//
//  TakeoverNotificationViewController.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/11/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

class TakeoverNotificationViewController: BaseNotificationViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var viewMask: UIView!


    convenience init(notification: InAppNotification) {
        self.init(notification: notification, nameOfClass: TakeoverNotificationViewController.notificationXibToLoad())
    }

    static func notificationXibToLoad() -> String {
        var xibName = String(describing: TakeoverNotificationViewController.self)

        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            let isLandscape = UIInterfaceOrientationIsLandscape(UIApplication.shared.statusBarOrientation)
            if isLandscape {
                xibName += "~iphonelandscape"
            } else {
                xibName += "~iphoneportrait"
            }
        } else {
            xibName += "~ipad"
        }

        return xibName
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let notificationImage = notification.image, let image = UIImage(data: notificationImage, scale: 2) {
            imageView.image = image
        } else {
            Logger.error(message: "notification image failed to load from data")
        }

        titleLabel.text = notification.title
        bodyLabel.text = notification.body

        if !notification.callToAction.isEmpty {
            okButton.setTitle(notification.callToAction, for: UIControlState.normal)
        }

        okButton.layer.cornerRadius = 5
        okButton.layer.borderWidth = 2

        if notification.style == Style.light.rawValue {
            viewMask.backgroundColor = InAppNotificationsConstants.takeoverLightBGColor
            titleLabel.textColor = InAppNotificationsConstants.takeoverLightTitleColor
            bodyLabel.textColor = InAppNotificationsConstants.takeoverLightBodyColor
            okButton.setTitleColor(InAppNotificationsConstants.takeoverLightBodyColor, for: UIControlState.normal)
            okButton.layer.borderColor = InAppNotificationsConstants.takeoverOKButtonBorderColor.cgColor
            let origImage = closeButton.image(for: UIControlState.normal)
            let tintedImage = origImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
            closeButton.setImage(tintedImage, for: UIControlState.normal)
            closeButton.tintColor = InAppNotificationsConstants.takeoverCloseButtonColor
        } else {
            okButton.layer.borderColor = UIColor.white.cgColor
        }
        viewMask.clipsToBounds = true
        viewMask.layer.cornerRadius = 6
    }

    override func show(animated: Bool) {
        window = UIWindow(frame: CGRect(x: 0,
                                        y: UIScreen.main.bounds.size.height,
                                        width: UIScreen.main.bounds.size.width,
                                        height: UIScreen.main.bounds.size.height))
        if let window = window {
            window.windowLevel = UIWindowLevelAlert
            window.rootViewController = self
            window.isHidden = false
        }

        let duration = animated ? 0.25 : 0
        UIView.animate(withDuration: duration, animations: {
            self.window?.frame.origin.y -= UIScreen.main.bounds.size.height
            }, completion: { _ in
        })
    }

    override func hide(animated: Bool, completion: @escaping () -> Void) {
        let duration = animated ? 0.5 : 0
        UIView.animate(withDuration: duration, animations: {
            self.window?.frame.origin.y += UIScreen.main.bounds.size.height
            }, completion: { _ in
                self.window?.isHidden = true
                self.window?.removeFromSuperview()
                self.window = nil
                completion()
        })
    }

    @IBAction func tappedOk(_ sender: AnyObject) {
        delegate?.notificationShouldDismiss(controller: self, status: true)
    }

    @IBAction func tappedClose(_ sender: AnyObject) {
        delegate?.notificationShouldDismiss(controller: self, status: false)
    }

    override var shouldAutorotate: Bool {
        return false
    }

    @IBAction func didPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case UIGestureRecognizerState.began:
            panStartPoint = imageView.layer.position
        case UIGestureRecognizerState.changed:
            let translation = gesture.translation(in: view)
            imageView.layer.position = CGPoint(x: 0.3 * translation.x + panStartPoint.x, y: 0.3 * translation.y + panStartPoint.y)
        case UIGestureRecognizerState.ended, UIGestureRecognizerState.cancelled:
            let viewEnd = imageView.layer.position
            let viewDistance = CGPoint(x: viewEnd.x - panStartPoint.x, y: viewEnd.y - panStartPoint.y)
            let duration = sqrtf(Float(viewDistance.x * viewDistance.x) + Float(viewDistance.y * viewDistance.y)) / 500
            UIView.animate(withDuration: TimeInterval(duration), animations: {
                self.imageView.layer.position = self.panStartPoint
                }, completion: nil)
        default:
            break
        }
    }

}

class FadingView: UIView {
    var gradientMask: CAGradientLayer!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        gradientMask = CAGradientLayer()
        layer.mask = gradientMask
        gradientMask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        gradientMask.locations = [0, 0.4, 0.9, 1]
        gradientMask.startPoint = CGPoint(x: 0, y: 0)
        gradientMask.endPoint = CGPoint(x: 0, y: 1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientMask.frame = bounds
    }
}
