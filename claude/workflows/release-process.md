# Complete Release Process Workflow

## Pre-Release Checklist

### 1. Code Quality
- [ ] All tests passing on all platforms
- [ ] No SwiftLint warnings
- [ ] Code coverage above 80%
- [ ] No compiler warnings
- [ ] API documentation complete

### 2. Testing Matrix
Run tests on:
- [ ] iOS 11.0 (minimum) on oldest device
- [ ] iOS 17.0 (latest) on newest device  
- [ ] macOS 10.13 (minimum)
- [ ] macOS 14.0 (latest)
- [ ] tvOS 11.0 and latest
- [ ] watchOS 4.0 and latest

### 3. Integration Testing
- [ ] CocoaPods integration works
- [ ] Carthage build succeeds
- [ ] Swift Package Manager resolves
- [ ] Demo apps run without issues

## Release Steps

### Step 1: Version Bump
Update version in THREE places:

```bash
# 1. Podspec
vim Mixpanel-swift.podspec
# Change: s.version = "5.0.0"

# 2. Info.plist
vim Info.plist
# Change: <key>CFBundleShortVersionString</key>
#         <string>5.0.0</string>

# 3. Source code
vim Sources/AutomaticProperties.swift
# Change: "$lib_version": "5.0.0"
```

### Step 2: Update CHANGELOG

```markdown
## [5.0.0] - 2024-01-30

### Added
- New feature X with example usage
- Support for Y platform

### Changed
- Improved performance of Z by 50%
- Updated minimum iOS version to 11.0

### Fixed
- Fixed crash when tracking events with nil properties (#123)
- Resolved memory leak in background flush (#456)

### Deprecated
- `oldMethod()` - use `newMethod()` instead

### Removed
- Removed support for iOS 10.0
```

### Step 3: Final Testing

```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/Mixpanel-*

# Test all platforms
xcodebuild test -scheme MixpanelDemo -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -scheme MixpanelDemoMac
xcodebuild test -scheme MixpanelDemoTV -destination 'platform=tvOS Simulator,name=Apple TV'

# Verify demo apps
open MixpanelDemo/MixpanelDemo.xcodeproj
# Build and run each target
```

### Step 4: Generate Documentation

```bash
# Install jazzy if needed
gem install jazzy

# Generate docs
./scripts/generate_docs.sh

# Verify documentation
open docs/index.html

# Check for undocumented symbols
cat docs/undocumented.json
```

### Step 5: Create Release Commit

```bash
# Stage all changes
git add -A

# Commit with version
git commit -m "Version 5.0.0

- Add feature X
- Improve performance
- Fix critical bugs

See CHANGELOG.md for details"
```

### Step 6: Tag Release

```bash
# Create annotated tag
git tag -a v5.0.0 -m "Version 5.0.0

Major release with:
- Feature X
- Performance improvements
- Bug fixes"

# Verify tag
git show v5.0.0
```

### Step 7: Push to GitHub

```bash
# Push commits
git push origin main

# Push tag
git push origin v5.0.0
```

### Step 8: Create GitHub Release

1. Go to https://github.com/mixpanel/mixpanel-swift/releases
2. Click "Draft a new release"
3. Select tag: v5.0.0
4. Title: "Version 5.0.0"
5. Copy CHANGELOG entry to description
6. Add migration guide if breaking changes
7. Attach any binaries if needed
8. Click "Publish release"

### Step 9: Publish to CocoaPods

```bash
# Validate podspec
pod lib lint Mixpanel-swift.podspec

# If validation passes, push to trunk
pod trunk push Mixpanel-swift.podspec

# Verify on CocoaPods
open https://cocoapods.org/pods/Mixpanel-swift
```

### Step 10: Verify Carthage

```bash
# In a test project
echo 'github "mixpanel/mixpanel-swift" ~> 5.0.0' > Cartfile
carthage update --platform iOS

# Verify framework built
ls Carthage/Build/iOS/Mixpanel.framework
```

### Step 11: Verify Swift Package Manager

```swift
// In Package.swift of test project
dependencies: [
    .package(
        url: "https://github.com/mixpanel/mixpanel-swift.git",
        from: "5.0.0"
    )
]

// Then verify
swift package resolve
swift build
```

## Post-Release

### 1. Monitor for Issues
- Watch GitHub issues for problems
- Monitor crash reporting services
- Check CocoaPods quality metrics

### 2. Update Documentation Site
- Update version in documentation
- Add migration guide if needed
- Update code examples

### 3. Announce Release
- Post in company Slack/communication channels
- Update internal documentation
- Notify major customers if breaking changes

### 4. Plan Next Release
- Create milestone for next version
- Triage incoming issues
- Plan feature roadmap

## Hotfix Process

For critical bugs in released version:

### 1. Create Hotfix Branch
```bash
# From the release tag
git checkout -b hotfix/5.0.1 v5.0.0
```

### 2. Fix Issue
```bash
# Make minimal changes
vim Sources/BuggyFile.swift

# Add test for the fix
vim MixpanelDemoTests/HotfixTests.swift

# Verify fix
xcodebuild test -scheme MixpanelDemo
```

### 3. Update Version
```bash
# Bump patch version in all 3 places
# 5.0.0 → 5.0.1
```

### 4. Release Hotfix
```bash
# Commit
git commit -am "Fix critical bug in event tracking"

# Tag
git tag -a v5.0.1 -m "Hotfix 5.0.1: Fix critical bug"

# Push
git push origin hotfix/5.0.1
git push origin v5.0.1

# Merge back to main
git checkout main
git merge hotfix/5.0.1
git push origin main
```

### 5. Fast-Track Publishing
- Skip beta testing for critical fixes
- Immediately push to CocoaPods
- Update GitHub release notes
- Notify affected users

## Rollback Process

If critical issue found after release:

### 1. Immediate Actions
```bash
# Yank from CocoaPods (if within 24 hours)
pod trunk delete Mixpanel-swift 5.0.0

# Mark as pre-release on GitHub
# Edit release and check "This is a pre-release"
```

### 2. Fix Forward
- Create hotfix version 5.0.1
- Include fix for the issue
- Add regression test
- Release as soon as possible

### 3. Communication
- Post known issues in GitHub
- Email major customers
- Update status page if available

## Automation Script

The release script automates many steps:

```bash
python scripts/release.py --old 4.9.0 --new 5.0.0

# What it does:
# 1. Updates version in all files
# 2. Generates documentation  
# 3. Creates git commit
# 4. Tags release
# 5. Pushes to GitHub
# 6. Publishes to CocoaPods
```

Use manual process for major releases or when careful review needed.