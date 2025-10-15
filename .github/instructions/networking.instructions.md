---
applyTo: "**/Network.swift,**/Flush*.swift"
---
# Networking Instructions

## API Endpoints
- Track: https://api.mixpanel.com/track
- Engage: https://api.mixpanel.com/engage
- Groups: https://api.mixpanel.com/groups
- Decide: https://api.mixpanel.com/decide

## Request Format
- Use POST with form-encoded data
- Include "data" parameter with base64-encoded JSON
- Support gzip compression when enabled
- Set proper Content-Type headers

## Batching
- Maximum 50 events per batch
- Calculate batch size limits
- Split large batches automatically
- Maintain order of events

## Network Queue Usage
```swift
networkQueue.async { [weak self] in
    self?.sendRequest(request) { success in
        // Handle response
    }
}
```

## Error Handling
- Retry on network failures (500, 502, 503, 504)
- Don't retry on client errors (400)
- Implement exponential backoff
- Log all network errors

## Flush Behavior
- Automatic flush on timer (default 60s)
- Flush on app background
- Manual flush via flush() method
- Respect flushOnBackground setting

## Request Headers
- Content-Type: application/x-www-form-urlencoded
- Content-Encoding: gzip (when applicable)
- Accept: application/json

## Response Handling
- Parse JSON responses
- Check "status" field (1 = success)
- Handle "error" field gracefully
- Update flush metrics