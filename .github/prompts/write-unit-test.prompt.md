---
mode: agent
tools: [codebase]
description: Write comprehensive unit tests for Mixpanel functionality
---
# Write Unit Tests for ${input:component:Component or feature to test}

## Test Requirements

1. **Setup test class**:
   - Extend `MixpanelBaseTests`
   - Use `testToken` from TestConstants
   - Set up fresh instance in `setUp()`
   - Clean up in `tearDown()`

2. **Test categories to cover**:
   - Happy path functionality
   - Edge cases and error conditions
   - Thread safety (concurrent access)
   - Platform-specific behavior
   - Memory management

3. **Use test utilities**:
   - `waitForTrackingQueue()` - ensure async operations complete
   - `flushAndWaitForTrackingQueue()` - flush and wait
   - `randomId()` - generate test identifiers
   - Direct queue access for verification

4. **Test patterns from** [testing instructions](../.github/instructions/testing.instructions.md)

5. **Assertions to include**:
   - Verify queue counts
   - Check property values
   - Validate persistence
   - Confirm network calls (using mocks if needed)

## Example test structure:
```swift
func testFeatureName() {
    // Arrange
    let instance = MixpanelInstance(apiToken: testToken)
    let testData = createTestData()
    
    // Act
    instance.performAction(testData)
    waitForTrackingQueue(instance)
    
    // Assert
    XCTAssertEqual(instance.eventsQueue.count, 1)
    // More assertions
}
```

## Platform-specific tests:
- Use `#if os(iOS)` for iOS-only features
- Skip tests on unsupported platforms
- Test automatic events only on iOS