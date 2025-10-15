# /fix-thread-safety

Fix thread safety issues in selected code by adding proper synchronization.

## Usage
```
/fix-thread-safety
```

## Analysis Checklist

1. **Identify Shared State**
   - Instance variables accessed from multiple threads
   - Collections that are modified
   - Properties without synchronization

2. **Common Issues to Fix**
   - Direct property access without locks
   - Race conditions in read-modify-write operations
   - Missing `[weak self]` in async closures
   - Incorrect queue usage

## Fix Patterns

### Basic Property Protection
```swift
// BEFORE (Unsafe)
class Component {
    var sharedData: [String: Any] = [:]
    
    func updateData(key: String, value: Any) {
        sharedData[key] = value  // RACE CONDITION!
    }
}

// AFTER (Thread-safe)
class Component {
    private let readWriteLock = ReadWriteLock(label: "com.mixpanel.component")
    private var _sharedData: [String: Any] = [:]
    
    var sharedData: [String: Any] {
        return readWriteLock.read { _sharedData }
    }
    
    func updateData(key: String, value: Any) {
        readWriteLock.write {
            _sharedData[key] = value
        }
    }
}
```

### Collection Operations
```swift
// BEFORE
func addItem(_ item: String) {
    items.append(item)  // UNSAFE!
}

// AFTER  
func addItem(_ item: String) {
    readWriteLock.write {
        _items.append(item)
    }
}
```

### Async Operations
```swift
// BEFORE
trackingQueue.async {
    self.processEvent()  // RETAIN CYCLE!
}

// AFTER
trackingQueue.async { [weak self] in
    guard let self = self else { return }
    self.processEvent()
}
```

### Read-Modify-Write
```swift
// BEFORE
var counter: Int {
    get { _counter }
    set { _counter = newValue }
}

func increment() {
    counter += 1  // NOT ATOMIC!
}

// AFTER
func increment() {
    readWriteLock.write {
        _counter += 1
    }
}
```

## Queue Usage Rules
- `trackingQueue`: All event tracking operations
- `networkQueue`: All network requests
- `flushQueue`: Batch processing operations
- Main queue: UI updates only

## Testing Thread Safety
```swift
func testConcurrentAccess() {
    let iterations = 1000
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = iterations * 2
    
    DispatchQueue.concurrentPerform(iterations: iterations) { i in
        // Write operation
        component.updateData(key: "key\(i)", value: i)
        expectation.fulfill()
        
        // Read operation
        _ = component.sharedData
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10.0)
    XCTAssertEqual(component.sharedData.count, iterations)
}
```

## Common Mistakes to Avoid
- ❌ Calling `write` from within `read` block (deadlock)
- ❌ Forgetting `[weak self]` in closures
- ❌ Using wrong queue for operation type
- ❌ Synchronous dispatch from same queue
- ❌ Multiple locks in different order