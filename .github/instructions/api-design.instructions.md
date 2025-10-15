---
applyTo: "**/Mixpanel.swift,**/MixpanelInstance.swift,**/People.swift,**/Group.swift"
---
# API Design Instructions

## Public API Guidelines
- Keep public surface minimal and focused
- Maintain backward compatibility
- Use @available for deprecation
- Document all public methods thoroughly

## Method Design
- Return self or @discardableResult for chaining
- Use default parameters for optional values
- Provide both sync and async variants where appropriate
- Use completion handlers for async operations

## Naming Conventions
- Use clear, descriptive method names
- Follow Swift API design guidelines
- Use verbs for actions (track, identify, flush)
- Use nouns for properties (distinctId, people)

## Parameter Design
```swift
// Good: Clear parameters with defaults
public func track(event: String, 
                 properties: Properties? = nil,
                 completion: (() -> Void)? = nil)

// Bad: Unclear or too many parameters
public func track(_ e: String, _ p: [String: Any]?, _ c: Bool)
```

## Error Handling
- Never throw from public APIs
- Use completion handlers with Result type for errors
- Log errors internally
- Provide sensible fallbacks

## Objective-C Compatibility
- Mark methods with @objc when needed
- Avoid Swift-only features in public API
- Provide type-safe wrappers

## Documentation Pattern
```swift
/// Tracks an event with optional properties
/// - Parameters:
///   - event: The name of the event to track
///   - properties: Optional properties dictionary
/// - Returns: The current instance for chaining
```