//
//  UIEdgeInsetsToDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(UIEdgeInsetsToNSDictionary) class UIEdgeInsetsToNSDictionary: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? NSValue, value.responds(to: #selector(getter: NSValue.uiEdgeInsetsValue)) else {
            return nil
        }
        let edgeInsets = value.uiEdgeInsetsValue

        return ["top": edgeInsets.top,
                "bottom": edgeInsets.bottom,
                "left": edgeInsets.left,
                "right": edgeInsets.right] as NSDictionary
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let dict = value as? NSDictionary else {
            return NSValue(uiEdgeInsets: .zero)
        }

        let top = dict["top"]
        let bottom = dict["bottom"]
        let left = dict["left"]
        let right = dict["right"]

        if let top = top as? CGFloat,
            let bottom = bottom as? CGFloat,
            let left = left as? CGFloat,
            let right = right as? CGFloat {
            let edgeInsets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            return NSValue(uiEdgeInsets: edgeInsets)
        }

        return NSValue(uiEdgeInsets: .zero)
    }
}
