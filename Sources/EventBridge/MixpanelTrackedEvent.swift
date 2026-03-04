//
//  MixpanelTrackedEvent.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-03-03.
//

import Foundation

/// Event data container that can evolve without breaking protocol changes.
/// New fields can be added in future versions without affecting existing listeners.
public struct MixpanelTrackedEvent {
    /// Event name (e.g., "purchase_completed")
    public let name: String

    /// Event properties (immutable, may be filtered per listener)
    public let properties: [String: Any]

    /// When the event was tracked
    public let timestamp: Date

    /// Instance name if using multiple Mixpanel instances (nil = main instance)
    public let instanceName: String?

    public init(
        name: String,
        properties: [String: Any],
        timestamp: Date,
        instanceName: String? = nil
    ) {
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
        self.instanceName = instanceName
    }
}
