---
mode: agent
tools: [codebase, githubRepo]
description: Add a new automatic property to events
---
# Add New Automatic Event Property

I need to add a new automatic property named "${input:propertyName:Enter property name (e.g., app_build_number)}" to all tracked events.

## Requirements

1. **Update AutomaticProperties.swift**:
   - Add the new property to the appropriate collection method
   - Follow existing patterns for platform-specific properties
   - Use proper MixpanelType conformance

2. **Consider platform differences**:
   - Check if property is available on all platforms (iOS, macOS, tvOS, watchOS)
   - Use conditional compilation if needed

3. **Update Constants if needed**:
   - Add any new constant keys to Constants.swift
   - Follow naming convention (e.g., `$app_build_number`)

4. **Add tests**:
   - Create test in MixpanelAutomaticEventsTests.swift
   - Verify property is included in tracked events
   - Test on all supported platforms

5. **Documentation**:
   - Update CHANGELOG.md with the new property
   - Add inline documentation explaining the property

## Implementation guidelines from [property-types instructions](../.github/instructions/property-types.instructions.md)

## Example pattern to follow:
Look at how `$app_version` or `$os_version` are implemented in AutomaticProperties.swift