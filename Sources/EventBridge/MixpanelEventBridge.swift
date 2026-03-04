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

    // MARK: - Public API

    /// Register a listener to receive event notifications.
    /// - Parameter listener: The listener to register (stored as weak reference)
    @objc public func registerListener(_ listener: AnyObject) {
        guard let listener = listener as? MixpanelEventListener else {
            MixpanelLogger.warn(message: "Attempted to register non-conforming listener")
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            // Check if already registered
            let id = ObjectIdentifier(listener)
            if self.listeners.contains(where: { $0.id == id }) {
                MixpanelLogger.debug(message: "Listener already registered, skipping")
                return
            }

            self.listeners.append(WeakListener(listener))
            self.cleanupDeallocatedListeners()

            MixpanelLogger.info(message: "Event bridge listener registered")
        }
    }

    /// Unregister a specific listener.
    /// - Parameter listener: The listener to unregister
    @objc public func unregisterListener(_ listener: AnyObject) {
        guard let listener = listener as? MixpanelEventListener else {
            MixpanelLogger.warn(message: "Attempted to unregister non-conforming listener")
            return
        }
        queue.async { [weak self] in
            guard let self = self else { return }

            let id = ObjectIdentifier(listener)
            self.listeners.removeAll { $0.id == id }

            MixpanelLogger.info(message: "Event bridge listener unregistered")
        }
    }

    /// Remove all registered listeners.
    @objc public func removeAllListeners() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let count = self.listeners.count
            self.listeners.removeAll()
            MixpanelLogger.debug(message: "Removed \(count) event bridge listener(s)")
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

            // Notify each listener
            for wrapper in self.listeners {
                guard let listener = wrapper.listener else { continue }
                listener.mixpanelDidTrackEvent(trackedEvent)
            }
        }
    }

    // MARK: - Private Methods

    /// Remove nil weak references from the listener array
    private func cleanupDeallocatedListeners() {
        listeners.removeAll { $0.listener == nil }
    }
}
