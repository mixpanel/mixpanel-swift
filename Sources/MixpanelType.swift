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
/// Numbers are not NaN or infinity
public protocol MixpanelType: Any {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     */
    func isValidNestedTypeAndValue() -> Bool
    
    func equals(rhs: MixpanelType) -> Bool
}

extension Optional: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        guard let val = self else { return true } // nil is valid
        switch val {
        case let v as MixpanelType:
            return v.isValidNestedTypeAndValue()
        default:
            // non-nil but cannot be unwrapped to MixpanelType
            return false
        }
    }

    public func equals(rhs: MixpanelType) -> Bool {
        if let v = self as? String, rhs is String {
            return v == rhs as! String
        } else if let v = self as? NSString, rhs is NSString {
            return v == rhs as! NSString
        } else if let v = self as? NSNumber, rhs is NSNumber {
            return v.isEqual(to: rhs as! NSNumber)
        } else if let v = self as? Int, rhs is Int {
            return v == rhs as! Int
        } else if let v = self as? UInt, rhs is UInt {
            return v == rhs as! UInt
        } else if let v = self as? Double, rhs is Double {
            return v == rhs as! Double
        } else if let v = self as? Float, rhs is Float {
            return v == rhs as! Float
        } else if let v = self as? Bool, rhs is Bool {
            return v == rhs as! Bool
        } else if let v = self as? Date, rhs is Date {
            return v == rhs as! Date
        } else if let v = self as? URL, rhs is URL {
            return v == rhs as! URL
        } else if self is NSNull && rhs is NSNull {
            return true
        }
        return false
    }
}
extension String: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is String {
            return self == rhs as! String
        }
        return false
    }
}

extension NSString: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }

    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is NSString {
            return self == rhs as! NSString
        }
        return false
    }
}

extension NSNumber: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool {
        return !self.doubleValue.isInfinite && !self.doubleValue.isNaN
    }
    
    public func equals(rhs: MixpanelType) -> Bool {
        if rhs is NSNumber {
            return self.isEqual(rhs)
        }
        return false
    }
}

extension Int: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     Will always return true.
     */
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
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
    public func isValidNestedTypeAndValue() -> Bool { return true }
    
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
    public func isValidNestedTypeAndValue() -> Bool {
        return !self.isInfinite && !self.isNaN
    }
    
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
    public func isValidNestedTypeAndValue() -> Bool {
        return !self.isInfinite && !self.isNaN
    }
    
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
    public func isValidNestedTypeAndValue() -> Bool { return true }

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
    public func isValidNestedTypeAndValue() -> Bool { return true }

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
    public func isValidNestedTypeAndValue() -> Bool { return true }

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
    public func isValidNestedTypeAndValue() -> Bool { return true }

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
    public func isValidNestedTypeAndValue() -> Bool {
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

            if !isValidNestedTypeAndValue() {
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

extension NSArray: MixpanelType {
    /**
     Checks if this object has nested object types that Mixpanel supports.
     */
    public func isValidNestedTypeAndValue() -> Bool {
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

            if !isValidNestedTypeAndValue() {
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
    public func isValidNestedTypeAndValue() -> Bool {
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
            
            if !isValidNestedTypeAndValue() {
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
            MPAssert(v.isValidNestedTypeAndValue(),
                "Property values must be of valid type (MixpanelType) and valid value. Got \(type(of: v)) and Value \(v)")
        }
    }
}

extension Dictionary {
    func get<T>(key: Key, defaultValue: T) -> T {
        if let value = self[key] as? T {
            return value
        }

        return defaultValue
    }
}
