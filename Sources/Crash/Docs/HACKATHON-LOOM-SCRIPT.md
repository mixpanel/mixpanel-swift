# 🎬 Loom Video Script (3 Minutes)

## Pre-Recording Checklist
- [ ] Open Xcode with crash detection code
- [ ] Have demo app ready to run
- [ ] Open Mixpanel dashboard in another tab
- [ ] Have terminal ready with build output
- [ ] Prepare simulated crash scenario

---

## Script with Timestamps

### 0:00 - 0:20 | THE HOOK (20 seconds)

**[Show Mixpanel dashboard with crash reports]**

> "Hey everyone! Quick question: How many times have you seen this?"

**[Show stack trace with no context]**

> "A crash report that just says 'NSInvalidArgumentException in checkout flow' and your only response is..." 

**[Type in ticket]** "Cannot reproduce."

**[Pause]**

> "Yeah. Me too. What if I told you we could **watch** every crash happen? Let me show you."

---

### 0:20 - 1:00 | THE PROBLEM (40 seconds)

**[Switch to slide/diagram showing BEFORE timeline]**

> "Here's the problem. When an app crashes today, we get crash reports from MetricKit 24 to 48 hours later. And all we get is a stack trace."

**[Point to stack trace]**

> "This tells us WHERE the code failed. Line 47, checkout.swift. Cool. But it doesn't tell us WHAT the user was doing."

**[Show examples]**
- "Did they enter invalid data?"
- "Did they tap a button twice?"  
- "Was it their first purchase or their hundredth?"

> "And the worst part? ANR events—when the app freezes but doesn't crash—these often go completely unreported. The user just force-quits, frustrated, and we never know."

---

### 1:00 - 1:40 | THE SOLUTION (40 seconds)

**[Switch to architecture diagram]**

> "So we built three-layer crash detection for iOS:"

**[Point to each layer as you explain]**

> "**Layer 1: The Fast Path.** We use a UserDefaults marker. When the app goes to foreground, we arm it. When it goes to background, we mark it complete. If it doesn't complete? Crash detected. Instantly. On the next launch."

> "**Layer 2: The Rich Path.** We hook into iOS MetricKit to get the detailed crash diagnostics—signal type, exception codes. We correlate these with our detected crashes to upgrade them with full metadata."

> "**Layer 3: Live Detection.** An ANR watchdog running on a background thread that pings the main thread every 50 milliseconds. If the main thread doesn't respond within 250 milliseconds, we detect the hang in real-time."

> "And the killer feature? Every event includes the Session Replay ID."

---

### 1:40 - 2:20 | THE DEMO (40 seconds)

**[Switch to Xcode showing demo app]**

> "Let me show you. I've got a demo app running here with Session Replay enabled."

**[Show code]**

```swift
// Simulate a crash for demo
mixpanel.debugSimulateCrash()
```

> "I'm going to simulate a crash using our debug utility. Watch this."

**[Run app, trigger crash, force quit]**

> "Boom. Crashed."

**[Restart app]**

> "Now I restart the app and..."

**[Show console log]**

```
[Mixpanel] Detected unexpected exit: sessionId=ABC-123-XYZ, replayId=replay-789
[Mixpanel] Emitted $unexpected_exit event
```

> "There it is! Crash detected instantly. Event emitted with the replay ID."

**[Switch to Mixpanel dashboard]**

> "Now in the dashboard, I can see the crash event..."

**[Click on event, show properties]**

> "...with all the metadata: session ID, replay ID, crash timestamp, app version."

**[Click 'View Session Replay' link]**

> "And when I click 'View Session Replay'..."

**[Session replay plays showing the crash]**

> "I can **watch exactly what the user did** that caused the crash. This is a game-changer."

---

### 2:20 - 2:50 | THE IMPACT (30 seconds)

**[Switch back to yourself/slides]**

> "So what does this mean?"

**[Show BEFORE/AFTER comparison]**

> "**Before:** 24-48 hour delay, stack trace only, 'cannot reproduce.'

> **After:** Instant detection, full session replay, fix it the same day."

**[Show metrics slide]**

> "This turns crashes from black boxes into visual debugging sessions. Engineering teams can:"

- ✅ Debug with full user context
- ✅ Catch ANR events that were invisible before  
- ✅ Prioritize crashes that have replay footage
- ✅ Reduce time-to-resolution from **days to minutes**

> "And here's a bonus: using **remote event trigger settings**, you can automatically start Session Replay recording when specific events happen—like entering a checkout flow. So even if replay wasn't initially running, it captures the activity right before a crash. That means no more blind spots in critical user journeys."

---

### 2:50 - 3:00 | THE CLOSE (10 seconds)

**[Back to you, confident close]**

> "We built this entirely on native iOS foundations—no external dependencies. It's ready for production testing on the Swift SDK."

**[Final line with energy]**

> "Let's ship this and turn 'cannot reproduce' into 'fixed in one PR.' Thank you!"

