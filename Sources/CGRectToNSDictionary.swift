//
//  CGRectToNSDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(CGRectToNSDictionary) class CGRectToNSDictionary: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? NSValue, value.responds(to: #selector(getter: NSValue.cgRectValue)) else {
            return nil
        }
        var rect = value.cgRectValue
        rect.origin.x = rect.origin.x.isNormal ? rect.origin.x : 0.0
        rect.origin.y = rect.origin.y.isNormal ? rect.origin.y : 0.0
        rect.size.width = rect.size.width.isNormal ? rect.size.width : 0.0
        rect.size.height = rect.size.height.isNormal ? rect.size.height : 0.0
        return rect.dictionaryRepresentation as NSDictionary
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        let dict = value as! CFDictionary
        if let rect = CGRect(dictionaryRepresentation: dict) {
            return NSValue(cgRect: rect)
        }

        return NSValue(cgRect: .zero)
    }
}
