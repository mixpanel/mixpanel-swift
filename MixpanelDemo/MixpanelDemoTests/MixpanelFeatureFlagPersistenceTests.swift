//
//  MixpanelFeatureFlagPersistenceTests.swift
//  MixpanelDemo
//
//  Tests for the feature-flag variant persistence layer:
//   - Persistence round-trip + self-healing on malformed blobs
//   - distinctId and TTL validation
//   - Init loads persisted blob and stamps variants with .persistence(persistedAt:)
//   - PersistenceUntilNetworkSuccess serves persisted values immediately
//   - NetworkFirst awaits the initial network response, falls back on failure
//   - reset() wipes both in-memory state and the on-disk blob
//   - successful fetches write the blob (when policy is .persistenceUntilNetworkSuccess or .networkFirst)
//   - $experiment_started includes $variant_source / $persisted_at_in_ms / $ttl_in_ms when
//     the served variant came from the persistence layer
//

import XCTest

@testable import Mixpanel

// MARK: - Test-local mocks
//
// Defined here (rather than reusing the mocks in MixpanelFeatureFlagTests.swift) so this
// file can be compiled into both the iOS and macOS test targets without dragging in the
// rest of that file's iOS-specific dependencies. Keep the surface minimal — just what
// these persistence tests actually exercise.

private final class PersistenceTestMockDelegate: MixpanelFlagDelegate {
  var options: MixpanelOptions
  var distinctId: String
  var anonymousId: String?
  var trackedEvents: [(event: String?, properties: Properties?)] = []
  private let trackQueue = DispatchQueue(label: "persistence.test.mock.track")

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

  func snapshotTrackedEvents() -> [(event: String?, properties: Properties?)] {
    return trackQueue.sync { trackedEvents }
  }
}

/// Minimal mock of FeatureFlagManager that intercepts the network call. Deliberately
/// reproduces the parts of the real fetch path we care about (source stamping,
/// awaitingInitialNetworkResponse handling, completion fan-out) so async-lookup tests
/// can verify behavior end-to-end.
private final class PersistenceTestMockManager: FeatureFlagManager {
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

class FeatureFlagPersistenceTests: XCTestCase {

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
    MixpanelPersistence.deleteFlagsPersistence(instanceName: instanceName)
    instanceName = nil
    retainedDelegates.removeAll()
    try super.tearDownWithError()
  }

  // MARK: - Persistence layer

  func testSaveAndLoadRoundTrip() throws {
    let blob = FlagsPersistenceBlob(
      persistedAt: Date(timeIntervalSince1970: 1_700_000_000),
      distinctId: "user_a",
      response: #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    )

    MixpanelPersistence.saveFlagsPersistence(blob, instanceName: instanceName)
    let loaded = MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName)

    let loadedBlob = try XCTUnwrap(loaded)
    XCTAssertEqual(loadedBlob.distinctId, blob.distinctId)
    XCTAssertEqual(loadedBlob.response, blob.response)
    XCTAssertEqual(
      loadedBlob.persistedAt.timeIntervalSince1970,
      blob.persistedAt.timeIntervalSince1970, accuracy: 0.001)
  }

