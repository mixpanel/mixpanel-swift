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
| `$attr-role` | Element role (Button, Switch, etc.) |
| `$elements` | View hierarchy string (max 5 levels) |

There is no `$attr-aria-label` property. Accessibility labels are not reported at all.

## Element Identification (`$el_id`)

`$el_id` resolution is internal to the SDK and not configurable by the host app.

### Walk-Up to Clickable Parent

When a non-interactive leaf view (e.g., `UILabel` inside a `UIButton`) is tapped, the SDK walks up the view hierarchy to the nearest interactive ancestor and uses its identity for `$el_id`. This is always-on behavior — not configurable.

- The walk-up always takes the interactive parent's identity, even if the leaf has its own identifier.
- Stops at the first interactive ancestor (nested clickables: inner wins).
- Max ancestor search depth: **10 levels**.
- If no interactive ancestor is found within 10 levels, the leaf's own identity (or hash fallback) is used.

`accessibilityLabel` is **never** a source, on either path: it is user-facing text, so it is
localized — the same element would report a different identifier per language — and it can carry
personal data.

### UIKit Resolution Order

1. React Native `nativeID` — the JS-side prop, read through the Objective-C runtime so the SDK
   carries no compile-time dependency on React Native
2. `accessibilityIdentifier` (if non-empty, and not a framework-internal identifier such as
   `_private` or `AXID-1`)
3. `<ClassName>_<hash>` (fallback)

```swift
// Give the interactive element an accessibilityIdentifier
button.accessibilityIdentifier = "checkout_button"

// accessibilityLabel is for VoiceOver only — it never becomes $el_id
button.accessibilityLabel = "Checkout"
```

### SwiftUI Resolution Order

1. `accessibilityIdentifier`, read from SwiftUI's accessibility element tree
2. `<ClassName>_<hash>` (fallback)

There is no `nativeID` step: React Native renders through UIKit, never SwiftUI.

```swift
Button("Checkout") { /* ... */ }
    .accessibilityIdentifier("checkout_button")
```

**Caveat:** SwiftUI never puts the identifier on the backing UIKit view — it lives in the
accessibility element tree, which the SDK queries via `accessibilityHitTest`. That query requires
**iOS 18+**, and returns nil when no accessibility client is active. On iOS 15–17, or with the tree
unmaterialized, SwiftUI elements fall through to `<ClassName>_<hash>`.

### The hash fallback

`<ClassName>_<hash>` is derived from the element's **position** in the hierarchy, not its instance,
so it is stable across app launches. It identifies a position rather than a specific element:
reordering siblings changes it, and two rows of the same list differ by index rather than by
content. Instrument the elements you care about.

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
| macOS (Catalyst) | Not supported | Options are accepted so shared iOS sources compile, but capture never starts |
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
- Set `.accessibilityIdentifier("...")` on the interactive element — it is the only `$el_id` source
- Reading it requires iOS 18+ and a materialized accessibility tree; on iOS 15–17 the element falls
  back to the hash regardless of what you set
- An `accessibilityLabel` will not help; it is never used as an identifier

**UIKit or React Native elements showing hash IDs:**
- Set `accessibilityIdentifier` on the element that handles the tap, or a `nativeID` prop in React
  Native — an identifier on a non-interactive ancestor is not used

**False positive dead clicks:**
- Element may have a handler that doesn't produce visible UI change

## Privacy Considerations

### What is Captured

- Touch coordinates
- View class names and hierarchy
- `accessibilityIdentifier`s and React Native `nativeID`s
- Element roles

### What is NOT Captured

- Visible text content (see note below)
- Accessibility labels

Autocapture does not capture visible text content (`$el_text`) from tapped elements. Tracking text can be invasive and raise privacy concerns. Additionally, the complexity of nested view hierarchies can cause text extraction to capture content from unintended views — for example, tapping a container view might extract text from a deeply nested label that isn't semantically related to the tap. The remaining captured properties (`$el_id`, `$el_tag_name`, `$attr-role`, `$elements`) are purely structural UI metadata.

`accessibilityLabel` is not captured either. It is user-facing text that can carry personal data, and
it is localized, so it never becomes an identifier and is not reported as a property.

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
