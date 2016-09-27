//
//  CGAffineTransformToNSDictionary.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

@objc(CGAffineTransformToNSDictionary) class CGAffineTransformToNSDictionary: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSDictionary.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let affineTransformVal = value as? NSValue else {
            return nil
        }

        let affineTransform = affineTransformVal.cgAffineTransformValue

        return ["a": affineTransform.a,
                "b": affineTransform.b,
                "c": affineTransform.c,
                "d": affineTransform.d,
                "tx": affineTransform.tx,
                "ty": affineTransform.ty]
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let dict = value as? NSDictionary else {
            return NSValue(cgAffineTransform: .identity)
        }

        let a = dict["a"] as? CGFloat
        let b = dict["b"] as? CGFloat
        let c = dict["c"] as? CGFloat
        let d = dict["d"] as? CGFloat
        let tx = dict["tx"] as? CGFloat
        let ty = dict["ty"] as? CGFloat

        if let a = a, let b = b, let c = c, let d = d, let tx = tx, let ty = ty {
            return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
        }

        return NSValue(cgAffineTransform: .identity)
    }

}
