# 🎨 Visual Flow Diagrams for Presentation

## Architecture Overview Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Mixpanel iOS SDK                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Session Recovery Manager (Crash Detection)       │  │
│  │                                                           │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │  │
│  │  │  Layer 1:   │  │   Layer 2:   │  │   Layer 3:     │  │  │
│  │  │ UserDefaults│  │  MetricKit   │  │ ANR Watchdog   │  │  │
│  │  │   Marker    │  │ Diagnostics  │  │  (Live Ping)   │  │  │
│  │  │             │  │              │  │                │  │  │
│  │  │  Instant    │  │   ~24 hours  │  │   Real-time    │  │  │
│  │  │  Detection  │  │ Correlation  │  │   Detection    │  │  │
│  │  └─────────────┘  └──────────────┘  └────────────────┘  │  │
│  │         │                 │                  │           │  │
│  │         └─────────────────┴──────────────────┘           │  │
│  │                           ↓                               │  │
│  │              ┌──────────────────────────┐                │  │
│  │              │   Event Emission         │                │  │
│  │              │ • $unexpected_exit       │                │  │
│  │              │ • $crash (corroborated)  │                │  │
│  │              │ • $app_hang              │                │  │
│  │              └──────────────────────────┘                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↓                                     │
│              ┌──────────────────────────┐                       │
│              │   Common Bridge          │                       │
│              │ (mixpanel-swift-common)  │                       │
│              └──────────────────────────┘                       │
│                           ↓                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Session Replay SDK                               │  │
│  │  • Provides replay_id, timestamps                        │  │
│  │  • Notifies: start/frame/stop                           │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                           ↓
              ┌──────────────────────────┐
              │   Mixpanel Dashboard     │
              │  • Crash event with      │
              │    replay link           │
              │  • Click to watch        │
              │    session               │
              └──────────────────────────┘
```

---

## User Journey Flow (Before/After Comparison)

### ❌ BEFORE: The Black Box

```
User Action → Crash → ???
                 ↓
         Crash Report Generated
                 ↓
         (24-48 hours later)
                 ↓
         ┌───────────────────────┐
         │  Stack Trace Only     │
         │                       │
         │  Signal: SIGSEGV      │
         │  Line: checkout.swift │
         │  Function: processCart│
         │                       │
         │  🤷 No user context   │
         └───────────────────────┘
                 ↓
         Engineer: "Cannot reproduce"
                 ↓
         Ticket closed or sits for weeks
```

### ✅ AFTER: Full Context

```
User Action → Crash → INSTANT DETECTION
                 ↓
         (Next app launch - 0ms delay)
                 ↓
         ┌───────────────────────────────────┐
         │  $unexpected_exit Event           │
         │                                   │
         │  ✓ Session ID                     │
         │  ✓ Replay ID (linked!)            │
         │  ✓ Crash Timestamp                │
         │  ✓ Last Frame Timestamp           │
         │  ✓ Device/OS/App Version          │
         │                                   │
         │  [Click to Watch Session Replay]  │
         └───────────────────────────────────┘
                 ↓
         Engineer clicks replay link
                 ↓
         🎥 WATCHES THE ACTUAL CRASH HAPPEN
                 ↓
         "Oh! User entered emoji in zip code field"
                 ↓
         Fixed in 1 PR (same day)
```

---

## Crash Detection Timeline

```
Time:     T-5s      T-2s      T-0s     T+0s      T+1s      T+24h
          │         │         │        │         │         │
User:     ┌─────┐   ┌─────┐   💥       ⚠️        ✅        ✅
Action    │Click│   │Enter│  CRASH   Restart   Detection Complete
          └─────┘   └─────┘           
                                      
SR SDK:   ━━━━━━━━━━━━━━━━━━━━━━━━▶  (stopped)
          │                        │
          └─ Capturing frames ─────┘
                    │
                    ▼
          Last Frame: T-0.5s
                                      
Marker:   ┌────────────────────────┐  
          │ sessionCompleted=false │──▶ (persisted)
          └────────────────────────┘
                                          │
                                          ▼
                                      Next Launch:
                                      "Previous session 
                                       didn't complete!"
                                          │
                                          ▼
                                      Emit Event:
                                      $unexpected_exit
                                          │
                                          ▼
                                      MetricKit:
                                      (arrives ~24h later)
                                          │
                                          ▼
                                      Correlate & Upgrade:
                                      $crash with signal/exception
