//
//  MixpanelEventBridge.swift
//  Mixpanel
//
//  Created by Ketan on 25/03/26.
//  Copyright © 2026 Mixpanel. All rights reserved.
//


import Foundation

public struct MixpanelEvent {
    public let eventName: String
    public let properties: [String: Any]
}

/// Event bridge for multicasting Mixpanel events to external consumers via AsyncStream.
/// Thread-safe, supports multiple concurrent stream consumers with automatic cleanup.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public final class MixpanelEventBridge: NSObject {

    // MARK: - Singleton
    /// Shared instance
    @objc public static let shared = MixpanelEventBridge()

    // MARK: - Private Properties

    /// Thread-safe storage for active stream continuations
    private var continuations: [UUID: AsyncStream<MixpanelEvent>.Continuation] = [:]
    private let continuationsLock = NSLock()

    /// Serial queue for event dispatch
    private let queue = DispatchQueue(
        label: "com.mixpanel.bridge",
        qos: .utility
    )

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Creates a new event stream for consuming tracked events.
    /// Each call returns a new stream that receives all subsequent events.
    /// - Returns: AsyncStream that yields event data dictionaries containing "eventName" and "properties"
    public func eventStream() -> AsyncStream<MixpanelEvent> {
        let id = UUID()

        return AsyncStream { continuation in
            // Register continuation
            self.continuationsLock.lock()
            self.continuations[id] = continuation
            self.continuationsLock.unlock()

            // Setup automatic cleanup on termination
            continuation.onTermination = { [weak self] _ in
                self?.continuationsLock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.continuationsLock.unlock()
            }
        }
    }

    // MARK: - Public API

    /// Notify all active stream consumers of a tracked event.
    /// - Parameters:
    ///   - eventName: Event name
    ///   - properties: Event properties
    public func notifyListeners(
        eventName: String,
        properties: [String: Any]
    ) {
        let event = MixpanelEvent(eventName: eventName, properties: properties)

        queue.async { [weak self] in
            guard let self = self else { return }

            // Get snapshot of active continuations
            self.continuationsLock.lock()
            let activeConsumers = Array(self.continuations.values)
            self.continuationsLock.unlock()

            // Yield to all consumers
            for continuation in activeConsumers {
                continuation.yield(event)
            }
        }
    }
}
