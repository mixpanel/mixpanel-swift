# /add-property

Add a new automatic property to all tracked events in the Mixpanel SDK.

## Usage
```
/add-property $app_build_number
```

## Steps I'll Execute

1. **Update `Sources/AutomaticProperties.swift`**
   - Add property to the appropriate collection method
   - Handle platform-specific availability with `#if os()`
   - Follow existing patterns (look at `$app_version` implementation)

2. **Add Constants** (if needed)
   - Update `Sources/Constants.swift` with new property key
   - Follow naming convention: `$property_name`

3. **Platform Compatibility**
   ```swift
   #if os(iOS)
       properties["$app_build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
   #endif
   ```

4. **Write Tests**
   - Add test to `MixpanelDemoTests/MixpanelAutomaticEventsTests.swift`
   - Verify property appears in tracked events
   - Test across all platforms

5. **Update Documentation**
   - Add entry to `CHANGELOG.md`
   - Document property meaning and platform availability

## Example Implementation
```swift
// In AutomaticProperties.swift
func collectAutomaticProperties() -> InternalProperties {
    var properties: InternalProperties = [
        // Existing properties...
    ]
    
    #if os(iOS) || os(tvOS)
    if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
        properties["$app_build_number"] = buildNumber
    }
    #endif
    
    return properties
}
```

## Validation
- Property value must conform to `MixpanelType`
- Test on iOS, macOS, tvOS, watchOS
- Verify in event payload: `instance.eventsQueue.first?["$app_build_number"]`