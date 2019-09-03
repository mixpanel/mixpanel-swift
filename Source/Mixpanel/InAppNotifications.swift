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
    func trackNotification(_ notification: InAppNotification, event: String, properties: Properties?)
}

enum InAppType: String {
    case mini = "mini"
    case takeover = "takeover"
}

class InAppNotifications: NotificationViewControllerDelegate {
    let lock: ReadWriteLock
    var checkForNotificationOnActive = true
    var showNotificationOnActive = true
    var miniNotificationPresentationTime = 6.0
    var shownNotifications = Set<Int>()
    var triggeredNotifications = [InAppNotification]()
    var inAppNotifications = [InAppNotification]()
    var currentlyShowingNotification: InAppNotification?
    var delegate: InAppNotificationsDelegate?

    init(lock: ReadWriteLock) {
        self.lock = lock
    }

    func showNotification(event: String?, properties: InternalProperties) {
        for triggeredNotification in triggeredNotifications {
            if (triggeredNotification.matchesEvent(event: event, properties: properties)) {
                showNotification(triggeredNotification)
                break;
            }
        }
    }
    
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
            if (notification.hasDisplayTriggers()) {
                triggeredNotifications = triggeredNotifications.filter { $0.ID != notification.ID }
            } else {
                inAppNotifications = inAppNotifications.filter { $0.ID != notification.ID }
            }
        }
    }

    func markNotificationShown(notification: InAppNotification) {
        self.lock.write {
            Logger.info(message: "marking notification as seen: \(notification.ID)")
            currentlyShowingNotification = notification
            shownNotifications.insert(notification.ID)
            if (notification.hasDisplayTriggers()) {
                triggeredNotifications = triggeredNotifications.filter { $0.ID != notification.ID }
            }
        }
    }

    func showMiniNotification(_ notification: MiniNotification) -> Bool {
        let miniNotificationVC = MiniNotificationViewController(notification: notification)
        miniNotificationVC.delegate = self
        miniNotificationVC.show(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + miniNotificationPresentationTime) {
            self.notificationShouldDismiss(controller: miniNotificationVC,
                                           callToActionURL: nil,
                                           shouldTrack: false,
                                           additionalTrackingProperties: nil)
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
    func notificationShouldDismiss(controller: BaseNotificationViewController,
                                   callToActionURL: URL?,
                                   shouldTrack: Bool,
                                   additionalTrackingProperties: Properties?) -> Bool {
        if currentlyShowingNotification?.ID != controller.notification.ID {
            return false
        }

        let completionBlock = {
            if shouldTrack {
                var properties = additionalTrackingProperties
                if let urlString = callToActionURL?.absoluteString {
                    if properties == nil {
                        properties = [:]
                    }
                    properties!["url"] = urlString
                }
                self.delegate?.trackNotification(controller.notification, event: "$campaign_open", properties: properties)
            }
            self.currentlyShowingNotification = nil
        }

        if let callToActionURL = callToActionURL {
            controller.hide(animated: true) {
                Logger.info(message: "opening CTA URL: \(callToActionURL)")
                MixpanelInstance.sharedUIApplication()?.performSelector(onMainThread: NSSelectorFromString("openURL:"), with: callToActionURL, waitUntilDone: true)
                completionBlock()
            }
        } else {
            controller.hide(animated: true, completion: completionBlock)
        }

        return true
    }
}
