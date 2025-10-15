# Type Safety Patterns in Mixpanel SDK

## MixpanelType Protocol

The SDK enforces type safety through the `MixpanelType` protocol, ensuring only valid types are sent to Mixpanel's API.

### Protocol Definition
```swift
public protocol MixpanelType {
    func toAPIObject() -> Any
    static func isValidType(_ value: Any) -> Bool
}
```

### Conforming Types
```swift
// Primitives
extension String: MixpanelType {}
extension Int: MixpanelType {}
extension UInt: MixpanelType {}
extension Double: MixpanelType {}
extension Float: MixpanelType {}
extension Bool: MixpanelType {}

// Objects
extension Date: MixpanelType {
    func toAPIObject() -> Any {
        return DateFormatter.mixpanelDateFormatter.string(from: self)
    }
}

extension URL: MixpanelType {
    func toAPIObject() -> Any {
        return self.absoluteString
    }
}

extension NSNull: MixpanelType {}

// Collections
extension Array: MixpanelType where Element: MixpanelType {}
extension Dictionary: MixpanelType where Key == String, Value: MixpanelType {}

// Optional support
extension Optional: MixpanelType where Wrapped: MixpanelType {
    func toAPIObject() -> Any {
        switch self {
        case .none:
            return NSNull()
        case .some(let value):
            return value.toAPIObject()
        }
    }
}
```

## Type Validation Patterns

### 1. Property Validation
```swift
public typealias Properties = [String: MixpanelType]

func assertPropertyTypes(_ properties: Properties) {
    #if DEBUG
    for (key, value) in properties {
        assert(
            MixpanelType.isValidType(value),
            "Property '\(key)' has invalid type: \(type(of: value))"
        )
        
        // Check nested types
        if let array = value as? [Any] {
            array.forEach { element in
                assert(
                    MixpanelType.isValidType(element),
                    "Array element in '\(key)' has invalid type"
                )
            }
        }
        
        if let dict = value as? [String: Any] {
            dict.forEach { (nestedKey, nestedValue) in
                assert(
                    MixpanelType.isValidType(nestedValue),
                    "Nested property '\(key).\(nestedKey)' has invalid type"
                )
            }
        }
    }
    #endif
}
```

### 2. Safe Type Conversion
```swift
// Convert unknown types safely
func convertToMixpanelType(_ value: Any) -> MixpanelType? {
    // Direct cast
    if let mixpanelValue = value as? MixpanelType {
        return mixpanelValue
    }
    
    // Handle NSNumber (from Objective-C)
    if let number = value as? NSNumber {
        // Check for boolean
        if CFBooleanGetTypeID() == CFGetTypeID(number) {
            return number.boolValue
        }
        
        // Check for integer
        if let int = number as? Int {
            return int
        }
        
        // Default to Double
        return number.doubleValue
    }
    
    // Handle collections with type erasure
    if let array = value as? [Any] {
        let converted = array.compactMap { convertToMixpanelType($0) }
        return converted.count == array.count ? converted : nil
    }
    
    if let dict = value as? [String: Any] {
        let converted = dict.compactMapValues { convertToMixpanelType($0) }
        return converted.count == dict.count ? converted : nil
    }
    
    return nil
}
```

### 3. Filtering Invalid Types
```swift
extension Dictionary where Key == String {
    func filterValidProperties() -> Properties {
        return self.compactMapValues { value in
            if let mixpanelValue = value as? MixpanelType {
                return mixpanelValue
            }
            
            // Try conversion
            return convertToMixpanelType(value)
        }
    }
}

// Usage
let rawProperties: [String: Any] = [
    "valid_string": "hello",
    "valid_number": 42,
    "invalid_object": SomeCustomClass(),  // Will be filtered out
    "valid_date": Date()
]

let validProperties = rawProperties.filterValidProperties()
// Only contains valid_string, valid_number, and valid_date
```

## Common Type Patterns

### 1. Numeric Type Handling
```swift
// Problem: Swift has many numeric types
func handleNumericProperty(_ value: Any) -> MixpanelType? {
    switch value {
    case let int as Int:
        return int
    case let uint as UInt:
        return uint
    case let double as Double:
        return double
    case let float as Float:
        return float
    case let int8 as Int8:
        return Int(int8)
    case let int16 as Int16:
        return Int(int16)
    case let int32 as Int32:
        return Int(int32)
    case let int64 as Int64:
        return Double(int64)  // Prevent overflow
    default:
        return nil
    }
}
```

### 2. Date Formatting
```swift
extension DateFormatter {
    static let mixpanelDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// Consistent date handling
func formatDate(_ date: Date) -> String {
    return DateFormatter.mixpanelDateFormatter.string(from: date)
}

func parseDate(_ string: String) -> Date? {
    return DateFormatter.mixpanelDateFormatter.date(from: string)
}
```

### 3. Collection Type Safety
```swift
// Ensure homogeneous arrays
func validateArray(_ array: [Any]) -> [MixpanelType]? {
    let converted = array.compactMap { convertToMixpanelType($0) }
    
    // All elements must convert successfully
    guard converted.count == array.count else {
        Logger.warning("Array contains invalid types")
        return nil
    }
    
    // Optional: Check all elements are same type
    if !array.isEmpty {
        let firstType = type(of: array[0])
        let homogeneous = array.allSatisfy { type(of: $0) == firstType }
        if !homogeneous {
            Logger.debug("Array contains mixed types")
        }
    }
    
    return converted
}
```

