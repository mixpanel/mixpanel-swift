# Crash & ANR-Linked Session Replay Detection

## Core Problem

**When apps crash, we lose critical context about what the user was doing.**

Today's challenges:
- **Crash reports lack user context**: Stack traces show *where* code failed, but not *what the user was doing* when it happened
- **Delayed diagnosis**: MetricKit provides crash data 24-48 hours later, but many crashes go undetected entirely
- **Reproduction difficulty**: Engineering teams struggle to reproduce bugs without seeing the actual user journey
- **ANR/hangs are invisible**: Application Not Responding events often go unreported, leaving users frustrated

## Expected Impact

**Faster bug resolution and improved user experience**

What changes:
- **Visual crash context**: Engineers see exactly what users were doing via session replay when crashes occur
- **Immediate detection**: Crashes detected on next app launch (UserDefaults marker), not 24-48 hours later
- **Higher resolution rates**: Bugs that were "unreproducible" become clear when you can watch the session
- **ANR visibility**: Live watchdog detects UI freezes (>250ms warning, >2s severe) that previously went dark
- **Reduced support burden**: Users experiencing crashes are automatically flagged with replay context

## Feasibility & Technical Approach

**High feasibility - leverages existing iOS infrastructure**

Architecture:
1. **Fast path (UserDefaults marker)**: Instant crash detection on next launch
2. **Rich path (MetricKit)**: iOS 14+ diagnostics upgrade "unexpected exit" → "crash" with signal/exception type
3. **Live detection (ANR Watchdog)**: Background thread pings main thread, detects hangs in real-time
4. **Zero build dependencies**: Communication via `mixpanel-swift-common` protocol bridge

Key considerations:
- ✅ **Crash-loop protection**: Max retry limits, pending exit caps, expiration windows
- ✅ **iOS 13+ compatible**: MetricKit features iOS 14+, but core detection works iOS 13+
- ✅ **Thread-safe**: Dedicated metrics queue, separate from tracking operations
- ✅ **False positive guards**: ANR watchdog pauses during debugger/background/startup
- ⚠️ **MetricKit timing**: OS controls delivery (usually 24h), correlation based on time windows
- ⚠️ **Privacy**: Session replay data follows existing SR sampling rates and masking rules

Implementation status:
- Core crash detection: ✅ Complete
- ANR watchdog: ✅ Complete
- MetricKit correlation: ✅ Complete
- Debug utilities: ✅ Complete (separate file for production removal)
- SR SDK integration: 🔄 In progress (bridge calls being added)

Risk mitigation:
- Separate debug file (`SessionRecoveryDebug.swift`) with `#if DEBUG` - easily removed
- Non-destructive: Only emits events, doesn't modify app behavior
- Graceful degradation: Works without Session Replay (emits events without replay ID)