```

---

## ANR Watchdog Flow

```
Main Thread:           Background Watchdog Thread:
    │                         │
    │                         │ Every 50ms:
    │                         ├─ Ping main thread
    │                         └─ Wait for response
    │                         
  ┌─┴─┐                       
  │ UI │ ◀─── Ping!           │
  │Code│                      │
  └─┬─┘                       │
    │ ─────── Pong! ────────▶ │ ✓ Response in 10ms
    │                         │   (Healthy)
    │                         
  ┌─┴─────────────────┐      
  │  Heavy Operation  │      │
  │  (Network call,   │      ├─ Ping! 
  │   parsing, etc.)  │      │ (Waiting...)
  │                   │      │
  │ ......still.......│      │ 250ms ⚠️ Warning
  │ ......going.......│      │
  │ .................│      │ 1000ms ⚠️ Moderate  
  │ .................│      │
  │ .................│      │ 2000ms 🚨 SEVERE
  └───────────────────┘      │
    │ ────── Pong! ────────▶ │
    │   (2.3 seconds later)   │
    │                         ▼
    │                    Emit $app_hang event:
    │                    • session_id
    │                    • replay_id  
    │                    • hang_duration: 2300ms
    │                    • severity: "severe"
```

---

## Event Schema Comparison

### $unexpected_exit Event
```json
{
  "event": "$unexpected_exit",
  "properties": {
    "$session_id": "ABC-123-XYZ",
    "$replay_id": "replay-789",
    "$crash_timestamp": 1718724000.5,
    "$exit_type": "unexpected",
    "$app_version": "2.1.0",
    "$os_version": "iOS 17.4"
  }
}
```

### $crash Event (MetricKit Corroborated)
```json
{
  "event": "$crash",
  "properties": {
    "$session_id": "ABC-123-XYZ",
    "$replay_id": "replay-789",
    "$crash_timestamp": 1718724000.5,
    "$exit_type": "crash",
    "$crash_type": "crash",
    "$signal": "SIGSEGV",
    "$exception_type": "NSInvalidArgumentException",
    "$correlation_confidence": "HIGH",
    "$app_version": "2.1.0",
    "$os_version": "iOS 17.4",
    "$event_id": "ABC-123-XYZ_1718724000_1718810400"
  }
}
```

### $app_hang Event
```json
{
  "event": "$app_hang",
  "properties": {
    "$session_id": "ABC-123-XYZ", 
    "$replay_id": "replay-789",
    "$hang_duration": 2300,
    "$hang_severity": "severe",
    "$timestamp": 1718724000.0,
    "$app_version": "2.1.0"
  }
}
```

---

## Code Structure Map

```
mixpanel-swift/
└── Sources/
    └── Crash/
        ├── SessionRecoveryRecord.swift       (430 lines)
        │   └── Data structure for marker + storage
        │
        ├── SessionRecoveryManager.swift      (283 lines)  
        │   └── Core coordinator, lifecycle, events
        │
        ├── SessionRecoveryMetricKit.swift    (249 lines)
        │   └── MetricKit integration + correlation
        │
        ├── ANRWatchdog.swift                 (204 lines)
        │   └── Live hang detection
        │
        └── SessionRecoveryDebug.swift        (129 lines)
            └── #if DEBUG utilities (removable)

mixpanel-swift-common/
└── Sources/MixpanelSwiftCommon/
    └── MixpanelCommonBridge.swift            (42 lines)
        └── Protocol bridge for SR ↔ Analytics

Total: ~1,337 lines of new code
```

---

## Demo Script Visual Cues

### Screen 1: The Problem
- Show a real crash report (stack trace only)
- Circle the missing context: "What did user do?"

### Screen 2: The Code
- Split screen: 
  - Left: `SessionRecoveryManager.swift` (marker logic)
  - Right: Terminal showing marker being saved

### Screen 3: Simulate Crash
```swift
// In demo app:
mixpanel.debugSimulateCrash()
// Force kill app
```

### Screen 4: Restart & Detection
- Relaunch app
- Show console log: "Detected unexpected exit"
- Show event being tracked

### Screen 5: The Dashboard
- Open Mixpanel dashboard
- Show `$unexpected_exit` event
- Click "View Session Replay"
- **Boom** - watch the crash happen

### Screen 6: The Fix
- Show the actual bug in code
- Show 1-line fix
- Show PR being merged

---

## Key Metrics to Highlight

```
┌─────────────────────────────────────────────────────────┐
│  BEFORE This Feature          AFTER This Feature        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ❌ 24-48 hour delay          ✅ Instant (0ms)          │
│                                                          │
│  ❌ Stack trace only          ✅ Full session replay    │
│                                                          │
│  ❌ "Cannot reproduce"        ✅ Watch it happen        │
│                                                          │
│  ❌ ANRs invisible            ✅ Live detection         │
│                                                          │
│  ❌ Days to debug             ✅ Minutes to debug       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```
