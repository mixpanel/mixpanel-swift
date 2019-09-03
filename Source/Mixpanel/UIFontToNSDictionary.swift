//
//  UIFontToNSDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(UIFontToNSDictionary) class UIFontToNSDictionary: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let font = value as? UIFont else {
            return nil
        }

        return ["familyName": font.familyName,
                "fontName": font.fontName,
                "pointSize": font.pointSize]
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let dict = value as? NSDictionary else {
            return nil
        }

        if let fontSize = dict["pointSize"] as? CGFloat, fontSize > 0.0, let fontName = dict["fontName"] as? String {
            let systemFont = UIFont.systemFont(ofSize: fontSize)
            let boldSystemFont = UIFont.boldSystemFont(ofSize: fontSize)
            let italicSystemFont = UIFont.italicSystemFont(ofSize: fontSize)

            if systemFont.fontName == fontName {
                return systemFont
            } else if boldSystemFont.fontName == fontName {
                return boldSystemFont
            } else if italicSystemFont.fontName == fontName {
                return italicSystemFont
            } else {
                return UIFont(name: fontName, size: fontSize)
            }
        }
        return nil
    }
}
