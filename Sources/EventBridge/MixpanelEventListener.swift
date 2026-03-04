//
//  MixpanelEventListener.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-03-03.
//

import Foundation

/// Protocol that event listeners must implement to receive tracked events.
/// Defined in mixpanel-swift but can be implemented by any SDK.
public protocol MixpanelEventListener: AnyObject {
    /// Called when an event is tracked in Mixpanel.
    /// - Parameter event: Event data with all context (name, properties, timestamp, etc.)
    func mixpanelDidTrackEvent(_ event: MixpanelTrackedEvent)
}
