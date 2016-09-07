//
//  IdentityTransformer.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/6/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

@objc(IdentityTransformer) class IdentityTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSObject.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return value
    }

}