  func testLoadReturnsNilWhenNothingPersisted() {
    XCTAssertNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))
  }

  func testDeleteRemovesBlob() {
    let blob = FlagsPersistenceBlob(
      persistedAt: Date(), distinctId: "user_x", response: "{}")
    MixpanelPersistence.saveFlagsPersistence(blob, instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    MixpanelPersistence.deleteFlagsPersistence(instanceName: instanceName)
    XCTAssertNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))
  }

  func testMalformedBlobIsSelfHealed() {
    // Write a non-JSON byte sequence directly to the same key the persistence layer uses.
    let defaults = UserDefaults(suiteName: "Mixpanel")!
    let key = "mixpanel-\(instanceName!)-MPFlagsPersistence"
    defaults.set(Data([0xFF, 0xFE, 0xFD]), forKey: key)

    // Read should return nil AND clear the blob so we don't keep failing on every load.
    XCTAssertNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))
    XCTAssertNil(defaults.data(forKey: key))
  }

  func testWellFormedJSONWithUnexpectedShapeIsSelfHealed() {
    // Valid JSON but wrong shape (missing required keys) should also self-heal.
    let defaults = UserDefaults(suiteName: "Mixpanel")!
    let key = "mixpanel-\(instanceName!)-MPFlagsPersistence"
    let bogus = #"{"unexpected":"shape"}"#.data(using: .utf8)!
    defaults.set(bogus, forKey: key)

    XCTAssertNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))
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

    let persistedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let persistenceStamped = original.withSource(.persistence(persistedAt: persistedAt))
    if case .persistence(let at) = persistenceStamped.source {
      XCTAssertEqual(at.timeIntervalSince1970, persistedAt.timeIntervalSince1970, accuracy: 0.001)
    } else {
      XCTFail("expected .persistence source")
    }
  }

  func testFallbackVariantsHaveFallbackSource() {
    let fallback = MixpanelFlagVariant(value: "default")
    if case .fallback = fallback.source {} else {
      XCTFail("developer-supplied variants should carry .fallback source")
    }
  }

  // MARK: - Default TTL

  /// `VariantLookupPolicy.defaultTTL` is 24 hours, and the zero-arg static factories
  /// `persistenceUntilNetworkSuccess()` / `networkFirst()` produce cases keyed to that default. This also
  /// exercises the case-plus-static-func overload pattern (different parameter lists, so
  /// `.persistenceUntilNetworkSuccess()` and `.persistenceUntilNetworkSuccess(ttl:)` resolve to different members).
  func testDefaultTTLConvenienceConstructors() throws {
    XCTAssertEqual(VariantLookupPolicy.defaultTTL, 24 * 60 * 60, "default TTL should be 24 hours")

    let convenientPersistenceUntilNetworkSuccess = VariantLookupPolicy.persistenceUntilNetworkSuccess()
    if case .persistenceUntilNetworkSuccess(let ttl) = convenientPersistenceUntilNetworkSuccess {
      XCTAssertEqual(ttl, VariantLookupPolicy.defaultTTL)
    } else {
      XCTFail("convenience persistenceUntilNetworkSuccess() should produce .persistenceUntilNetworkSuccess case")
    }

    let convenientNetworkFirst = VariantLookupPolicy.networkFirst()
    if case .networkFirst(let ttl) = convenientNetworkFirst {
      XCTAssertEqual(ttl, VariantLookupPolicy.defaultTTL)
    } else {
      XCTFail("convenience networkFirst() should produce .networkFirst case")
    }
  }

  // MARK: - Init loads persisted variants and stamps them

  func testInitLoadsPersistedVariantsAndStampsPersistenceSource() throws {
    // `Date()` (rather than a fixed-far-past timestamp) so the 86_400s TTL check passes.
    let persistedAt = Date()
    let context = ["plan": "enterprise"]
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":42},"flag_b":{"variant_key":"v2","variant_value":"hello"}}}"#

    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(persistedAt: persistedAt, distinctId: "user_a", response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: context, policy: .persistenceUntilNetworkSuccess(ttl: 86_400))

    waitForTrackingQueue(manager: manager)

    XCTAssertTrue(manager.areFlagsReady())
    let variants = manager.getAllVariantsSync()
    XCTAssertEqual(variants.count, 2)

    if case .persistence(let at) = variants["flag_a"]?.source {
      XCTAssertEqual(at.timeIntervalSince1970, persistedAt.timeIntervalSince1970, accuracy: 0.001)
    } else {
      XCTFail("flag_a should have .persistence source")
    }
    XCTAssertEqual(variants["flag_a"]?.value as? Int, 42)
    XCTAssertEqual(variants["flag_b"]?.value as? String, "hello")
  }

  /// distinctId mismatch on init is the cross-session form of "distinctId changed":
  /// it leaves flags empty AND wipes the stale blob from disk, so the prior identity's
  /// variants don't sit on this device after the user has moved on.
  func testInitWipesPersistenceOnDistinctIdMismatch() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "different_user",
        response: response),
      instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), "distinctId mismatch should leave flags empty")
    XCTAssertTrue(manager.getAllVariantsSync().isEmpty)
    XCTAssertNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      "distinctId mismatch on init should wipe the stale blob")
  }

  /// Documents the deliberate decision to key persistence on distinctId only — context changes
  /// do NOT invalidate the persisted blob. A blob written under one context will load under
  /// a different context for the same user (in-memory variants will then be stale with respect
  /// to the new context until the next successful fetch overwrites them).
  ///
  /// Customers signaled this tradeoff is acceptable: context rarely flips mid-session in
  /// practice, and the gain is keeping the persistence layer useful when customers do flip
  /// between contexts they've used before.
  func testInitLoadsPersistenceRegardlessOfContextDifference() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        // Blob originally persisted under no context.
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    // Manager comes up under a different context for the same user.
    let manager = makeManager(
      distinctId: "user_a",
      context: ["plan": "enterprise"],
      policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertTrue(
      manager.areFlagsReady(),
      "context mismatch must NOT invalidate persisted blob when keyed on distinctId only")
    XCTAssertEqual(manager.getAllVariantsSync().count, 1)
  }

  func testInitIgnoresPersistenceWhenExpired() throws {
    let oldDate = Date(timeIntervalSinceNow: -86_400 * 7) // 7 days ago
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: oldDate,
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))  // 60s TTL
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), "expired entry should be ignored")
  }

  func testInitClearsPersistedBlobWhenResponseStringIsUnparseable() throws {
    // Structurally-valid envelope but the `response` string is garbage. Without self-heal
    // the blob would stick on disk and fail every cold-start. The init-time persistence load
    // should both ignore it AND wipe it.
    let blob = FlagsPersistenceBlob(
      persistedAt: Date(),
      distinctId: "user_a",
      response: "this is not json"
    )
    MixpanelPersistence.saveFlagsPersistence(blob, instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), "unparseable response should leave flags empty")
    XCTAssertNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      "blob should be wiped so the next successful fetch gets a clean slate")
  }

  /// `.networkOnly` does two things on init when a stale blob is on disk: (a) doesn't load
  /// it into memory, and (b) actively wipes it. This way, toggling from a persisting policy
  /// back to `.networkOnly` cleans up the orphaned blob rather than leaving it stranded.
  func testInitWipesAndDoesNotLoadPersistenceWhenPolicyIsNetworkOnly() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    let manager = makeManager(distinctId: "user_a", context: [:], policy: .networkOnly)
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(manager.areFlagsReady(), ".networkOnly must not load from persistence")
    XCTAssertNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      ".networkOnly init should wipe a stale blob from a previous persisting-policy session")
  }

  /// Regression test for the init-time race that motivated moving FeatureFlagManager
  /// construction below `unarchive()` in MixpanelInstance.init.
  ///
  /// The async persistence-load block reads `delegate.getDistinctId()` at the moment GCD
  /// picks it up — NOT at the moment FeatureFlagManager.init dispatched it. This test
  /// simulates the race by:
  ///   1. Persisting a blob keyed to "real_user".
  ///   2. Constructing the manager with a delegate whose distinctId is "wrong_user" — the
  ///      persistence-load block is queued on a SUSPENDED tracking queue, so it can't run yet.
  ///   3. Mutating delegate.distinctId to "real_user" (simulating unarchive() loading the
  ///      persisted identity AFTER FeatureFlagManager init returned).
  ///   4. Resuming the queue and waiting.
  /// If the persistence load read distinctId at the right time (block-execution, not
  /// dispatch), flags load successfully. If we'd snapshotted at dispatch time, this would
  /// fail.
  func testPersistenceLoadReadsDistinctIdAtBlockExecutionNotDispatch() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "real_user",
        response: response),
      instanceName: instanceName)

    let delegate = PersistenceTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          variantLookupPolicy: .persistenceUntilNetworkSuccess(ttl: 86_400))),
      distinctId: "wrong_user")
    retainedDelegates.append(delegate)

    // Suspend the queue BEFORE the manager init so the persistence-load dispatch sits in
    // the queue without running. Models the worst-case race: GCD couldn't schedule the
    // worker thread before init's caller continued past the dispatch point.
    let queue = DispatchQueue(label: "ff.persistence.race.test.\(UUID().uuidString)")
    queue.suspend()
    let manager = FeatureFlagManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)

    // "unarchive() finishes" — the persisted identity is now visible via the delegate.
    delegate.distinctId = "real_user"

    // Let the persistence load proceed. The waitForTrackingQueue helper posts a barrier
    // task; because the queue is serial, the persistence load runs first.
    queue.resume()
    waitForTrackingQueue(manager: manager)

    XCTAssertTrue(
      manager.areFlagsReady(),
      "persistence load should have used the post-mutation distinctId, not the construction-time one")
    XCTAssertEqual(manager.getAllVariantsSync().count, 1)
  }

  // MARK: - TTL re-check on get
  //
  // The TTL is re-checked on every `getVariant`/`getAllVariants` call (not only at init load
  // time). Once a `.persistence(persistedAt:)`-stamped variant ages past TTL while sitting in
  // memory, lookups return the developer fallback rather than the stale value. The on-disk
  // blob is NOT deleted — the next successful fetch will overwrite it.

  /// A `.persistence(persistedAt:)`-stamped variant that's older than the configured TTL is
  /// treated as not-present by `getVariantSync` — the developer fallback is returned instead.
  func testGetVariantSyncReturnsFallbackForExpiredPersistedVariant() throws {
    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: manager)

    // Inject an expired persisted variant directly into in-memory state. Bypasses the disk
    // load path so we can test the get-time TTL check in isolation. persistedAt is 1 hour
    // ago, well past the 60s TTL configured above.
    let persistedAt = Date(timeIntervalSinceNow: -3600)
    let expired = MixpanelFlagVariant(key: "v1", value: "stale_value")
      .withSource(.persistence(persistedAt: persistedAt))
    manager.flagsLock.write {
      manager.flags = ["flag_a": expired]
      manager.loadedBlobPersistedAt = persistedAt
    }

    let fallback = MixpanelFlagVariant(key: "fb", value: "fallback_value")
    let result = manager.getVariantSync("flag_a", fallback: fallback)

    XCTAssertEqual(result.value as? String, "fallback_value")
    if case .fallback = result.source {} else {
      XCTFail("served fallback should carry .fallback source")
    }
  }

  /// A `.persistence(persistedAt:)`-stamped variant within TTL is served as-is (with
  /// `.persistence` source preserved).
  func testGetVariantSyncReturnsFreshPersistedVariant() throws {
    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    let persistedAt = Date(timeIntervalSinceNow: -60)
    let fresh = MixpanelFlagVariant(key: "v1", value: "fresh_value")
      .withSource(.persistence(persistedAt: persistedAt))
    manager.flagsLock.write {
      manager.flags = ["flag_a": fresh]
      manager.loadedBlobPersistedAt = persistedAt
    }

    let fallback = MixpanelFlagVariant(key: "fb", value: "fallback_value")
    let result = manager.getVariantSync("flag_a", fallback: fallback)

    XCTAssertEqual(result.value as? String, "fresh_value")
    if case .persistence = result.source {} else {
      XCTFail("expected .persistence source preserved")
    }
  }

  /// `.network`-stamped variants are never expired regardless of how old they are — TTL only
  /// applies to `.persistence(persistedAt:)` variants.
  func testGetVariantSyncReturnsNetworkVariantRegardlessOfAge() throws {
    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: manager)

    // .network variants don't carry a timestamp, so the TTL check should always return false.
    let networkVariant = MixpanelFlagVariant(key: "v1", value: "from_network")
      .withSource(.network)
    manager.flagsLock.write {
      manager.flags = ["flag_a": networkVariant]
    }

    let fallback = MixpanelFlagVariant(key: "fb", value: "fallback_value")
    let result = manager.getVariantSync("flag_a", fallback: fallback)
    XCTAssertEqual(result.value as? String, "from_network")
  }

  /// When the loaded persisted blob is past TTL, `getAllVariantsSync` filters out all
  /// `.persistence` variants but keeps `.network` variants (e.g., activated first-time
  /// events that were promoted to network source mid-session). Documents the blob-level
  /// expiry rule: all `.persistence` variants share `persistedAt`, so they pass-or-fail
  /// the TTL check together.
  func testGetAllVariantsSyncFiltersPersistedVariantsWhenBlobIsStale() throws {
    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: manager)

    let stalePersistedAt = Date(timeIntervalSinceNow: -3600)
    let stalePersistedA = MixpanelFlagVariant(key: "v1", value: "stale_a")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    let stalePersistedB = MixpanelFlagVariant(key: "v2", value: "stale_b")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    let networkSourced = MixpanelFlagVariant(key: "v3", value: "from_network")
      .withSource(.network)

    manager.flagsLock.write {
      manager.flags = [
        "stale_flag_a": stalePersistedA,
        "stale_flag_b": stalePersistedB,
        "network_flag": networkSourced,
      ]
      manager.loadedBlobPersistedAt = stalePersistedAt
    }

    let result = manager.getAllVariantsSync()
    XCTAssertEqual(result.count, 1)
    XCTAssertNil(result["stale_flag_a"], "stale persisted variant should be filtered out")
    XCTAssertNil(result["stale_flag_b"], "stale persisted variant should be filtered out")
    XCTAssertNotNil(
      result["network_flag"], ".network variants survive blob expiration (e.g., activated FTEs)")
  }

  /// The on-disk blob is NOT deleted when an in-memory variant expires at get-time.
  /// Per the rule: "no harm in keeping. Will likely be overwritten shortly after."
  func testExpiredVariantOnGetVariantDoesNotWipeDiskPersistence() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"v"}}}"#
    let blob = FlagsPersistenceBlob(persistedAt: Date(), distinctId: "user_a", response: response)
    MixpanelPersistence.saveFlagsPersistence(blob, instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    // Force the in-memory variant to be expired without wiping the disk blob.
    let stalePersistedAt = Date(timeIntervalSinceNow: -90_000)  // > 86_400s TTL
    let expired = MixpanelFlagVariant(key: "v1", value: "stale")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    manager.flagsLock.write {
      manager.flags = ["flag_a": expired]
      manager.loadedBlobPersistedAt = stalePersistedAt
    }

    let fallback = MixpanelFlagVariant(key: "fb", value: "fb")
    let result = manager.getVariantSync("flag_a", fallback: fallback)
    XCTAssertEqual(result.value as? String, "fb")

    // Critical: blob persists. The next successful fetch overwrites it; this lookup didn't
    // delete it.
    XCTAssertNotNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      "expired-on-get must NOT wipe the on-disk blob")
  }

  // MARK: - NetworkFirst gating

  func testNetworkFirstSetsAwaitingFlagWhenPersistenceLoaded() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    // Sync lookups + areFlagsReady reflect the persistence layer regardless of policy.
    XCTAssertTrue(manager.areFlagsReady())
    var awaitingValue = false
    manager.flagsLock.read { awaitingValue = manager.awaitingInitialNetworkResponse }
    XCTAssertTrue(awaitingValue, ".networkFirst must await initial network response")
  }

  func testPersistenceUntilNetworkSuccessDoesNotSetAwaitingFlagWhenPersistenceLoaded() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    var awaitingValue = false
    manager.flagsLock.read { awaitingValue = manager.awaitingInitialNetworkResponse }
    XCTAssertFalse(awaitingValue, ".persistenceUntilNetworkSuccess must not await initial network response")
  }

  func testNetworkFirstAsyncLookupAwaitsFetchEvenWithPersistence() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(ttl: 86_400))

    // Configure the mock to "succeed" with new flags, but with a delay that lets us assert
    // the async lookup waited for the network rather than serving persisted values
    // immediately.
    mock.simulatedFetchResult = (
      success: true,
      flags: [
        "flag_a": MixpanelFlagVariant(key: "v_fresh", value: "network_val")
      ]
    )
    mock.simulatedNetworkDelay = 0.1  // 100ms delay

    waitForTrackingQueue(manager: mock)
    // Persistence load should have populated `flags` with .persistence stamping. Now async
    // lookup must NOT serve those persisted values — it has to await the network response.
    let asyncDone = expectation(description: "async lookup completes after network")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      // The variant served must be the network value, not the persisted one.
      XCTAssertEqual(variant.value as? String, "network_val")
      if case .network = variant.source {} else {
        XCTFail("variant served by NetworkFirst should be from .network after fetch")
      }
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  func testNetworkFirstFallsBackToPersistenceOnFetchFailure() throws {
    let persistedAt = Date(timeIntervalSinceNow: -60)  // 60s old, well within TTL
    let response = #"{"flags":{"flag_a":{"variant_key":"v_persisted","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: persistedAt,
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(ttl: 86_400))
    mock.simulatedFetchResult = (success: false, flags: nil)

    waitForTrackingQueue(manager: mock)

    let asyncDone = expectation(description: "async lookup completes after fetch failure")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      // Fetch failed → persisted values stay → async lookup serves the persisted variant.
      XCTAssertEqual(variant.value as? String, "persisted_val")
      if case .persistence = variant.source {} else {
        XCTFail("variant served on NetworkFirst failure should keep .persistence source")
      }
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  func testPersistenceUntilNetworkSuccessAsyncLookupServesPersistedImmediately() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    // Configure a slow network so we'd notice if the lookup was waiting on it.
    mock.simulatedFetchResult = (
      success: true, flags: ["flag_a": MixpanelFlagVariant(key: "v2", value: "network_val")])
    mock.simulatedNetworkDelay = 0.1

    waitForTrackingQueue(manager: mock)

    let asyncDone = expectation(description: "async lookup completes")
    let start = Date()
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      let elapsed = Date().timeIntervalSince(start)
      XCTAssertEqual(
        variant.value as? String, "persisted_val", "persistenceUntilNetworkSuccess should serve persisted")
      if case .persistence = variant.source {} else { XCTFail("expected .persistence source") }
      // Generous bound — just want to confirm we didn't wait on the 100ms simulated network.
      XCTAssertLessThan(elapsed, 0.08, "persistenceUntilNetworkSuccess should not wait for network")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 1.0)
  }

  // MARK: - Reset wipes persistence

  func testResetWipesDiskPersistence() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: manager)

    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    manager.reset()
    waitForTrackingQueue(manager: manager)

    XCTAssertNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      "reset() should wipe the on-disk persistence blob")
    XCTAssertFalse(manager.areFlagsReady())
  }

  /// `setContext` deliberately does NOT clear in-memory variants OR the on-disk blob. The
  /// blob is keyed on distinctId only, so it remains valid across context changes for the
  /// same user. The next successful fetch under the new context overwrites the blob.
  func testSetContextDoesNotWipePersistenceOrInMemoryState() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    // Make the post-setContext fetch fail so we can isolate setContext's effect — without
    // a successful overwrite, the blob's survival is solely attributable to setContext
    // NOT wiping it. The same goes for in-memory state.
    mock.simulatedFetchResult = (success: false, flags: nil)
    mock.simulatedNetworkDelay = 0
    waitForTrackingQueue(manager: mock)

    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))
    XCTAssertTrue(mock.areFlagsReady(), "persistence load on init should populate flags")

    let setContextDone = expectation(description: "setContext fetch completes")
    mock.setContext(["plan": "enterprise"]) { setContextDone.fulfill() }
    wait(for: [setContextDone], timeout: 2.0)
    waitForTrackingQueue(manager: mock)

    XCTAssertNotNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      "setContext must NOT wipe the on-disk persistence blob")
    XCTAssertTrue(
      mock.areFlagsReady(),
      "setContext must NOT clear in-memory variants")
  }

  // MARK: - Async lookups refresh when loaded blob is stale
  //
  // When a persisting policy is in effect and the loaded persisted blob has aged past TTL
  // mid-session, the async getVariant / getAllVariants paths must fall through to a network
  // fetch rather than silently serving the developer fallback or an empty dict. The blob
  // shares a single `persistedAt`, so any one expired entry decides for the whole set.

  /// `getVariant(completion:)` triggers a fetch when the in-memory persisted variant for the
  /// requested flag has aged past TTL, and serves the post-fetch (network) value rather than
  /// the developer fallback.
  func testGetVariantAsyncTriggersFetchWhenLoadedBlobIsStale() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: mock)

    // Inject an expired persisted variant directly. Bypasses the disk-load path so we can
    // pin the staleness without depending on init timing.
    let stalePersistedAt = Date(timeIntervalSinceNow: -3600)
    let expired = MixpanelFlagVariant(key: "v_old", value: "stale_val")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    mock.flagsLock.write {
      mock.flags = ["flag_a": expired]
      mock.loadedBlobPersistedAt = stalePersistedAt
    }

    // Mock the refresh response so we can confirm the served value came from the network.
    mock.simulatedFetchResult = (
      success: true,
      flags: ["flag_a": MixpanelFlagVariant(key: "v_fresh", value: "network_val")]
    )
    mock.simulatedNetworkDelay = 0

    let asyncDone = expectation(description: "async lookup completes after refresh")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(
        variant.value as? String, "network_val",
        "stale persisted blob should trigger fetch and serve the network value")
      if case .network = variant.source {} else {
        XCTFail("post-fetch variant should carry .network source")
      }
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  /// When the loaded blob is stale and the refresh fails, async getVariant serves the
  /// developer fallback (the stale persisted value is filtered by `_getVariantSyncImpl`'s
  /// per-variant TTL check). This documents the post-fix tolerance: we fetch, but we don't
  /// resurrect stale values just because the network was unavailable.
  func testGetVariantAsyncReturnsFallbackWhenStaleBlobAndFetchFails() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: mock)

    let stalePersistedAt = Date(timeIntervalSinceNow: -3600)
    let expired = MixpanelFlagVariant(key: "v_old", value: "stale_val")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    mock.flagsLock.write {
      mock.flags = ["flag_a": expired]
      mock.loadedBlobPersistedAt = stalePersistedAt
    }

    mock.simulatedFetchResult = (success: false, flags: nil)
    mock.simulatedNetworkDelay = 0

    let asyncDone = expectation(description: "async lookup completes after failed refresh")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback_val")) { variant in
      XCTAssertEqual(variant.value as? String, "fallback_val")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  /// `getAllVariants(completion:)` triggers a fetch when the loaded blob is stale rather
  /// than returning an empty (post-filter) dictionary without attempting refresh.
  func testGetAllVariantsAsyncTriggersFetchWhenLoadedBlobIsStale() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: mock)

    let stalePersistedAt = Date(timeIntervalSinceNow: -3600)
    let expiredA = MixpanelFlagVariant(key: "v1", value: "stale_a")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    let expiredB = MixpanelFlagVariant(key: "v2", value: "stale_b")
      .withSource(.persistence(persistedAt: stalePersistedAt))
    mock.flagsLock.write {
      mock.flags = ["flag_a": expiredA, "flag_b": expiredB]
      mock.loadedBlobPersistedAt = stalePersistedAt
    }

    mock.simulatedFetchResult = (
      success: true,
      flags: [
        "flag_a": MixpanelFlagVariant(key: "v1f", value: "fresh_a"),
        "flag_b": MixpanelFlagVariant(key: "v2f", value: "fresh_b"),
      ]
    )
    mock.simulatedNetworkDelay = 0

    let asyncDone = expectation(description: "async getAll completes after refresh")
    mock.getAllVariants { variants in
      XCTAssertEqual(variants.count, 2)
      XCTAssertEqual(variants["flag_a"]?.value as? String, "fresh_a")
      XCTAssertEqual(variants["flag_b"]?.value as? String, "fresh_b")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  /// An empty persisted blob within TTL is treated as a valid state: serve the developer
  /// fallback, no network refresh. The customer is opting into "use cached flags," and
  /// the cache says "no flags configured at the time it was written" — until TTL elapses,
  /// we trust that.
  func testGetVariantAsyncServesFallbackOnEmptyFreshBlobWithoutRefresh() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: mock)

    let freshPersistedAt = Date(timeIntervalSinceNow: -60)  // well within TTL
    mock.flagsLock.write {
      mock.flags = [:]
      mock.loadedBlobPersistedAt = freshPersistedAt
    }

    // Configure a recognizable network response. If the staleness check wrongly triggers
    // a fetch, the served value would be "should_not_be_served".
    mock.simulatedFetchResult = (
      success: true,
      flags: ["flag_a": MixpanelFlagVariant(key: "v1", value: "should_not_be_served")]
    )
    mock.simulatedNetworkDelay = 0

    let asyncDone = expectation(description: "async lookup completes without refresh")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(
        variant.value as? String, "fallback",
        "empty fresh blob should serve fallback without auto-refreshing")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  /// An empty persisted blob PAST TTL still triggers a fetch — the TTL governs when to
  /// refresh regardless of whether the blob has flags in it. This is exactly why we keep
  /// `loadedBlobPersistedAt` separate from variant inspection: an empty blob has no
  /// variants to check, but its persistedAt still tells us when to give up on the cache.
  func testGetVariantAsyncTriggersFetchWhenEmptyBlobIsStale() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 60))
    waitForTrackingQueue(manager: mock)

    let stalePersistedAt = Date(timeIntervalSinceNow: -3600)  // well past 60s TTL
    mock.flagsLock.write {
      mock.flags = [:]
      mock.loadedBlobPersistedAt = stalePersistedAt
    }

    mock.simulatedFetchResult = (
      success: true,
      flags: ["flag_a": MixpanelFlagVariant(key: "v1", value: "fresh_val")]
    )
    mock.simulatedNetworkDelay = 0

    let asyncDone = expectation(description: "async lookup refreshes stale empty blob")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(
        variant.value as? String, "fresh_val",
        "stale empty blob should trigger fetch and serve newly-discovered flag")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)
  }

  /// Sanity check the existing serve-immediately path still wins when the loaded blob is
  /// fresh — the staleness check shouldn't push fresh persisted variants through a needless
  /// network round-trip.
  func testGetVariantAsyncServesFreshPersistedImmediatelyWithoutFetch() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: 86_400))
    waitForTrackingQueue(manager: mock)

    let freshPersistedAt = Date(timeIntervalSinceNow: -60)
    let fresh = MixpanelFlagVariant(key: "v1", value: "persisted_val")
      .withSource(.persistence(persistedAt: freshPersistedAt))
    mock.flagsLock.write {
      mock.flags = ["flag_a": fresh]
      mock.loadedBlobPersistedAt = freshPersistedAt
    }

    // Configure a slow + clearly-different network response. If the staleness check
    // wrongly triggers a fetch, the test will catch the wrong value (and the slow delay
    // would add noticeable latency).
    mock.simulatedFetchResult = (
      success: true,
      flags: ["flag_a": MixpanelFlagVariant(key: "v2", value: "network_val")]
    )
    mock.simulatedNetworkDelay = 0.1

    let asyncDone = expectation(description: "async getVariant completes")
    let start = Date()
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fb")) { variant in
      let elapsed = Date().timeIntervalSince(start)
      XCTAssertEqual(variant.value as? String, "persisted_val")
      if case .persistence = variant.source {} else {
        XCTFail("fresh persisted variant should be served as-is, not refreshed")
      }
      XCTAssertLessThan(elapsed, 0.08, "fresh blob must not wait on the network")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 1.0)
  }

  // MARK: - Tracking properties for persisted variants

  /// When a served variant came from the persistence layer, `$experiment_started` carries
  /// `$variant_source` = "persistence", `$persisted_at_in_ms` (raw epoch ms — no offsets,
  /// no deltas), and `$ttl_in_ms` (the customer-configured TTL in ms). Verifies the values
  /// against the same `persistedAt` and `ttl` we configured.
  func testTrackingIncludesPersistencePropertiesForPersistedVariant() throws {
    // Use a recent fixed timestamp (offset from "now") so we can assert the exact
    // $persisted_at_in_ms while still passing the TTL check.
    let persistedAt = Date(timeIntervalSinceNow: -60)  // 60s ago
    let ttlSeconds: TimeInterval = 86_400  // 24 hours
    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(ttl: ttlSeconds))
    waitForTrackingQueue(manager: manager)
    let delegate = retainedDelegates.last as! PersistenceTestMockDelegate

    // Inject a .persistence-stamped variant directly. Bypasses the disk-load round-trip so
    // we can pin `persistedAt` to an exact value for the assertion below without depending
    // on the blob serializer's millisecond rounding.
    let persistedVariant = MixpanelFlagVariant(key: "v1", value: "persisted_val")
      .withSource(.persistence(persistedAt: persistedAt))
    manager.flagsLock.write {
      manager.flags = ["flag_a": persistedVariant]
      manager.loadedBlobPersistedAt = persistedAt
    }

    // Trigger tracking by reading the persisted variant (first read records the tracking
    // event; subsequent reads are deduped via `trackedFeatures`).
    let fallback = MixpanelFlagVariant(key: "fb", value: "fb")
    _ = manager.getVariantSync("flag_a", fallback: fallback)

    // The delegate.track call is dispatched async to main; spin briefly until it lands.
    let trackedExpectation = expectation(description: "tracking event recorded")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      let events = delegate.snapshotTrackedEvents()
      if events.contains(where: { $0.event == "$experiment_started" }) {
        trackedExpectation.fulfill()
      }
    }
    wait(for: [trackedExpectation], timeout: 2.0)

    let events = delegate.snapshotTrackedEvents()
    let experiment = try XCTUnwrap(events.first(where: { $0.event == "$experiment_started" }))
    let props = try XCTUnwrap(experiment.properties)

    XCTAssertEqual(props["$variant_source"] as? String, "persistence")
    let expectedPersistedAtMs = Int(persistedAt.timeIntervalSince1970 * 1000)
    XCTAssertEqual(props["$persisted_at_in_ms"] as? Int, expectedPersistedAtMs)
    XCTAssertEqual(props["$ttl_in_ms"] as? Int, Int(ttlSeconds * 1000))
  }

  /// `.network`-sourced variants must NOT include any of the persistence-layer tracking
  /// properties. This protects against accidentally leaking persistence-stamped variants
  /// through the `.network` path or vice versa.
  func testTrackingOmitsPersistencePropertiesForNetworkVariant() throws {
    let delegate = PersistenceTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          variantLookupPolicy: .networkOnly)),
      distinctId: "user_a")
    retainedDelegates.append(delegate)
    let queue = DispatchQueue(label: "ff.network.tracking.test.\(UUID().uuidString)")
    let manager = FeatureFlagManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)
    waitForTrackingQueue(manager: manager)

    // Inject a .network-sourced variant directly — bypasses the fetch path.
    let networkVariant = MixpanelFlagVariant(key: "v1", value: "network_val")
      .withSource(.network)
    manager.flagsLock.write { manager.flags = ["flag_a": networkVariant] }

    let fallback = MixpanelFlagVariant(key: "fb", value: "fb")
    _ = manager.getVariantSync("flag_a", fallback: fallback)

    let trackedExpectation = expectation(description: "tracking event recorded")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      let events = delegate.snapshotTrackedEvents()
      if events.contains(where: { $0.event == "$experiment_started" }) {
        trackedExpectation.fulfill()
      }
    }
    wait(for: [trackedExpectation], timeout: 2.0)

    let events = delegate.snapshotTrackedEvents()
    let experiment = try XCTUnwrap(events.first(where: { $0.event == "$experiment_started" }))
    let props = try XCTUnwrap(experiment.properties)

    XCTAssertNil(props["$variant_source"], "network variants must not carry $variant_source")
    XCTAssertNil(props["$persisted_at_in_ms"])
    XCTAssertNil(props["$ttl_in_ms"])
  }

  // MARK: - Helpers

  private func makeManager(
    distinctId: String,
    context: [String: Any],
    policy: VariantLookupPolicy
  ) -> FeatureFlagManager {
    let delegate = PersistenceTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          context: context,
          variantLookupPolicy: policy)),
      distinctId: distinctId)
    retainedDelegates.append(delegate)
    let queue = DispatchQueue(label: "ff.persistence.test.\(UUID().uuidString)")
    return FeatureFlagManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)
  }

  private func makeMockManager(
    distinctId: String,
    context: [String: Any],
    policy: VariantLookupPolicy
  ) -> PersistenceTestMockManager {
    let delegate = PersistenceTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          context: context,
          variantLookupPolicy: policy)),
      distinctId: distinctId)
    retainedDelegates.append(delegate)
    let queue = DispatchQueue(label: "ff.persistence.mock.test.\(UUID().uuidString)")
    return PersistenceTestMockManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)
  }

  /// Wait for any pending work on the manager's tracking queue (notably the async
  /// persistence load posted from init) to complete by posting a barrier task and blocking
  /// on it.
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
