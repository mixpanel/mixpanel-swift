---
applyTo: "**/*Tests.swift,**/*Test.swift"
---
# Testing Instructions for Mixpanel Swift SDK

## Test Class Structure
- Extend MixpanelBaseTests for common utilities
- Use testToken constant from TestConstants.swift
- Override setUp() and call super.setUp()
- Clean up in tearDown()

## Queue Management in Tests
Always wait for queues to complete:
```swift
waitForTrackingQueue(instance)
flushAndWaitForTrackingQueue(instance)
```

## Test Data Generation
- Use randomId() for unique identifiers
- Use Date() for timestamps
- Create realistic test properties

## Common Test Patterns
```swift
// Test event tracking
instance.track(event: "Test Event", properties: ["key": "value"])
waitForTrackingQueue(instance)
XCTAssertEqual(instance.eventsQueue.count, 1)

// Test with completion handler
let expectation = XCTestExpectation(description: "flush complete")
instance.flush(completion: {
    expectation.fulfill()
})
wait(for: [expectation], timeout: 10.0)
```

## Platform-Specific Tests
- Use #if os(iOS) for iOS-specific tests
- Test automatic events only on iOS
- Verify platform-specific behavior

## Performance Tests
- Test with large data sets (1000+ events)
- Measure memory usage
- Verify SQLite performance

## Edge Cases to Test
- Empty strings and nil values
- Very long property names/values
- Concurrent access scenarios
- Network failures and retries
- App lifecycle transitions