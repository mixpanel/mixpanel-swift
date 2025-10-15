---
mode: edit
description: Fix thread safety issues in selected code
---
# Fix Thread Safety Issues

Review and fix thread safety issues in the selected code:

1. **Identify shared state** that needs protection
2. **Add ReadWriteLock** protection where missing
3. **Use proper queue dispatch** for async operations
4. **Fix any potential race conditions**

## Required changes:

- Wrap all shared property reads in `readWriteLock.read { }`
- Wrap all shared property writes in `readWriteLock.write { }`
- Dispatch tracking operations to `trackingQueue`
- Dispatch network operations to `networkQueue`
- Use `[weak self]` in async closures to prevent retain cycles
- Never access instance variables directly outside of locks

## Refer to:
- [Thread safety instructions](../.github/instructions/thread-safety.instructions.md)
- Existing patterns in Track.swift and MixpanelInstance.swift

## Common patterns to apply:
```swift
// Thread-safe getter
var property: Type {
    return readWriteLock.read { _property }
}

// Thread-safe setter
func setProperty(_ value: Type) {
    readWriteLock.write { _property = value }
}

// Async operation
trackingQueue.async { [weak self] in
    guard let self = self else { return }
    // Operation code
}
```