import UIKit
import UserNotifications

@available(iOS 10.0, *)
public class MixpanelPushNotifications {
    public static func isMixpanelPushNotification(_ notification: UNNotification) -> Bool {
        return notification.request.content.userInfo["mp"] != nil
    }
    
    public static func handleResponse(response: UNNotificationResponse,
           withCompletionHandler completionHandler:
             @escaping () -> Void) {

#if !BUILDING_FOR_APP_EXTENSION
        guard self.isMixpanelPushNotification(response.notification) else {
            completionHandler()
            return
        }
        
        let userInfo = response.notification.request.content.userInfo
        let isButtonTarget = response.actionIdentifier.starts(with: "MP_ACTION_")
        
        let mpMetaData = userInfo["mp"] as? [AnyHashable: Any]
        var trackingProps: Properties = [:]
        
        if mpMetaData != nil {
            trackingProps["campaign_id"] = mpMetaData!["c"] as! Int
            trackingProps["message_id"] = mpMetaData!["m"] as! Int
        }
        
        var ontap: [AnyHashable: Any]? = nil
        
        if (isButtonTarget) {
            guard let buttons = userInfo["mp_buttons"] as? [[AnyHashable: Any]] else {
                NSLog("Expected 'mp_buttons' prop in userInfo dict")
                completionHandler();
                return
            }
            
            guard let idx = Int(response.actionIdentifier.replacingOccurrences(of: "MP_ACTION_", with: "")) else {
                NSLog("unable to parse button index in \(response.actionIdentifier)")
                completionHandler();
                return
            }
            
            let button = buttons[idx]
            
            guard let buttonOnTap = button["ontap"] as? [AnyHashable: Any] else {
                NSLog("Expected 'ontap' property in button dict")
                completionHandler();
                return
            }
            
            ontap = buttonOnTap
            
            trackingProps["button_id"] = button["id"] as! String
            trackingProps["button_label"] = button["lbl"] as! String
            
        } else if (userInfo["mp_ontap"] != nil) {
            ontap = (userInfo["mp_ontap"] as? [AnyHashable: Any])!
        }

        
        guard ontap != nil else {
            completionHandler()
            return
        }

        // Track tap event to all Mixpanel instances
        for instance in Mixpanel.allInstances() {
            instance.track(event:"$push_notification_tap", properties:trackingProps)
        }
        
        // Perform the specified action
        guard let type = ontap!["type"] as? String else {
            NSLog("Expected 'type' in ontap dict")
            completionHandler()
            return
        }

        if (type == "homescreen") {
            // do nothing, already going to be at homescreen
            completionHandler();
        } else if (type == "browser" || type == "deeplink") {
            
            guard let urlStr = ontap!["uri"] as? String else {
                NSLog("Expected 'uri' in ontap dict")
                completionHandler()
                return
            }
            
            guard let url = URL(string: urlStr) else {
                NSLog("Failed to convert urlStr \"\(urlStr)\" to url")
                completionHandler()
                return
            }

            UIApplication.shared.open(url, options: [:], completionHandler: { success in
                if success {
                    NSLog("Successfully loaded url: \(url)")
                } else {
                    NSLog("Failed to load url: \(url)")
                }
                completionHandler();
            })
        } else {
            NSLog("Unexpected value for type: \(type)")
            completionHandler();
        }
#endif
    }
}



