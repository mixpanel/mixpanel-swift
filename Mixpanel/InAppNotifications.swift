//
//  InAppNotifications.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/9/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

protocol InAppNotificationsDelegate {
    func notificationDidShow(_ notification: InAppNotification)
    func notificationDidCTA(_ notification: InAppNotification, event: String)
}

enum InAppType: String {
    case mini = "mini"
    case takeover = "takeover"
}

class InAppNotifications: NotificationViewControllerDelegate {

    var checkForNotificationOnActive = true
    var showNotificationOnActive = true
    var miniNotificationPresentationTime = 6.0
    var shownNotifications = Set<Int>()
    var inAppNotifications = [InAppNotification]()
    var currentlyShowingNotification: InAppNotification?
    var delegate: InAppNotificationsDelegate?

    func showNotification( _ notification: InAppNotification) {
        let notification = notification
        if notification.image != nil {
            DispatchQueue.main.async {
                if self.currentlyShowingNotification != nil {
                    Logger.warn(message: "already showing an in-app notification")
                } else {
                    var shownNotification = false
                    if let notification = notification as? MiniNotification {
                        shownNotification = self.showMiniNotification(notification)
                    } else if let notification = notification as? TakeoverNotification {
                        shownNotification = self.showTakeoverNotification(notification)
                    }
                    if shownNotification {
                        self.markNotificationShown(notification: notification)
                        self.delegate?.notificationDidShow(notification)
                    }
                }
            }
        } else {
            inAppNotifications = inAppNotifications.filter { $0.ID != notification.ID }
        }
    }

    func markNotificationShown(notification: InAppNotification) {
        Logger.info(message: "marking notification as seen: \(notification.ID)")

        currentlyShowingNotification = notification
        shownNotifications.insert(notification.ID)
    }

    func showMiniNotification(_ notification: MiniNotification) -> Bool {
        let miniNotificationVC = MiniNotificationViewController(notification: notification)
        miniNotificationVC.delegate = self
        miniNotificationVC.show(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + miniNotificationPresentationTime) {
            self.notificationShouldDismiss(controller: miniNotificationVC, callToActionURL: nil)
        }
        return true
    }

    func showTakeoverNotification(_ notification: TakeoverNotification) -> Bool {
        let takeoverNotificationVC = TakeoverNotificationViewController(notification: notification)
        takeoverNotificationVC.delegate = self
        takeoverNotificationVC.show(animated: true)
        return true
    }

    @discardableResult
    func notificationShouldDismiss(controller: BaseNotificationViewController, callToActionURL: URL?) -> Bool {
        if currentlyShowingNotification?.ID != controller.notification.ID {
            return false
        }

        let completionBlock = {
            self.currentlyShowingNotification = nil
        }

        if let callToActionURL = callToActionURL {
            controller.hide(animated: true) {
                Logger.info(message: "opening CTA URL: \(callToActionURL)")
                guard let canOpenURL = MixpanelInstance.sharedUIApplication()?.perform(NSSelectorFromString("openURL"), with: callToActionURL).takeUnretainedValue() as? Bool else {
                    return
                }
                if !canOpenURL {
                    Logger.error(message: "Mixpanel failed to open given URL: \(callToActionURL)")
                }

                self.delegate?.notificationDidCTA(controller.notification, event: "$campaign_open")
                completionBlock()
            }
        } else {
            controller.hide(animated: true, completion: completionBlock)
        }

        return true
    }
}
