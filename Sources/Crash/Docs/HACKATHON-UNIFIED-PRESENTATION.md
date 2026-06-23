# 🎯 Crash & ANR-Linked Session Replay - Unified Presentation Guide

**Complete presentation combining slides + Loom script**  
Total time: 3 minutes | 8 slides (condensed version)

---

## Pre-Recording Checklist

- [ ] Xcode open with crash detection code
- [ ] Demo app ready with Mixpanel + Session Replay
- [ ] Dashboard open in browser tab
- [ ] Terminal ready
- [ ] Water nearby
- [ ] Timer set for 3 minutes
- [ ] Deep breath! 🚀

---

# SLIDE 1: The Hook
**Time: 0:00 - 0:20 (20 seconds)**

### Visual:
```
┌─────────────────────────────────────────────┐
│                                             │
│   Fatal Exception: NSInvalidArgumentException
│   0  CoreFoundation  __exceptionPreprocess  │
│   1  libobjc        objc_exception_throw    │
│   2  MyApp          Checkout.processPayment │
│                     (checkout.swift:47)     │
│                                             │
│   ❌ No user context                        │
│   ❌ Cannot reproduce                       │
│   ❌ Close ticket                           │
│                                             │
└─────────────────────────────────────────────┘
```

### What to Say:
**[Show crash report on screen]**

> "Hey everyone! Quick question: How many times have you seen this?"

**[Point to the stack trace]**

> "A crash report that just says 'NSInvalidArgumentException in checkout flow' and your only response is..." 

**[Type in imaginary ticket]** 

> "'Cannot reproduce.'"

**[Pause for effect]**

> "Yeah. Me too. What if I told you we could **watch** every crash happen? Let me show you."

---

# SLIDE 2: The Problem
**Time: 0:20 - 0:50 (30 seconds)**

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

### What to Say:
**[Show timeline diagram]**

> "Here's what happens today. When an app crashes, we get crash reports from MetricKit **24 to 48 hours later**. And all we get is a stack trace."

**[Point to stack trace box]**

> "This tells us WHERE the code failed. Line 47, checkout.swift. Cool. But it doesn't tell us WHAT the user was doing."

**[Show examples with hands]**
- "Did they enter invalid data?"
- "Did they tap a button twice?"
- "Was it their first purchase or their hundredth?"

> "And the worst part? ANR events—when the app freezes but doesn't crash—these often go completely unreported. The user just force-quits, frustrated, and we never know."

---

# SLIDE 3: The Solution - 3 Layers
**Time: 0:50 - 1:30 (40 seconds)**

### Visual:
```
┌─────────────────────────────────────────────────────┐
│              Our Solution: 3 Layers                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Layer 1: FAST PATH ⚡                             │
│  ┌──────────────────────────────────────┐          │
│  │ UserDefaults Marker                  │          │
│  │ • Armed on foreground                │          │
│  │ • Completed on background            │          │
│  │ • Detection: 0ms (INSTANT!)          │          │
│  │ • Emits: $unexpected_exit            │          │
│  └──────────────────────────────────────┘          │
│                                                     │
│  Layer 2: RICH PATH 📊                             │
│  ┌──────────────────────────────────────┐          │
│  │ MetricKit Diagnostics (iOS 14+)      │          │
│  │ • OS-provided crash reports          │          │
│  │ • Detection: ~24 hours               │          │
│  │ • Emits: $crash (with signal/type)   │          │
│  └──────────────────────────────────────┘          │
│                                                     │
│  Layer 3: LIVE PATH 🚨                             │
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

### What to Say:
**[Show architecture diagram]**

> "So we built three-layer detection:"

**[Point to Layer 1 - move cursor to highlight it]**

> "**Layer 1: The Fast Path.** We use a UserDefaults marker. When the app goes to foreground, we arm it. When it goes to background, we mark it complete. If it doesn't complete? Crash detected. **Instantly**. On the next launch."

**[Point to Layer 2]**

> "**Layer 2: The Rich Path.** We hook into iOS MetricKit to get the detailed crash diagnostics—signal type, exception codes. We correlate these with our detected crashes to upgrade them with full metadata."

**[Point to Layer 3]**

> "**Layer 3: Live Detection.** An ANR watchdog running on a background thread that pings the main thread every 50 milliseconds. If the main thread doesn't respond within 250 milliseconds, we detect the hang **in real-time**."

**[Point to bottom - emphasize this]**

> "And the killer feature? **Every event includes the Session Replay ID**. Engineers can click directly to watch what happened."

---

# SLIDE 4: DEMO TIME
**Time: 1:30 - 2:10 (40 seconds)**

### Visual:
**Live screen recording:**
1. Xcode with demo app
2. Show app running with Session Replay
3. Trigger simulated crash
4. Force quit app
5. Restart → console shows detection
6. Dashboard → event appears
7. Click replay → watch crash happen

### What to Say:
**[Switch to Xcode]**

> "Let me show you this working. I've got a demo app here with Session Replay enabled."

**[Show the code snippet]**
```swift
mixpanel.debugSimulateCrash()
```

> "I'm going to simulate a crash using our debug utility. Watch this."

**[Run app, trigger crash, force quit - be deliberate]**

> "Boom. Crashed."

**[Restart app, show console immediately]**

> "Now I restart the app and..."

**[Point to console output]**
```
[Mixpanel] Detected unexpected exit: sessionId=ABC-123-XYZ, replayId=replay-789
[Mixpanel] Emitted $unexpected_exit event
```

> "There it is! Crash detected **instantly**. Event emitted with the replay ID."

**[Switch to dashboard tab]**

> "Now in the dashboard, I can see the crash event..."

**[Click on event, show properties panel]**

> "...with all the metadata: session ID, replay ID, crash timestamp, app version."

**[Click 'View Session Replay' button]**

> "And when I click 'View Session Replay'..."

**[Session replay plays - let it play for 2-3 seconds showing the crash]**

> "I can **watch exactly what the user did** that caused the crash. This is a game-changer."

---

# SLIDE 5: The Impact
**Time: 2:10 - 2:50 (40 seconds)**

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
└─────────────────────────────────────────────────────────┘
```