## API Design for Type Safety

### 1. Generic Constraints
```swift
// Type-safe property setter
func set<T: MixpanelType>(property: String, to value: T) {
    properties[property] = value
}

// Usage
people.set(property: "age", to: 25)  // ✅ Int conforms
people.set(property: "name", to: "John")  // ✅ String conforms
// people.set(property: "custom", to: MyClass())  // ❌ Compile error
```

### 2. Builder Pattern with Type Safety
```swift
class EventBuilder {
    private var properties: Properties = [:]
    
    func with<T: MixpanelType>(_ key: String, value: T) -> Self {
        properties[key] = value
        return self
    }
    
    func withOptional<T: MixpanelType>(_ key: String, value: T?) -> Self {
        if let value = value {
            properties[key] = value
        }
        return self
    }
    
    func build() -> Properties {
        return properties
    }
}

// Usage
let event = EventBuilder()
    .with("product_id", value: 12345)
    .with("product_name", value: "Widget")
    .withOptional("coupon_code", value: userCoupon)
    .build()
```

### 3. Result Type for Validation
```swift
enum ValidationResult<T> {
    case valid(T)
    case invalid(reason: String)
}

func validateProperties(_ raw: [String: Any]) -> ValidationResult<Properties> {
    var validated: Properties = [:]
    
    for (key, value) in raw {
        if let validValue = convertToMixpanelType(value) {
            validated[key] = validValue
        } else {
            return .invalid(
                reason: "Property '\(key)' has invalid type: \(type(of: value))"
            )
        }
    }
    
    return .valid(validated)
}

// Usage
switch validateProperties(userInput) {
case .valid(let properties):
    track(event: "Purchase", properties: properties)
case .invalid(let reason):
    Logger.error("Invalid properties: \(reason)")
}
```

## Objective-C Interoperability

### 1. Type Bridging
```swift
@objc public class MixpanelObjC: NSObject {
    @objc public static func track(
        event: String,
        properties: [String: Any]?
    ) {
        // Convert to type-safe properties
        let validProperties = properties?.filterValidProperties() ?? [:]
        Mixpanel.mainInstance().track(
            event: event,
            properties: validProperties
        )
    }
}
```

### 2. Safe NSNumber Handling
```swift
extension NSNumber {
    var mixpanelValue: MixpanelType {
        // Check if boolean
        if CFBooleanGetTypeID() == CFGetTypeID(self) {
            return boolValue
        }
        
        // Check encoding
        let encoding = String(cString: objCType)
        
        switch encoding {
        case "c", "C", "B":  // char, unsigned char, bool
            return boolValue
        case "i", "s", "l", "q":  // int types
            return intValue
        case "I", "S", "L", "Q":  // unsigned int types
            return uintValue
        case "f":  // float
            return floatValue
        case "d":  // double
            return doubleValue
        default:
            return doubleValue  // Safe default
        }
    }
}
```

## Testing Type Safety

### 1. Property Type Tests
```swift
func testValidPropertyTypes() {
    let validProperties: Properties = [
        "string": "test",
        "int": 42,
        "double": 3.14,
        "bool": true,
        "date": Date(),
        "url": URL(string: "https://mixpanel.com")!,
        "array": [1, 2, 3],
        "dict": ["nested": "value"],
        "null": NSNull(),
        "optional": Optional<String>.none
    ]
    
    // Should not crash
    assertPropertyTypes(validProperties)
    
    // All should be valid
    for (_, value) in validProperties {
        XCTAssertTrue(MixpanelType.isValidType(value))
    }
}
```

### 2. Invalid Type Tests
```swift
func testInvalidPropertyTypes() {
    let invalidValues: [Any] = [
        UIView(),  // Custom object
        NSObject(),  // Foundation object
        { print("closure") },  // Closure
        Selector("test"),  // Selector
    ]
    
    for value in invalidValues {
        XCTAssertFalse(MixpanelType.isValidType(value))
        XCTAssertNil(convertToMixpanelType(value))
    }
}
```

### 3. Conversion Tests
```swift
func testTypeConversion() {
    // NSNumber conversions
    XCTAssertEqual(convertToMixpanelType(NSNumber(value: true)) as? Bool, true)
    XCTAssertEqual(convertToMixpanelType(NSNumber(value: 42)) as? Int, 42)
    
    // Collection conversions
    let nsArray = NSArray(array: ["a", "b", "c"])
    let converted = convertToMixpanelType(nsArray) as? [String]
    XCTAssertEqual(converted, ["a", "b", "c"])
}
```

## Best Practices

1. **Always validate at API boundaries** - Don't trust external input
2. **Use type aliases** - `Properties` is clearer than `[String: MixpanelType]`
3. **Fail gracefully** - Log and skip invalid properties rather than crash
4. **Document supported types** - Make it clear what types are accepted
5. **Test edge cases** - Empty strings, very large numbers, special characters
6. **Consider performance** - Type checking has overhead, cache when possible