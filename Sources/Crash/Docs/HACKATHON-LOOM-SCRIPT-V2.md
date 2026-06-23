
# SLIDE 1: Title Slide
**Time: 0:00 - 0:10 (10 seconds)**


### What to Say:
> "Hey everyone! I'm Ketan, and today I'm going to show you how we can turn every mobile crash into a visual debugging session. Let's dive in."

**[Advance to next slide]**

---

# SLIDE 2: Crash Log Analysis
**Time: 0:10 - 0:30 (20 seconds)**


### What to Say:
**[Point to the crash log]**

> "Here's the problem we all know too well. A crash happens. We get a stack trace that tells us WHERE the code failed—line 47 in checkout.swift."

**[Point to the red X marks]**

> "But look at what's missing: **No user context**. **No visual data**. **No session info**. We have no idea WHAT the user was doing when this happened."

**[Pause for emphasis]**

> "This is the black box problem. And it's costing us time, revenue, and customer trust."

---

# SLIDE 3: Our Solution - 3 Layers
**Time: 0:30 - 1:10 (40 seconds)**```

### What to Say:
**[Gesture to all three layers]**

> "We built a three-layer detection system to solve this."

**[Point to Layer 1]**

> "**Layer 1 is the Fast Path.** A locally persisted marker that's armed on foreground, marked complete on background. If the app crashes? We detect it **instantly** on the next launch—zero milliseconds. We emit an `$unexpected_exit` event."

**[Point to Layer 2]**

> "**Layer 2 is the Rich Path.** We use iOS MetricKit to get OS-provided crash diagnostics—signal types, exception codes. This comes about 24 hours later, but it gives us the deep technical details. We emit a `$crash` event with full metadata."

**[Point to Layer 3]**

> "**Layer 3 is the Live Path.** An ANR watchdog—a background thread that continuously pings the main thread. If the main thread hangs? We detect it in **real-time** and emit an `$app_hang` event with severity levels."

**[Emphasize]**

> "Three layers. Instant detection. Full context. Every event linked to Session Replay."

---

# SLIDE 4: DEMO TIME
**Time: 1:10 - 1:50 (40 seconds)**


### What to Say:
**[Switch to demo screen - Xcode/App]**

> "Let me show you this in action."

**[Show app running]**

> "I've got a demo app here with Session Replay enabled and crash detection running."

**[Show code or trigger]**

> "I'm going to simulate a crash."

**[Trigger crash - force quit app]**

> "Boom. App crashes."

**[Restart app - show console]**

> "When I restart..."

**[Point to console output]**
```
[Mixpanel] Detected unexpected exit
[Mixpanel] Emitted $unexpected_exit event
  sessionId: ABC-123
  replayId: replay-789
```

> "There it is! **Crash detected instantly.** The event is emitted with the session ID and replay ID."

**[Switch to Mixpanel dashboard]**

> "Now in the dashboard, I can see the crash event with all the metadata..."

**[Click View Session Replay]**

> "...and when I click 'View Session Replay'..."

**[Replay plays - let it show 2-3 seconds]**

> "I can **watch exactly what the user did** that caused the crash. This changes everything."

**[Switch back to slides]**

---

# SLIDE 5: Technical Achievements
**Time: 1:50 - 2:05 (15 seconds)**


### What to Say:
**[Quick, confident delivery]**

> "From a technical standpoint, there are **Zero external dependencies**—built entirely on native iOS APIs. **Thread-safe architecture** with dedicated queues. **Crash-loop protection** built in. And it works on **iOS 13 and above**."

---

# SLIDE 6: Real-World Scenario
**Time: 2:05 - 2:35 (30 seconds)**


### What to Say:
**[Tell it like a story]**

> "Here's a real scenario. An e-commerce app crashes at checkout."

**[Point to LEFT side - WITHOUT]**

> "**Without this feature:** User reports the crash. We see the exception in the log. Engineer tries to reproduce it... can't. Ticket sits for 5 days, maybe never gets fixed. Customer is frustrated. Revenue is lost."

**[Point to RIGHT side - WITH]**

> "**With this feature:** Crash detected instantly. Engineer opens the session replay. **Sees the user entered an emoji in the zip code field.** Adds input validation. Fixed in 2 hours. Customer comes back, completes the purchase, and is happy."

**[Emphasize]**

> "From lost revenue to saved customer. That's the power of visual debugging."

---

# SLIDE 7: The Impact
**Time: 2:35 - 3:05 (30 seconds)**


### What to Say:
**[Read through the benefits with energy]**

> "This turns crashes from black boxes into visual debugging sessions."

**[Point to each checkmark]**

> "Engineering teams can **debug with full user context**. They can **catch ANR events** that were completely invisible before. They can **prioritize crashes** that have replay footage. And they can **reduce time-to-resolution from days to minutes**."

**[Point to BONUS section]**

> "And here's a bonus feature: **Remote Event Triggers**. You can automatically start Session Replay recording when specific events happen—like when a user enters a checkout flow."

**[Emphasize this]**

> "This means even if replay wasn't initially running, looking at the crash events, you can enable the replay remtotely based on the sequence of previsous events. **No more blind spots** in your most important user journeys."

---

# SLIDE 8: Thank You
**Time: 3:05 - 3:15 (10 seconds)**


### What to Say:
**[Confident close]**

SMILE

> "Let's ship this and turn 'cannot reproduce' into 'fixed in one PR.' Thank you!"


**[Hold for 1-2 seconds, then end recording]**

