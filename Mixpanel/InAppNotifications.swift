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
        var notification = notification
        if notification.image != nil {
            DispatchQueue.main.async {
                if self.currentlyShowingNotification != nil {
                    Logger.warn(message: "already showing an in-app notification")
                } else {
                    var shownNotification = false
                    #if os(iOS)
                    if notification.type == InAppType.mini.rawValue {
                        shownNotification = self.showMiniNotification(notification)
                    } else {
                        shownNotification = self.showTakeoverNotification(notification)
                    }
                    if shownNotification {
                        self.markNotificationShown(notification: notification)
                        self.delegate?.notificationDidShow(notification)
                    }
                    #endif
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

    #if os(iOS)
    func showMiniNotification(_ notification: InAppNotification) -> Bool {
        let miniNotificationVC = MiniNotificationViewController(notification: notification)
        miniNotificationVC.delegate = self
        miniNotificationVC.show(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + miniNotificationPresentationTime) {
            self.notificationShouldDismiss(controller: miniNotificationVC, status: false)
        }
        return true
    }

    func showTakeoverNotification(_ notification: InAppNotification) -> Bool {
        let takeoverNotificationVC = TakeoverNotificationViewController(notification: notification)
        takeoverNotificationVC.delegate = self
        takeoverNotificationVC.show(animated: true)
        return true
    }
    #endif

    @discardableResult
    func notificationShouldDismiss(controller: BaseNotificationViewController, status: Bool) -> Bool {
        if currentlyShowingNotification?.ID != controller.notification.ID {
            return false
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

                self.delegate?.notificationDidCTA(controller.notification, event: "$campaign_open")
                completionBlock()
            }
        } else {
            controller.hide(animated: true, completion: completionBlock)
        }

        return true
    }
}
