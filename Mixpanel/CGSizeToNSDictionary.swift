//
//  CGSizeToDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(CGSizeToNSDictionary) class CGSizeToNSDictionary: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? NSValue, value.responds(to: #selector(getter: NSValue.cgSizeValue)) else {
            return nil
        }

        return value.cgSizeValue.dictionaryRepresentation as NSDictionary
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        let dict = value as! CFDictionary
        if let size = CGSize(dictionaryRepresentation: dict) {
            return NSValue(cgSize: size)
        }

        return NSValue(cgSize: .zero)
    }
}
