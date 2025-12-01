# Copilot Instructions for mixpanel-swift

## Repository Summary

This repository contains the **Mixpanel Swift SDK** - an analytics tracking library for Apple platforms. It enables iOS, tvOS, macOS, and watchOS applications to send event and user data to Mixpanel. The SDK supports Swift Package Manager, CocoaPods, and Carthage for installation.

**Languages/Frameworks:** Swift 5.0+  
**Platforms:** iOS 12+, tvOS 11+, macOS 10.13+, watchOS 4+  
**Project Size:** ~6,000 lines of Swift code across ~25 source files

## Building and Testing

### Prerequisites
- **macOS with Xcode** is required (Apple platform SDK dependencies: UIKit, Foundation, CoreTelephony)
- **SwiftLint** is used for linting (installed via Homebrew: `brew install swiftlint`)
- **CocoaPods** is required for pod linting: `gem install cocoapods`

### Build Commands

**Swift Package Manager (does not work without Apple SDK):**
```bash
swift build  # Requires macOS with Xcode - will fail on Linux
```

**Xcode Build & Test (iOS) - PRIMARY METHOD:**
```bash
cd MixpanelDemo
# Use available simulator - check with: xcrun simctl list devices
xcodebuild \
  -scheme MixpanelDemo \
  -derivedDataPath Build/ \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -configuration Debug \
  ONLY_ACTIVE_ARCH=NO \
  ENABLE_TESTABILITY=YES \
  -enableCodeCoverage YES \
  clean build test | xcpretty -c
```

**Xcode Build & Test (macOS):**
```bash
cd MixpanelDemo
xcodebuild \
  -scheme MixpanelDemoMac \
  -derivedDataPath Build/ \
  -configuration Debug \
  ONLY_ACTIVE_ARCH=NO \
  ENABLE_TESTABILITY=YES \
  -enableCodeCoverage YES \
  clean build test | xcpretty -c
```

**Pod Lint (validates CocoaPods spec):**
```bash
pod lib lint --allow-warnings
```

**SwiftLint:**
```bash
swiftlint lint --config .swiftlint.yml
```

### Important Notes
- Building requires macOS with Xcode - the SDK uses Apple platform frameworks (UIKit, CoreTelephony)
- Tests run from `MixpanelDemo/` directory using Xcode schemes
- CI uses `xcpretty` for cleaner output - install via `gem install xcpretty`
- Available Xcode schemes: `MixpanelDemo` (iOS), `MixpanelDemoMac`, `MixpanelDemoTV`, `MixpanelDemoWatch`

## Project Layout

### Source Files
- **`Sources/`** - Main SDK source files
  - `Mixpanel.swift` - Primary entry point, initialization methods
  - `MixpanelInstance.swift` - Core instance management (~1000 lines)
  - `Track.swift` - Event tracking logic
  - `People.swift` - User profile management
  - `Group.swift` - Group analytics
  - `Flush.swift`, `FlushRequest.swift` - Network flush logic
  - `MPDB.swift`, `MixpanelPersistence.swift` - SQLite persistence
  - `FeatureFlags.swift` - Feature flags support
  - `AutomaticEvents.swift`, `AutomaticProperties.swift` - Auto-tracking
  - `MixpanelOptions.swift` - Configuration options
- **`Sources/Mixpanel/PrivacyInfo.xcprivacy`** - Apple privacy manifest

### Demo App and Tests
- **`MixpanelDemo/`** - Demo application and test suite
  - `MixpanelDemo.xcodeproj/` - Xcode project (use this for building)
  - `MixpanelDemoTests/` - iOS unit tests
  - `MixpanelDemoMacTests/` - macOS unit tests
  - `MixpanelDemoTVTests/` - tvOS tests
  - Test files: `MixpanelBaseTests.swift` (base class), `MixpanelDemoTests.swift` (main tests)

### Configuration Files
- **`Package.swift`** - Swift Package Manager manifest
- **`Mixpanel-swift.podspec`** - CocoaPods specification (version: 5.1.3)
- **`.swiftlint.yml`** - SwiftLint rules (line_length: 140, excludes `MixpanelDemo/`)
- **`Info.plist`** - Framework bundle info
- **`Mixpanel.xcodeproj/`** - Framework Xcode project (schemes: Mixpanel, Mixpanel_macOS, Mixpanel_tvOS, Mixpanel_watchOS)

### CI/CD Workflows (`.github/workflows/`)
- **`iOS.yml`** - iOS tests on pull requests/pushes to master
- **`macOS.yml`** - macOS tests on pull requests/pushes to master  
- **`release.yml`** - Automated release on version tags (v*)

### Scripts (`scripts/`)
- `generate_docs.sh` - Generates API documentation with Jazzy
- `carthage.sh` - Builds Carthage framework
- `release.py` - Version bumping script (updates podspec, Info.plist, AutomaticProperties.swift)

## Making Changes

### Version Updates
When updating the SDK version, these files must be modified:
1. `Mixpanel-swift.podspec` - `s.version` field
2. `Info.plist` - `CFBundleShortVersionString` key
3. `Sources/AutomaticProperties.swift` - `libVersion()` function return value (line ~151)
4. `scripts/generate_docs.sh` - `--module-version` parameter

### Test Patterns
Tests use `MixpanelBaseTests` as base class. Key patterns:
- Use `randomId()` for test tokens
- Use `waitForTrackingQueue()` after async operations
- Use `flushAndWaitForTrackingQueue()` for network operations
- Call `removeDBfile(token)` in teardown to clean SQLite files

### Platform-Specific Code
Use conditional compilation:
```swift
#if !os(OSX)
  import UIKit
#else
  import Cocoa
#endif

#if os(iOS)
  // iOS-specific code
#endif
```

### SwiftLint Exclusions
Files excluded from linting are listed in `.swiftlint.yml` - includes legacy/deprecated code. When adding new files, ensure they follow the configured rules (line_length: 140).

## Validation Checklist
1. Run SwiftLint: `swiftlint lint --config .swiftlint.yml`
2. Build and test iOS: Use `xcodebuild` with `MixpanelDemo` scheme
3. Validate pod spec: `pod lib lint --allow-warnings`
4. Ensure no breaking changes to public API (check `open class` and `public` declarations)

Trust these instructions. Only search the codebase if information here is incomplete or incorrect.
