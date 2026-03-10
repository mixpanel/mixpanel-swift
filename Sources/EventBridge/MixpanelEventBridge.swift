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
        weak var listener: AnyObject?
        let id: ObjectIdentifier

        init(_ listener: AnyObject) {
            self.listener = listener
            self.id = ObjectIdentifier(listener)
        }
    }

    /// Registered listeners (stored as weak references)
    private var listeners: [WeakListener] = []

    // MARK: - Public API

    /// Register a listener to receive event notifications.
    /// Uses duck-typing via Objective-C runtime to check for required method.
    /// - Parameter listener: The listener to register (must respond to mixpanelDidTrackEvent:)
    @objc public func registerListener(_ listener: AnyObject) {
        // Use duck-typing: check if object responds to required selector
        let selector = NSSelectorFromString("mixpanelDidTrackEvent:")
        guard listener.responds(to: selector) else {
            MixpanelLogger.warn(message: "Listener does not implement mixpanelDidTrackEvent:")
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
    ///   - eventName: Event name
    ///   - properties: Event properties
    internal func notifyListeners(
        eventName: String,
        properties: [String: Any]
    ) {
        // Create event data dictionary
        let eventData: [String: Any] = [
            "eventName": eventName,
            "properties": properties
        ]
        queue.async { [weak self] in
            guard let self = self else { return }

            // Early exit if no listeners
            guard !self.listeners.isEmpty else { return }

            self.cleanupDeallocatedListeners()

            // Notify each listener using selector (duck-typing)
            let selector = NSSelectorFromString("mixpanelDidTrackEvent:")
            for wrapper in self.listeners {
                guard let listener = wrapper.listener else { continue }
                if listener.responds(to: selector) {
                    _ = listener.perform(selector, with: eventData)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Remove nil weak references from the listener array
    private func cleanupDeallocatedListeners() {
        listeners.removeAll { $0.listener == nil }
    }
}
