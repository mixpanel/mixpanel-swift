# 🎯 Crash & ANR-Linked Session Replay Detection

## The Problem: Crashes Are a Black Box

**When your app crashes, you lose the most important context: what the user was actually doing.**

Real scenario:
- User reports: "App crashed when I tried to checkout"
- Crash log shows: `NSInvalidArgumentException` in payment flow
- Engineer's question: **"What did they click? What data did they enter? Can I reproduce this?"**
- Answer: ¯\\\_(ツ)_/¯

**Current gaps:**
1. 📊 **MetricKit delivers crash reports 24-48 hours later** - too slow for immediate response
2. 🔍 **Stack traces show WHERE code failed, not WHAT the user did** - missing context
3. 👻 **ANR/hangs often go completely unreported** - silent user frustration
4. 🎲 **"Cannot reproduce"** - the most common engineering response to bug reports

---

## The Impact: From Days to Minutes

**Engineers see exactly what happened, not just where code failed.**

### Before (Today):
```
Crash Report → Stack trace → "Cannot reproduce" → Close ticket
                               ↓
                         User frustrated
```

### After (With This Feature):
```
Crash Detected → Session Replay Link → Watch user journey → Fix in 1 PR
     ↓
Immediate alert with visual context
```

### What Changes:
- ⚡ **Instant detection** - Crash detected on next app launch (not 24-48 hours)
- 🎥 **Visual debugging** - Watch the actual session replay leading up to the crash
- 📈 **Higher fix rates** - "Unreproducible" bugs become obvious when you can watch them
- 🚨 **ANR visibility** - Detect UI freezes (>250ms warning, >2s severe) that users never report
- 🎯 **Automatic prioritization** - Crashes with session replay get flagged for immediate attention
- 🎬 **Smart recording** - Use remote event triggers to start Session Replay before crashes in critical flows (checkout, payments, etc.)

**Example use cases:**
- E-commerce app: See exact product/cart state when checkout crashes
- Social app: Watch the interaction sequence that triggers a feed crash
- Banking app: Identify which form fields cause validation crashes
- Gaming app: See the exact user actions that cause level load hangs

---

## Feasibility: Built on iOS Foundations

**High feasibility - leverages native iOS infrastructure, no third-party dependencies.**

### Technical Architecture (3-Layer Detection):

#### Layer 1: Fast Path (UserDefaults Marker) ✅
- **How**: Arm marker on foreground, mark complete on background
- **Detection**: Next launch checks if previous session completed
- **Speed**: Immediate (0ms delay)
- **Emits**: `$unexpected_exit` event with session replay ID

#### Layer 2: Rich Path (MetricKit Diagnostics) ✅
- **How**: iOS 14+ MetricKit provides crash/hang diagnostics
- **Detection**: Correlate with pending unexpected exits
- **Speed**: 24 hours (OS-controlled delivery)
- **Emits**: `$crash` event with signal, exception type, HIGH/MEDIUM/LOW confidence

#### Layer 3: Live Detection (ANR Watchdog) ✅
- **How**: Background thread pings main thread every 50ms
- **Detection**: Main thread unresponsive >250ms/1s/2s
- **Speed**: Real-time
- **Emits**: `$app_hang` event with severity level

### Implementation Status:
- ✅ Core crash detection (UserDefaults marker)
- ✅ MetricKit integration (iOS 14+, graceful degradation)
- ✅ ANR watchdog with false positive guards
- ✅ Thread-safe architecture (dedicated metrics queue)
- ✅ Crash-loop protection (retry limits, expiration windows)
- ✅ Bridge communication (via mixpanel-swift-common)
- ✅ Debug utilities (separate file for easy removal)
- 🔄 Session Replay SDK integration (in progress)

### Key Considerations:

**✅ Solved:**
- **Thread safety**: Dedicated serial queue for metrics operations
- **Crash loops**: Max retry count (3), pending exit cap (10), 24h expiration
- **False positives**: ANR pauses during debugger/background/startup grace period
- **Build dependencies**: Protocol bridge via shared common SDK (no circular deps)
- **iOS compatibility**: iOS 13+ (MetricKit features require iOS 14+)

**⚠️ Trade-offs:**
- **MetricKit timing**: OS controls delivery (~24h), not instant
- **Correlation accuracy**: Time-window matching (HIGH/MEDIUM/LOW confidence levels)
- **Privacy**: Follows existing Session Replay sampling & masking rules
- **Storage**: UserDefaults for marker (< 1KB), in-memory pending exits

**🚫 Risks (Mitigated):**
- Debug code in production → Separate `#if DEBUG` file for easy removal
- Performance impact → Dedicated queue, async operations, 50ms ping interval
- Storage leaks → Expiration cleanup (24h), max pending cap (10)

### Code Stats:
- **Lines added**: ~1,200 lines
- **New files**: 5 files in `/Sources/Crash/`
- **Dependencies**: Zero new external dependencies
- **Test coverage**: Debug utilities for crash simulation

---

## Demo Flow (For Loom)

### Setup (0:00 - 0:30)
"Here's the problem: when apps crash, we lose context about what the user was doing..."

### Show the Code (0:30 - 1:30)
1. **UserDefaults marker** - Show `SessionRecoveryRecord` structure
2. **ANR Watchdog** - Show real-time hang detection
3. **MetricKit** - Show crash correlation logic
4. **Bridge integration** - Show how SR SDK communicates

### Demo the Feature (1:30 - 2:30)
1. **Simulate a crash** - Use debug utility: `debugSimulateCrash()`
2. **Restart app** - Show `$unexpected_exit` event emission
3. **Show event properties** - `$session_id`, `$replay_id`, `$crash_timestamp`
4. **Open Session Replay** - Click replay link, watch user journey

### Impact & Next Steps (2:30 - 3:00)
"This means engineers can debug crashes with full visual context, not just stack traces. Next: Roll out to production SDKs."

---

## Talking Points for Presentation

### Hook (First 15 seconds):
> "Raise your hand if you've ever closed a bug ticket with 'Cannot reproduce.' Now imagine if every crash report came with a video of exactly what the user was doing. That's what we built."

### Problem Statement:
- Crashes are debugging nightmares without user context
- MetricKit is too slow (24-48 hours)
- ANRs go unreported
- "Cannot reproduce" = wasted engineering time

### Solution Overview:
- 3-layer detection: instant UserDefaults marker + rich MetricKit diagnostics + live ANR watchdog
- Automatic session replay linking
- Zero configuration required

### Technical Highlights:
- Built entirely on iOS foundations (no external deps)
- Thread-safe, crash-loop protected
- Works iOS 13+, enhanced on iOS 14+

### Impact Story:
- From "Cannot reproduce" to "Fixed in one PR"
- Visual debugging for every crash
- Proactive ANR detection

### Call to Action:
- Ready for production testing
- Want to roll out to Swift SDK first, then React Native
- Could reduce crash resolution time by 10x
