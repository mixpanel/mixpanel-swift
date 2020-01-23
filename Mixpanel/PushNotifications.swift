import UIKit
import UserNotifications

enum PushTapActionType: String {
    case browser = "browser"
    case deeplink = "deeplink"
    case homescreen = "homescreen"
}

@available(iOS 10.0, *)
public class MixpanelPushNotifications {

    public static func isMixpanelPushNotification(_ content: UNNotificationContent) -> Bool {
        return content.userInfo["mp"] != nil
    }

    @available(iOSApplicationExtension, unavailable)
    public static func handleResponse(response: UNNotificationResponse,
           withCompletionHandler completionHandler:
             @escaping () -> Void) {

        guard self.isMixpanelPushNotification(response.notification.request.content) else {
            Logger.debug(message: "Calling MixpanelPushNotifications.handleResponse on a non-Mixpanel push notification is a noop...")
            completionHandler()
            return
        }
        
        let userInfo = response.notification.request.content.userInfo
        
        // Initialize properties to track to Mixpanel
        var trackingProps: Properties = [:]
        if let mpMetaData = userInfo["mp"] as? [AnyHashable: Any] {
            if let campaign_id =  mpMetaData["c"] as? Int {
               trackingProps["campaign_id"] = campaign_id
            }
            if let message_id =  mpMetaData["m"] as? Int {
               trackingProps["message_id"] = message_id
            }
        }

        Logger.debug(message: "didReceiveNotificationResponse action: \(response.actionIdentifier)");

        // If the notification was dismissed, just track and return
        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            for instance in Mixpanel.allInstances() {
                instance.track(event:"$push_notification_dismissed", properties:trackingProps)
                instance.flush()
            }
            completionHandler();
            return;
        }

        var ontap: [AnyHashable: Any]? = nil

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // The action that indicates the user opened the app from the notification interface.
            trackingProps["tap_target"] = "notification";

            if (userInfo["mp_ontap"] != nil) {
                ontap = (userInfo["mp_ontap"] as? [AnyHashable: Any])!
            }
        } else {
            // Non-default, non-dismiss action -- probably a button tap
            let wasButtonTapped = response.actionIdentifier.contains("MP_ACTION_")

            if wasButtonTapped {
                guard let buttons = userInfo["mp_buttons"] as? [[AnyHashable: Any]] else {
                    Logger.debug(message: "Expected 'mp_buttons' prop in userInfo dict")
                    completionHandler();
                    return
                }

                guard let idx = Int(response.actionIdentifier.replacingOccurrences(of: "MP_ACTION_", with: "")) else {
                    Logger.debug(message: "Unable to parse button index in \(response.actionIdentifier)")
                    completionHandler();
                    return
                }

                let button = buttons[idx]

                guard let buttonOnTap = button["ontap"] as? [AnyHashable: Any] else {
                    Logger.debug(message: "Expected 'ontap' property in button dict")
                    completionHandler();
                    return
                }

                ontap = buttonOnTap

                trackingProps["tap_target"] = "button"

                if let buttonId = button["id"] as? String {
                    trackingProps["button_id"] = buttonId
                } else {
                    NSLog("Failed to get button id for tracking")
                }

                if let buttonLabel = button["lbl"] as? String {
                    trackingProps["button_label"] = buttonLabel
                } else {
                    NSLog("Failed to get button label for tracking")
                }
            }
        }

        // Track tap event to all Mixpanel instances
        for instance in Mixpanel.allInstances() {
            instance.track(event:"$push_notification_tap", properties:trackingProps)
            instance.flush()
        }

        // Perform the specified action
        guard let tapAction = ontap else {
            Logger.debug(message: "Unable to determine tap behavior")
            completionHandler()
            return
        }
        
        guard let actionTypeStr = tapAction["type"] as? String else {
            Logger.debug(message: "Expected 'type' in ontap dict")
            completionHandler()
            return
        }

        guard let actionType = PushTapActionType(rawValue: actionTypeStr) else {
            Logger.debug(message: "Unexpected value for push notification tap action type: \(actionTypeStr)")
            completionHandler()
            return
        }

        switch(actionType) {

        case .homescreen:
            // Do nothing, already going to be at homescreen
            completionHandler();

        case .browser, .deeplink:
            guard let urlStr = tapAction["uri"] as? String else {
                Logger.debug(message: "Expected 'uri' in ontap dict")
                completionHandler()
                return
            }

            guard let url = URL(string: urlStr) else {
                Logger.debug(message: "Failed to convert urlStr \"\(urlStr)\" to url")
                completionHandler()
                return
            }

            UIApplication.shared.open(url, options: [:], completionHandler: { success in
                if success {
                    Logger.debug(message: "Successfully loaded url: \(url)")
                } else {
                    Logger.debug(message: "Failed to load url: \(url)")
                }
                completionHandler();
            })

        }

    }
}
