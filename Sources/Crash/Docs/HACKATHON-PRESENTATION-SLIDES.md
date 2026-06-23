# 📊 Presentation Slides Outline

## Slide Format
Each slide includes:
- **Title**
- **Visual elements** (describe what to show)
- **Talking points** (what to say)
- **Time allocation**

---

## SLIDE 1: Title Slide (5 seconds)

### Visual:
```
┌─────────────────────────────────────────────┐
│                                             │
│    🎯 Crash & ANR-Linked Session Replay    │
│                                             │
│         Visual Debugging for iOS            │
│                                             │
│              [Your Name]                    │
│           Mixpanel Hackathon                │
│                                             │
└─────────────────────────────────────────────┘
```

### Say:
> "Hi everyone! I'm [name] and I built visual debugging for iOS crashes."

---

## SLIDE 2: The Hook (15 seconds)

### Visual:
Show actual crash report:
```
Fatal Exception: NSInvalidArgumentException
0  CoreFoundation  __exceptionPreprocess
1  libobjc        objc_exception_throw
2  MyApp          Checkout.processPayment
                  (checkout.swift:47)

❌ No user context
❌ Cannot reproduce
❌ Close ticket
```

### Say:
> "Raise your hand if you've seen this: a crash report with just a stack trace. Line 47 in checkout.swift crashed. Great. But WHAT was the user doing? What did they enter? What buttons did they tap?"

**[Pause for effect]**

> "Yeah. We can't reproduce it. So we close the ticket. This is the problem we solved."

---

## SLIDE 3: The Problem - Why Crashes Are Black Boxes (30 seconds)

### Visual:
```
┌──────────────────────────────────────────────────────┐
│                  Current State                       │
├──────────────────────────────────────────────────────┤
│                                                      │
│  User Action  →  💥 CRASH  →  ???                   │
│                      ↓                               │
│               (24-48 hours later)                    │
│                      ↓                               │
│           ┌──────────────────────┐                  │
│           │   Stack Trace Only   │                  │
│           │   ❌ No user context  │                  │
│           │   ❌ No visual data   │                  │
│           │   ❌ No session info  │                  │
│           └──────────────────────┘                  │
│                      ↓                               │
│           "Cannot reproduce"                         │
│                      ↓                               │
│           Ticket closed or sits for weeks            │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Say:
> "Here's what happens today:"

1. **"User crashes"** - something goes wrong in the app
2. **"24-48 hour delay"** - MetricKit eventually delivers a crash report
3. **"Stack trace only"** - we see WHERE code failed, not WHAT the user did
4. **"Cannot reproduce"** - without context, we're stuck

> "And the worst part? Application Not Responding events—ANRs, where the app freezes—these often go completely unreported. User just force-quits, frustrated."

---

## SLIDE 4: The Impact - What This Costs Us (20 seconds)

### Visual:
```
┌────────────────────────────────────────┐
│         Real Consequences              │
├────────────────────────────────────────┤
│                                        │
│  ⏱️  Days to debug simple bugs         │
│                                        │
│  😤  Frustrated users (silent churn)   │
│                                        │
│  🎫  Bloated backlog of crash tickets  │
│                                        │
│  💸  Wasted engineering time           │
│                                        │
│  📉  Lower app ratings                 │
│                                        │
└────────────────────────────────────────┘
```

### Say:
> "This isn't just annoying—it costs us real money. Engineering time debugging without context. Users churning silently. App ratings dropping. We needed a better way."

---

## SLIDE 5: The Solution - 3-Layer Detection (40 seconds)

### Visual:
```
┌─────────────────────────────────────────────────────┐
│              Our Solution: 3 Layers                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Layer 1: FAST PATH                                │
│  ┌──────────────────────────────────────┐          │
│  │ UserDefaults Marker                  │          │
│  │ • Armed on foreground                │          │
│  │ • Completed on background            │          │
│  │ • Detection: 0ms (instant!)          │          │
│  │ • Emits: $unexpected_exit            │          │
│  └──────────────────────────────────────┘          │
│                                                     │
│  Layer 2: RICH PATH                                │
│  ┌──────────────────────────────────────┐          │
│  │ MetricKit Diagnostics (iOS 14+)      │          │
│  │ • OS-provided crash reports          │          │
│  │ • Detection: ~24 hours               │          │
│  │ • Emits: $crash (with signal/type)   │          │
│  └──────────────────────────────────────┘          │
│                                                     │
│  Layer 3: LIVE PATH                                │
│  ┌──────────────────────────────────────┐          │
│  │ ANR Watchdog                         │          │
│  │ • Background thread pings main       │          │
│  │ • Detection: Real-time               │          │
│  │ • Emits: $app_hang (severity levels) │          │
│  └──────────────────────────────────────┘          │
│                                                     │
│  🎥 Every event includes Session Replay ID         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Say:
> "We built three-layer detection:"

