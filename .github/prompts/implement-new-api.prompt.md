---
mode: agent
tools: [codebase]
description: Implement a new public API method
---
# Implement New Public API Method

I need to implement a new public API method: ${input:methodSignature:Enter method signature (e.g., trackCustomEvent(name: String, metadata: [String: Any]))}

## Implementation Steps

1. **Add to Mixpanel.swift** (static interface):
   - Add public static method
   - Forward to mainInstance()
   - Include proper documentation

2. **Add to MixpanelInstance.swift**:
   - Implement actual logic
   - Use @objc if needed for Objective-C compatibility
   - Make thread-safe with ReadWriteLock
   - Return self or @discardableResult for fluent API

3. **Follow patterns**:
   - Reference similar methods like track() or identify()
   - Use established queue patterns from [thread-safety instructions](../.github/instructions/thread-safety.instructions.md)
   - Validate inputs using property type system

4. **Error handling**:
   - Use MixpanelLogger for errors
   - Don't throw exceptions
   - Fail gracefully with sensible defaults

5. **Add tests**:
   - Create comprehensive tests in appropriate test file
   - Test edge cases and invalid inputs
   - Test thread safety

6. **Documentation**:
   - Add comprehensive doc comments
   - Include usage examples
   - Document any platform-specific behavior
   - Update public API documentation

## Code Pattern Example:
```swift
@discardableResult
public func newMethod(param: String) -> MixpanelInstance {
    readWriteLock.write {
        // Implementation
    }
    return self
}
```