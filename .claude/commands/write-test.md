# /write-test

Write comprehensive unit tests for Mixpanel SDK components.

## Usage
```
/write-test People.set
/write-test trackingQueue synchronization
```

## Test Structure Template

```swift
import XCTest
@testable import Mixpanel

class ComponentNameTests: MixpanelBaseTests {
    
    var instance: MixpanelInstance!
    
    override func setUp() {
        super.setUp()
        instance = MixpanelInstance(
            apiToken: testToken,
            flushInterval: 0,  // Disable auto-flush
            trackAutomaticEvents: false
        )
    }
    
    override func tearDown() {
        instance.reset()
        super.tearDown()
    }
    
    // Test methods here
}
```

## Test Categories

### 1. Basic Functionality Test
```swift
func testBasicOperation() {
    // Arrange
    let testData = "test value"
    
    // Act
    instance.performOperation(testData)
    waitForTrackingQueue(instance)
    
    // Assert
    XCTAssertEqual(instance.someProperty, expectedValue)
}
```

### 2. Edge Cases Test
```swift
func testEdgeCases() {
    // Empty input
    instance.track(event: "")
    waitForTrackingQueue(instance)
    XCTAssertEqual(instance.eventsQueue.count, 0, "Empty events should be rejected")
    
    // Nil values
    let props: Properties = ["key": NSNull()]
    instance.track(event: "Test", properties: props)
    waitForTrackingQueue(instance)
    XCTAssertNotNil(instance.eventsQueue.first?["properties"]?["key"])
    
    // Very long strings
    let longString = String(repeating: "a", count: 10000)
    instance.track(event: longString)
    waitForTrackingQueue(instance)
    // Verify truncation or handling
}
```

### 3. Thread Safety Test
```swift
func testConcurrentAccess() {
    let iterations = 100
    let expectation = XCTestExpectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = iterations
    
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
        instance.track(event: "Event \(index)")
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
    waitForTrackingQueue(instance)
    
    XCTAssertEqual(instance.eventsQueue.count, iterations)
}
```

### 4. Persistence Test
```swift
func testPersistence() {
    // Track events
    instance.track(event: "Test Event", properties: ["key": "value"])
    waitForTrackingQueue(instance)
    
    // Verify persisted
    let saved = instance.persistence.loadEntitiesInBatch(type: .events)
    XCTAssertEqual(saved.count, 1)
    
    // Create new instance (simulating app restart)
    let newInstance = MixpanelInstance(apiToken: testToken)
    waitForTrackingQueue(newInstance)
    
    // Verify events restored
    XCTAssertEqual(newInstance.eventsQueue.count, 1)
}
```

### 5. Network/Flush Test
```swift
func testFlush() {
    // Track multiple events
    for i in 0..<5 {
        instance.track(event: "Event \(i)")
    }
    
    let expectation = XCTestExpectation(description: "Flush complete")
    
    instance.flush { 
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 10.0)
    
    // Verify queue cleared
    XCTAssertEqual(instance.eventsQueue.count, 0)
}
```

### 6. Platform-Specific Test
```swift
#if os(iOS)
func testIOSSpecificFeature() {
    // Test automatic events
    XCTAssertTrue(instance.trackAutomaticEvents)
    // iOS-specific assertions
}
#else
func testNonIOSBehavior() {
    // Test that automatic events are disabled
    XCTAssertFalse(instance.trackAutomaticEvents)
}
#endif
```

## Test Utilities

### Wait for Async Operations
```swift
waitForTrackingQueue(instance)
flushAndWaitForTrackingQueue(instance)
```

### Generate Test Data
```swift
let testId = randomId()
let testProps: Properties = [
    "test_id": testId,
    "timestamp": Date(),
    "count": 42,
    "active": true
]
```

### Custom Assertions
```swift
func assertEventTracked(name: String, properties: Properties? = nil) {
    let event = instance.eventsQueue.first { $0["event"] as? String == name }
    XCTAssertNotNil(event, "Event '\(name)' not found")
    
    if let properties = properties {
        for (key, value) in properties {
            XCTAssertEqual(
                event?["properties"]?[key] as? MixpanelType, 
                value,
                "Property '\(key)' mismatch"
            )
        }
    }
}
```

## Performance Test Template
```swift
func testPerformance() {
    measure {
        for i in 0..<1000 {
            instance.track(event: "Performance Test \(i)")
        }
        flushAndWaitForTrackingQueue(instance)
    }
}
```

## Test Checklist
- [ ] Happy path scenarios
- [ ] Edge cases (nil, empty, very large)
- [ ] Error conditions
- [ ] Thread safety
- [ ] Memory leaks (use Instruments)
- [ ] Platform-specific behavior
- [ ] Performance benchmarks