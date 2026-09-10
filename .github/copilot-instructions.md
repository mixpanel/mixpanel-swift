# Copilot Instructions for mixpanel-swift

The canonical, verified agent instructions live in the repo root **`AGENTS.md`** — read that
file first. Copilot surfaces that support AGENTS.md load it automatically; this file exists for
the surfaces that only read copilot-instructions.md, and repeats just the essentials.

## Essentials

- **Mixpanel Swift SDK** for iOS 12+, tvOS 12+, macOS 10.13+, watchOS 4+.
  `swift-tools-version: 5.3`; keep code valid for Swift < 6.1 (no trailing commas in calls).
- ~8,000 lines across 25 Swift files, flat in `Sources/`. Two dependencies only
  (`mixpanel-swift-common`, `json-logic-swift`) — do not add more.
- **Tests live in `MixpanelDemo/` (Xcode project), not SPM.** Primary command (from `MixpanelDemo/`):

  ```bash
  set -o pipefail && xcodebuild -scheme MixpanelDemo -derivedDataPath Build/ \
    -destination 'name=iPhone 17 Pro,OS=latest' -configuration Debug \
    ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=YES -enableCodeCoverage YES \
    clean build test | xcpretty -c
  ```

  (`set -o pipefail` is required — otherwise xcpretty's exit code hides xcodebuild failures.)

  macOS: `-scheme MixpanelDemoMac -destination 'platform=macOS,arch=arm64'`;
  tvOS: `-scheme MixpanelDemoTV -destination 'platform=tvOS Simulator,name=Apple TV'`.
- **Formatting is Apple swift-format** (`.swift-format`: lineLength 120, 4-space indent) via
  `sh ./scripts/format-swift.sh`. There is **no SwiftLint** in this repo.
- **PR titles must match `^(feat|fix|chore|release): .+$`** — a blocking CI check.
- Error philosophy: never crash the host app — fail soft, log via `MixpanelLogger`.
  Debug-only assertions (`MPAssert`) are fine; no traps in release paths.
- Adding a source file? Also add it to BOTH the podspec `base_source_files` list
  (tvOS/macOS/watchOS subspecs enumerate files explicitly) AND the `Mixpanel.xcodeproj`
  source build phases (Carthage builds the xcodeproj and would otherwise omit the file).
- The SDK version is synced across the podspec, `Info.plist`,
  `Sources/AutomaticProperties.swift` `libVersion()` (the authoritative copy), and
  `scripts/generate_docs.sh` — version bumps are done by the `prepare-release.yml` workflow,
  not by hand, and `scripts/release.py` is dead code.

For architecture (two network paths, SQLite persistence, queue/lock model), testing patterns
(`MixpanelBaseTests` helpers), platform gates (no automatic events on watchOS), and the
three-step release process, see `AGENTS.md`.
