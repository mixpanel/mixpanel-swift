//
//  MixpanelEventBridgeListener.swift
//  Mixpanel
//
//  Created by Mixpanel on 2026-03-03.
//

import Foundation

/// Protocol that event listeners must implement to receive tracked events.
/// Uses dictionary-based messaging for runtime-only coupling with external SDKs.
@objc public protocol MixpanelEventBridgeListener: AnyObject {
    /// Called when an event is tracked in Mixpanel.
    /// - Parameter eventData: Dictionary containing event information with keys:
    ///   - `"eventName"`: String - The event name
    ///   - `"properties"`: [String: Any] - Event properties
    @objc func mixpanelDidTrackEvent(_ eventData: [String: Any])
}
