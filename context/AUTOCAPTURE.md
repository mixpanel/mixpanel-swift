# iOS Autocapture

Autocapture automatically tracks user interactions in your iOS app without requiring manual instrumentation.

## Overview

Autocapture captures three types of events:

| Event | Name | Description |
|-------|------|-------------|
| Click | `$mp_click` | Fired when a user taps any element |
| Rage Click | `$mp_rage_click` | Fired when a user taps rapidly (4+ times) in the same area |
| Dead Click | `$mp_dead_click` | Fired when a tap produces no visible UI response |

**Privacy:** Autocapture is designed with privacy in mind. No personally identifiable information (PII) is captured by default.

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

That's it! No additional setup required. Autocapture automatically intercepts all touch events via a non-claiming gesture recognizer.

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
| `timeWindowMs` | `500` | Response wait time in milliseconds |

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
    )
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
| `$attr-aria-label` | Accessibility label |
| `$attr-role` | Element role (Button, Switch, etc.) |
| `$elements` | View hierarchy string (max 5 levels) |

## Element Identification (`$el_id`)

The `$el_id` property uses different resolution rules for UIKit and SwiftUI:

### UIKit Resolution Order

1. `accessibilityIdentifier` (if non-empty)
2. `accessibilityLabel` (if non-empty)
3. `ClassName_<hash>` (fallback)

```swift
// Recommended: Set accessibilityIdentifier for reliable tracking
button.accessibilityIdentifier = "checkout_button"

// Alternative: accessibilityLabel (also used for VoiceOver)
button.accessibilityLabel = "Checkout"
```

### SwiftUI Resolution Order

1. `accessibilityLabel` (primary - always available)
2. `accessibilityIdentifier` (only available when VoiceOver is active)
3. `ClassName_<hash>` (fallback)

```swift
// Recommended: Use accessibilityLabel (always works)
Button("Checkout") { /* ... */ }
    .accessibilityLabel("checkout_button")

// Note: accessibilityIdentifier only works when VoiceOver is active
Button("Checkout") { /* ... */ }
    .accessibilityIdentifier("checkout_button")  // May not be captured
```

**Why the difference?** SwiftUI's accessibility tree is lazily materialized only when VoiceOver or Accessibility Inspector is running. Without these tools, `accessibilityIdentifier` returns nil.

## Dead Click Detection

Dead click detection monitors interactive elements for UI response:

### How It Works

1. User taps an element with interaction handlers
2. Capture a snapshot of the UI state immediately (synchronous baseline)
3. Wait 500ms (time window)
4. Capture a final snapshot and compare with baseline
5. If UI hasn't changed, emit `$mp_dead_click`

### Excluded Controls

These controls are excluded from dead click detection because they always produce a visual response when tapped (inherent feedback). They still emit `$mp_click` events.

**UIKit:**
- `UITextField` / `UITextView` - Keyboard appears
- `UISwitch` - Toggles own state
- `UISlider` - Thumb moves
- `UIStepper` - Value changes
- `UISegmentedControl` - Selection changes
- `UIDatePicker` / `UIPickerView` - Picker UI appears

**SwiftUI:**
- `TextField` / `TextEditor` / `SecureField` - Keyboard appears
- `Toggle` - Toggles own state
- `Slider` / `Stepper` - Value changes
- `Picker` / `DatePicker` - Picker UI appears

### What Counts as UI Change

- View count change (new views added/removed)
- Content change (text, button titles, etc.)
- Window count change (alerts, sheets, modals)

**Note:** Text input controls (`UITextField`, `UITextView`, `TextField`, etc.) are fully excluded from dead click monitoring, so the keyboard appearing after a tap does not produce a false `$mp_dead_click`.

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
- Ensure the app is not in an app extension (autocapture is disabled in extensions)

**SwiftUI elements showing hash IDs:**
- Set `accessibilityLabel` on interactive elements
- `accessibilityIdentifier` only works when VoiceOver is active

**False positive dead clicks:**
- Element may have a handler that doesn't produce visible UI change

## Privacy Considerations

### What is Captured

- Touch coordinates
- View class names and hierarchy
- Accessibility labels and identifiers

### What is NOT Captured

- Visible text content (see note below)

Autocapture does not capture visible text content (`$el_text`) from tapped elements. Tracking text can be invasive and raise privacy concerns. Additionally, the complexity of nested view hierarchies can cause text extraction to capture content from unintended views — for example, tapping a container view might extract text from a deeply nested label that isn't semantically related to the tap. The remaining captured properties (`$el_id`, `$el_tag_name`, `$attr-aria-label`, `$attr-role`, `$elements`) are purely structural UI metadata.

### AppTrackingTransparency

Autocapture does **not** require ATT permission. It is first-party analytics with:
- No cross-app tracking
- No IDFA usage
- No new permission prompts

## Technical Details

### Touch Interception

Autocapture uses a non-claiming gesture recognizer added to all windows to observe touch events. This approach:

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
