---
applyTo: "**/Track.swift,**/People.swift,**/Group.swift,**/*Properties*.swift"
---
# Property Type System Instructions

## MixpanelType Protocol
All property values MUST conform to MixpanelType protocol. Valid types:
- String, Int, UInt, Double, Float, Bool
- [MixpanelType] (arrays of valid types)
- [String: MixpanelType] (dictionaries with String keys)
- Date, URL, NSNull
- Optional<MixpanelType> (optionals of valid types)

## Property Validation
Always validate properties before use:
```swift
assertPropertyTypes(properties)
```

## Type Conversion
Use the established conversion patterns:
```swift
// Convert Any to MixpanelType
if let validValue = value as? MixpanelType {
    // Use validValue
}

// For dictionaries
Properties.filterValues { isValidNestedTypeAndValue($0) }
```

## Reserved Properties
Never use these reserved property names:
- mp_lib, $lib_version, $os, $os_version
- $manufacturer, $brand, $model
- time, distinct_id, $device_id

## Property Naming
- Use snake_case for property names (matching Mixpanel convention)
- Prefix Mixpanel internal properties with $ or mp_
- Keep property names under 255 characters