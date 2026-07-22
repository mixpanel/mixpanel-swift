# iOS Autocapture Audit Report

Cross-referenced against Android PR #982 review findings.
Audited: 2026-07-02

---

## Issues That Apply to iOS

### CRITICAL

#### 3. Every touch-up treated as a click — scrolls and swipes emit `$mp_click`
- **File:** `TouchInterceptor.swift:194`
- **Status:** SAME AS ANDROID
- **Description:** `TouchObservingGestureRecognizer.touchesEnded()` fires on every single-finger touch-up. `touchesBegan` (line 186) is empty — no down position recorded. `touchesMoved` (line 190) is empty — no movement tracking. No touch-slop check, no duration check. Every scroll, swipe, fling, or long press produces a spurious `$mp_click`.
- **Fix:** Record touch-down position/timestamp in `touchesBegan`. In `touchesEnded`, verify displacement is within touch slop and duration is reasonable for a tap.
- [x] Fixed
- **Resolution:** Added `downLocation`/`downTime` tracking in `TouchObservingGestureRecognizer`. `touchesBegan` records position and timestamp. `touchesEnded` checks displacement <= 10pt (`maxTapDisplacement`) and duration < 500ms (`maxTapDuration`) before forwarding to `processTouchEnded`. Scrolls, swipes, and long presses are now filtered out. Matches Android's CurtainsHelper fix.

### MEDIUM

#### 4. Dead click baseline captured 150ms after click — fast UI responses absorbed
- **File:** `DeadClickDetector.swift:213`
- **Status:** SAME AS ANDROID
- **Description:** `startMonitoring` schedules baseline capture via `asyncAfter(deadline: .now() + .milliseconds(baselineDelayMs))` with default 150ms. UI responses completing within 150ms are absorbed into the baseline, causing false positive dead clicks.
- **Fix:** Capture baseline synchronously at click time.
- [x] Fixed
- **Resolution:** Baseline snapshot is now captured synchronously in `startMonitoring` before scheduling the timeout check. Removed `baselineDelayMs` field, `captureBaseline()` method, and the 150ms async delay. `PendingCheck.baselineSnapshot` changed from optional to non-optional. Only a single `asyncAfter` at `timeoutMs` remains. Matches Android's synchronous baseline logic.

#### D7. Hit-testing picks deepest view, not the clickable target
- **File:** `TouchInterceptor.swift:207`, `SemanticExtractor.swift:143-170`
- **Status:** SAME AS ANDROID
- **Description:** `touch.view` returns the deepest (frontmost) view via UIKit hit-testing. For UIButton > UILabel, the UILabel is returned. `determineRole()` checks only the passed view (not ancestors), so role="Text" instead of "Button". `hasInteractionHandlers()` (line 245) checks only the immediate view for gesture recognizers/UIControl targets — a UILabel inside a UIButton reports `isInteractive=false`.
- **Fix:** Walk up to the nearest interactive ancestor when the leaf is non-interactive.
- [x] Fixed
- **Resolution:** Added `isInteractive(_:)` and `findInteractiveAncestor(of:maxDepth:)` to `SemanticExtractor`. `extractSemantics` now checks if the touched view is interactive (UIControl with targets, or has enabled UITapGestureRecognizer). If not, walks up the superview chain (max 5 levels) to find the nearest interactive ancestor and extracts semantics from that instead. Falls back to original view if no interactive ancestor found.

