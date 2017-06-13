//
//  MiniNotificationViewController.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/10/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

class MiniNotificationViewController: BaseNotificationViewController {

    var miniNotification: MiniNotification! {
        get {
            return super.notification as! MiniNotification
        }
    }
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var bodyLabel: UILabel!
    var isDismissing = false
    var canPan = true
    var position: CGPoint!

    convenience init(notification: MiniNotification) {
        self.init(notification: notification, nameOfClass: String(describing: MiniNotificationViewController.self))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bodyLabel.text = notification.body
        if let image = notification.image {
            imageView.image = UIImage(data: image)
        }

        view.backgroundColor = UIColor(MPHex: miniNotification.backgroundColor)
        bodyLabel.textColor = UIColor(MPHex: miniNotification.bodyColor)
        imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = UIColor(MPHex: miniNotification.imageTintColor)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(gesture:)))
        tapGesture.numberOfTapsRequired = 1
        window?.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:)))
        window?.addGestureRecognizer(panGesture)
    }

    override func show(animated: Bool) {
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return
        }
        canPan = false
        let frame: CGRect
        if UIInterfaceOrientationIsPortrait(sharedApplication.statusBarOrientation)
            && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone {
            frame = CGRect(x: InAppNotificationsConstants.miniSidePadding,
                           y: UIScreen.main.bounds.size.height,
                           width: UIScreen.main.bounds.size.width - (InAppNotificationsConstants.miniSidePadding * 2),
                           height: InAppNotificationsConstants.miniInAppHeight)
        } else { // Is iPad or Landscape mode
            frame = CGRect(x: UIScreen.main.bounds.size.width / 4,
                           y: UIScreen.main.bounds.size.height,
                           width: UIScreen.main.bounds.size.width / 2,
                           height: InAppNotificationsConstants.miniInAppHeight)
        }
        window = UIWindow(frame: frame)
        if let window = window {
            window.windowLevel = UIWindowLevelAlert
            window.clipsToBounds = true
            window.rootViewController = self
            window.layer.cornerRadius = 6
            window.layer.borderColor = UIColor(MPHex: miniNotification.borderColor).cgColor
            window.layer.borderWidth = 1
            window.isHidden = false
        }

        let duration = animated ? 0.1 : 0
        UIView.animate(withDuration: duration, animations: {
            self.window?.frame.origin.y -= (InAppNotificationsConstants.miniInAppHeight + InAppNotificationsConstants.miniBottomPadding)
            self.canPan = true
            }, completion: { _ in
                self.position = self.window?.layer.position
        })
    }

    override func hide(animated: Bool, completion: @escaping () -> Void) {
        if !isDismissing {
            canPan = false
            isDismissing = true
            let duration = animated ? 0.5 : 0
            UIView.animate(withDuration: duration, animations: {
                self.window?.frame.origin.y += (InAppNotificationsConstants.miniInAppHeight + InAppNotificationsConstants.miniBottomPadding)
                }, completion: { _ in
                    self.window?.isHidden = true
                    self.window?.removeFromSuperview()
                    self.window = nil
                    completion()
            })
        }
    }

    func didTap(gesture: UITapGestureRecognizer) {
        if !isDismissing && gesture.state == UIGestureRecognizerState.ended {
            delegate?.notificationShouldDismiss(controller: self, callToActionURL: miniNotification.callToActionURL)
        }
    }

    func didPan(gesture: UIPanGestureRecognizer) {
        if canPan, let window = window {
            switch gesture.state {
            case UIGestureRecognizerState.began:
                panStartPoint = gesture.location(in: MixpanelInstance.sharedUIApplication()?.keyWindow)
            case UIGestureRecognizerState.changed:
                var position = gesture.location(in: MixpanelInstance.sharedUIApplication()?.keyWindow)
                let diffY = position.y - panStartPoint.y
                position.y = max(position.y, position.y + diffY)
                window.layer.position = CGPoint(x: window.layer.position.x, y: position.y)
            case UIGestureRecognizerState.ended, UIGestureRecognizerState.cancelled:
                if window.layer.position.y > position.y + (InAppNotificationsConstants.miniInAppHeight / 2) {
                    delegate?.notificationShouldDismiss(controller: self, callToActionURL: miniNotification.callToActionURL)
                } else {
                    UIView.animate(withDuration: 0.2, animations: {
                        window.layer.position = self.position
                    })
                }
            default:
                break
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return
        }
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (ctx) in
            let frame: CGRect
            if UIInterfaceOrientationIsPortrait(sharedApplication.statusBarOrientation)
                && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone {
                frame = CGRect(x: InAppNotificationsConstants.miniSidePadding,
                               y: UIScreen.main.bounds.size.height -
                                (InAppNotificationsConstants.miniInAppHeight + InAppNotificationsConstants.miniBottomPadding),
                               width: UIScreen.main.bounds.size.width -
                                (InAppNotificationsConstants.miniSidePadding * 2),
                               height: InAppNotificationsConstants.miniInAppHeight)
            } else { // Is iPad or Landscape mode
                frame = CGRect(x: UIScreen.main.bounds.size.width / 4,
                               y: UIScreen.main.bounds.size.height -
                                (InAppNotificationsConstants.miniInAppHeight + InAppNotificationsConstants.miniBottomPadding),
                               width: UIScreen.main.bounds.size.width / 2,
                               height: InAppNotificationsConstants.miniInAppHeight)
            }
            self.window?.frame = frame

            }, completion: nil)
    }
}
