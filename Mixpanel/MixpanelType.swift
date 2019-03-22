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
    
    func equals(rhs: MixpanelType) -> Bool
}

extension String: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is String {
            return self == rhs as! String
        }
        return false
    }
}

extension Int: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is Int {
            return self == rhs as! Int
        }
        return false
    }
}
extension UInt: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is UInt {
            return self == rhs as! UInt
        }
        return false
    }
}
extension Double: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is Double {
            return self == rhs as! Double
        }
        return false
    }
}
extension Float: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is Float {
            return self == rhs as! Float
        }
        return false
    }
}
extension Bool: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }

    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is Bool {
            return self == rhs as! Bool
        }
        return false
    }
}

extension Date: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }

    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is Date {
            return self == rhs as! Date
        }
        return false
    }
}

extension URL: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }

    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is URL {
            return self == rhs as! URL
        }
        return false
    }
}

extension NSNull: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedType() -> Bool { return true }

    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is NSNull {
            return true
        }
        return false
    }
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

    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is [MixpanelType] {
            let rhs = rhs as! [MixpanelType]
            
            if self.count != rhs.count {
                return false
            }

            if !isValidNestedType() {
                return false
            }
            
            let lhs = self as! [MixpanelType]
            for (i, val) in lhs.enumerated() {
                if !val.equals(rhs: rhs[i]) {
                    return false
                }
            }
            return true
        }
        return false
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
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is [String: MixpanelType] {
            let rhs = rhs as! [String: MixpanelType]
            
            if self.keys.count != rhs.keys.count {
                return false
            }
            
            if !isValidNestedType() {
                return false
            }
            
            for (key, val) in self as! [String: MixpanelType] {
                guard let rVal = rhs[key] else {
                    return false
                }

                if !val.equals(rhs: rVal) {
                    return false
                }
            }
            return true
        }
        return false
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