**[Point to Layer 1]**
> "Layer 1 is the fast path. A UserDefaults marker. We arm it when the app goes to foreground, mark it complete on background. If it doesn't complete? Crash detected. Instantly."

**[Point to Layer 2]**
> "Layer 2 is the rich path. We hook into iOS MetricKit to get detailed crash diagnostics—signal types, exception codes. We correlate these with our detected crashes to upgrade them with metadata."

**[Point to Layer 3]**
> "Layer 3 is live detection. An ANR watchdog—a background thread that pings the main thread every 50 milliseconds. Main thread doesn't respond? We detect the hang in real-time."

**[Point to bottom]**
> "And here's the magic: **every event includes the Session Replay ID.** Engineers can click directly to the replay."

---

## SLIDE 6: How It Works - Visual Timeline (30 seconds)

### Visual:
```
┌─────────────────────────────────────────────────────────┐
│                    Timeline                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  T-5s        T-2s        T-0s       T+0s      T+1s      │
│   │          │           │          │         │         │
│   │          │          💥         ⚠️        ✅        │
│  Click     Enter      CRASH     Restart   Detected!    │
│           Data                                          │
│   │          │           │          │         │         │
│   └──────────┴───────────┘          │         │         │
│    Session Replay captures           │         │         │
│    (last frame: T-0.5s)              │         │         │
│                                      │         │         │
│  ┌────────────────────────┐          │         │         │
│  │ sessionCompleted=false │──────────┼─────────┼────▶    │
│  └────────────────────────┘  saved   │         │  read   │
│                              to disk │         │         │
│                                      │         ▼         │
│                                      │   "Previous       │
│                                      │   session didn't  │
│                                      │   complete!"      │
│                                      │         │         │
│                                      │         ▼         │
│                                      │   Emit Event:     │
│                                      │   $unexpected_exit│
│                                      │   + replay_id     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Say:
> "Let me walk you through what happens when a crash occurs:"

**[Point to timeline]**
1. **T-5s**: "User is using the app, Session Replay is capturing frames"
2. **T-2s**: "User enters some data, takes some action"
3. **T-0s**: "💥 App crashes"
4. **T+0s**: "User restarts the app"
5. **T+1s**: "We check the marker—previous session didn't complete. Crash detected! Event emitted with replay ID."

> "From crash to detection: **1 second**. Not 24 hours."

---

## SLIDE 7: The Event - What Engineers See (20 seconds)

### Visual:
```
┌──────────────────────────────────────────────────┐
│         $unexpected_exit Event                   │
├──────────────────────────────────────────────────┤
│                                                  │
│  {                                               │
│    "event": "$unexpected_exit",                  │
│    "properties": {                               │
│      "$session_id": "ABC-123-XYZ",              │
│      "$replay_id": "replay-789",   ◀── THE MAGIC│
│      "$crash_timestamp": 1718724000.5,          │
│      "$app_version": "2.1.0",                   │
│      "$os_version": "iOS 17.4"                  │
│    }                                             │
│  }                                               │
│                                                  │
│  ┌────────────────────────────────┐             │
│  │  [View Session Replay] ▶       │             │
│  └────────────────────────────────┘             │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Say:
> "In the Mixpanel dashboard, engineers see this event. Session ID, replay ID, crash timestamp, all the metadata. And there's a button: **View Session Replay**. Click it, and you're watching the crash happen."

---

## SLIDE 8: DEMO TIME (60 seconds)

### Visual:
**Screen recording of:**
1. Xcode with demo app
2. Running app with Session Replay
3. Triggering simulated crash
4. Force quit
5. Restart → console shows detection
6. Dashboard → event appears
7. Click replay → watch it happen

### Say:
> "Let me show you this working. I've got a demo app here with Session Replay enabled."

**[Show code]**
> "I'm going to simulate a crash using our debug utility."

**[Trigger crash]**
> "Boom. Crashed."

**[Restart app]**
> "Restart the app and... there! Console shows 'Detected unexpected exit.' Event emitted."

**[Switch to dashboard]**
> "In the dashboard, here's the event with all the metadata."

**[Click replay link]**
> "And when I click View Session Replay... I can watch exactly what happened. This is game-changing."

---

## SLIDE 9: ANR Detection Bonus (20 seconds)

