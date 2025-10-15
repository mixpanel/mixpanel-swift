# Claude Code Quick Reference for Mixpanel Swift SDK

## Available Slash Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `/add-property` | Add automatic event property | `/add-property $app_build_number` |
| `/new-api` | Create public API method | `/new-api trackBatch(events: [Event])` |
| `/fix-thread-safety` | Fix concurrency issues | `/fix-thread-safety` |
| `/write-test` | Generate unit tests | `/write-test People.set` |
| `/debug-issue` | Debug SDK problems | `/debug-issue Events not tracking` |
| `/migrate-db` | Database schema changes | `/migrate-db Add retry_count column` |

## Knowledge Base Structure

```
@claude/architecture/threading-model.md    # Concurrency deep dive
@claude/architecture/persistence-layer.md  # Database architecture
@claude/patterns/type-safety-patterns.md   # Type system patterns
@claude/technologies/swift-features.md     # Swift language usage
@claude/workflows/release-process.md       # Release procedures
```

## Most Common Operations

### Track an Event
```swift
Mixpanel.mainInstance().track(event: "Purchase", properties: [
    "amount": 29.99,
    "currency": "USD"
])
```

### Identify User
```swift
Mixpanel.mainInstance().identify(distinctId: "user_123")
Mixpanel.mainInstance().people.set(properties: [
    "name": "John Doe",
    "email": "john@example.com"
])
```

### Thread-Safe Property
```swift
private var _value: String = ""
var value: String {
    get { readWriteLock.read { _value } }
    set { readWriteLock.write { _value = newValue } }
}
```

### Test Pattern
```swift
func testFeature() {
    instance.track(event: "Test")
    waitForTrackingQueue(instance)
    XCTAssertEqual(instance.eventsQueue.count, 1)
}
```

## Critical Rules (Always Remember)
1. **Always use ReadWriteLock** for shared state
2. **All properties must be MixpanelType**
3. **Never break API compatibility**
4. **Test on all platforms**
5. **Use `[weak self]` in async closures**

## Platform Quick Check
- iOS 11.0+ ✓ Automatic Events
- macOS 10.13+ ✗ No Automatic Events  
- tvOS 11.0+ ✗ Limited Background
- watchOS 4.0+ ✗ Limited Storage

## Debug Commands
```swift
// Enable logging
Mixpanel.mainInstance().logger = MixpanelLogger(level: .debug)

// Check queues
print("Events: \(instance.eventsQueue.count)")
```