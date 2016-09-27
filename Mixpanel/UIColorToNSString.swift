//
//  UIColorToNSString.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(UIColorToNSString) class UIColorToNSString: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let color = value as? UIColor else {
            return nil
        }

        let colorSpace = color.cgColor.colorSpace
        if let csModel = colorSpace?.model, let components = color.cgColor.components {
            let numberOfComponents = color.cgColor.numberOfComponents
            if csModel == .monochrome && numberOfComponents >= 1 {
                let w = 255 * components[0]
                let a = numberOfComponents > 1 ? components[1] : 1.0
                return NSString(format: "rgba(%.0f, %.0f, %.0f, %.2f)", w, w, w, a)
            } else if csModel == .rgb && numberOfComponents >= 3 {
                let r = 255 * components[0]
                let g = 255 * components[1]
                let b = 255 * components[2]
                let a = numberOfComponents > 3 ? components[3] : 1.0
                return NSString(format:"rgba(%.0f, %.0f, %.0f, %.2f)", r, g, b, a)
            }
        }
        return nil
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let str = value as? String else {
            return nil
        }

        let scanner = Scanner(string: str)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "rgba(), ")
        scanner.locale = Locale(identifier: "en_US_POSIX")

        var r: Float = 0.0, g: Float = 0.0, b: Float = 0.0, a: Float = 1.0
        if scanner.scanFloat(&r) && scanner.scanFloat(&g) && scanner.scanFloat(&b) && scanner.scanFloat(&a) {
            return UIColor(red: CGFloat(r) / 255.0,
                           green: CGFloat(g) / 255.0,
                           blue: CGFloat(b) / 255.0,
                           alpha: CGFloat(a))
        }

        return nil
    }
}
