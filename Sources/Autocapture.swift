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

    /**
       Track a screen view event. This is a convenience method for tracking when users view
       a screen/page in your application.
    
       - parameter screenName: The name of the screen/page being viewed
       - parameter properties: Optional properties to include with this event
       */
    open func trackScreenView(screenName: String, properties: Properties? = nil) {
        guard let mixpanelInstance = mixpanelInstance else { return }
        guard !screenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MixpanelLogger.warn(
                message: "trackScreenView called with empty screenName, ignoring event")
            return
        }

        var mergedProperties: Properties = [:]

        if let properties = properties {
            for (key, value) in properties {
                mergedProperties[key] = value
            }
        }

        // SDK properties set after caller properties to prevent overrides
        mergedProperties["current_page_title"] = screenName
        mergedProperties["$mp_autocapture"] = true

        mixpanelInstance.track(event: "$mp_page_view", properties: mergedProperties)
    }

    /**
       Track a screen leave event. This is a convenience method for tracking when users leave
       a screen/page in your application.
    
       - parameter screenName: The name of the screen/page being left
       - parameter properties: Optional properties to include with this event
       */
    open func trackScreenLeave(screenName: String, properties: Properties? = nil) {
        guard let mixpanelInstance = mixpanelInstance else { return }
        guard !screenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MixpanelLogger.warn(
                message: "trackScreenLeave called with empty screenName, ignoring event")
            return
        }

        var mergedProperties: Properties = [:]

        if let properties = properties {
            for (key, value) in properties {
                mergedProperties[key] = value
            }
        }

        // SDK properties set after caller properties to prevent overrides
        mergedProperties["current_page_title"] = screenName
        mergedProperties["$mp_autocapture"] = true

        mixpanelInstance.track(event: "$mp_page_leave", properties: mergedProperties)
    }
}
