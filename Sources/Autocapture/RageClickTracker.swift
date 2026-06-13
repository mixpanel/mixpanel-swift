//
//  RageClickTracker.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

#if os(iOS)
  import UIKit

  /// Result of tracking a click for rage click detection.
  struct RageClickResult {
    /// Whether this click triggered a rage click event
    let isRageClick: Bool

    /// Total number of clicks in the current sequence
    let tapCount: Int
  }

  /// Tracks rapid repeated clicks to detect user frustration (rage clicks).
  ///
  /// A rage click is detected when a user taps multiple times within a short time window
  /// in approximately the same location, indicating frustration with an unresponsive element.
  ///
  /// Default thresholds (matching JS SDK):
  /// - 4 or more clicks
  /// - Within 1000ms time window
  /// - Within 44pt spatial radius
  final class RageClickTracker {
    // MARK: - Configuration

    private let clickThreshold: Int
    private let timeWindowMs: Int64
    private let spatialRadius: CGFloat

    // MARK: - State

    private var recentClicks: [ClickRecord] = []
    private let lock = NSLock()

    // MARK: - Time Provider (for testability)

    private let timeProvider: () -> Int64

    // MARK: - Types

    private struct ClickRecord {
      let x: CGFloat
      let y: CGFloat
      let timestamp: Int64
    }

    // MARK: - Initialization

    /// Create a rage click tracker with custom configuration.
    ///
    /// - Parameters:
    ///   - options: Rage click detection options
    ///   - timeProvider: Optional time provider for testing (defaults to current time in ms)
    init(
      options: RageClickOptions,
      timeProvider: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
      self.clickThreshold = options.clickThreshold
      self.timeWindowMs = options.timeWindowMs
      self.spatialRadius = options.radius
      self.timeProvider = timeProvider
    }

    // MARK: - Public API

    /// Track a click and check if it triggers a rage click.
    ///
    /// - Parameters:
    ///   - x: X coordinate of the click
    ///   - y: Y coordinate of the click
    /// - Returns: Result indicating if this is a rage click and the total tap count
    func trackClick(x: CGFloat, y: CGFloat) -> RageClickResult {
      lock.lock()
      defer { lock.unlock() }

      let now = timeProvider()

      // Clean old clicks outside time window
      cleanOldClicks(currentTime: now)

      // Count nearby clicks within spatial threshold
      let nearbyCount = countNearbyClicks(x: x, y: y)

      // Add current click to history
      recentClicks.append(ClickRecord(x: x, y: y, timestamp: now))

      // Total count includes current click
      let totalCount = nearbyCount + 1

      // Rage click triggers when we have threshold-1 previous clicks nearby
      // (so the current click is the Nth click)
      let isRageClick = nearbyCount >= (clickThreshold - 1)

      // Clean old clicks to prevent memory growth
      if recentClicks.count > 20 {
        cleanOldClicks(currentTime: now)
      }

      return RageClickResult(isRageClick: isRageClick, tapCount: totalCount)
    }

    /// Reset tracking state (e.g., on scene change or app background).
    func reset() {
      lock.lock()
      defer { lock.unlock() }
      recentClicks.removeAll()
    }

    // MARK: - Private

    private func cleanOldClicks(currentTime: Int64) {
      let cutoff = currentTime - timeWindowMs
      recentClicks.removeAll { $0.timestamp < cutoff }
    }

    private func countNearbyClicks(x: CGFloat, y: CGFloat) -> Int {
      var count = 0
      for click in recentClicks {
        let distance = sqrt(pow(click.x - x, 2) + pow(click.y - y, 2))
        if distance <= spatialRadius {
          count += 1
        }
      }
      return count
    }
  }
#endif
