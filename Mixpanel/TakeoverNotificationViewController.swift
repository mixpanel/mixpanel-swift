//
//  TakeoverNotificationViewController.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/11/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit

class TakeoverNotificationViewController: BaseNotificationViewController {

    var takeoverNotification: TakeoverNotification! {
        get {
            return super.notification as! TakeoverNotification
        }
    }
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var firstButton: UIButton!
    @IBOutlet weak var secondButton: UIButton!
    @IBOutlet weak var secondButtonContainer: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var viewMask: UIView!

    @IBOutlet weak var fadingView: FadingView!
    @IBOutlet weak var bottomImageSpacing: NSLayoutConstraint!

    convenience init(notification: TakeoverNotification) {
        self.init(notification: notification, nameOfClass: TakeoverNotificationViewController.notificationXibToLoad())
    }

    static func notificationXibToLoad() -> String {
        var xibName = String(describing: TakeoverNotificationViewController.self)
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return xibName
        }
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            let isLandscape = UIInterfaceOrientationIsLandscape(sharedApplication.statusBarOrientation)
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
            if let width = imageView.image?.size.width, width / UIScreen.main.bounds.width <= 0.6, let height = imageView.image?.size.height,
                height / UIScreen.main.bounds.height <= 0.3 {
                imageView.contentMode = UIViewContentMode.center
            }
        } else {
            Logger.error(message: "notification image failed to load from data")
        }

        if takeoverNotification.title == nil || takeoverNotification.body == nil {
            NSLayoutConstraint(item: titleLabel,
                               attribute: NSLayoutAttribute.height,
                               relatedBy: NSLayoutRelation.equal,
                               toItem: nil,
                               attribute: NSLayoutAttribute.notAnAttribute,
                               multiplier: 1,
                               constant: 0).isActive = true
            NSLayoutConstraint(item: bodyLabel,
                               attribute: NSLayoutAttribute.height,
                               relatedBy: NSLayoutRelation.equal,
                               toItem: nil,
                               attribute: NSLayoutAttribute.notAnAttribute,
                               multiplier: 1,
                               constant: 0).isActive = true
        } else {
            titleLabel.text = takeoverNotification.title
            bodyLabel.text = takeoverNotification.body
        }

        viewMask.backgroundColor = UIColor(MPHex: takeoverNotification.backgroundColor)

        titleLabel.textColor = UIColor(MPHex: takeoverNotification.titleColor)
        bodyLabel.textColor = UIColor(MPHex: takeoverNotification.bodyColor)

        let origImage = closeButton.image(for: UIControlState.normal)
        let tintedImage = origImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        closeButton.setImage(tintedImage, for: UIControlState.normal)
        closeButton.tintColor = UIColor(MPHex: takeoverNotification.closeButtonColor)
        closeButton.imageView?.contentMode = UIViewContentMode.scaleAspectFit

        if takeoverNotification.buttons.count >= 1 {
            setupButtonView(buttonView: firstButton, buttonModel: takeoverNotification.buttons[0], index: 0)
            if takeoverNotification.buttons.count == 2 {
                setupButtonView(buttonView: secondButton, buttonModel: takeoverNotification.buttons[1], index: 1)
            } else {
                NSLayoutConstraint(item: secondButtonContainer,
                                   attribute: NSLayoutAttribute.width,
                                   relatedBy: NSLayoutRelation.equal,
                                   toItem: nil,
                                   attribute: NSLayoutAttribute.notAnAttribute,
                                   multiplier: 1,
                                   constant: 0).isActive = true
            }
        }

        if !takeoverNotification.shouldFadeImage {
            if bottomImageSpacing != nil {
                bottomImageSpacing.constant = 30
            }
            fadingView.layer.mask = nil
        }

        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            self.view.backgroundColor = UIColor(MPHex: takeoverNotification.backgroundColor)
            self.view.backgroundColor = self.view.backgroundColor?.withAlphaComponent(0.8)
            viewMask.clipsToBounds = true
            viewMask.layer.cornerRadius = 6
        }

    }

    func setupButtonView(buttonView: UIButton, buttonModel: InAppButton, index: Int) {
        buttonView.setTitle(buttonModel.text, for: UIControlState.normal)
        buttonView.titleLabel?.adjustsFontSizeToFitWidth = true
        buttonView.layer.cornerRadius = 5
        buttonView.layer.borderWidth = 2
        buttonView.setTitleColor(UIColor(MPHex: buttonModel.textColor), for: UIControlState.normal)
        buttonView.setTitleColor(UIColor(MPHex: buttonModel.textColor), for: UIControlState.highlighted)
        buttonView.setTitleColor(UIColor(MPHex: buttonModel.textColor), for: UIControlState.selected)
        buttonView.layer.borderColor = UIColor(MPHex: buttonModel.borderColor).cgColor
        buttonView.backgroundColor = UIColor(MPHex: buttonModel.backgroundColor)
        buttonView.addTarget(self, action: #selector(buttonTapped(_:)), for: UIControlEvents.touchUpInside)
        buttonView.tag = index
    }

    override func show(animated: Bool) {
        window = UIWindow(frame: CGRect(x: 0,
                                        y: 0,
                                        width: UIScreen.main.bounds.size.width,
                                        height: UIScreen.main.bounds.size.height))
        if let window = window {
            window.alpha = 0
            window.windowLevel = UIWindowLevelAlert
            window.rootViewController = self
            window.isHidden = false
        }

        let duration = animated ? 0.25 : 0
        UIView.animate(withDuration: duration, animations: {
            self.window?.alpha = 1
            }, completion: { _ in
        })
    }

    override func hide(animated: Bool, completion: @escaping () -> Void) {
        let duration = animated ? 0.25 : 0
        UIView.animate(withDuration: duration, animations: {
            self.window?.alpha = 0
            }, completion: { _ in
                self.window?.isHidden = true
                self.window?.removeFromSuperview()
                self.window = nil
                completion()
        })
    }

    @objc func buttonTapped(_ sender: AnyObject) {
        var whichButton = "primary"
        if self.takeoverNotification.buttons.count == 2 {
            whichButton = sender.tag == 0 ? "secondary" : "primary"
        }
        delegate?.notificationShouldDismiss(controller: self,
                                            callToActionURL: takeoverNotification.buttons[sender.tag].callToActionURL,
                                            shouldTrack: true,
                                            additionalTrackingProperties: ["button": whichButton])
    }


    @IBAction func tappedClose(_ sender: AnyObject) {
        delegate?.notificationShouldDismiss(controller: self,
                                            callToActionURL: nil,
                                            shouldTrack: false,
                                            additionalTrackingProperties: nil)
    }

    override var shouldAutorotate: Bool {
        return false
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

class InAppButtonView: UIButton {
    var origColor: UIColor?
    var wasCalled = false
    let overlayColor = UIColor(MPHex: 0x33868686)
    override var isHighlighted: Bool {
        didSet {
            switch isHighlighted {
            case true:
                if !wasCalled {
                    origColor = backgroundColor
                    if origColor == UIColor(red: 0, green: 0, blue: 0, alpha: 0) {
                        backgroundColor = overlayColor
                    } else {
                        backgroundColor = backgroundColor?.add(overlay: overlayColor)
                    }
                    wasCalled = true
                }
            case false:
                backgroundColor = origColor
                wasCalled = false
            }
        }
    }
}
