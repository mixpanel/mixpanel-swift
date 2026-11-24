# AGENTS.md — Mixpanel Swift SDK

Canonical instructions for AI coding agents (Claude Code, Cursor, Copilot, Codex, etc.).
`CLAUDE.md` imports this file via `@AGENTS.md` — edit **this** file. Every fact below was
verified against the code at v6.5.1; when code and doc disagree, trust the code and fix this file.

**Mixpanel Swift SDK** — analytics library for Apple platforms (iOS, tvOS, macOS, watchOS).
Ships via SPM, CocoaPods, and Carthage. ~8,000 lines across 25 Swift files, flat in `Sources/`.
Prioritizes: never crash the host app, thread safety, backward compatibility.

## Project configuration

- Platforms: **iOS 12+, tvOS 12+, macOS 10.13+, watchOS 4+** (`Package.swift`, podspec agree)
- `swift-tools-version: 5.3`; podspec `swift_version = '5.0'`; code must stay valid for
  **Swift < 6.1** — no trailing commas in call sites (enforced by the local pre-commit hook;
  the CI check for it is informational only)
- Dependencies (only two, `Package.swift`): `mixpanel-swift-common` (event bridge),
  `json-logic-swift`. **Do not add dependencies.**
- The SDK version lives in **four synced places** (bumped together by `prepare-release.yml` —
  do not restate the value elsewhere): `Mixpanel-swift.podspec` (`s.version`), `Info.plist`
  (`CFBundleShortVersionString`), `Sources/AutomaticProperties.swift` (`libVersion()` — the
  current-version oracle the release workflow greps), `scripts/generate_docs.sh`
  (`--module-version`). `Package.swift` carries no version. Release tags have **no `v`
  prefix** (since 6.4.0).

## Build, test, lint

Tests live in the **demo app project**, not SPM — there is no `.testTarget` in `Package.swift`.

```bash
# iOS build + test (primary; what CI runs, from MixpanelDemo/).
# set -o pipefail is essential — without it xcpretty's exit code masks xcodebuild failures.
cd MixpanelDemo && set -o pipefail && xcodebuild -scheme MixpanelDemo -derivedDataPath Build/ \
  -destination 'name=iPhone 17 Pro,OS=latest' -configuration Debug \
  ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES -enableCodeCoverage YES \
  clean build test | xcpretty -c

# macOS (CI: macOS.yml)
cd MixpanelDemo && set -o pipefail && xcodebuild -scheme MixpanelDemoMac -derivedDataPath Build/ \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES -enableCodeCoverage YES \
  clean build test | xcpretty -c

# tvOS (CI: tvOS.yml)
cd MixpanelDemo && set -o pipefail && xcodebuild -scheme MixpanelDemoTV -derivedDataPath Build/ \
  -destination 'platform=tvOS Simulator,name=Apple TV' -configuration Debug \
  ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES -enableCodeCoverage YES \
  clean build test | xcpretty -c

# SPM compile check (works locally; not used in CI)
swift build

# Formatting — Apple swift-format, NOT SwiftLint (there is no .swiftlint.yml)
sh ./scripts/format-swift.sh <files...>   # or no args to format the whole repo
```

- Config: `.swift-format` (lineLength **120**, 4-space indent, `trailingCommas: neverUsed`,
  `indentSwitchCaseLabels: true`). A `.githooks/pre-commit` hook checks staged files.
- CI (`pr-checks.yml`): **PR titles must match `^(feat|fix|chore|release): .+$`** (blocking).
  The entire `format-check` job — swift-format diff AND the trailing-comma scan — is
  `continue-on-error: true`, i.e. informational only; the pre-commit hook is the real gate.
- Scheme gotcha: only `MixpanelDemo` and the watch schemes are **shared**;
  `MixpanelDemoMac`/`MixpanelDemoTV` are targets relying on Xcode's implicit scheme creation.
- No watchOS test target or CI exists.

### Testing conventions

- iOS suite `MixpanelDemo/MixpanelDemoTests/` (16 files) is the superset; Mac mirrors part of
  it (9 files, separate copy of the base class); TV has 3 files that do **not** use the base class.
- Base class `MixpanelBaseTests` helpers take the instance as an argument:
  `waitForTrackingQueue(_ mixpanel:)`, `flushAndWaitForTrackingQueue(_ mixpanel:)`,
  plus `randomId()`, `removeDBfile(_ token:)` (call in teardown to delete SQLite files),
  `waitForAsyncTasks()`, and queue readers (`eventQueue(token:)`, `peopleQueue(token:)`, …).

## Architecture

Producer-consumer over SQLite; **two network paths** sharing the `Network` base class:

```
Mixpanel (static facade) → MixpanelManager registry → MixpanelInstance (per instanceName)
  ├─ track ─→ trackingQueue ─→ Track (builds envelope) ─→ MixpanelPersistence ─→ MPDB (SQLite)
  ├─ flush ─→ trackingQueue (load batches) ─→ networkQueue ─→ Flush ─→ FlushRequest ─→ URLSession
  └─ flags ─→ FeatureFlagManager ─→ Network directly (async GET /flags/, Basic auth)
```

- **Flush path** (`Flush`/`FlushRequest`): batches of ≤50, gzip (configurable), primary→backup-host
  failover, retry backoff with `Retry-After`, **synchronous** send (semaphore, 120 s timeout).
  On success, rows are deleted by id back on `trackingQueue`.
- **Flags path** (`FeatureFlags.swift`): does NOT go through `Flush` — no gzip/backoff/backup-host.
  Auth is `Basic base64("<token>:")`. Second endpoint: POST `/flags/<id>/first-time-events`.
  ⚠️ `serverURL.didSet` on the instance updates only the flush path; `FeatureFlagManager`
  snapshots `serverURL` at init.
