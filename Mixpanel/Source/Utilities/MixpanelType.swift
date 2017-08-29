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
    /**
     Checks if this object has nested object types that Mixpanel supports.
     */
    func isValidNestedType() -> Bool
}

extension String: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension Int: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension UInt: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension Double: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension Float: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension Bool: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension Date: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension URL: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension NSNull: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
}
extension Array: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     */
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
    /**
     Checks if this object has nested object types that Mixpanel supports.
     */
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
