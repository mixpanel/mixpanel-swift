# Custom Device ID Provider

The `deviceIdProvider` closure in `MixpanelOptions` gives you complete control over device ID generation in the Mixpanel Swift SDK.

## Overview

By default, Mixpanel generates a device ID using:
- **IDFV** (Identifier for Vendor) when `useUniqueDistinctId: true`
- **Random UUID** otherwise

The `deviceIdProvider` closure allows you to supply your own device ID, enabling:
- Persistent device IDs that survive app reinstalls (via Keychain, cached at launch)
- Pre-fetched server-generated device IDs
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

| Scenario | Provider Called? | Value Used? |
|----------|------------------|-------------|
| First SDK initialization (no persisted identity) | ✅ Yes | ✅ Provider value |
| Subsequent initialization (identity persisted) | ✅ For comparison | ❌ Persisted value* |
| After `reset()` | ✅ Yes | ✅ Provider value |
| After `optOutTracking()` | ✅ Yes | ✅ Provider value |

*When persisted identity exists, the provider is called to compare with the existing value. If different, an error is logged but the persisted value is used to preserve identity continuity.

> **Thread Safety:** This closure is called synchronously while holding internal locks. Keep implementations fast and non-blocking. **Do not** perform Keychain access, network calls, or other blocking operations directly inside the closure. Instead, retrieve and cache your device ID at app launch, then return the cached value from the provider.

## Controlling Reset Behavior

The closure's return value determines how device ID behaves across resets:

### Persistent Device ID (Never Resets)

Return the **same value** each time the closure is called. **Important:** Cache the value at app launch to avoid blocking operations inside the provider.

```swift
// DeviceIdManager: cache the ID at app launch, return cached value in provider
// Note: KeychainHelper is a pseudocode wrapper. See Apple's Keychain Services documentation
// for implementation details: https://developer.apple.com/documentation/security/keychain_services
class DeviceIdManager {
    static let shared = DeviceIdManager()

    // Cache populated at app launch (in AppDelegate, before Mixpanel init)
    private(set) var cachedDeviceId: String?

    private let keychainKey = "com.yourapp.mixpanel.deviceId"

    /// Call this ONCE at app launch, before initializing Mixpanel
    func loadDeviceId() {
        if let existing = KeychainHelper.get(keychainKey) {
            cachedDeviceId = existing
            return
        }
        let newId = UUID().uuidString
        KeychainHelper.set(keychainKey, value: newId)
        cachedDeviceId = newId
    }
}

// In AppDelegate.didFinishLaunchingWithOptions:
DeviceIdManager.shared.loadDeviceId()  // Cache before Mixpanel init

let options = MixpanelOptions(
    token: "YOUR_TOKEN",
    deviceIdProvider: {
        return DeviceIdManager.shared.cachedDeviceId  // Fast: returns cached value
    }
)
```

With this pattern:
- Device ID survives `reset()` and `optOutTracking()` calls
- Device ID survives app reinstalls (if using Keychain)
- User identity continuity is maintained
- No blocking operations inside the provider closure

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

The `deviceIdProvider` is designed for Mixpanel's [Simplified ID Merge](https://docs.mixpanel.com/docs/tracking-methods/id-management/identifying-users-simplified) system (the default for new projects):

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

> **Note:** If using [Original ID Merge](https://docs.mixpanel.com/docs/tracking-methods/id-management/identifying-users-original), persistent device IDs require careful handling on shared devices. With Original ID Merge, calling `createAlias()` with the same device ID for different users will incorrectly merge their identities. Consider using an ephemeral provider strategy or migrating to Simplified ID Merge.

## Edge Cases

### Returning nil or Empty String

If your provider returns `nil` or an empty string, the SDK falls back to default behavior and logs a warning:

```swift
// Return nil to signal "use default" - useful for error handling
deviceIdProvider: {
    guard let id = fetchDeviceIdFromServer() else {
        return nil  // Fall back to SDK default
    }
    return id
}

// Empty string also falls back to default
deviceIdProvider: { "" }  // Falls back to UUID/IDFV
```

This allows graceful error handling when your device ID source is unavailable.

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

1. **Cache at launch** - retrieve Keychain/server IDs before Mixpanel init, return cached values
2. **Keep the closure fast** - no blocking I/O, network, or Keychain access inside the provider
3. **Use Keychain** for persistent device IDs that survive reinstalls (cached at launch)
4. **Generate UUIDs** - they're format-compatible with Mixpanel's expectations
5. **Set provider on first app version** - don't add it later
6. **Test thoroughly** - verify identity flows work as expected before shipping
7. **Monitor the warning log** - it indicates potential identity issues

## See Also

- [Mixpanel Identity Management Overview](https://docs.mixpanel.com/docs/tracking-methods/id-management)
- [Simplified ID Merge](https://docs.mixpanel.com/docs/tracking-methods/id-management/identifying-users-simplified)
- [MixpanelOptions API Reference](../Sources/MixpanelOptions.swift)