- **Persistence**: `MPDB` — one SQLite file `<sanitizedInstanceName>_MPDB.sqlite` (Library dir
  on iOS, Caches elsewhere), WAL mode, tables `mixpanel_<sanitizedInstanceName>_{events,people,groups}`
  (keyed by **instanceName**, which defaults to the token but can differ) with schema
  `(id, data blob, time real, flag integer)`; `flag` marks un-identified People rows, flipped by
  `identifyPeople`. `MixpanelPersistence` also owns UserDefaults (suite `"Mixpanel"`, keys
  prefixed `mixpanel-<instanceName>-`) for identity, super properties, timed events, opt-out,
  and the flags blob. Legacy NSKeyedArchiver→SQLite migration runs at init.
- **Concurrency**: per-instance **serial** `trackingQueue` and `networkQueue` (labels
  `com.mixpanel.<token>.tracking)`/`.network)` — the stray `)` is in the code);
  `ReadWriteLock` = concurrent DispatchQueue with barrier writes; flush `Timer` on the main
  queue, default interval **60 s** (0 disables; setting it also flushes immediately);
  `flushBatchSize` clamps to 50 (`APIConstants.maxBatchSize`). No OperationQueue anywhere.
- **Lifecycle**: didBecomeActive starts the timer; willResignActive stops it; iOS/tvOS
  didEnterBackground takes a background task + full flush (`flushOnBackground` default true).
  No lifecycle listeners on watchOS. On iOS/tvOS the listener setup skips app extensions
  (which instead flush on every track), but the macOS branch registers its `NSApplication`
  observers unconditionally.

## Public API & conventions

- **Singleton per `instanceName`** (defaults to the token), registry in `MixpanelManager`;
  most recently initialized becomes `mainInstance()`. `mainInstance()` **asserts in debug on
  device builds** if uninitialized (the assert is `#if !targetEnvironment(simulator)`, so
  simulator runs — including the test suite — skip it) — `safeMainInstance()` is the
  non-asserting variant.
- `MixpanelOptions` is a plain `public init` with ~15 defaulted params — **not a builder**.
  ⚠️ Default divergence: `useGzipCompression` defaults **true** via `MixpanelOptions` but
  **false** via the legacy `initialize(token:...)` overloads.
- Platform-split init: on iOS/tvOS/visionOS `trackAutomaticEvents:` is required (no default);
  on macOS/watchOS it defaults to `false`.
- **Error philosophy — fail soft + log**: catch, `MixpanelLogger.warn/error`, return nil/false;
  never crash release builds. `MPAssert`/`assertPropertyTypes` trap **only in debug**.
  Logging is off by default (`loggingEnabled = true` to enable).
- Visibility: `open` for customer-overridable surface (`Mixpanel`, `MixpanelInstance`, `People`,
  `Group`, `Autocapture`); `public` for protocols/structs; `internal` for machinery
  (`Track`, `Flush`, `Network`, `MPDB`, `MixpanelPersistence`, `FeatureFlagManager`).
  Delegates are `AnyObject`-constrained and held `weak` — with one exception:
  `ProxyServerConfig` is a struct whose `delegate` is a strong `let` (and `MixpanelOptions`
  retains the config), so a proxy delegate's lifetime is tied to the options object even
  though `MixpanelInstance.proxyServerDelegate` itself is weak.
- Locked state uses backing `_foo` + computed `foo` under `ReadWriteLock`
  (snapshot under lock → mutate copy → write back).
- Platform gates to respect: automatic events, `minimumSessionDuration`/`maximumSessionDuration`
  do **not exist on watchOS**; reachability/`$wifi`/CoreTelephony are iOS-only
  (`!targetEnvironment(macCatalyst)`); `Autocapture` is manual screen-tracking API only
  (no UIKit hooking, no platform gate).
- **New-source-file gotcha (two manifests)**: adding a file to `Sources/` is not enough.
  (1) The podspec ships `Sources/*.swift` on iOS but an explicit `base_source_files` list on
  tvOS/macOS/watchOS — update it or non-iOS pods silently miss the file. (2) `Mixpanel.xcodeproj`
  enumerates every source in its build phases and is what Carthage builds
  (`carthage build --no-skip-current`) — add the file there too or Carthage frameworks omit it.

## Release process

Three manual `workflow_dispatch` workflows, driven by `.github/modules.json`
(module `analytics`: podspec path, `version_files`, empty `tag_prefix`).
**`scripts/release.py` is dead code — do not use it** (it tags with a `v` prefix, contradicting
the real process).

1. **`prepare-release.yml`** — bumps the four version locations, regenerates Jazzy `docs/`,
   prepends the changelog, opens a `release/<version>` PR (idempotent; title matches the PR gate).
2. **`release-spm.yml`** (master only, `release` environment) — validates versions everywhere,
   `pod lib lint`, Carthage smoke build, creates the annotated tag (immutable — never re-tag),
   drafts the GitHub Release from the changelog.
3. **`release-cocoapod.yml`** (`release-cocoapods` environment, manual approval;
   secret `COCOAPODS_TRUNK_TOKEN`) — re-validates inside the tag, `pod trunk push`.
   Finish by publishing the draft GitHub Release.

## Validation before a PR

1. Build + test iOS (and macOS/tvOS when the change is platform-relevant).
2. `sh ./scripts/format-swift.sh` on changed files (or rely on the pre-commit hook).
3. PR title matches `^(feat|fix|chore|release): .+$`.
4. No new dependencies; no breaking changes to `open`/`public` API.
5. New source file? Update BOTH the podspec `base_source_files` list AND the
   `Mixpanel.xcodeproj` source build phases (Carthage builds the xcodeproj).
6. New tests where behavior changed (iOS suite first; mirror to Mac when applicable).
