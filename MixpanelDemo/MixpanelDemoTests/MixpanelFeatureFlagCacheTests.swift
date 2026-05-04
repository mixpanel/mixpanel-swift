//
//  MixpanelFeatureFlagCacheTests.swift
//  MixpanelDemo
//
//  Tests for the feature-flag variant persistence layer:
//   - Persistence round-trip + self-healing on malformed blobs
//   - distinctId and TTL validation
//   - Init loads cache and stamps variants with .cache(at:)
//   - CacheFirst serves cached values immediately
//   - NetworkFirst awaits the initial network response, falls back on failure
//   - reset() wipes both in-memory state and the on-disk blob
//   - cacheVariants=true causes successful fetches to write the blob
//

import XCTest

@testable import Mixpanel

// MARK: - Test-local mocks
//
// Defined here (rather than reusing the mocks in MixpanelFeatureFlagTests.swift) so this
// file can be compiled into both the iOS and macOS test targets without dragging in the
// rest of that file's iOS-specific dependencies. Keep the surface minimal — just what these
// cache tests actually exercise.

private final class CacheTestMockDelegate: MixpanelFlagDelegate {
  var options: MixpanelOptions
  var distinctId: String
  var anonymousId: String?
  var trackedEvents: [(event: String?, properties: Properties?)] = []
  private let trackQueue = DispatchQueue(label: "cache.test.mock.track")

  init(options: MixpanelOptions, distinctId: String, anonymousId: String? = nil) {
    self.options = options
    self.distinctId = distinctId
    self.anonymousId = anonymousId
  }

  func getOptions() -> MixpanelOptions { return options }
  func getDistinctId() -> String { return distinctId }
  func getAnonymousId() -> String? { return anonymousId }
  func track(event: String?, properties: Properties?) {
    trackQueue.sync { trackedEvents.append((event: event, properties: properties)) }
  }
}

/// Minimal mock of FeatureFlagManager that intercepts the network call. Deliberately
/// reproduces the parts of the real fetch path we care about (source stamping,
/// awaitingInitialNetworkResponse handling, completion fan-out) so async-lookup tests
/// can verify behavior end-to-end.
private final class CacheTestMockManager: FeatureFlagManager {
  var simulatedFetchResult: (success: Bool, flags: [String: MixpanelFlagVariant]?)?
  var simulatedNetworkDelay: TimeInterval = 0.1

  override func _performFetchRequest() {
    let work: () -> Void = { [weak self] in
      guard let self = self else { return }
      guard let result = self.simulatedFetchResult else {
        self.flagsLock.write { self.awaitingInitialNetworkResponse = false }
        self._completeFetch(success: false)
        return
      }
      if result.success, let flags = result.flags {
        let stamped = flags.mapValues { $0.withSource(.network) }
        self.flagsLock.write {
          self.flags = stamped
          self.awaitingInitialNetworkResponse = false
          self.timeLastFetched = Date()
        }
        self._completeFetch(success: true)
      } else {
        // Failure: leave flags in place (NetworkFirst fallback semantics) but clear awaiting.
        self.flagsLock.write { self.awaitingInitialNetworkResponse = false }
        self._completeFetch(success: false)
      }
    }
    if simulatedNetworkDelay > 0 {
      DispatchQueue.global().asyncAfter(deadline: .now() + simulatedNetworkDelay, execute: work)
    } else {
      work()
    }
  }

  // No-op so we don't fire real first-time-event recording requests.
  override func recordFirstTimeEvent(
    flagId: String, projectId: Int, firstTimeEventHash: String, distinctId: String
  ) {}
}

class FeatureFlagCacheTests: XCTestCase {

  // Each test uses a unique instance name so UserDefaults state from one test can't bleed
  // into another. Writes go to the shared "Mixpanel" suite, but the per-instance prefix
  // keys keep them isolated.
  private var instanceName: String!

  // FeatureFlagManager.delegate is `weak`. Tests build delegates inside helper methods, so
  // unless the test instance holds a strong ref the delegate gets deallocated as soon as the
  // helper returns and `delegate?.getOptions()` returns nil. Stash all created delegates
  // here for the test's lifetime.
  private var retainedDelegates: [MixpanelFlagDelegate] = []

