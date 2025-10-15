---
applyTo: "**/*.swift"
---
# Thread Safety Instructions for Mixpanel Swift SDK

## Always use ReadWriteLock for shared state
- Wrap read operations: `readWriteLock.read { /* read code */ }`
- Wrap write operations: `readWriteLock.write { /* write code */ }`
- Never access shared properties directly outside of lock protection

## Queue Usage
- Use `trackingQueue` for all event tracking operations
- Use `networkQueue` for all network requests
- Both queues use QoS: .utility and autorelease: .workItem
- Dispatch async unless synchronous operation is explicitly needed

## Common Thread-Safe Patterns
```swift
// Reading a property
var value: String {
    return readWriteLock.read { _value }
}

// Writing a property
func setValue(_ newValue: String) {
    readWriteLock.write { _value = newValue }
}

// Async operation
trackingQueue.async { [weak self] in
    self?.performOperation()
}
```

## Avoid Deadlocks
- Never call readWriteLock.write from within readWriteLock.read
- Use weak self in async closures to prevent retain cycles
- Order lock acquisition consistently across the codebase

## Testing Thread Safety
- Use waitForTrackingQueue() in tests to ensure operations complete
- Test concurrent access scenarios
- Verify no data races with Thread Sanitizer