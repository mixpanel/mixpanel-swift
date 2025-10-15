# /debug-issue

Debug and diagnose issues in the Mixpanel SDK.

## Usage
```
/debug-issue Events not being tracked
/debug-issue App crashes when tracking
/debug-issue Memory leak in People operations
```

## Debugging Steps

### 1. Enable Verbose Logging
```swift
// In AppDelegate or initialization
Mixpanel.mainInstance().logger = MixpanelLogger(level: .debug)

// Custom logger for more control
class CustomLogger: MixpanelLogging {
    func log(_ message: MixpanelLogMessage) {
        print("[\(message.level)] \(message.text)")
        // Can also write to file, send to crash reporter, etc.
    }
}
Mixpanel.mainInstance().logger = CustomLogger()
```

### 2. Common Issues & Solutions

#### Events Not Tracking
```swift
// Check 1: Verify token
print("Token: \(instance.apiToken)")

// Check 2: Inspect queue
print("Events in queue: \(instance.eventsQueue.count)")
instance.eventsQueue.forEach { event in
    print("Event: \(event)")
}

// Check 3: Force synchronous check
instance.trackingQueue.sync {
    print("Internal queue count: \(instance._eventsQueue.count)")
}

// Check 4: Verify persistence
let saved = instance.persistence.loadEntitiesInBatch(type: .events)
print("Persisted events: \(saved.count)")

// Check 5: Test network
instance.flush { 
    print("Flush completed")
}
```

#### Thread Safety Issues
```swift
// Enable Thread Sanitizer in Xcode:
// Edit Scheme → Run → Diagnostics → ✓ Thread Sanitizer

// Add debug logging to ReadWriteLock operations
extension ReadWriteLock {
    func debugRead<T>(_ block: () -> T) -> T {
        print("🔵 Read lock acquired: \(label)")
        defer { print("🔵 Read lock released: \(label)") }
        return read(block)
    }
}
```

#### Memory Leaks
```swift
// Check for retain cycles
// 1. Use Instruments → Leaks
// 2. Add weak self checks:

// Look for missing [weak self]:
trackingQueue.async { 
    self.doSomething() // RETAIN CYCLE!
}

// Should be:
trackingQueue.async { [weak self] in
    self?.doSomething()
}

// Debug deallocations:
deinit {
    print("✅ \(type(of: self)) deallocated")
}
```

### 3. Database Debugging

```bash
# Find SQLite database
find ~/Library/Developer/CoreSimulator -name "mixpanel-*.sqlite" -ls

# Inspect database
sqlite3 /path/to/mixpanel-TOKEN.sqlite

# Useful queries
.tables
SELECT COUNT(*) FROM events;
SELECT * FROM events LIMIT 5;
SELECT * FROM events WHERE json_extract(data, '$.event') = 'Your Event';
.schema events
```

### 4. Network Debugging

```swift
// Use proxy to inspect requests
// 1. Set up Charles Proxy or similar
// 2. Configure in SDK:

let serverURL = "https://your-proxy.com/mixpanel"
instance.setServerURL(serverURL: serverURL)

// Log all network requests:
class DebugNetwork: Network {
    override func sendRequest(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        print("📡 Request: \(request.url?.absoluteString ?? "")")
        if let body = request.httpBody {
            print("📡 Body: \(String(data: body, encoding: .utf8) ?? "")")
        }
        
        super.sendRequest(request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response: \(httpResponse.statusCode)")
            }
            if let error = error {
                print("📡 Error: \(error)")
            }
            completion(data, response, error)
        }
    }
}
```

### 5. Performance Profiling

```swift
// Measure operation time
let start = CFAbsoluteTimeGetCurrent()
// Operation
let elapsed = CFAbsoluteTimeGetCurrent() - start
print("Operation took \(elapsed)s")

// Profile with Instruments:
// 1. Time Profiler - Find slow methods
// 2. Allocations - Track memory usage
// 3. System Trace - Queue behavior
```

### 6. Debugging Checklist

#### For "Events Not Appearing":
- [ ] Check API token is correct
- [ ] Verify network connectivity
- [ ] Check flush is being called
- [ ] Inspect server response for errors
- [ ] Verify property types are valid
- [ ] Check for opt-out status

#### For Crashes:
- [ ] Check crash logs for stack trace
- [ ] Look for force unwraps (!)
- [ ] Verify thread safety
- [ ] Check for nil delegate/closure calls
- [ ] Test with Guard Malloc

#### For Performance Issues:
- [ ] Profile with Instruments
- [ ] Check batch sizes
- [ ] Monitor queue lengths
- [ ] Verify SQLite query performance
- [ ] Check for main thread blocking

### 7. Test in Isolation

```swift
// Minimal reproduction case
let instance = MixpanelInstance(apiToken: "YOUR_TOKEN")
instance.logger = MixpanelLogger(level: .debug)
instance.track(event: "Test")
instance.flush {
    print("Done")
}
```

## Quick Debug Properties

```swift
// Add to track calls for debugging
let debugProps: Properties = [
    "debug_timestamp": Date().timeIntervalSince1970,
    "debug_thread": Thread.current.isMainThread ? "main" : "background",
    "debug_queue_size": instance.eventsQueue.count
]
```