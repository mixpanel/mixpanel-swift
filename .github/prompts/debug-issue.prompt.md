---
mode: agent
tools: [codebase, terminalLastCommand]
description: Debug and fix issues in Mixpanel SDK
---
# Debug Mixpanel SDK Issue

Debug issue: ${input:issueDescription:Describe the issue you're experiencing}

## Debugging Steps

1. **Enable verbose logging**:
   ```swift
   Mixpanel.mainInstance().logger = MixpanelLogger(level: .debug)
   ```

2. **Check common issues**:
   - **Events not tracking**: Verify token, check queue, ensure flush
   - **Crashes**: Look for thread safety issues, nil unwrapping
   - **Memory leaks**: Check retain cycles, use Instruments
   - **Network failures**: Verify endpoints, check proxies

3. **Debugging tools**:
   - Set breakpoints in key methods
   - Use `MPAssert` for validation
   - Check SQLite database directly
   - Monitor network traffic with proxy

4. **Queue inspection**:
   ```swift
   // Check event queue
   print("Events in queue: \(instance.eventsQueue.count)")
   
   // Force synchronous operation for debugging
   instance.trackingQueue.sync {
       // Inspect state
   }
   ```

5. **Common problem areas**:
   - **Thread safety**: Race conditions, deadlocks
   - **Type system**: Invalid property types
   - **Persistence**: SQLite errors, migration issues
   - **Network**: SSL errors, timeouts
   - **Memory**: Retain cycles, large payloads

6. **Platform-specific debugging**:
   - iOS: Check for app extension limitations
   - macOS: Verify sandboxing permissions
   - Background modes and state restoration

## Debug patterns:
- Add logging throughout code path
- Use guard statements to identify failure points
- Test with minimal reproduction case
- Check test files for similar issues

## Related files to check:
- MixpanelLogger.swift for logging
- Error.swift for error definitions
- Test files for expected behavior