### What to Say:
**[Show Before/After comparison slide]**

> "So what does this mean?"

**[Read through comparison with emphasis]**

> "**Before:** 24-48 hour delay, stack trace only, 'cannot reproduce.'"

> "**After:** Instant detection, full session replay, fix it the same day."

**[Lean in with enthusiasm]**

> "This turns crashes from black boxes into visual debugging sessions. Engineering teams can:"

**[Count on fingers as you say each]**
- ✅ "Debug with **full user context**"
- ✅ "Catch **ANR events** that were invisible before"  
- ✅ "Prioritize crashes that have **replay footage**"
- ✅ "Reduce time-to-resolution from **days to minutes**"

**[Add the bonus point]**

> "And here's a bonus: using **remote event trigger settings**, you can automatically start Session Replay recording when specific events happen—like entering a checkout flow. So even if replay wasn't initially running, it captures the activity right before a crash. **No more blind spots** in critical user journeys."

---

# SLIDE 6: Technical Highlights
**Time: 2:50 - 3:10 (20 seconds)**

### Visual:
```
┌──────────────────────────────────────────────────┐
│         Technical Achievements                   │
├──────────────────────────────────────────────────┤
│                                                  │
│  ✅ Zero external dependencies                  │
│  ✅ Thread-safe architecture                    │
│  ✅ Crash-loop protection                       │
│  ✅ iOS 13+ compatible                          │
│  ✅ Production-ready                            │
│                                                  │
│  📊 Stats: ~1,337 lines, 5 new files            │
│                                                  │
└──────────────────────────────────────────────────┘
```

### What to Say:
**[Quick confident summary]**

> "From a technical standpoint, this is solid: **Zero external dependencies**—built entirely on native iOS APIs. **Thread-safe** with dedicated queue. **Crash-loop protection** built in. Works **iOS 13+**. And it's **production-ready**."

**[Quick stat]**

> "About 1,300 lines of code, built during this hackathon. Ready to test."

---

# SLIDE 7: Real-World Impact
**Time: 3:10 - 3:40 (30 seconds)**

### Visual:
```
┌──────────────────────────────────────────────────┐
│           Real-World Scenario                    │
├──────────────────────────────────────────────────┤
│                                                  │
│  E-commerce App Crash:                          │
│                                                  │
│  WITHOUT this feature:                          │
│  • User: "Crashed at checkout"                  │
│  • Log: NSInvalidArgumentException              │
│  • Engineer: "Cannot reproduce"                 │
│  • Resolution: 5 days (or never)                │
│  • Impact: ❌ Lost revenue                      │
│                                                  │
│  WITH this feature:                             │
│  • Crash detected instantly                     │
│  • Engineer watches session replay              │
│  • Sees: User entered emoji in zip code         │
│  • Fix: Add input validation                    │
│  • Resolution: ⚡ 2 hours                       │
│  • Impact: ✅ Happy customer                    │
│                                                  │
└──────────────────────────────────────────────────┘
```

### What to Say:
**[Tell the story]**

> "Here's a real scenario: E-commerce app crashes at checkout."

**[WITHOUT side]**

> "Without this feature? We get a stack trace, can't reproduce it, might take days or never get fixed. Customer is lost. Revenue lost."