  override func setUpWithError() throws {
    try super.setUpWithError()
    instanceName = "fftest-\(UUID().uuidString)"
  }

  override func tearDownWithError() throws {
    MixpanelPersistence.deleteFlagsCache(instanceName: instanceName)
    instanceName = nil
    retainedDelegates.removeAll()
    try super.tearDownWithError()
  }

  // MARK: - Persistence layer

  func testSaveAndLoadRoundTrip() throws {
    let blob = FlagsCacheBlob(
      cachedAt: Date(timeIntervalSince1970: 1_700_000_000),
      distinctId: "user_a",
      response: #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    )

    MixpanelPersistence.saveFlagsCache(blob, instanceName: instanceName)
    let loaded = MixpanelPersistence.loadFlagsCache(instanceName: instanceName)

    let loadedBlob = try XCTUnwrap(loaded)
    XCTAssertEqual(loadedBlob.distinctId, blob.distinctId)
    XCTAssertEqual(loadedBlob.response, blob.response)
    XCTAssertEqual(
      loadedBlob.cachedAt.timeIntervalSince1970,
      blob.cachedAt.timeIntervalSince1970, accuracy: 0.001)
  }

  func testLoadReturnsNilWhenNothingPersisted() {
    XCTAssertNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))
  }

  func testDeleteRemovesBlob() {
    let blob = FlagsCacheBlob(
      cachedAt: Date(), distinctId: "user_x", response: "{}")
    MixpanelPersistence.saveFlagsCache(blob, instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))

    MixpanelPersistence.deleteFlagsCache(instanceName: instanceName)
    XCTAssertNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))
  }

  func testMalformedBlobIsSelfHealed() {
    // Write a non-JSON byte sequence directly to the same key the persistence layer uses.
    let defaults = UserDefaults(suiteName: "Mixpanel")!
    let key = "mixpanel-\(instanceName!)-MPFlagsCache"
    defaults.set(Data([0xFF, 0xFE, 0xFD]), forKey: key)

    // Read should return nil AND clear the blob so we don't keep failing on every load.
    XCTAssertNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))
    XCTAssertNil(defaults.data(forKey: key))
  }

  func testWellFormedJSONWithUnexpectedShapeIsSelfHealed() {
    // Valid JSON but wrong shape (missing required keys) should also self-heal.
    let defaults = UserDefaults(suiteName: "Mixpanel")!
    let key = "mixpanel-\(instanceName!)-MPFlagsCache"
    let bogus = #"{"unexpected":"shape"}"#.data(using: .utf8)!
    defaults.set(bogus, forKey: key)

    XCTAssertNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))
    XCTAssertNil(defaults.data(forKey: key))
  }

  // MARK: - Source stamping

  func testWithSourceStampsAndPreservesOtherFields() {
    let original = MixpanelFlagVariant(
      key: "k", value: "v", isExperimentActive: true, isQATester: false, experimentID: "exp_1")
    let stamped = original.withSource(.network)

    XCTAssertEqual(stamped.key, "k")
    XCTAssertEqual(stamped.value as? String, "v")
    XCTAssertEqual(stamped.experimentID, "exp_1")
    XCTAssertEqual(stamped.isExperimentActive, true)
    XCTAssertEqual(stamped.isQATester, false)
    if case .network = stamped.source {} else { XCTFail("expected .network source") }

    let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let cacheStamped = original.withSource(.cache(at: cachedAt))
    if case .cache(let at) = cacheStamped.source {
      XCTAssertEqual(at.timeIntervalSince1970, cachedAt.timeIntervalSince1970, accuracy: 0.001)
    } else {
      XCTFail("expected .cache source")
    }
  }

  func testFallbackVariantsHaveNilSource() {
    let fallback = MixpanelFlagVariant(value: "default")
    XCTAssertNil(fallback.source)
  }

  // MARK: - Init loads cache and stamps variants

  func testInitLoadsCachedVariantsAndStampsCacheSource() throws {
    // `Date()` (rather than a fixed-far-past timestamp) so the 86_400s TTL check passes.
    let cachedAt = Date()
    let context = ["plan": "enterprise"]
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":42},"flag_b":{"variant_key":"v2","variant_value":"hello"}}}"#

    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(cachedAt: cachedAt, distinctId: "user_a", response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: context, policy: .cacheFirst(ttl: 86_400))

    waitForTrackingQueue(manager: manager)

    XCTAssertTrue(manager.areFlagsReady())
    let variants = manager.getAllVariantsSync()
    XCTAssertEqual(variants.count, 2)

    if case .cache(let at) = variants["flag_a"]?.source {
      XCTAssertEqual(at.timeIntervalSince1970, cachedAt.timeIntervalSince1970, accuracy: 0.001)
    } else {
      XCTFail("flag_a should have .cache source")
    }
    XCTAssertEqual(variants["flag_a"]?.value as? Int, 42)
    XCTAssertEqual(variants["flag_b"]?.value as? String, "hello")
  }

  func testInitIgnoresCacheOnDistinctIdMismatch() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "different_user",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), "distinctId mismatch should leave flags empty")
    XCTAssertTrue(manager.getAllVariantsSync().isEmpty)
  }

  /// Documents the deliberate decision to key the cache on distinctId only — context changes
  /// do NOT invalidate the cached blob. A cache written under one context will load under a
  /// different context for the same user (in-memory variants will then be stale with respect
  /// to the new context until the next successful fetch overwrites them).
  ///
  /// Customers signaled this tradeoff is acceptable: context rarely flips mid-session in
  /// practice, and the gain is keeping the cache useful when customers do flip between
  /// contexts they've used before.
  func testInitLoadsCacheRegardlessOfContextDifference() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        // Blob originally cached under no context.
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    // Manager comes up under a different context for the same user.
    let manager = makeManager(
      distinctId: "user_a",
      context: ["plan": "enterprise"],
      policy: .cacheFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertTrue(
      manager.areFlagsReady(),
      "context mismatch must NOT invalidate cache when keyed on distinctId only")
    XCTAssertEqual(manager.getAllVariantsSync().count, 1)
  }

  func testInitIgnoresCacheWhenExpired() throws {
    let oldDate = Date(timeIntervalSinceNow: -86_400 * 7) // 7 days ago
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: oldDate,
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 60))  // 60s TTL
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), "expired entry should be ignored")
  }

  func testInitClearsCacheBlobWhenResponseStringIsUnparseable() throws {
    // Structurally-valid envelope but the `response` string is garbage. Without self-heal
    // the blob would stick on disk and fail every cold-start. The init-time cache load
    // should both ignore it AND wipe it.
    let blob = FlagsCacheBlob(
      cachedAt: Date(),
      distinctId: "user_a",
      response: "this is not json"
    )
    MixpanelPersistence.saveFlagsCache(blob, instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), "unparseable response should leave flags empty")
    XCTAssertNil(
      MixpanelPersistence.loadFlagsCache(instanceName: instanceName),
      "blob should be wiped so the next successful fetch gets a clean slate")
  }

  func testInitDoesNotLoadCacheWhenPolicyIsNetworkOnly() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(distinctId: "user_a", context: [:], policy: .networkOnly)
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), ".networkOnly must not load from cache")
  }

  /// Regression test for the init-time race that motivated moving FeatureFlagManager
  /// construction below `unarchive()` in MixpanelInstance.init.
  ///
  /// The async cache-load block reads `delegate.getDistinctId()` at the moment GCD picks it
  /// up — NOT at the moment FeatureFlagManager.init dispatched it. This test simulates the
  /// race by:
  ///   1. Persisting a cache blob keyed to "real_user".
  ///   2. Constructing the manager with a delegate whose distinctId is "wrong_user" — the
  ///      cache-load block is queued on a SUSPENDED tracking queue, so it can't run yet.
  ///   3. Mutating delegate.distinctId to "real_user" (simulating unarchive() loading the
  ///      persisted identity AFTER FeatureFlagManager init returned).
  ///   4. Resuming the queue and waiting.
  /// If the cache load read distinctId at the right time (block-execution, not dispatch),
  /// flags load successfully. If we'd snapshotted at dispatch time, this would fail.
  func testCacheLoadReadsDistinctIdAtBlockExecutionNotDispatch() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "real_user",
        response: response),
      instanceName: instanceName)

    let delegate = CacheTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          variantLookupPolicy: .cacheFirst(ttl: 86_400),
          cacheVariants: true)),
      distinctId: "wrong_user")
    retainedDelegates.append(delegate)

    // Suspend the queue BEFORE the manager init so the cache-load dispatch sits in the queue
    // without running. Models the worst-case race: GCD couldn't schedule the worker thread
    // before init's caller continued past the dispatch point.
    let queue = DispatchQueue(label: "ff.cache.race.test.\(UUID().uuidString)")
    queue.suspend()
    let manager = FeatureFlagManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)

    // "unarchive() finishes" — the persisted identity is now visible via the delegate.
    delegate.distinctId = "real_user"

    // Let the cache load proceed. The waitForTrackingQueue helper posts a barrier task;
    // because the queue is serial, the cache-load runs first.
    queue.resume()
    waitForTrackingQueue(manager: manager)

    XCTAssertTrue(
      manager.areFlagsReady(),
      "cache load should have used the post-mutation distinctId, not the construction-time one")
    XCTAssertEqual(manager.getAllVariantsSync().count, 1)
  }

  // MARK: - NetworkFirst gating

  func testNetworkFirstSetsAwaitingFlagWhenCacheLoaded() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"cached_val"}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    // Sync lookups + areFlagsReady reflect the cache regardless of policy.
    XCTAssertTrue(manager.areFlagsReady())
    var awaitingValue = false
    manager.flagsLock.read { awaitingValue = manager.awaitingInitialNetworkResponse }
    XCTAssertTrue(awaitingValue, ".networkFirst must await initial network response")
  }

  func testCacheFirstDoesNotSetAwaitingFlagWhenCacheLoaded() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"cached_val"}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    var awaitingValue = false
    manager.flagsLock.read { awaitingValue = manager.awaitingInitialNetworkResponse }
    XCTAssertFalse(awaitingValue, ".cacheFirst must not await initial network response")
  }

  func testNetworkFirstAsyncLookupAwaitsFetchEvenWithCache() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"cached_val"}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(ttl: 86_400))

    // Configure the mock to "succeed" with new flags, but with a delay that lets us assert
    // the async lookup waited for the network rather than serving cached values immediately.
    mock.simulatedFetchResult = (
      success: true,
      flags: [
        "flag_a": MixpanelFlagVariant(key: "v_fresh", value: "network_val")
      ]
    )
    mock.simulatedNetworkDelay = 0.1  // 100ms delay

    waitForTrackingQueue(manager: mock)
    // Cache should have populated `flags` with .cache stamping. Now async lookup must NOT
    // serve those cached values — it has to await the network response.
    let asyncDone = expectation(description: "async lookup completes after network")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      // The variant served must be the network value, not the cached one.
      XCTAssertEqual(variant.value as? String, "network_val")
      if case .network = variant.source {} else {
        XCTFail("variant served by NetworkFirst should be from .network after fetch")
      }
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  func testNetworkFirstFallsBackToCacheOnFetchFailure() throws {
    let cachedAt = Date(timeIntervalSinceNow: -60)  // 60s old, well within TTL
    let response = #"{"flags":{"flag_a":{"variant_key":"v_cached","variant_value":"cached_val"}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: cachedAt,
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(ttl: 86_400))
    mock.simulatedFetchResult = (success: false, flags: nil)

    waitForTrackingQueue(manager: mock)

    let asyncDone = expectation(description: "async lookup completes after fetch failure")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      // Fetch failed → cached values stay → async lookup serves the cached variant.
      XCTAssertEqual(variant.value as? String, "cached_val")
      if case .cache = variant.source {} else {
        XCTFail("variant served on NetworkFirst failure should keep .cache source")
      }
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  func testCacheFirstAsyncLookupServesCachedImmediately() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"cached_val"}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 86_400))
    // Configure a slow network so we'd notice if the lookup was waiting on it.
    mock.simulatedFetchResult = (
      success: true, flags: ["flag_a": MixpanelFlagVariant(key: "v2", value: "network_val")])
    mock.simulatedNetworkDelay = 0.1

    waitForTrackingQueue(manager: mock)

    let asyncDone = expectation(description: "async lookup completes")
    let start = Date()
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      let elapsed = Date().timeIntervalSince(start)
      XCTAssertEqual(variant.value as? String, "cached_val", "cacheFirst should serve cached")
      if case .cache = variant.source {} else { XCTFail("expected .cache source") }
      // Generous bound — just want to confirm we didn't wait on the 100ms simulated network.
      XCTAssertLessThan(elapsed, 0.08, "cacheFirst should not wait for network")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 1.0)
  }

  // MARK: - Reset wipes cache

  func testResetWipesDiskCache() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertNotNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))

    manager.reset()
    waitForTrackingQueue(manager: manager)

    XCTAssertNil(
      MixpanelPersistence.loadFlagsCache(instanceName: instanceName),
      "reset() should wipe the on-disk cache")
    XCTAssertFalse(manager.areFlagsReady())
  }

  /// `setContext` deliberately does NOT clear in-memory variants OR the on-disk cache. The
  /// cache is keyed on distinctId only, so it remains valid across context changes for the
  /// same user. The next successful fetch under the new context overwrites the cache.
  func testSetContextDoesNotWipeCacheOrInMemoryState() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsCache(
      FlagsCacheBlob(
        cachedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .cacheFirst(ttl: 86_400))
    // Make the post-setContext fetch fail so we can isolate setContext's effect — without
    // a successful overwrite, the blob's survival is solely attributable to setContext
    // NOT wiping it. The same goes for in-memory state.
    mock.simulatedFetchResult = (success: false, flags: nil)
    mock.simulatedNetworkDelay = 0
    waitForTrackingQueue(manager: mock)

    XCTAssertNotNil(MixpanelPersistence.loadFlagsCache(instanceName: instanceName))
    XCTAssertTrue(mock.areFlagsReady(), "cache load on init should populate flags")

    let setContextDone = expectation(description: "setContext fetch completes")
    mock.setContext(["plan": "enterprise"]) { setContextDone.fulfill() }
    wait(for: [setContextDone], timeout: 2.0)
    waitForTrackingQueue(manager: mock)

    XCTAssertNotNil(
      MixpanelPersistence.loadFlagsCache(instanceName: instanceName),
      "setContext must NOT wipe the on-disk cache")
    XCTAssertTrue(
      mock.areFlagsReady(),
      "setContext must NOT clear in-memory variants")
  }

  // MARK: - Helpers

  private func makeManager(
    distinctId: String,
    context: [String: Any],
    policy: VariantLookupPolicy,
    cacheVariants: Bool = true
  ) -> FeatureFlagManager {
    let delegate = CacheTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          context: context,
          variantLookupPolicy: policy,
          cacheVariants: cacheVariants)),
      distinctId: distinctId)
    retainedDelegates.append(delegate)
    let queue = DispatchQueue(label: "ff.cache.test.\(UUID().uuidString)")
    return FeatureFlagManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)
  }

  private func makeMockManager(
    distinctId: String,
    context: [String: Any],
    policy: VariantLookupPolicy,
    cacheVariants: Bool = true
  ) -> CacheTestMockManager {
    let delegate = CacheTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          context: context,
          variantLookupPolicy: policy,
          cacheVariants: cacheVariants)),
      distinctId: distinctId)
    retainedDelegates.append(delegate)
    let queue = DispatchQueue(label: "ff.cache.mock.test.\(UUID().uuidString)")
    return CacheTestMockManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)
  }

  /// Wait for any pending work on the manager's tracking queue (notably the async cache
  /// load posted from init) to complete by posting a barrier task and blocking on it.
  private func waitForTrackingQueue(
    manager: FeatureFlagManager,
    timeout: TimeInterval = 1.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let done = expectation(description: "tracking queue drained")
    manager.trackingQueue.async { done.fulfill() }
    wait(for: [done], timeout: timeout)
  }
}
