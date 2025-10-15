---
mode: agent
tools: [codebase]
description: Add platform-specific functionality
---
# Add Platform-Specific Functionality

Add platform-specific implementation for: ${input:feature:Describe the platform-specific feature}

## Steps to implement:

1. **Identify platform requirements**:
   - Determine which platforms support this feature
   - Check API availability (iOS 11.0+, tvOS 11.0+, macOS 10.13+, watchOS 4.0+)

2. **Use conditional compilation**:
   ```swift
   #if os(iOS)
   // iOS-specific code
   #elseif os(macOS)
   // macOS-specific code
   #elseif os(tvOS)
   // tvOS-specific code
   #elseif os(watchOS)
   // watchOS-specific code
   #endif
   ```

3. **Common patterns**:
   - Check `!os(OSX)` for features not on macOS
   - Use `targetEnvironment(macCatalyst)` for Mac Catalyst
   - Check `isiOSAppExtension()` for app extensions

4. **Update relevant files**:
   - AutomaticEvents.swift for automatic tracking
   - AutomaticProperties.swift for platform properties
   - MixpanelInstance.swift for initialization

5. **Test on all platforms**:
   - Create platform-specific test targets
   - Use appropriate simulators/devices
   - Verify no compilation errors on unsupported platforms

6. **Documentation**:
   - Document platform availability
   - Add platform badges to method documentation
   - Update README if needed

## Examples to reference:
- Automatic events (iOS only)
- Network activity indicator (iOS only)
- Screen properties (not on watchOS)