#### D5. TouchInterceptor install: `isInstalled=true` set before window instrumentation succeeds
- **File:** `TouchInterceptor.swift:77, 82-87`
- **Status:** PARTIALLY APPLICABLE
- **Description:** `isInstalled` is set to `true` on line 77 before the actual window instrumentation at lines 82+. If `UIApplication.shared` is unavailable (app extensions), install silently fails but `isInstalled` is already `true`, preventing retries. Also, `uninstall()` clears `observedWindows` and `isInstalled` but does NOT remove the `UIWindow.didBecomeVisibleNotification` observer — new windows after uninstall will still get gesture recognizers attached (though they no-op since `manager` is nil).
- **Fix:** Set `isInstalled` only after successful window instrumentation. Remove notification observer in `uninstall()`.
- [x] Fixed
- **Resolution:** Moved `isInstalled = true` to after the window iteration loop. If `UIApplication.shared` is unavailable (app extensions), install returns without setting the flag, allowing retries. Notification observer management also fixed (see #10).

### LOW

#### D1. "Disabled by default" OR pattern
- **File:** `AutocaptureOptions.swift:147-149`
- **Status:** PARTIALLY APPLICABLE (mitigated)
- **Description:** `isEnabled` is an OR over sub-options, same as Android. However, iOS mitigates the risk: `MixpanelOptions.autocaptureOptions` is `Optional` defaulting to `nil`. Autocapture only activates when the developer explicitly provides an `AutocaptureOptions` instance. The residual risk: if a developer already opted in and a new sub-option is added with `enabled: true` default, it silently activates.
- **Fix:** Add a master enabled flag or ensure new sub-options default to `enabled: false`.
- [ ] Not fixed (intentional)
- **Resolution:** Not fixing — the double gate (optional autocaptureOptions + per-feature enabled flags) already provides adequate protection. The OR pattern matches Android's design, and the residual risk is minimal: new sub-options should default to `enabled: false` as a convention.

#### 10. Notification observer persists after uninstall
- **File:** `TouchInterceptor.swift:34-39, 108-118`
- **Status:** PARTIALLY APPLICABLE
- **Description:** `uninstall()` removes gesture recognizers and clears state, but the `UIWindow.didBecomeVisibleNotification` observer (registered in `init()`) is never removed except in `deinit`. Since `TouchInterceptor` is a singleton, `deinit` never runs. After `uninstall()`, new windows can still get gesture recognizers attached (though they no-op since `manager` is nil).
- **Fix:** Remove notification observer in `uninstall()`. Add `guard isInstalled` check in `windowDidBecomeVisible`.
- [x] Fixed
- **Resolution:** Moved notification observer registration from `init()` to `performInstall()` (after successful window instrumentation). `uninstall()` now removes the observer. `windowDidBecomeVisible` guards with `isInstalled` check. Observer is re-registered on each `install()` call.

---

## Issues That Do NOT Apply to iOS

| # | Issue | Why Not Applicable |
|---|-------|--------------------|
| **1** | Events dropped when `trackAutomaticEvents=false` | iOS autocapture uses `$mp_` prefix; the filter only drops `$ae_` events. Completely independent flags. |
| **2** | WindowSpy mViews swap race | Invalid on Android too. iOS has no equivalent mechanism. |
| **5** | Deferred init misses current screen | `performInstall()` proactively iterates all existing windows via `UIApplication.shared.windows` and attaches immediately. |
| **6** | Dialogs/popups never captured | Invalid on Android (already fixed). iOS uses UIKit hit-testing which handles all windows naturally. |
| **7** | Coordinate space mismatch | iOS uses `touch.location(in: window)` (window coordinates) consistently. No custom hit-testing — relies on `touch.view` from UIKit. |
| **8** | Window.Callback methods not delegated | iOS uses a passive gesture recognizer, not callback wrapping. `cancelsTouchesInView=false`, `delaysTouchesEnded=false`, always transitions to `.failed`. No responder chain interference. |
| **D2** | Two divergent detection mechanisms | iOS dead click detection uses a single unified snapshot mechanism for both UIKit and SwiftUI. (Note: exclusion lists ARE duplicated between `DeadClickDetector` and `SemanticExtractor` — see dead code section.) |
| **D3** | Hardcoded change-detection sensitivity | iOS uses exact comparison (`viewCount !=`, `contentHash !=`), no +/-5 threshold. |
| **D4** | MAX_ACCESSIBILITY_NODES misused | iOS uses correctly named `maxHierarchyDepth` (5, upward walk) and `maxRecursionDepth` (20, downward walk). No mislabeled constants. |
| **D6** | Duplicate lifecycle callbacks | No duplication within autocapture. Legacy SDK has overlapping observers for different purposes (flush vs session). |
| **P1** | Extraction before app receives touch | Gesture recognizer fires in `touchesEnded` — the app has already processed the touch through the responder chain. |
| **P2** | Per-node coordinate conversion in DFS | iOS doesn't do DFS hit-testing. Uses `touch.view` from UIKit directly. Only walks upward for accessibility properties. |
| **P5** | Hot-path logs build strings eagerly | `MixpanelLogger` uses `@autoclosure` — string interpolation is deferred and only evaluated when the log level is enabled. |

---

## iOS-Specific Dead Code and Issues

#### Duplicated exclusion lists
- **Files:** `DeadClickDetector.swift:62-91` and `SemanticExtractor.swift:215-236`
- **Description:** `excludedControlTypes` + `swiftUIExcludedPatterns` are identical copies in both files. If one is updated without the other, behavior will diverge.
- **Fix:** Extract to a shared constant.
- [x] Fixed
- **Resolution:** Moved both lists to `AutocaptureDefaults` in `AutocaptureOptions.swift` as shared `static let` constants. Both `DeadClickDetector` and `SemanticExtractor` now reference `AutocaptureDefaults.excludedControlTypes` and `AutocaptureDefaults.swiftUIExcludedPatterns`. Removed the `hasInteractionHandlers` method from `SemanticExtractor` (89 lines removed).

#### `isInteractive` on ClickEvent is write-only
- **File:** `ClickEvent.swift`
- **Description:** `isInteractive` is set by `SemanticExtractor.extractSemantics()` but never included in `toProperties()` and never read anywhere. Dead data.
- **Fix:** Either emit it or remove it.
- [x] Fixed
- **Resolution:** Removed `isInteractive` field from `ClickEvent`. Dead click detector has its own `hasInteractionHandlers()` check.

#### `isRageClick` on ClickEvent is write-only
- **File:** `ClickEvent.swift`
- **Description:** `isRageClick` is set but never emitted in `toProperties()`. Rage click determination uses `RageClickResult.isRageClick` directly in `AutocaptureManager`, not the ClickEvent field.
- **Fix:** Remove from ClickEvent — it's redundant with RageClickResult.
- [x] Fixed
- **Resolution:** Removed `isRageClick` field from `ClickEvent`. Also removed the rage click ClickEvent reconstruction in `AutocaptureManager.processTouch` that was rebuilding the entire struct just to set `isRageClick: true`.

#### `tapCount` on non-rage ClickEvent is write-only
- **File:** `ClickEvent.swift:49`, `AutocaptureManager.swift:211`
- **Description:** Every ClickEvent gets `tapCount: 1`, but `toProperties()` never emits it. Only `emitRageClickEvent` manually adds `$tap_count`. For regular clicks, `tapCount` is dead data.
- **Fix:** Remove from ClickEvent or include in `toProperties()`.
- [x] Fixed
- **Resolution:** Removed `tapCount` field from `ClickEvent`. Also removed `$tap_count` emission from `emitRageClickEvent` — the JS SDK doesn't send this property either (matches Android decision).

#### `handleTouchGesture(_:)` is dead code
- **File:** `TouchInterceptor.swift:148-150`
- **Description:** Defined as the action for the gesture recognizer, but the comment says "This won't be called." The recognizer overrides `touchesEnded` directly and sets `state = .failed`, so this action method never fires. Exists because `UIGestureRecognizer(target:action:)` requires an action selector.
- **Fix:** Document or remove.
- [x] Fixed
- **Resolution:** Kept the method (required by `UIGestureRecognizer(target:action:)`) but added a clear comment explaining why it exists and is intentionally empty.

---

## Summary

| Severity | Count | Key Items |
|----------|-------|-----------|
| CRITICAL | 1 | Touch-slop/duration check missing (#3) |
| MEDIUM | 3 | Dead click baseline delay (#4), deepest-view hit-testing (D7), install flag (D5) |
| LOW | 2 | OR-based isEnabled (D1), notification observer leak (#10) |
| Dead code | 5 | Duplicated exclusions, write-only fields, dead handler |
