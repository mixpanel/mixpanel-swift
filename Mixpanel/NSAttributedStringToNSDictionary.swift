//
//  NSAttributedStringToNSDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(NSAttributedStringToNSDictionary) class NSAttributedStringToNSDictionary: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let attributedString = value as? NSAttributedString else {
            return nil
        }

        do {
            let data = try attributedString.data(from: NSRange(location: 0,
                                                               length: attributedString.length),
                                                 documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType:
                                                    NSAttributedString.DocumentType.html])
            if let dataString = String(data: data, encoding: String.Encoding.utf8) {
                return ["mime_type": "text/html",
                        "data": dataString]
            }
        } catch {
            Logger.debug(message: "Failed to convert NSAttributedString to HTML")
        }
        return nil
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let dict = value as? NSDictionary else {
            return nil
        }

        let mimeType = dict["mime_type"]
        let dataString = dict["data"]

        if let mimeType = mimeType as? String, mimeType == "text/html", let dataString = dataString as? String {
            if let data = dataString.data(using: String.Encoding.utf8) {
                do {
                    return try NSAttributedString(data: data,
                                                  options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html],
                                                  documentAttributes: nil)
                } catch {
                    Logger.debug(message: "Failed to convert HTML to NSAttributedString")
                }
            }
        }
        return nil
    }
}
