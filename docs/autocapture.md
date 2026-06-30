# iOS Autocapture

Autocapture automatically tracks user interactions in your iOS app without requiring manual instrumentation.

## Overview

Autocapture captures three types of events:

| Event | Name | Description |
|-------|------|-------------|
| Click | `$mp_click` | Fired when a user taps any element |
| Rage Click | `$mp_rage_click` | Fired when a user taps rapidly (4+ times) in the same area |
| Dead Click | `$mp_dead_click` | Fired when a tap produces no visible UI response |

**Privacy:** Autocapture is designed with privacy in mind. No personally identifiable information (PII) is captured by default. Secure text fields are never captured, and sensitive content patterns (credit cards, SSNs) are automatically redacted.

## Quick Start

Autocapture is **disabled by default**. Enable it by providing `AutocaptureOptions` during SDK initialization:

```swift
import Mixpanel

let options = MixpanelOptions(
    token: "YOUR_TOKEN",
    autocaptureOptions: AutocaptureOptions()
)
let mixpanel = Mixpanel.initialize(options: options)
```

That's it! No additional setup required. Autocapture automatically intercepts all touch events via method swizzling.

## Configuration Options

### ClickOptions

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Track all click events |

### RageClickOptions

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Track rage click events |
| `clickThreshold` | `4` | Number of clicks required to trigger |
| `timeWindowMs` | `1000` | Time window in milliseconds |
| `radius` | `44` | Spatial threshold in points |

### DeadClickOptions

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Track dead click events |
| `timeoutMs` | `500` | Response wait time in milliseconds |
| `baselineDelayMs` | `150` | Delay before capturing baseline snapshot |

### AutocaptureOptions

| Option | Default | Description |
|--------|---------|-------------|
| `captureTextContent` | `false` | Capture text content of tapped elements as `$el_text`. Disabled by default to protect user privacy. |

### Custom Configuration Example

```swift
let autocaptureOpts = AutocaptureOptions(
    clickOptions: ClickOptions(enabled: true),
    rageClickOptions: RageClickOptions(
        enabled: true,
        clickThreshold: 5,        // Require 5 clicks instead of 4
        timeWindowMs: 800         // Shorter time window
    ),
    deadClickOptions: DeadClickOptions(
        enabled: false            // Disable dead click detection
    ),
    captureTextContent: true      // Enable $el_text capture
)

let options = MixpanelOptions(
    token: "YOUR_TOKEN",
    autocaptureOptions: autocaptureOpts
)
```

## Event Properties

All autocapture events include these properties:

| Property | Description |
|----------|-------------|
| `$x` | Touch X coordinate (screen points) |
| `$y` | Touch Y coordinate (screen points) |
| `$el_id` | Element identifier (see resolution rules below) |
| `$el_tag_name` | Class name of the view (e.g., `UIButton`) |
| `$el_text` | Visible text content (max 100 chars, **opt-in** — requires `captureTextContent: true`) |
| `$attr-aria-label` | Accessibility label |
| `$attr-role` | Element role (Button, Switch, etc.) |
| `$elements` | View hierarchy string (max 5 levels) |

### Rage Click Additional Properties

| Property | Description |
|----------|-------------|
| `$tap_count` | Number of taps in the rage click sequence |

## Element Identification (`$el_id`)

The `$el_id` property uses different resolution rules for UIKit and SwiftUI:

### UIKit Resolution Order

1. `accessibilityIdentifier` (if non-empty)
2. `accessibilityLabel` (if non-empty)
3. `ClassName_view_<hash>` (fallback)

```swift
// Recommended: Set accessibilityIdentifier for reliable tracking
button.accessibilityIdentifier = "checkout_button"

// Alternative: accessibilityLabel (also used for VoiceOver)
button.accessibilityLabel = "Checkout"
```

### SwiftUI Resolution Order

1. `accessibilityLabel` (primary - always available)
2. `accessibilityIdentifier` (only available when VoiceOver is active)
3. `ClassName_view_<hash>` (fallback)

```swift
// Recommended: Use accessibilityLabel (always works)
Button("Checkout") { /* ... */ }
    .accessibilityLabel("checkout_button")

// Note: accessibilityIdentifier only works when VoiceOver is active
Button("Checkout") { /* ... */ }
    .accessibilityIdentifier("checkout_button")  // May not be captured
```

**Why the difference?** SwiftUI's accessibility tree is lazily materialized only when VoiceOver or Accessibility Inspector is running. Without these tools, `accessibilityIdentifier` returns nil.

## Disabling for Specific Elements

Mark elements as sensitive to exclude them from **all** autocapture events:

### Using accessibilityIdentifier

```swift
// UIKit
sensitiveView.accessibilityIdentifier = "mp-sensitive"

// SwiftUI
SecretView()
    .accessibilityIdentifier("mp-sensitive")
```

