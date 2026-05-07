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
/// `loadedBlobPersistedAt` lifecycle, completion fan-out) so async-lookup tests can
/// verify behavior end-to-end.
private final class PersistenceTestMockManager: FeatureFlagManager {
  var simulatedFetchResult: (success: Bool, flags: [String: MixpanelFlagVariant]?)?
  var simulatedNetworkDelay: TimeInterval = 0.1
  private let fetchCountQueue = DispatchQueue(label: "ff.mock.fetchcount.\(UUID().uuidString)")
  private var _fetchCallCount = 0
  var fetchCallCount: Int { fetchCountQueue.sync { _fetchCallCount } }

  override func _performFetchRequest() {
    fetchCountQueue.sync { _fetchCallCount += 1 }
    let work: () -> Void = { [weak self] in
      guard let self = self else { return }
      guard let result = self.simulatedFetchResult else {
        self._completeFetch(success: false)
        return
      }
      if result.success, let flags = result.flags {
        let stamped = flags.mapValues { $0.withSource(.network) }
        self.flagsLock.write {
          self.flags = stamped
          // Mirror production: a successful fetch overwrites the persisted blob (so the
          // marker clears) and resets the per-flag $experiment_started dedup window.
          self.loadedBlobPersistedAt = nil
          self.trackedFeatures.removeAll()
          self.timeLastFetched = Date()
        }
        self._completeFetch(success: true)
      } else {
        // Failure: leave `flags` AND `loadedBlobPersistedAt` in place. NetworkFirst's
        // `isNetworkFirstAwaitingFetch()` derives from the persisted-blob marker, so the
        // gate stays true after a failure and the next async lookup retries the network.
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
  /// `.persistenceUntilNetworkSuccess()` and `.persistenceUntilNetworkSuccess(persistenceTtl:)` resolve to different members).
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

  /// Factories preserve exactly what was asked — they don't sanitize. The "non-positive TTL
  /// becomes networkOnly" rule is enforced at SDK init via `VariantLookupPolicy.effective(_:)`,
  /// not at construction time, so callers can introspect what they configured.
  func testFactoriesPreserveExactTtl() throws {
    if case .persistenceUntilNetworkSuccess(let t) = VariantLookupPolicy.persistenceUntilNetworkSuccess(persistenceTtl: -1) {
      XCTAssertEqual(t, -1)
    } else {
      XCTFail("expected .persistenceUntilNetworkSuccess case")
    }
    if case .persistenceUntilNetworkSuccess(let t) = VariantLookupPolicy.persistenceUntilNetworkSuccess(persistenceTtl: 0) {
      XCTAssertEqual(t, 0)
    } else {
      XCTFail("expected .persistenceUntilNetworkSuccess case")
    }
    if case .networkFirst(let t) = VariantLookupPolicy.networkFirst(persistenceTtl: -100) {
      XCTAssertEqual(t, -100)
    } else {
      XCTFail("expected .networkFirst case")
    }
  }

  /// Persisting policies with TTL <= 0 do no useful work (we'd write to disk on every fetch
  /// but never serve anything from persistence) so the SDK substitutes `.networkOnly` at init.
  func testEffectivePolicyNonPositiveTtlBecomesNetworkOnly() throws {
    let resolvedNegativePersistence = VariantLookupPolicy.effective(.persistenceUntilNetworkSuccess(persistenceTtl: -1))
    if case .networkOnly = resolvedNegativePersistence {} else {
      XCTFail("negative TTL on persistenceUntilNetworkSuccess should resolve to .networkOnly")
    }

    let resolvedZeroPersistence = VariantLookupPolicy.effective(.persistenceUntilNetworkSuccess(persistenceTtl: 0))
    if case .networkOnly = resolvedZeroPersistence {} else {
      XCTFail("zero TTL on persistenceUntilNetworkSuccess should resolve to .networkOnly")
    }

    let resolvedNegativeNetworkFirst = VariantLookupPolicy.effective(.networkFirst(persistenceTtl: -100))
    if case .networkOnly = resolvedNegativeNetworkFirst {} else {
      XCTFail("negative TTL on networkFirst should resolve to .networkOnly")
    }

    let resolvedZeroNetworkFirst = VariantLookupPolicy.effective(.networkFirst(persistenceTtl: 0))
    if case .networkOnly = resolvedZeroNetworkFirst {} else {
      XCTFail("zero TTL on networkFirst should resolve to .networkOnly")
    }
  }

  /// Sanity: non-degenerate configurations pass through `effective(_:)` unchanged.
  func testEffectivePolicyPositiveTtlPreserved() throws {
    let persistence = VariantLookupPolicy.persistenceUntilNetworkSuccess(persistenceTtl: 3600)
    if case .persistenceUntilNetworkSuccess(let t) = VariantLookupPolicy.effective(persistence) {
      XCTAssertEqual(t, 3600)
    } else {
      XCTFail("positive TTL should pass through unchanged")
    }

    let networkOnly = VariantLookupPolicy.networkOnly
    if case .networkOnly = VariantLookupPolicy.effective(networkOnly) {} else {
      XCTFail(".networkOnly should pass through unchanged")
    }
  }

  /// End-to-end check: configuring the SDK with a persisting policy + non-positive TTL means
  /// no persistence happens at runtime — the SDK behaves as if `.networkOnly` was configured.
  func testNonPositiveTtlPersistingPolicyBehavesAsNetworkOnly() throws {
    // Pre-stage a persisted blob on disk. Under .networkOnly init, the manager should wipe
    // it (proves the resolved policy is .networkOnly, not the persisting policy the customer
    // requested).
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":true}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)
    XCTAssertNotNil(MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName))

    let manager = makeManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 0))
    waitForTrackingQueue(manager: manager)

    XCTAssertFalse(
      manager.areFlagsReady(),
      "non-positive TTL should resolve to .networkOnly; nothing loaded from persistence")
    XCTAssertNil(
      MixpanelPersistence.loadFlagsPersistence(instanceName: instanceName),
      "resolved .networkOnly init should wipe the existing blob")
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
      distinctId: "user_a", context: context, policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))

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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))  // 60s TTL
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
          variantLookupPolicy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))),
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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

  func testNetworkFirstAsyncLookupAwaitsFetchEvenWithPersistence() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(persistenceTtl: 86_400))

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
      distinctId: "user_a", context: [:], policy: .networkFirst(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 60))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
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
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: ttlSeconds))
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

  /// `.network`-sourced variants carry `$variant_source = "network"` (matching the JS SDK)
  /// but NOT the persistence-layer-only properties (`$persisted_at_in_ms`, `$ttl_in_ms`).
  /// This protects against accidentally leaking persistence properties through the
  /// `.network` path.
  func testTrackingIncludesVariantSourceForNetworkVariant() throws {
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

    XCTAssertEqual(props["$variant_source"] as? String, "network")
    XCTAssertNil(props["$persisted_at_in_ms"], "network variants don't carry persistedAt")
    XCTAssertNil(props["$ttl_in_ms"], "network variants don't carry TTL")
  }

  // MARK: - NetworkFirst retries until a fetch succeeds

  /// Regression test for the bug where NetworkFirst would stop attempting the network after
  /// the first failure: `awaitingInitialNetworkResponse` was being cleared on fetch failure,
  /// so subsequent async lookups would silently serve persistence forever even though no
  /// successful network response had ever come back.
  ///
  /// Spec: NetworkFirst lookups await a successful network response. After a failed fetch,
  /// the next async lookup must retry the network — only a successful fetch satisfies the
  /// "we got the network value" gate. Verified end-to-end: two failed fetches in a row → two
  /// fetch attempts (not one).
  func testNetworkFirstRetriesNetworkAfterFailureUntilSuccess() throws {
    let response = #"{"flags":{"flag_a":{"variant_key":"v1","variant_value":"persisted_val"}}}"#
    MixpanelPersistence.saveFlagsPersistence(
      FlagsPersistenceBlob(
        persistedAt: Date(),
        distinctId: "user_a",
        response: response),
      instanceName: instanceName)

    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .networkFirst(persistenceTtl: 86_400))
    waitForTrackingQueue(manager: mock)

    // Round 1: fetch fails. Lookup falls back to persisted value.
    mock.simulatedFetchResult = (success: false, flags: nil)
    mock.simulatedNetworkDelay = 0
    let firstDone = expectation(description: "first lookup")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(variant.value as? String, "persisted_val",
                     "first lookup should fall back to persisted value after failed fetch")
      firstDone.fulfill()
    }
    wait(for: [firstDone], timeout: 2.0)
    XCTAssertEqual(mock.fetchCallCount, 1, "first lookup should trigger one fetch attempt")

    // Round 2: fetch fails again. Pre-fix, the lookup would skip the network entirely
    // (`awaiting` had been cleared by round 1's failure) and serve persisted directly,
    // leaving the count at 1. Post-fix, NetworkFirst retries until success.
    let secondDone = expectation(description: "second lookup")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(variant.value as? String, "persisted_val")
      secondDone.fulfill()
    }
    wait(for: [secondDone], timeout: 2.0)
    XCTAssertEqual(
      mock.fetchCallCount, 2,
      "NetworkFirst must retry the network on subsequent lookups after a failure")

    // Round 3: fetch succeeds. Network value served, blob marker cleared.
    mock.simulatedFetchResult = (
      success: true, flags: ["flag_a": MixpanelFlagVariant(key: "v_fresh", value: "network_val")])
    let thirdDone = expectation(description: "third lookup")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(variant.value as? String, "network_val",
                     "successful fetch should serve the network value")
      thirdDone.fulfill()
    }
    wait(for: [thirdDone], timeout: 2.0)
    XCTAssertEqual(mock.fetchCallCount, 3, "third lookup triggers the successful fetch")

    // Round 4: subsequent lookup should NOT retry — the gate flipped off after success.
    let fourthDone = expectation(description: "fourth lookup")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      XCTAssertEqual(variant.value as? String, "network_val")
      fourthDone.fulfill()
    }
    wait(for: [fourthDone], timeout: 2.0)
    XCTAssertEqual(
      mock.fetchCallCount, 3,
      "after a successful fetch, NetworkFirst stops retrying — gate is satisfied")
  }

  // MARK: - PersistenceUntilNetworkSuccess background refresh

  /// PUN's contract is "serve persisted now, refresh in background." The first lookup that
  /// finds the immediate-serve path satisfied by a persisted blob (not yet overwritten by a
  /// successful network fetch) must kick off a background fetch — without blocking the
  /// lookup itself — so subsequent lookups eventually see fresh values. The fetch self-stops
  /// because a successful fetch clears `loadedBlobPersistedAt`, taking us off the
  /// background-refresh trigger.
  func testPersistenceUntilNetworkSuccessLookupKicksOffBackgroundRefresh() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
    waitForTrackingQueue(manager: mock)

    let freshPersistedAt = Date(timeIntervalSinceNow: -60)
    let persisted = MixpanelFlagVariant(key: "v_old", value: "persisted_val")
      .withSource(.persistence(persistedAt: freshPersistedAt))
    mock.flagsLock.write {
      mock.flags = ["flag_a": persisted]
      mock.loadedBlobPersistedAt = freshPersistedAt
    }

    // Hang the simulated fetch so it counts as kicked-off but doesn't complete and replace
    // `flags` mid-test. Counter increments synchronously inside `_performFetchRequest`.
    mock.simulatedFetchResult = (success: true, flags: ["flag_a": MixpanelFlagVariant(key: "v_new", value: "network_val")])
    mock.simulatedNetworkDelay = 60  // effectively never completes within the test

    XCTAssertEqual(mock.fetchCallCount, 0, "no fetch before lookup")

    let asyncDone = expectation(description: "async lookup completes immediately")
    let start = Date()
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fallback")) { variant in
      let elapsed = Date().timeIntervalSince(start)
      XCTAssertEqual(
        variant.value as? String, "persisted_val",
        "lookup must serve the persisted value, not wait on the background fetch")
      if case .persistence = variant.source {} else {
        XCTFail("expected .persistence source")
      }
      XCTAssertLessThan(elapsed, 0.5, "lookup must not block on the background fetch")
      asyncDone.fulfill()
    }
    wait(for: [asyncDone], timeout: 2.0)

    // Drain the tracking queue to make sure the background _fetchFlagsIfNeeded has been
    // invoked (it's posted to the same serial queue from inside the lookup block).
    waitForTrackingQueue(manager: mock)
    XCTAssertEqual(
      mock.fetchCallCount, 1,
      "PUN's first lookup serving persistence should kick off exactly one background fetch")
  }

  /// After the background fetch completes successfully, `loadedBlobPersistedAt` is cleared
  /// (in production, by the fetch-success handler) so subsequent lookups stop triggering
  /// the background-refresh path. Verifies the self-stopping property: PUN doesn't fire a
  /// fetch on every single lookup forever.
  func testPersistenceUntilNetworkSuccessBackgroundRefreshSelfStopsAfterSuccess() throws {
    let mock = makeMockManager(
      distinctId: "user_a", context: [:], policy: .persistenceUntilNetworkSuccess(persistenceTtl: 86_400))
    waitForTrackingQueue(manager: mock)

    let freshPersistedAt = Date(timeIntervalSinceNow: -60)
    let persisted = MixpanelFlagVariant(key: "v1", value: "persisted_val")
      .withSource(.persistence(persistedAt: freshPersistedAt))
    mock.flagsLock.write {
      mock.flags = ["flag_a": persisted]
      mock.loadedBlobPersistedAt = freshPersistedAt
    }

    mock.simulatedFetchResult = (
      success: true, flags: ["flag_a": MixpanelFlagVariant(key: "v2", value: "network_val")])
    mock.simulatedNetworkDelay = 0  // complete immediately so flags get replaced post-fetch

    // First lookup: kicks off the background refresh.
    let firstDone = expectation(description: "first lookup")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fb")) { _ in firstDone.fulfill() }
    wait(for: [firstDone], timeout: 2.0)
    waitForTrackingQueue(manager: mock)
    XCTAssertEqual(mock.fetchCallCount, 1, "first lookup kicks off the background refresh")

    // Second lookup: now `loadedBlobPersistedAt` should be nil (cleared by the successful
    // fetch), so this lookup serves the network value without triggering another fetch.
    let secondDone = expectation(description: "second lookup")
    mock.getVariant("flag_a", fallback: MixpanelFlagVariant(value: "fb")) { variant in
      XCTAssertEqual(
        variant.value as? String, "network_val",
        "second lookup should serve the freshly-fetched network value")
      secondDone.fulfill()
    }
    wait(for: [secondDone], timeout: 2.0)
    waitForTrackingQueue(manager: mock)
    XCTAssertEqual(
      mock.fetchCallCount, 1,
      "no additional fetch — successful refresh cleared loadedBlobPersistedAt")
  }

  // MARK: - Tracking dedup window resets after every successful fetch

  /// Regression test mirroring mixpanel-android's
  /// `testTracking_getVariantSync_refireAfterSuccessfulRefetch`.
  ///
  /// The per-flag `trackedFeatures` set deduplicates `$experiment_started` within a fetch
  /// round, but must clear on every successful refetch so a second fetch round gets a fresh
  /// shot at firing tracking — even when the variant value didn't change. Without the clear,
  /// a flag whose value flipped between fetches (persisted "control" → network "treatment")
  /// would serve the new value but skip tracking, leaving Mixpanel analytics permanently
  /// tied to the prior exposure.
  func testTrackingRefiresAfterSuccessfulRefetch() throws {
    let delegate = PersistenceTestMockDelegate(
      options: MixpanelOptions(
        token: "test_token",
        featureFlagOptions: FeatureFlagOptions(
          enabled: true,
          variantLookupPolicy: .networkOnly)),
      distinctId: "user_a")
    retainedDelegates.append(delegate)
    let queue = DispatchQueue(label: "ff.refire.test.\(UUID().uuidString)")
    let mock = PersistenceTestMockManager(
      serverURL: "https://example.test",
      trackingQueue: queue,
      instanceName: instanceName,
      delegate: delegate)
    waitForTrackingQueue(manager: mock)

    // ── Fetch round 1: server returns flag_X = variant_A. ──
    mock.simulatedFetchResult = (
      success: true,
      flags: ["flag_x": MixpanelFlagVariant(key: "variant_a", value: "value_a")]
    )
    mock.simulatedNetworkDelay = 0
    let firstFetchDone = expectation(description: "first fetch completes")
    mock.loadFlags(completion: { _ in firstFetchDone.fulfill() })
    wait(for: [firstFetchDone], timeout: 2.0)

    let fallback = MixpanelFlagVariant(key: "fb", value: "fb_value")

    // First lookup → tracks once.
    _ = mock.getVariantSync("flag_x", fallback: fallback)
    waitForMainAndTracking(manager: mock)
    XCTAssertEqual(
      delegate.snapshotTrackedEvents().filter { $0.event == "$experiment_started" }.count, 1,
      "first lookup should fire $experiment_started exactly once")

    // Second lookup in the same fetch round → still 1 (dedup intact).
    _ = mock.getVariantSync("flag_x", fallback: fallback)
    waitForMainAndTracking(manager: mock)
    XCTAssertEqual(
      delegate.snapshotTrackedEvents().filter { $0.event == "$experiment_started" }.count, 1,
      "repeat lookup in the same fetch round must not re-fire (dedup window)")

    // ── Fetch round 2: server returns the SAME variant — proves we're testing the
    //    dedup-clearing behavior, not a value-change-detection behavior. ──
    mock.simulatedFetchResult = (
      success: true,
      flags: ["flag_x": MixpanelFlagVariant(key: "variant_a", value: "value_a")]
    )
    let secondFetchDone = expectation(description: "second fetch completes")
    mock.loadFlags(completion: { _ in secondFetchDone.fulfill() })
    wait(for: [secondFetchDone], timeout: 2.0)

    // Lookup after refetch → fires again (dedup window reset).
    _ = mock.getVariantSync("flag_x", fallback: fallback)
    waitForMainAndTracking(manager: mock)
    XCTAssertEqual(
      delegate.snapshotTrackedEvents().filter { $0.event == "$experiment_started" }.count, 2,
      "successful refetch should clear the dedup window so the next lookup re-fires")
  }

  /// `waitForTrackingQueue` only drains the tracking queue. Tracking-event recording goes
  /// through `DispatchQueue.main.async` after the tracking queue, so we need to drain main
  /// too to observe the recorded events.
  private func waitForMainAndTracking(manager: FeatureFlagManager) {
    waitForTrackingQueue(manager: manager)
    let mainDrained = expectation(description: "main queue drained")
    DispatchQueue.main.async { mainDrained.fulfill() }
    wait(for: [mainDrained], timeout: 1.0)
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
