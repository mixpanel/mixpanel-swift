//
//  InAppNotifications.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/9/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol InAppNotificationsDelegate {
    func markNotification(_ notification: InAppNotification)
    func trackNotification(_ notification: InAppNotification, event: String)
}

enum InAppType: String {
    case Mini = "mini"
    case Takeover = "takeover"
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
        var notification = notification
        if notification.image != nil {
            DispatchQueue.main.async {
                if self.currentlyShowingNotification != nil {
                    Logger.warn(message: "already showing an in-app notification")
                } else {
                    var shownNotification = false
                    if notification.type == InAppType.Mini.rawValue {
                        shownNotification = self.showMiniNotification(notification)
                    } else {
                        shownNotification = self.showTakeoverNotification(notification)
                    }

                    if shownNotification {
                        self.markNotificationShown(notification: notification)
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
        delegate?.markNotification(notification)
    }

    func showMiniNotification(_ notification: InAppNotification) -> Bool {
        let miniNotificationVC = MiniNotificationViewController(notification: notification)
        miniNotificationVC.delegate = self
        miniNotificationVC.show(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + miniNotificationPresentationTime) {
            self.dismissNotification(controller: miniNotificationVC, status: false)
        }
        return true
    }

    func showTakeoverNotification(_ notification: InAppNotification) -> Bool {
        let takeoverNotificationVC = TakeoverNotificationViewController(notification: notification)
        takeoverNotificationVC.delegate = self
        takeoverNotificationVC.show(animated: true)
        return true
    }

    func dismissNotification(controller: BaseNotificationViewController, status: Bool) {
        if currentlyShowingNotification?.ID != controller.notification.ID {
            return
        }

        let completionBlock = {
            self.currentlyShowingNotification = nil
        }

        if status, let URL = controller.notification.callToActionURL {
            controller.hide(animated: true) {
                Logger.info(message: "opening CTA URL: \(URL)")

                if !UIApplication.shared.openURL(URL) {
                    Logger.error(message: "Mixpanel failed to open given URL: \(URL)")
                }

                self.delegate?.trackNotification(controller.notification, event: "$campaign_open")
                completionBlock()

            }
        } else {
            controller.hide(animated: true, completion: completionBlock)
        }
    }
}
