//
//  MixpanelType.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/19/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// Property keys must be String objects and the supported value types need to conform to MixpanelType.
/// MixpanelType can be either String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, or NSNull.
public protocol MixpanelType: Any {
    func isValidNestedType() -> Bool
}

extension String: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension Int: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension UInt: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension Double: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension Float: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension Bool: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension Date: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension URL: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension NSNull: MixpanelType {
    public func isValidNestedType() -> Bool { return true }
}
extension Array: MixpanelType {
    public func isValidNestedType() -> Bool {
        for element in self {
            guard let _ = element as? MixpanelType else {
                return false
            }
        }
        return true
    }
}
extension Dictionary: MixpanelType {
    public func isValidNestedType() -> Bool {
        for (key, value) in self {
            guard let _ = key as? String, let _ = value as? MixpanelType else {
                return false
            }
        }
        return true
    }
}


func assertPropertyTypes(_ properties: Properties?) {
    if let properties = properties {
        for (_, v) in properties {
            MPAssert(v.isValidNestedType(),
                "Property values must be of valid type (MixpanelType). Got \(type(of: v))")
        }
    }
}