### Using accessibilityLabel

```swift
// UIKit
sensitiveView.accessibilityLabel = "mp-no-track"

// SwiftUI
SecretView()
    .accessibilityLabel("mp-no-track")
```

Both `mp-sensitive` and `mp-no-track` are supported. The check uses `contains()`, so identifiers like `payment-form-mp-sensitive` also work.

**Note:** When a view is marked as sensitive, it is completely excluded - no `$mp_click`, `$mp_rage_click`, or `$mp_dead_click` events are emitted. Child views inherit this exclusion.

## Dead Click Detection

Dead click detection monitors interactive elements for UI response:

### How It Works

1. User taps an element with interaction handlers
2. Wait 150ms for animations to settle (baseline delay)
3. Capture a snapshot of the UI state
4. Wait until 500ms total (timeout)
5. If UI hasn't changed, emit `$mp_dead_click`

### Excluded Controls

These controls are excluded from dead click detection because they have inherent feedback not detected by UI snapshots:

- `UISwitch` - Toggles own state
- `UITextField` - Keyboard appears
- `UITextView` - Keyboard appears
- `UIStepper` - Increments value
- `UISegmentedControl` - Changes selection
- `UIDatePicker` - Shows picker
- `UIPickerView` - Shows picker

These controls still emit `$mp_click` events.

### What Counts as UI Change

- View count change (new views added/removed)
- Content change (text, button titles, etc.)
- Window count change (alerts, sheets, modals)

**Note:** Keyboard appearance does not count as a UI change for the tapped element.

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| iOS | Full | Primary target |
| iPadOS | Full | Same as iOS |
| macOS (Catalyst) | Limited | May need testing |
| tvOS | Not supported | Different interaction model |
| watchOS | Not supported | Different SDK |
| visionOS | Not supported | Different interaction model |

## Requirements

- iOS 12.0+
- Swift 5.3+
- SwiftUI autocapture requires iOS 13+

## Troubleshooting

### Enable Debug Logging

```swift
Mixpanel.mainInstance().loggingEnabled = true
```

This will log autocapture events to the console:
```
AutocaptureManager: emitted $mp_click for checkout_button
AutocaptureManager: emitted $mp_rage_click for submit_btn (count: 4)
AutocaptureManager: emitted $mp_dead_click for broken_link
```

### Verify Events in Dashboard

1. Enable logging as shown above
2. Trigger interactions in your app
3. Check the Mixpanel Live View for events
4. Events appear with names `$mp_click`, `$mp_rage_click`, `$mp_dead_click`

### Common Issues

**Events not appearing:**
- Verify `autocaptureOptions` is passed to `MixpanelOptions`
- Check that the view is not marked as sensitive
- Ensure the app is not in an app extension (autocapture is disabled in extensions)

**SwiftUI elements showing hash IDs:**
- Set `accessibilityLabel` on interactive elements
- `accessibilityIdentifier` only works when VoiceOver is active

**False positive dead clicks:**
- Element may have a handler that doesn't produce visible UI change
- Consider excluding specific elements with `mp-no-track`

## Privacy Considerations

### What is Captured

- Touch coordinates
- View class names and hierarchy
- Accessibility labels and identifiers
- Visible text content — **only when `captureTextContent: true` is set** (redacted for sensitive patterns)

### What is NOT Captured

- Secure text field content (`isSecureTextEntry = true`)
- Password fields (`textContentType` of `.password`, `.newPassword`, `.oneTimeCode`)
- Credit card numbers (regex redacted)
- Social Security Numbers (regex redacted)
- Content from elements marked `mp-sensitive` or `mp-no-track`

### AppTrackingTransparency

Autocapture does **not** require ATT permission. It is first-party analytics with:
- No cross-app tracking
- No IDFA usage
- No new permission prompts

## Technical Details

### Touch Interception

Autocapture uses method swizzling on `UIApplication.sendEvent(_:)` to intercept all touch events. This approach:

- Requires zero customer setup
- Captures all windows (main, alerts, sheets, modals)
- Works with SwiftUI via `UIHostingController`
- Works with Expo after `expo prebuild`

### Thread Safety

All autocapture components use thread-safe patterns:
- NSLock for mutable state
- Main thread for UI operations
- Weak references to prevent retain cycles

### Performance

Target performance budgets:
- Touch event processing: < 5ms
- Semantic extraction: < 10ms
- Dead click snapshot: < 15ms

## Migration from Manual Tracking

If you're currently using manual `track()` calls for clicks, you can gradually migrate:

1. Enable autocapture alongside existing tracking
2. Compare event counts in dashboard
3. Set meaningful `accessibilityIdentifier` values for important elements
4. Remove redundant manual `track()` calls
