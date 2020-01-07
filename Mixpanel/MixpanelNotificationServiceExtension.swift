
private let kDynamicCategoryIdentifier = "MP_DYNAMIC"
private let mediaUrlKey = "mp_media_url"

@available(iOS 10.0, *)
open class MixpanelNotificationServiceExtension: UNNotificationServiceExtension {
    private var richContentTaskComplete = false
    private var notificationCategoriesTaskComplete = false

    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override open func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            let userInfo = request.content.userInfo

            let buttons = userInfo["mp_buttons"] as? [[String:String]]
            if buttons != nil {
                registerDynamicCategory(userInfo, withButtons: buttons!)
            } else {
            #if DEBUG
                Logger.info(message: "No action buttons specified, not adding dynamic category")
            #endif
            }

            let mediaUrl = userInfo[mediaUrlKey] as? String
            if mediaUrl != nil {
                attachRichMedia(userInfo, withMediaUrl: mediaUrl!)
            } else {
            #if DEBUG
                Logger.info(message: "No media url specified, not attatching rich media")
            #endif
            }
        }
    }
    
    override open func serviceExtensionTimeWillExpire() {
        sendContent()
    }

    func taskComplete() {
        if richContentTaskComplete && notificationCategoriesTaskComplete {
            sendContent()
        }
    }

    func sendContent() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    func registerDynamicCategory(_ userInfo: [AnyHashable : Any]?, withButtons buttons: [[String:String]]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories(completionHandler: { categories in
            
            var actions: [UNNotificationAction] = []
            for (idx, button) in buttons.enumerated() {
                let action = UNNotificationAction(identifier: String(format: "MP_ACTION_%lu", idx), title: button["lbl"]!, options: .foreground)
                actions.append(action)
            }
         
            let dynamicMixpanelCategory = UNNotificationCategory(identifier: kDynamicCategoryIdentifier, actions: actions, intentIdentifiers: [], options: [])
            let mixpanelCategories: Set = [dynamicMixpanelCategory]
            let nonMixpanelCategories = categories.filter { (category) -> Bool in
                return !category.identifier.contains(kDynamicCategoryIdentifier)
            }
            center.setNotificationCategories(nonMixpanelCategories.union(mixpanelCategories))

            self.notificationCategoriesTaskComplete = true

            self.taskComplete()
        })
    }

    func attachRichMedia(_ userInfo: [AnyHashable : Any]?, withMediaUrl mediaUrl: String) {
        let mediaType = URL(fileURLWithPath: mediaUrl).pathExtension

        if mediaUrl == nil || mediaType == nil {
            if mediaUrl == nil {
                Logger.info(message: "Unable to add attachment: %@ is nil", mediaUrlKey)
            }

            if mediaType == nil {
                Logger.info(message: "Unable to add attachment: extension is nil")
            }
            richContentTaskComplete = true
            taskComplete()
            return
        }

        // load the attachment
        loadAttachment(forUrlString: mediaUrl, withType: mediaType, completionHandler: { attachment in
            if attachment != nil {
                self.bestAttemptContent?.attachments = [attachment!]
            }
            self.richContentTaskComplete = true
            self.taskComplete()
        })
    }

    func loadAttachment(forUrlString urlString: String?, withType type: String?, completionHandler: @escaping (UNNotificationAttachment?) -> Void) {
            var attachment: UNNotificationAttachment? = nil
            let attachmentURL = URL(string: urlString ?? "")
            let fileExt = "." + (type ?? "")

            let session = URLSession(configuration: URLSessionConfiguration.default)
            if let attachmentURL = attachmentURL {
                (session.downloadTask(with: attachmentURL, completionHandler: { temporaryFileLocation, response, error in
                    if error != nil {
                        Logger.info(message: "Unable to add attachment: %@", error?.localizedDescription ?? "")
                    } else {
                        let fileManager = FileManager.default
                        let localURL = URL(fileURLWithPath: temporaryFileLocation?.path ?? "" + (fileExt))
                        do {
                            if let temporaryFileLocation = temporaryFileLocation {
                                try fileManager.moveItem(at: temporaryFileLocation, to: localURL)
                            }
                        } catch {
                        }

                        var attachmentError: Error? = nil
                        do {
                            attachment = try UNNotificationAttachment(identifier: "", url: localURL, options: nil)
                        } catch let attachmentError {
                        }
                        if attachmentError != nil || attachment == nil {
                            Logger.info(message: "Unable to add attchment: %@", attachmentError?.localizedDescription ?? "")
                        }
                    }
                    completionHandler(attachment)
                })).resume()
            }
        }
    }
