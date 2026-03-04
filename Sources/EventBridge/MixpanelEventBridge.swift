//
//  MixpanelEventBridge.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-03-03.
//

import Foundation

/// Manages registration and dispatch of event notifications to external listeners.
/// Thread-safe, uses weak references to avoid retain cycles.
public final class MixpanelEventBridge: NSObject {

    // MARK: - Singleton

    /// Shared instance
    @objc public static let shared = MixpanelEventBridge()

    // MARK: - Private Properties

    /// Serial queue for thread-safe listener access and dispatch
    private let queue = DispatchQueue(
        label: "com.mixpanel.event-bridge",
        qos: .utility
    )

    /// Weak wrapper to avoid retain cycles with listeners
    private struct WeakListener {
        weak var listener: MixpanelEventListener?
        let id: ObjectIdentifier

        init(_ listener: MixpanelEventListener) {
            self.listener = listener
            self.id = ObjectIdentifier(listener)
        }
    }

    /// Registered listeners (stored as weak references)
    private var listeners: [WeakListener] = []

    /// Metrics for debugging and monitoring
    private var totalEventsDispatched: Int = 0
    private var totalDispatchTime: TimeInterval = 0

    // MARK: - Public API

    /// Optional metrics handler for monitoring (production-safe)
    public var metricsHandler: ((BridgeMetrics) -> Void)?

    #if DEBUG
    /// Enable verbose logging for debugging
    public var verboseLogging: Bool = false
    #endif

    /// Register a listener to receive event notifications.
    /// - Parameter listener: The listener to register (stored as weak reference)
    @objc public func registerListener(_ listener: AnyObject) {
        guard let listener = listener as? MixpanelEventListener else {
            print("[MixpanelEventBridge] Warning: Attempted to register non-conforming listener: \(listener)")
            return
        }
            
        queue.async { [weak self] in
            guard let self = self else { return }

            // Check if already registered
            let id = ObjectIdentifier(listener)
            if self.listeners.contains(where: { $0.id == id }) {
                return
            }

            self.listeners.append(WeakListener(listener))
            self.cleanupDeallocatedListeners()

            #if DEBUG
            print("[MixpanelEventBridge] Listener registered. Total: \(self.listeners.count)")
            #endif
        }
    }

    /// Unregister a specific listener.
    /// - Parameter listener: The listener to unregister
    @objc public func unregisterListener(_ listener: AnyObject) {
        guard let listener = listener as? MixpanelEventListener else {
            print("[MixpanelEventBridge] Warning: Attempted to register non-conforming listener: \(listener)")
            return
        }
        queue.async { [weak self] in
            guard let self = self else { return }

            let id = ObjectIdentifier(listener)
            self.listeners.removeAll { $0.id == id }

            #if DEBUG
            print("[MixpanelEventBridge] Listener unregistered. Total: \(self.listeners.count)")
            #endif
        }
    }

    /// Remove all registered listeners.
    @objc public func removeAllListeners() {
        queue.async { [weak self] in
            self?.listeners.removeAll()
        }
    }

    // MARK: - Internal API

    /// Notify all registered listeners of a tracked event.
    /// - Parameters:
    ///   - event: Event name
    ///   - properties: Event properties
    ///   - timestamp: When the event was tracked
    ///   - instanceName: Mixpanel instance name (nil = main)
    internal func notifyListeners(
        event: String,
        properties: [String: Any],
        timestamp: Date,
        instanceName: String? = nil
    ) {
        let startTime = Date()

        // Create event object
        let trackedEvent = MixpanelTrackedEvent(
            name: event,
            properties: properties,
            timestamp: timestamp,
            instanceName: instanceName
        )

        queue.async { [weak self] in
            guard let self = self else { return }

            self.cleanupDeallocatedListeners()

            // Early exit if no listeners
            guard !self.listeners.isEmpty else { return }

            #if DEBUG
            if self.verboseLogging {
                print("""
                [EventBridge] Dispatching '\(trackedEvent.name)'
                  → Listeners: \(self.listeners.count)
                  → Instance: \(trackedEvent.instanceName ?? "main")
                  → Properties: \(trackedEvent.properties.keys.sorted().joined(separator: ", "))
                """)
            }
            #endif

            // Notify each listener with filtered properties
            for wrapper in self.listeners {
                guard let listener = wrapper.listener else { continue }
                listener.mixpanelDidTrackEvent(trackedEvent)
            }

            // Update metrics
            self.totalEventsDispatched += 1
            let dispatchTime = Date().timeIntervalSince(startTime)
            self.totalDispatchTime += dispatchTime

            // Report metrics if handler is set
            if let handler = self.metricsHandler {
                let metrics = BridgeMetrics(
                    totalEventsDispatched: self.totalEventsDispatched,
                    activeListenerCount: self.listeners.count,
                    averageDispatchTime: self.totalDispatchTime / Double(self.totalEventsDispatched)
                )
                handler(metrics)
            }
        }
    }

    // MARK: - Private Methods
    
    /// Remove nil weak references from the listener array
    private func cleanupDeallocatedListeners() {
        let before = listeners.count
        listeners.removeAll { $0.listener == nil }
        let after = listeners.count

        #if DEBUG
        if before != after {
            print("[MixpanelEventBridge] Cleaned up \(before - after) deallocated listener(s)")
        }
        #endif
    }
}

// MARK: - Metrics

/// Public metrics for monitoring bridge performance
public struct BridgeMetrics {
    public let totalEventsDispatched: Int
    public let activeListenerCount: Int
    public let averageDispatchTime: TimeInterval
}

// MARK: - Debug Extension

#if DEBUG
extension MixpanelEventBridge {

    /// Print current bridge status to console (debug builds only)
    public func printDebugInfo() {
        queue.sync {
            cleanupDeallocatedListeners()

            print("""
            ╭─────────────────────────────────────╮
            │  MixpanelEventBridge Debug Info     │
            ╰─────────────────────────────────────╯

            Active Listeners: \(listeners.count)
            Total Events Dispatched: \(totalEventsDispatched)

            Registered Listeners:
            \(listeners.enumerated().map { idx, wrapper in
                let listenerType = type(of: wrapper.listener)
                return "  \(idx + 1). \(listenerType)"
            }.joined(separator: "\n"))
            """)
        }
    }
}
#endif
