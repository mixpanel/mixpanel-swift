# Threading Model Deep Dive

## Overview
The Mixpanel SDK uses a sophisticated threading model to ensure thread safety while maintaining high performance. Understanding this model is crucial for making safe modifications.

## Core Components

### ReadWriteLock
Custom implementation using GCD's concurrent queue with barriers.

```swift
public class ReadWriteLock {
    private let concurrentQueue: DispatchQueue
    
    init(label: String) {
        concurrentQueue = DispatchQueue(
            label: label,
            attributes: .concurrent
        )
    }
    
    func read<T>(_ block: () -> T) -> T {
        return concurrentQueue.sync { block() }
    }
    
    func write<T>(_ block: () -> T) -> T {
        return concurrentQueue.sync(flags: .barrier) { block() }
    }
}
```

**Why this design?**
- Multiple readers can access simultaneously
- Writers get exclusive access via barrier
- Prevents reader-writer and writer-writer conflicts
- Better performance than serial queues for read-heavy workloads

### Queue Architecture

```
Main Thread
    ↓
MixpanelInstance
    ├─ trackingQueue (serial, QoS: .utility)
    │   └─ Handles all event operations
    ├─ networkQueue (serial, QoS: .utility)
    │   └─ Manages network requests
    └─ flushQueue (serial, internal to Flush)
        └─ Coordinates batch processing
```

### Queue Responsibilities

#### trackingQueue
- Event creation and validation
- Property collection
- Persistence operations
- Queue management

```swift
trackingQueue.async { [weak self] in
    guard let self = self else { return }
    
    // 1. Validate event
    guard !eventName.isEmpty else { return }
    
    // 2. Collect properties
    var allProperties = self.automaticProperties()
    allProperties.merge(properties) { _, new in new }
    
    // 3. Create event
    let event = [
        "event": eventName,
        "properties": allProperties
    ]
    
    // 4. Add to queue (thread-safe)
    self.readWriteLock.write {
        self._eventsQueue.append(event)
    }
    
    // 5. Persist
    self.persistence.save(event)
}
```

#### networkQueue
- HTTP request creation
- Response handling
- Retry logic
- Error management

```swift
networkQueue.async { [weak self] in
    guard let self = self else { return }
    
    let request = self.buildRequest(events)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        self.networkQueue.async { [weak self] in
            self?.handleResponse(data, response, error)
        }
    }.resume()
}
```

## Thread Safety Patterns

### 1. Property Access Pattern
```swift
// Internal storage with underscore prefix
private var _distinctId: String = ""

// Public access through ReadWriteLock
public var distinctId: String {
    get { readWriteLock.read { _distinctId } }
    set { 
        readWriteLock.write { 
            _distinctId = newValue
            // Can trigger side effects safely here
            updateSuperProperties()
        }
    }
}
```

### 2. Collection Modification Pattern
```swift
// NEVER do this:
eventsQueue.append(event)  // RACE CONDITION!

// ALWAYS do this:
readWriteLock.write {
    _eventsQueue.append(event)
}

// For complex operations:
readWriteLock.write {
    _eventsQueue.removeAll { event in
        shouldRemove(event)
    }
    _eventsQueue.append(contentsOf: newEvents)
}
```

### 3. Async Operation Pattern
```swift
func performAsyncOperation(completion: @escaping () -> Void) {
    // Capture what you need
    let currentValue = readWriteLock.read { _someValue }
    
    // Perform async work
    trackingQueue.async { [weak self, currentValue] in
        guard let self = self else { 
            completion()
            return 
        }
        
        // Do work with captured value
        let result = process(currentValue)
        
        // Update state
        self.readWriteLock.write {
            self._someValue = result
        }
        
        // Call completion
        DispatchQueue.main.async {
            completion()
        }
    }
}
```

## Common Pitfalls

### 1. Nested Lock Acquisition
```swift
// ❌ DEADLOCK RISK
readWriteLock.read {
    let value = _property
    readWriteLock.write {  // DEADLOCK!
        _property = transform(value)
    }
}

// ✅ CORRECT
let value = readWriteLock.read { _property }
readWriteLock.write {
    _property = transform(value)
}
```

### 2. Synchronous Dispatch to Same Queue
```swift
// ❌ DEADLOCK
trackingQueue.sync {  // If already on trackingQueue
    performOperation()
}

// ✅ CORRECT - Check current queue
if DispatchQueue.current == trackingQueue {
    performOperation()
} else {
    trackingQueue.sync {
        performOperation()
    }
}
```

### 3. Missing Weak Self
```swift
// ❌ RETAIN CYCLE
trackingQueue.async {
    self.performOperation()  // Self captured strongly
}

// ✅ CORRECT
trackingQueue.async { [weak self] in
    guard let self = self else { return }
    self.performOperation()
}
```

## Testing Thread Safety

### 1. Use Thread Sanitizer
Enable in Xcode: Edit Scheme → Run → Diagnostics → ✓ Thread Sanitizer

### 2. Stress Test Pattern
```swift
func testConcurrentAccess() {
    let iterations = 1000
    let queues = [
        DispatchQueue(label: "test.1", attributes: .concurrent),
        DispatchQueue(label: "test.2", attributes: .concurrent),
        DispatchQueue(label: "test.3", attributes: .concurrent)
    ]
    
    let expectation = XCTestExpectation(description: "Concurrent")
    expectation.expectedFulfillmentCount = iterations * 3
    
    for i in 0..<iterations {
        queues[0].async {
            self.instance.track(event: "Read \(i)")
            expectation.fulfill()
        }
        
        queues[1].async {
            self.instance.people.set(property: "key\(i)", to: i)
            expectation.fulfill()
        }
        
        queues[2].async {
            _ = self.instance.distinctId
            expectation.fulfill()
        }
    }
    
    wait(for: [expectation], timeout: 30.0)
}
```

### 3. Deadlock Detection
```swift
// Add timeout to detect deadlocks
let semaphore = DispatchSemaphore(value: 0)
var operationCompleted = false

trackingQueue.async {
    performOperation()
    operationCompleted = true
    semaphore.signal()
}

let timeout = DispatchTime.now() + .seconds(5)
if semaphore.wait(timeout: timeout) == .timedOut {
    XCTFail("Operation deadlocked")
}
```

## Performance Considerations

### 1. Minimize Lock Hold Time
```swift
// ❌ BAD - Long operation inside lock
readWriteLock.write {
    let processed = expensiveOperation(_data)  // Blocks readers!
    _data = processed
}

// ✅ GOOD - Process outside lock
let currentData = readWriteLock.read { _data }
let processed = expensiveOperation(currentData)
readWriteLock.write {
    _data = processed
}
```

### 2. Batch Operations
```swift
// ❌ BAD - Multiple lock acquisitions
for event in events {
    readWriteLock.write {
        _eventsQueue.append(event)
    }
}

// ✅ GOOD - Single lock acquisition
readWriteLock.write {
    _eventsQueue.append(contentsOf: events)
}
```

### 3. Avoid Contention
```swift
// Use separate locks for independent data
private let eventsLock = ReadWriteLock(label: "events")
private let peopleLock = ReadWriteLock(label: "people")

// This allows concurrent access to different data types
```

## Queue Priority Guidelines

- **User-initiated**: Use `.userInitiated` for immediate user actions
- **Default**: Use `.default` for general work
- **Utility**: Use `.utility` for long-running tasks (current choice)
- **Background**: Use `.background` for maintenance tasks

Current SDK uses `.utility` because:
1. Analytics are important but not user-blocking
2. Allows system to optimize battery usage
3. Provides good balance of performance and efficiency