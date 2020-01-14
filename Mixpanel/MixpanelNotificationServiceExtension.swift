import UserNotifications

private let dynamicCategoryIdentifier = "MP_DYNAMIC"
private let mediaUrlKey = "mp_media_url"

@available(iOS 11.0, *)
open class MixpanelNotificationServiceExtension: UNNotificationServiceExtension {
    open override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            contentHandler(request.content)
            return
        }
        
        self.maybeAttachButtons(bestAttemptContent: bestAttemptContent) {
            self.maybeAttachMedia(bestAttemptContent: bestAttemptContent) {
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    func maybeAttachButtons(bestAttemptContent: UNMutableNotificationContent, completionHandler: @escaping () -> Void) {
        guard let buttons = bestAttemptContent.userInfo["mp_buttons"] as? [[AnyHashable: Any]] else {
            NSLog("maybeAttachButtons: No action buttons found in the push notification payload.")
            completionHandler()
            return
        }
        
        // build actions from buttons payload
        var actions: [UNNotificationAction] = []
        for (idx, button) in buttons.enumerated() {
            let identifier = String(format: "MP_ACTION_%lu", idx)
            let title = button["lbl"] as! String
            let action = UNNotificationAction(identifier: identifier, title: title, options: .foreground)
            actions.append(action)
        }

        // create the dynamic category
        let mpDynamicCategory =
              UNNotificationCategory(identifier: dynamicCategoryIdentifier,
              actions: actions,
              intentIdentifiers: [],
              hiddenPreviewsBodyPlaceholder: "",
              options: .customDismissAction)
                
        // add or replace the mixpanel dynamic category
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: { categories in
            var updatedCategories = categories.filter { (category) -> Bool in
                return !category.identifier.contains(dynamicCategoryIdentifier)
            }
            updatedCategories.insert(mpDynamicCategory)
            UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)
            
            // TODO: understand this further -- for some reason, if we don't
            // re-fetch the categories here the category changes don't seem
            // to be applied.
            // possibly related to this person's issue:
            // https://github.com/lionheart/openradar-mirror/issues/20575
            UNUserNotificationCenter.current().getNotificationCategories(completionHandler: { categories in
                completionHandler()
            })
        })
    }
    
    func maybeAttachMedia(bestAttemptContent: UNMutableNotificationContent, completionHandler: @escaping () -> Void) {
        guard let mediaUrlStr = (bestAttemptContent.userInfo[mediaUrlKey] as? String) else {
            NSLog("maybeAttachMedia: No media url specified.")
            completionHandler()
            return
        }
        
        let fileType = URL(fileURLWithPath: mediaUrlStr).pathExtension
        
        loadAttachment(mediaUrlStr: mediaUrlStr, fileType: fileType, completionHandler: { attachment in
            guard let attachment = attachment else {
                NSLog("maybeAttachMedia: Unable to load media attachment")
                completionHandler()
                return
            }
            
            NSLog("maybeAttachMedia: Attaching media from \(mediaUrlStr)")
            bestAttemptContent.attachments = [attachment]
            completionHandler()
        })
    }
    
    func loadAttachment(mediaUrlStr: String, fileType: String, completionHandler: @escaping (UNNotificationAttachment?) -> Void) {
        guard let mediaUrl = URL(string: mediaUrlStr) else {
            NSLog("Unable to convert mediaUrlStr \"\(mediaUrlStr)\" to URL")
            completionHandler(nil)
            return
        }

        // Download the file from URL to disk
        let session = URLSession(configuration: URLSessionConfiguration.default)
        (session.downloadTask(with: mediaUrl, completionHandler: { temporaryFileLocation, response, error in
            guard let temporaryFileLocation = temporaryFileLocation else {
                if let error = error {
                    NSLog("Error downloading the media attachment: \(error.localizedDescription)")
                } else {
                    NSLog("Unknown error downloading the media attachment")
                }
                completionHandler(nil)
                return
            }
            
            // Move the downloaded file to temp folder
            let fileManager = FileManager.default
            let localURL = URL(fileURLWithPath: temporaryFileLocation.path + "." + fileType)
            do {
                try fileManager.moveItem(at: temporaryFileLocation, to: localURL)
            } catch let moveError {
                NSLog("Failed to move file: \(moveError.localizedDescription)")
                completionHandler(nil)
                return
            }
            
            // Create the notification attachment from the file
            var attachment: UNNotificationAttachment? = nil
            do {
                attachment = try UNNotificationAttachment(identifier: "", url: localURL, options: nil)
                completionHandler(attachment)
            } catch let attachmentError {
                NSLog("Unable to add attchment: \(attachmentError.localizedDescription)")
                completionHandler(nil)
            }
        })).resume()
    }
}
