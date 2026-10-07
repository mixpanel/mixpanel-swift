Last tag: 6.7.0
## [6.8.0](https://github.com/mixpanel/mixpanel-swift/tree/6.8.0) (2026-10-07)

### Fixes

- NSMallocException crash in flush pipeline (#791)
  - Every flush (timer, background and manual) now sends the whole queue in batches of up to 50, one batch in memory at a time. Previously the timer sent one batch per tick, so a large offline backlog now goes out as back-to-back requests in one pass. A `flush(completion:)` called while one is running completes after a follow-up flush, not immediately.
  - Setting `flushInterval` to `0` (manual mode) no longer triggers a flush. `MixpanelInstance.flushInterval` is deprecated; set it in `MixpanelOptions` instead.
  - `reset()` no longer deletes queued events, group updates or identified people updates. They are sent under the identity they were tracked with. Only people updates queued before `identify()` are dropped. Use `optOutTracking()` if you need to purge queued data.
  - Queued people updates keep the `$distinct_id` they were tracked with and are no longer re-stamped with the current identity at flush. For example, `identify("A")`, then `people.set(...)`, then `identify("B")` before a flush now sends as A, not B.
  - Queued `$ae_` events are now sent even if `trackAutomaticEventsEnabled` is turned off later, and unreadable rows in the local database are deleted when read instead of blocking the queue.
  - Upgrade note: people updates queued before 6.8.0 that lack a `$distinct_id`, and legacy pre-SQLite anonymous people updates, may take the current identity at flush time once, at upgrade.
- cancel pending dead-click check on any new tap (#788)
- reset rage-click history after emission (#790)

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.7.0...6.8.0)

Last tag: 6.6.1
## [6.7.0](https://github.com/mixpanel/mixpanel-swift/tree/6.7.0) (2026-09-09)

### Features

- Implement semver and date custom operators for flags runtime events (#763) ([#763](https://github.com/mixpanel/mixpanel-swift/pull/763))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.6.1...6.7.0)

Last tag: 6.6.0
## [6.6.1](https://github.com/mixpanel/mixpanel-swift/tree/6.6.1) (2026-09-08)

### Fixes

- read the React Native nativeID on the new architecture (#781) ([#781](https://github.com/mixpanel/mixpanel-swift/pull/781))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.6.0...6.6.1)

Last tag: 6.5.1
## [6.6.0](https://github.com/mixpanel/mixpanel-swift/tree/6.6.0) (2026-09-02)

### Features

- autocapture (beta) — clicks, rage clicks and dead clicks (#776) ([#776](https://github.com/mixpanel/mixpanel-swift/pull/776))

### Fixes

- Added scene delegate functionality to sample app (#769) ([#769](https://github.com/mixpanel/mixpanel-swift/pull/769))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.5.1...6.6.0)

Last tag: 6.5.0
## [6.5.1](https://github.com/mixpanel/mixpanel-swift/tree/6.5.1) (2026-07-15)

### Fixes

- Reduce flush and DB memory spikes (#751) ([#751](https://github.com/mixpanel/mixpanel-swift/pull/751))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.5.0...6.5.1)

Last tag: 6.4.1
## [6.5.0](https://github.com/mixpanel/mixpanel-swift/tree/6.5.0) (2026-07-06)

### Features

- add backupHost support for failover (parity with Android SDK) (#737) ([#737](https://github.com/mixpanel/mixpanel-swift/pull/737))
- extend Source.fallback with FallbackReason (SDK-79) (#745) ([#745](https://github.com/mixpanel/mixpanel-swift/pull/745))
- add trackScreenView and trackScreenLeave tracking methods (#741) ([#741](https://github.com/mixpanel/mixpanel-swift/pull/741))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.4.1...6.5.0)

Last tag: 6.4.0
## [6.4.1](https://github.com/mixpanel/mixpanel-swift/tree/6.4.1) (2026-06-10)

### Features

- add MixpanelOptions.excludeProperties to strip event keys (#734) ([#734](https://github.com/mixpanel/mixpanel-swift/pull/734))

### Fixes

- add missing comma in .swift-format config (#736) ([#736](https://github.com/mixpanel/mixpanel-swift/pull/736))
- global accent color issue (#727) ([#727](https://github.com/mixpanel/mixpanel-swift/pull/727))

### Chores

- align changelog extraction with rest of SDK fleet (#735) ([#735](https://github.com/mixpanel/mixpanel-swift/pull/735))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.4.0...6.4.1)

# Changelog

Last tag: 6.3.0
## [6.4.0](https://github.com/mixpanel/mixpanel-swift/tree/6.4.0) (2026-05-07)

### Features

- Feature Flag persistence (#723) ([#723](https://github.com/mixpanel/mixpanel-swift/pull/723))

### Chores

- add 30-day dependabot cooldown (#703) ([#703](https://github.com/mixpanel/mixpanel-swift/pull/703))
- Standardize the release process (#716) ([#716](https://github.com/mixpanel/mixpanel-swift/pull/716))

[Full Changelog](https://github.com/mixpanel/mixpanel-swift/compare/6.3.0...6.4.0)

