# Mixpanel Swift SDK Copilot Instructions

## Project Overview
This is the official Mixpanel Swift SDK supporting iOS 11.0+, tvOS 11.0+, macOS 10.13+, and watchOS 4.0+.

## Architecture
- **Entry Point**: `Mixpanel` class (static) → `MixpanelManager` (singleton) → `MixpanelInstance`
- **Core Components**: Track, People, Groups, Flush, Network, FeatureFlags
- **Persistence**: SQLite via `MPDB` class, UserDefaults for metadata
- **Threading**: Custom `ReadWriteLock` with dedicated queues (trackingQueue, networkQueue)

## Coding Standards

### Swift Conventions
- Use trailing closures for completion handlers
- Use guard statements for early returns and validation
- Prefix internal properties with underscore (_)
- Use property observers (didSet) for reactive updates
- Mark completion handlers as @escaping when stored

### Thread Safety
- Always use ReadWriteLock for shared state access
- Use `.read {}` for read operations, `.write {}` for mutations
- Dispatch async work to trackingQueue (QoS: .utility)
- Network operations go to networkQueue

### Type System
- All property values must conform to MixpanelType protocol
- Supported types: String, Int, UInt, Double, Float, Bool, [MixpanelType], [String: MixpanelType], Date, URL, NSNull
- Always validate properties with `assertPropertyTypes()`
- Use `Properties` typealias for [String: MixpanelType]

### Error Handling
- Log errors via MixpanelLogger, don't throw
- Use MPAssert for debug assertions
- Fail gracefully with default values
- Return discardable results for fluent API

### Platform Support
- Use conditional compilation: #if os(iOS), #if !os(OSX)
- Check for app extensions with isiOSAppExtension()
- iOS supports automatic events, macOS doesn't by default
- Test on all platforms before making changes

### API Design
- Methods should return self or @discardableResult
- Provide sensible defaults for optional parameters
- Use completion handlers for async operations
- Keep public API surface minimal and backward compatible

### Testing
- Extend MixpanelBaseTests for new test classes
- Use waitForTrackingQueue() to ensure operations complete
- Use randomId() for test data generation
- Test on all supported platforms

### Documentation
- Add comprehensive documentation comments for public APIs
- Include code examples in documentation
- Document platform-specific behavior
- Update CHANGELOG.md for user-facing changes

## Common Operations

### Adding a new event property
1. Update automatic properties in AutomaticProperties.swift
2. Add validation in Track.swift
3. Update persistence if needed
4. Add tests in MixpanelDemoTests

### Modifying network behavior
1. Update Network.swift and FlushRequest.swift
2. Consider retry logic and error handling
3. Update APIConstants if endpoints change
4. Test with various network conditions

### Creating new components
1. Follow existing component patterns (Track.swift, People.swift)
2. Implement thread safety with ReadWriteLock
3. Add to MixpanelInstance initialization
4. Create corresponding test file

## Build and Test Commands
- Build all: `xcodebuild -scheme Mixpanel`
- Test iOS: `xcodebuild test -scheme MixpanelDemo -destination 'platform=iOS Simulator,name=iPhone 15'`
- Test macOS: `xcodebuild test -scheme MixpanelDemoMac`
- Carthage: `./scripts/carthage.sh`
- Documentation: `./scripts/generate_docs.sh`

## Version Updates
When updating version, modify:
- Mixpanel-swift.podspec
- Info.plist
- Sources/AutomaticProperties.swift ($lib_version constant)

## Important Notes
- NEVER commit secrets or API keys
- Always maintain backward compatibility
- Test memory usage with large event volumes
- Verify SQLite migrations work correctly
- Check performance on older devices