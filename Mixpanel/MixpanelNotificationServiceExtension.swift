import UserNotifications

@available(iOS 11.0, *)
open class MixpanelNotificationServiceExtension: UNNotificationServiceExtension {
    open override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            contentHandler(request.content)
            return
        }
        
        self.getCategoryIdentifier(content: request.content) { categoryIdentifier in
            if let categoryIdentifier = categoryIdentifier {
                NSLog("Using categoryIdentifer: \(categoryIdentifier)")
                bestAttemptContent.categoryIdentifier = categoryIdentifier
            }
            self.buildAttachments(content: request.content) { attachments in
                if attachments != nil {
                    NSLog("Adding \(attachments?.count ?? 0) attachment(s)")
                    bestAttemptContent.attachments = attachments!
                }
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    func getCategoryIdentifier(content: UNNotificationContent, completionHandler: @escaping (String?) -> Void) {

        guard content.categoryIdentifier.isEmpty else {
            NSLog("getCategoryIdentifier: explicit categoryIdentifer included in payload: \(content.categoryIdentifier)")
            completionHandler(content.categoryIdentifier)
            return
        }

        guard let buttons = content.userInfo["mp_buttons"] as? [[AnyHashable: Any]] else {
            NSLog("getCategoryIdentifier: No action buttons found in the push notification payload.")
            completionHandler(nil)
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

        let categoryId = NSNumber(value: NSDate().timeIntervalSince1970).stringValue

        // create the category to contain the custom action buttons
        let mpDynamicCategory =
              UNNotificationCategory(identifier: categoryId,
              actions: actions,
              intentIdentifiers: [],
              hiddenPreviewsBodyPlaceholder: "",
              options: .customDismissAction)
                
        // add the new category
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: { categories in
            var updatedCategories = categories
            updatedCategories.insert(mpDynamicCategory)
            UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)
            completionHandler(categoryId)
        })
    }
    
    func buildAttachments(content: UNNotificationContent, completionHandler: @escaping ([UNNotificationAttachment]?) -> Void) {
        guard let mediaUrlStr = (content.userInfo["mp_media_url"] as? String) else {
            NSLog("maybeAttachMedia: No media url specified.")
            completionHandler(nil)
            return
        }
        
        let fileType = URL(fileURLWithPath: mediaUrlStr).pathExtension
        
        loadAttachment(mediaUrlStr: mediaUrlStr, fileType: fileType, completionHandler: { attachment in
            guard let attachment = attachment else {
                NSLog("maybeAttachMedia: Unable to load media attachment")
                completionHandler(nil)
                return
            }
            NSLog("maybeAttachMedia: Built attachment from \(mediaUrlStr)")
            completionHandler([attachment])
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
