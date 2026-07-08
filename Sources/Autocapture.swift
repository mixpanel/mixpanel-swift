//
//  Autocapture.swift
//  Mixpanel
//
//  Provides methods for tracking autocapture events. Events tracked through this class
//  are automatically tagged with the $mp_autocapture property, which causes them
//  to appear with an "[Auto]" prefix in the Mixpanel web app.
//

import Foundation

/// Access to autocapture tracking methods, available as an accessible variable from
/// the main Mixpanel instance.
open class Autocapture {

    weak var mixpanelInstance: MixpanelInstance?

    /// Internal initializer — prevents host apps from creating instances directly.
    /// Use `mixpanel.autocapture` to access the SDK-managed instance.
    init() {}

    /**
       Track a screen view event. This is a convenience method for tracking when users view
       a screen/page in your application.
    
       - parameter screenName: The name of the screen/page being viewed
       - parameter properties: Optional properties to include with this event
       */
    open func trackScreenView(screenName: String, properties: Properties? = nil) {
        guard !screenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MixpanelLogger.warn(
                message: "trackScreenView called with empty screenName, ignoring event")
            return
        }

        var mergedProperties: Properties = properties ?? [:]
        // SDK properties set after caller properties to prevent overrides
        mergedProperties["current_page_title"] = screenName

        trackAutocaptureEvent("$mp_page_view", properties: mergedProperties)
    }

    /**
       Track a screen leave event. This is a convenience method for tracking when users leave
       a screen/page in your application.
    
       - parameter screenName: The name of the screen/page being left
       - parameter properties: Optional properties to include with this event
       */
    open func trackScreenLeave(screenName: String, properties: Properties? = nil) {
        guard !screenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MixpanelLogger.warn(
                message: "trackScreenLeave called with empty screenName, ignoring event")
            return
        }

        var mergedProperties: Properties = properties ?? [:]
        // SDK properties set after caller properties to prevent overrides
        mergedProperties["current_page_title"] = screenName

        trackAutocaptureEvent("$mp_page_leave", properties: mergedProperties)
    }

    // MARK: - Click Tracking

    #if os(iOS)
    /**
       Track a click event from a ClickEvent object. Use this for full control over
       click metadata when your app handles its own click detection.

       - parameter clickEvent: The click event containing element metadata
       - parameter properties: Optional additional properties to include with this event
       */
    open func trackClick(_ clickEvent: ClickEvent, properties: Properties? = nil) {
        trackClickEvent("$mp_click", clickEvent: clickEvent, properties: properties)
    }

    /**
       Track a rage click event from a ClickEvent object. Use this for full control over
       click metadata when your app handles its own rage click detection.

       - parameter clickEvent: The click event containing element metadata
       - parameter properties: Optional additional properties to include with this event
       */
    open func trackRageClick(_ clickEvent: ClickEvent, properties: Properties? = nil) {
        trackClickEvent("$mp_rage_click", clickEvent: clickEvent, properties: properties)
    }

    /**
       Track a dead click event from a ClickEvent object. Use this for full control over
       click metadata when your app handles its own dead click detection.

       - parameter clickEvent: The click event containing element metadata
       - parameter properties: Optional additional properties to include with this event
       */
    open func trackDeadClick(_ clickEvent: ClickEvent, properties: Properties? = nil) {
        trackClickEvent("$mp_dead_click", clickEvent: clickEvent, properties: properties)
    }

    private func trackClickEvent(_ eventName: String, clickEvent: ClickEvent,
                                 properties: Properties? = nil) {
        var mergedProperties = clickEvent.toProperties()

        if let properties = properties {
            for (key, value) in properties {
                mergedProperties[key] = value
            }
        }

        trackAutocaptureEvent(eventName, properties: mergedProperties)
    }
    #endif

    // MARK: - Private Helpers

    /// Adds the $mp_autocapture flag and tracks the event.
    /// All autocapture events (screen view, screen leave, click, rage click, dead click)
    /// are routed through this method.
    private func trackAutocaptureEvent(_ eventName: String, properties: Properties) {
        guard let mixpanelInstance = mixpanelInstance else { return }
        var props = properties
        props["$mp_autocapture"] = true
        mixpanelInstance.track(event: eventName, properties: props)
    }
}
