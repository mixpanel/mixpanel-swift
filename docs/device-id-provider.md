# Custom Device ID Provider

The `deviceIdProvider` closure in `MixpanelOptions` gives you complete control over device ID generation in the Mixpanel Swift SDK.

## Overview

By default, Mixpanel generates a device ID using:
- **IDFV** (Identifier for Vendor) when `useUniqueDistinctId: true`
- **Random UUID** otherwise

The `deviceIdProvider` closure allows you to supply your own device ID, enabling:
- Persistent device IDs stored in Keychain (survive app reinstalls)
- Server-generated device IDs
- Cross-platform device ID consistency
- Custom device ID formats

## Basic Usage

```swift
let options = MixpanelOptions(
    token: "YOUR_TOKEN",
    deviceIdProvider: {
        return MyDeviceIdManager.getDeviceId()
    }
)

let mixpanel = Mixpanel.initialize(options: options)
```

## When the Provider is Called

The `deviceIdProvider` closure is invoked:

| Scenario | Provider Called? |
|----------|-----------------|
| First SDK initialization (no persisted identity) | ✅ Yes |
| Subsequent initialization (identity persisted) | ⚠️ For comparison only* |
| After `reset()` | ✅ Yes |
| After `optOutTracking()` | ✅ Yes |

*When persisted identity exists, the provider is called to check if it returns a different value (triggers a warning log), but the persisted value is used.

## Controlling Reset Behavior

The closure's return value determines how device ID behaves across resets:

### Persistent Device ID (Never Resets)

Return the **same value** each time the closure is called:

```swift
// Store device ID in Keychain for persistence across reinstalls
class DeviceIdManager {
    static let shared = DeviceIdManager()

    private let keychainKey = "com.yourapp.mixpanel.deviceId"

    func getOrCreateDeviceId() -> String {
        if let existing = KeychainHelper.get(keychainKey) {
            return existing
        }
        let newId = UUID().uuidString
        KeychainHelper.set(keychainKey, value: newId)
        return newId
    }
}

// Usage
let options = MixpanelOptions(
    token: "YOUR_TOKEN",
    deviceIdProvider: {
        return DeviceIdManager.shared.getOrCreateDeviceId()
    }
)
```

With this pattern:
- Device ID survives `reset()` and `optOutTracking()` calls
- Device ID survives app reinstalls (if using Keychain)
- User identity continuity is maintained

### Ephemeral Device ID (Resets Each Time)

Return a **different value** each time:

```swift
let options = MixpanelOptions(
    token: "YOUR_TOKEN",
    deviceIdProvider: {
        return UUID().uuidString  // New ID each time
    }
)
```

With this pattern:
- Calling `reset()` generates a new device ID
- Calling `optOutTracking()` generates a new device ID
- Each session after reset appears as a new anonymous user

## Important: Choose Your Strategy Up Front

> **Warning**: The device ID strategy is an architectural decision that should be made at project inception, not retrofitted later.

### Do NOT:

- Add `deviceIdProvider` to an existing app that was using default device IDs
- Change your `deviceIdProvider` implementation after going to production
- Remove `deviceIdProvider` after previously using it

### Why?

Changing device ID strategy mid-stream causes **identity discontinuity**:

```
Before: User tracked as device-abc → identified as user@email.com
After:  User tracked as device-xyz (new device ID from provider)
        → Events appear as a NEW anonymous user
        → Historical data is orphaned
```

The SDK logs a warning when it detects this scenario:

```
deviceIdProvider returned 'new-id' but existing anonymousId is 'old-id'.
Using persisted value to preserve identity continuity.
```

## Integration with Mixpanel Identity Management

The `deviceIdProvider` works with Mixpanel's [Simplified ID Merge](https://docs.mixpanel.com/docs/tracking-methods/id-management/identifying-users-simplified) system:

1. Your custom device ID becomes the `$device_id` property on all events
2. When you call `identify(userId)`, the `$user_id` is set
3. Mixpanel automatically merges the `$device_id` cluster with the `$user_id`
4. All pre-identification events are retroactively attributed to the user

```swift
// Anonymous tracking with custom device ID
mixpanel.track(event: "App Launched")
// Event has: $device_id = "your-custom-id"

// User logs in
mixpanel.identify(distinctId: "user@email.com")
// Merge happens: your-custom-id → user@email.com

// All future events attributed to user@email.com
mixpanel.track(event: "Purchase Completed")
```

## Edge Cases

### Empty String Handling

If your provider returns an empty string, the SDK falls back to default behavior and logs a warning:

```swift
deviceIdProvider: { "" }  // Falls back to UUID/IDFV
```

### Multiple Instances

Each Mixpanel instance can have its own provider:

```swift
let analyticsOptions = MixpanelOptions(
    token: "ANALYTICS_TOKEN",
    deviceIdProvider: { AnalyticsDeviceId.get() }
)

let marketingOptions = MixpanelOptions(
    token: "MARKETING_TOKEN",
    deviceIdProvider: { MarketingDeviceId.get() }
)
```

## Best Practices

1. **Use Keychain** for persistent device IDs that survive reinstalls
2. **Generate UUIDs** - they're format-compatible with Mixpanel's expectations
3. **Set provider on first app version** - don't add it later
4. **Test thoroughly** - verify identity flows work as expected before shipping
5. **Monitor the warning log** - it indicates potential identity issues

## See Also

- [Mixpanel Identity Management Overview](https://docs.mixpanel.com/docs/tracking-methods/id-management)
- [Simplified ID Merge](https://docs.mixpanel.com/docs/tracking-methods/id-management/identifying-users-simplified)
- [MixpanelOptions API Reference](../Sources/MixpanelOptions.swift)