**[End screen: Project title + your name]**

---

## Visual Elements to Prepare

### Slides/Diagrams to Show:
1. **BEFORE Timeline** - showing 24-48 hour delay
2. **Architecture Diagram** - 3 layers visual
3. **AFTER Timeline** - showing instant detection
4. **Metrics Comparison** - Before/After stats

### Code to Show:
1. `SessionRecoveryManager.swift` - marker logic (lines 65-92)
2. `ANRWatchdog.swift` - ping logic (lines 45-80)
3. Demo app crash trigger
4. Console output showing detection

### Dashboard to Show:
1. Event list with `$unexpected_exit`
2. Event properties detail view
3. Session Replay player

---

## Pro Tips for Recording

### Voice & Pacing:
- **Speak clearly and with energy** (it's a hackathon!)
- **Pause after key points** (let them sink in)
- **Emphasize the pain points** ("Cannot reproduce" with frustration)
- **Emphasize the wins** ("Instant detection" with excitement)

### Screen Recording:
- **Close unnecessary tabs/apps** (clean desktop)
- **Zoom in on important code** (Cmd + Plus in Xcode)
- **Use cursor to highlight** (circle important lines)
- **Keep movements smooth** (no jerky scrolling)

### Editing:
- **Add text overlays** for key stats (if time permits)
- **Highlight sections** with colored boxes
- **Speed up boring parts** (app launching, loading)
- **Add transitions** between sections

---

## Backup Talking Points (If Needed)

### If asked "Why is this better than just using MetricKit?"
> "MetricKit is great, but it has two problems: timing and context. It delivers reports 24-48 hours later, and it only gives you stack traces. Our solution detects crashes instantly on next launch AND links them to session replay for full visual context. We use MetricKit as enrichment, not the primary detection mechanism."

### If asked "What about performance impact?"
> "Minimal. The UserDefaults marker is a single key-value write. The ANR watchdog runs on a background thread with 50ms ping intervals—that's 20 pings per second, negligible CPU usage. And we use a dedicated serial queue for all metrics operations so it never blocks the tracking queue."

### If asked "What about crash loops?"
> "Great question! We have three layers of protection: max retry count of 3 attempts, a cap of 10 pending exits, and automatic expiration after 24 hours. If something's causing a crash loop, we'll detect it once or twice but won't spam the system."

### If asked "Can this work without Session Replay?"
> "Absolutely! If Session Replay isn't enabled, we still detect the crash and emit the event—it just won't have a replay_id. The crash detection is valuable on its own, but the session replay link is what makes it **magical**."

### If asked "What if Session Replay isn't recording when the crash happens?"
> "Great question! That's where remote event trigger settings come in. You can configure Session Replay to automatically start recording when specific events happen—like when a user enters a checkout flow, starts a complex operation, or hits a known problematic area. This means even if replay wasn't initially running, it captures the critical moments right before a crash. No more blind spots in important user journeys."

---

## Key Phrases to Use

**Problem phrases** (say with frustration):
- "Cannot reproduce"
- "Black box debugging"
- "24-48 hour delay"
- "Silent failures"

**Solution phrases** (say with excitement):
- "Instant detection"
- "Visual debugging"
- "Watch it happen"
- "Full context"
- "Game-changer"

**Impact phrases** (say with confidence):
- "Days to minutes"
- "Fixed in one PR"
- "Turn crashes into insights"
- "Production-ready"

---

## Recording Environment

### Lighting:
- Face a window or light source
- Avoid backlighting

### Audio:
- Quiet room
- Use headphones with mic (better than laptop mic)
- Do a sound check first

### Camera (if showing yourself):
- Eye level
- Clean background
- Centered framing

---

## Post-Recording

### Share:
- [ ] Upload to Loom
- [ ] Add title: "Crash & ANR-Linked Session Replay for iOS"
- [ ] Add description with key points
- [ ] Set thumbnail to architecture diagram
- [ ] Copy link

### Accompany with:
- [ ] Link to 1-pager markdown
- [ ] Link to GitHub branch/PR
- [ ] Link to architecture diagrams

---

## Emergency Fallback (If Demo Breaks)

**Have these screenshots ready:**
1. Console output showing crash detection
2. Dashboard showing event
3. Session replay player

**Fallback line:**
> "I've got screenshots here showing the full flow. The demo gods aren't with us today, but you can see the crash was detected instantly, the event was emitted with replay ID, and engineers can click directly to watch the session."

---

## Final Checklist Before Recording

- [ ] All tabs/windows prepared and open
- [ ] Demo app built and ready
- [ ] Slides/diagrams ready to screen share
- [ ] Script printed or visible on second screen
- [ ] Timer ready (3-minute limit!)
- [ ] Water nearby (for dry mouth)
- [ ] Do a practice run (don't record yet)
- [ ] Take a deep breath
- [ ] **Hit record and crush it!** 🚀