**[WITH side - show the contrast]**

> "With this feature? Crash detected instantly. Engineer watches the replay. **Sees the user entered an emoji in the zip code field.** Adds input validation. Fixed in 2 hours. Customer completes purchase next time."

**[Emphasize]**

> "From lost revenue to saved customer. That's the impact."

---

# SLIDE 8: Call to Action
**Time: 3:40 - 4:00 (20 seconds)**

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

### What to Say:
**[Back to you, confident and direct]**

> "We built this entirely on native iOS foundations—no external dependencies. It's ready for production testing on the Swift SDK."

**[Pause for emphasis]**

> "The code is done. The value is clear. Teams are already asking for this capability."

**[Final line with energy - look directly at camera]**

> "Let's ship this and turn 'cannot reproduce' into 'fixed in one PR.' Thank you!"

**[Hold for 1 second, then end]**

---

## For 3-Minute Loom Version (STRICT)

Use only these slides:
- **SLIDE 1**: Hook (20s) - Show the problem
- **SLIDE 2**: Problem (30s) - Why it sucks
- **SLIDE 3**: Solution (40s) - 3 layers
- **SLIDE 4**: Demo (40s) - Prove it works
- **SLIDE 5**: Impact (40s) - Before/after + event triggers
- **SLIDE 8**: CTA (20s) - Let's ship it

**Total: 2:50** (10 seconds buffer)

Skip Slides 6 & 7 for timing.

---

## Recording Tips

### Voice & Energy:
- **Speak clearly with energy** - it's a hackathon!
- **Pause after key points** - "watch it happen" [pause]
- **Vary your tone** - frustration for problems, excitement for solutions
- **Don't rush** - 3 minutes is enough if you're clear

### Screen Work:
- **Close unnecessary tabs** - clean desktop
- **Use cursor to highlight** - circle important code/text
- **Zoom if needed** - Cmd + Plus in Xcode
- **Smooth transitions** - don't jerk between windows

### Demo Insurance:
- **Practice 2-3 times** before recording
- **Have backup screenshots** ready if demo breaks
- **Test crash simulation** beforehand
- **Pre-load dashboard** with sample event

### Key Phrases to Emphasize:

**Say with frustration:**
- "Cannot reproduce"
- "24-48 hour delay"
- "Stack trace only"

**Say with excitement:**
- "**Instant** detection"
- "**Watch** it happen"
- "**Game-changer**"
- "**Fixed in one PR**"

**Say with confidence:**
- "Production-ready"
- "Let's ship this"

---

## Backup Q&A (If Demo Extends or Questions)

### "Why not just use MetricKit?"
> "MetricKit has two problems: 24-48 hour delay and no user context. We use UserDefaults for instant detection, then MetricKit as enrichment. Plus we link to session replay which MetricKit can't do."

### "What about performance?"
> "Minimal. UserDefaults write is under 1ms. ANR watchdog runs on background thread with 50ms intervals. Dedicated queue prevents blocking tracking operations."

### "What if Session Replay isn't recording?"
> "Use remote event trigger settings to automatically start Session Replay when specific events happen—like entering checkout. Captures critical moments before crashes even if replay wasn't initially running."

---

## Pre-Flight Checklist

**Content Ready:**
- [ ] Know the hook (cannot reproduce)
- [ ] Know the 3 layers (fast/rich/live)
- [ ] Know the impact story (emoji in zip code)
- [ ] Know the CTA (let's ship this)

**Demo Ready:**
- [ ] App built and launches
- [ ] `debugSimulateCrash()` tested
- [ ] Dashboard has sample event
- [ ] Session Replay link works

**Recording Ready:**
- [ ] Quiet room
- [ ] Good lighting
- [ ] Audio check done
- [ ] Timer set for 3:00
- [ ] Water nearby
- [ ] Confident mindset ✅

---

## Final Reminders

**Your Story:**
Problem → Solution → Demo → Impact → Call to Action

**Your Message:**
Turn crashes from debugging nightmares into visual learning opportunities.

**Your Goal:**
Get approval to beta test and ship this feature.

**Your Energy:**
Confident, enthusiastic, clear. You built something awesome!

---

## Emergency Fallback Lines

**If demo crashes (ironically):**
> "Well, this would be a perfect test case! But I have screenshots showing the full flow..."

**If you lose your place:**
> "The key point is: instant detection with visual context. That's the game-changer."

**If running over time:**
> "Bottom line: production-ready crash detection with session replay linking. Let's ship it."

---

# 🚀 NOW GO RECORD!

You've got this. The feature is solid. The value is clear. Just tell the story.

**From "Cannot Reproduce" to "Fixed in One PR"** ✨