### Visual:
```
┌──────────────────────────────────────────────┐
│        ANR Watchdog in Action                │
├──────────────────────────────────────────────┤
│                                              │
│  Main Thread:    Background Watchdog:       │
│      │                 │                     │
│   Running            Ping! → Pong! ✓        │
│      │                 │                     │
│   Heavy              Ping! → ...            │
│   Operation           │ (waiting)           │
│   (2.3s)              │  250ms ⚠️ Warning   │
│      │                │  1000ms ⚠️ Moderate │
│      │                │  2000ms 🚨 SEVERE   │
│      │                │                     │
│   Done ────────────▶ Pong! (too late)       │
│                       │                     │
│                       ▼                     │
│                  Emit $app_hang             │
│                  duration: 2300ms           │
│                  severity: "severe"         │
│                                              │
└──────────────────────────────────────────────┘
```

### Say:
> "Bonus feature: ANR detection. Background thread pings the main thread every 50 milliseconds. If main thread takes more than 2 seconds to respond, we emit a hang event in real-time. These were invisible before."

---

## SLIDE 10: Before/After Comparison (30 seconds)

### Visual:
```
┌─────────────────────────────────────────────────────────┐
│                BEFORE vs AFTER                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  BEFORE (Today)              AFTER (This Feature)      │
│  ───────────────             ────────────────────      │
│                                                         │
│  ❌ 24-48 hour delay          ✅ Instant (0ms)          │
│                                                         │
│  ❌ Stack trace only          ✅ Full session replay    │
│                                                         │
│  ❌ "Cannot reproduce"        ✅ "Watch it happen"      │
│                                                         │
│  ❌ ANRs invisible            ✅ Live detection         │
│                                                         │
│  ❌ Days to debug             ✅ Hours to debug         │
│                                                         │
│  ❌ Frustrated users          ✅ Faster fixes           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Say:
> "Let me show you the before and after:"

**[Read through each line]**

> "From 24-hour delays to instant detection. From stack traces to full replays. From 'cannot reproduce' to 'watch it happen.' From days to hours. This is a massive improvement."

**[Add emphasis]**

> "And here's a pro tip: use remote event trigger settings to automatically start Session Replay before crashes in critical flows—like checkout or payments. Even if replay wasn't running initially, it captures the crucial moments. No more blind spots."

---

## SLIDE 11: Technical Highlights (30 seconds)

### Visual:
```
┌──────────────────────────────────────────────────┐
│         Technical Achievements                   │
├──────────────────────────────────────────────────┤
│                                                  │
│  ✅ Zero external dependencies                  │
│     Built entirely on iOS foundations            │
│                                                  │
│  ✅ Thread-safe architecture                    │
│     Dedicated serial queue for metrics           │
│                                                  │
│  ✅ Crash-loop protection                       │
│     Max 3 retries, 10 pending, 24h expiration   │
│                                                  │
│  ✅ iOS 13+ compatible                          │
│     Enhanced features on iOS 14+                 │
│                                                  │
│  ✅ Privacy-preserving                          │
│     Follows Session Replay sampling & masking    │
│                                                  │
│  ✅ Production-ready                            │
│     Separate debug utilities (#if DEBUG)         │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Say:
> "From a technical standpoint, this is solid:"

- "Zero external dependencies—built on native iOS APIs"
- "Thread-safe with dedicated queue"  
- "Crash-loop protection built in"
- "Works iOS 13+, enhanced on iOS 14+"
- "Privacy-preserving—follows SR settings"
- "Production-ready—debug code is separate"

---

## SLIDE 12: Code Stats (15 seconds)

### Visual:
```
┌─────────────────────────────────────┐
│       Implementation Stats          │
├─────────────────────────────────────┤
│                                     │
│  📁 Files: 5 new + 1 bridge         │
│                                     │
│  📝 Lines: ~1,337 lines             │
│                                     │
│  ⏱️  Time: Hackathon project        │
│                                     │
│  🐛 Dependencies: 0 new             │
│                                     │
│  ✅ Status: Ready for testing       │
│                                     │
└─────────────────────────────────────┘
```

### Say:
> "Quick stats: 5 new files, about 1,300 lines of code, built during this hackathon, zero new dependencies, and it's ready for production testing."

---

## SLIDE 13: Impact Story - Real Use Case (30 seconds)

### Visual:
```
┌──────────────────────────────────────────────────┐
│           Real-World Scenario                    │
├──────────────────────────────────────────────────┤
│                                                  │
│  E-commerce App Crash:                          │
│                                                  │
│  WITHOUT this feature:                          │
│  ────────────────────                           │
│  • User reports: "Crashed at checkout"          │
│  • Crash log: NSInvalidArgumentException        │
│  • Engineer: "Cannot reproduce"                 │
│  • Resolution: 5 days (or never)                │
│  • Impact: Lost revenue                         │
│                                                  │
│  WITH this feature:                             │
│  ──────────────────                             │
│  • Crash detected instantly                     │
│  • Engineer watches session replay              │
│  • Sees: User entered emoji in zip code         │
│  • Fix: Add input validation                    │
│  • Resolution: 2 hours                          │
│  • Impact: Happy customer                       │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Say:
> "Here's a real scenario: E-commerce app crashes at checkout. Without this feature, we get a stack trace, can't reproduce, might take days or never get fixed. Customer is lost."

> "With this feature? Crash detected instantly. Engineer watches the replay. Sees the user entered an emoji in the zip code field. Adds input validation. Fixed in 2 hours. Customer completes purchase next time."

> "From lost revenue to saved customer."

---

## SLIDE 14: Next Steps (20 seconds)

### Visual:
```
┌──────────────────────────────────┐
│         Roadmap                  │
├──────────────────────────────────┤
│                                  │
│  ✅ Phase 1: Implementation      │
│     (Completed!)                 │
│                                  │
│  🔄 Phase 2: Beta Testing        │
│     • Swift SDK first            │
│     • Monitor metrics            │
│     • Gather feedback            │
│                                  │
│  📅 Phase 3: Production          │
│     • Roll out to all users      │
│     • React Native next          │
│     • Other platforms            │
│                                  │
│  📈 Phase 4: Measure Impact      │
│     • Time-to-resolution         │
│     • Fix rates                  │
│     • User satisfaction          │
│                                  │
└──────────────────────────────────┘
```

### Say:
> "Here's the roadmap: Phase 1 is done—we built it. Phase 2 is beta testing on Swift SDK. Phase 3 is production rollout, starting with iOS then React Native. Phase 4 is measuring impact."

---

## SLIDE 15: Call to Action (15 seconds)

### Visual:
```
┌─────────────────────────────────────────────┐
│                                             │
│              Let's Ship This!               │
│                                             │
│  ✅ Code is complete                        │
│  ✅ Production-ready                        │
│  ✅ High-impact feature                     │
│  ✅ Teams are asking for this               │
│                                             │
│  From "Cannot Reproduce"                    │
│     to                                      │
│  "Fixed in One PR"                          │
│                                             │
│         🚀 Ready to Deploy 🚀               │
│                                             │
└─────────────────────────────────────────────┘
```

### Say:
> "Bottom line: this is production-ready. The code is done. The value is clear. Teams are already asking for this capability. Let's beta test it and ship it. Turn 'cannot reproduce' into 'fixed in one PR.'"

**[Pause for emphasis]**

> "Thank you!"

---

## SLIDE 16: Q&A (Backup)

### Visual:
```
┌──────────────────────────────┐
│                              │
│         Questions?           │
│                              │
│    [Your Contact Info]       │
│                              │
└──────────────────────────────┘
```

---

## Presentation Timing Summary

| Section | Time | Cumulative |
|---------|------|------------|
| Title | 5s | 0:05 |
| Hook | 15s | 0:20 |
| Problem | 30s | 0:50 |
| Impact | 20s | 1:10 |
| Solution | 40s | 1:50 |
| Timeline | 30s | 2:20 |
| Event View | 20s | 2:40 |
| Demo | 60s | 3:40 |
| ANR | 20s | 4:00 |
| Before/After | 30s | 4:30 |
| Technical | 30s | 5:00 |
| Code Stats | 15s | 5:15 |
| Use Case | 30s | 5:45 |
| Roadmap | 20s | 6:05 |
| CTA | 15s | 6:20 |

**Total: ~6 minutes** (trim as needed for 3-minute Loom)

---

## For 3-Minute Loom Version

### Essential Slides Only:
1. **Hook** (15s) - Slide 2
2. **Problem** (20s) - Slide 3 (condensed)
3. **Solution** (30s) - Slide 5
4. **Demo** (60s) - Slide 8
5. **Before/After** (30s) - Slide 10
6. **CTA** (15s) - Slide 15

**Total: 2:50** (leaves 10s buffer)

---

## Key Phrases to Emphasize

**Say with frustration:**
- "Cannot reproduce"
- "24-48 hour delay"
- "Stack trace only"

**Say with excitement:**
- "Instant detection"
- "Watch it happen"
- "Game-changer"
- "Fixed in one PR"

**Say with confidence:**
- "Production-ready"
- "Zero dependencies"
- "Let's ship this"
