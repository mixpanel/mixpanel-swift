import UserNotifications

@available(iOS 11.0, *)
open class MixpanelNotificationServiceExtension: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    open override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        NSLog("%@ MPNotificationServiceExtension didReceiveNotificationRequest", self);

        guard MixpanelPushNotifications.isMixpanelPushNotification(request.content) else {
            NSLog("%@ Not a Mixpanel push notification, returning original content", self);
            contentHandler(request.content);
            return;
        }

        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            contentHandler(request.content)
            return
        }

        // Store a reference to the mutable content and the contentHandler on the class so we
        // can use them in serviceExtensionTimeWillExpire if needed
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent

        // Track $push_notification_received event
        MixpanelPushNotifications.trackEvent("$push_notification_received", properties: [:], request: request)

        // Setup the category first since it's faster and less likely to cause time to expire
        self.getCategoryIdentifier(content: request.content) { categoryIdentifier in
            if let categoryIdentifier = categoryIdentifier {
                NSLog("Using categoryIdentifer: \(categoryIdentifier)")
                bestAttemptContent.categoryIdentifier = categoryIdentifier
            }

            // Download rich media and create an attachment
            self.buildAttachments(content: request.content) { attachments in
                if let attachments = attachments {
                    NSLog("Adding \(attachments.count) attachment(s)")
                    bestAttemptContent.attachments = attachments
                }
                contentHandler(bestAttemptContent)
            }
        }
    }

    open override func serviceExtensionTimeWillExpire() {
        NSLog("%@ contentHandler not called in time, returning bestAttemptContent", self);

        guard let contentHandler = self.contentHandler else {
            return;
        }

        guard let bestAttemptContent = self.bestAttemptContent else {
            return;
        }

        contentHandler(bestAttemptContent);
    }

    func getCategoryIdentifier(content: UNNotificationContent, completionHandler: @escaping (String?) -> Void) {
        // If the payload explicitly specifies a category, use it
        guard content.categoryIdentifier.isEmpty else {
            NSLog("getCategoryIdentifier: explicit categoryIdentifer included in payload: \(content.categoryIdentifier)")
            completionHandler(content.categoryIdentifier)
            return
        }

        // Generate unique cateogry id from timestamp
        let categoryId = NSNumber(value: NSDate().timeIntervalSince1970).stringValue

        // Get buttons if they are specified
        let buttons = content.userInfo["mp_buttons"] as? [[AnyHashable: Any]] ?? []
        if (buttons.count == 0) {
            NSLog("getCategoryIdentifier: No action buttons found in the push notification payload.")
        }
        
        // Build a list of actions from the buttons data
        var actions: [UNNotificationAction] = []
        for (idx, button) in buttons.enumerated() {
            let identifier = String(format: "MP_ACTION_%lu", idx)
            if let title = button["lbl"] as? String {
                let action = UNNotificationAction(identifier: identifier, title: title, options: .foreground)
                actions.append(action)
            }
        }

        // Create a new category with custom dismiss action set to true and any action buttons specified
        let mpDynamicCategory =
              UNNotificationCategory(identifier: categoryId,
              actions: actions,
              intentIdentifiers: [],
              hiddenPreviewsBodyPlaceholder: "",
              options: .customDismissAction)
                
        // Add the new category
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: { categories in
            var updatedCategories = categories
            updatedCategories.insert(mpDynamicCategory)
            UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)

            // In testing, it's clear that setNotificationCategories is not a synchronous action
            // or there is caching going on. We need to wait until the category is available.
            self.waitForCategoryExistence(categoryIdentifier: categoryId) {
                NSLog("getCategoryIdentifier: Category \"\(categoryId)\" found, returning.")
                completionHandler(categoryId)
            }
        })
    }

    func waitForCategoryExistence(categoryIdentifier: String, completionHandler: @escaping () -> Void) {
        NSLog("Checking for the existence of category \"\(categoryIdentifier)\"...")
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: { categories in
            for category in categories {
                if (category.identifier == categoryIdentifier) {
                    completionHandler()
                    return
                }
            }
            self.waitForCategoryExistence(categoryIdentifier: categoryIdentifier, completionHandler: completionHandler);
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
                NSLog("Unable to add attachment: \(attachmentError.localizedDescription)")
                completionHandler(nil)
            }
        })).resume()
    }
}
