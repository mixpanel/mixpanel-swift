//
//  Constants.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct QueueConstants {
    static var queueSize = 5000
}

struct APIConstants {
    static let batchSize = 50
    static let minRetryBackoff = 60.0
    static let maxRetryBackoff = 600.0
    static let failuresTillBackoff = 2
}

struct BundleConstants {
    static let ID = "com.mixpanel.Mixpanel"
}

struct InAppNotificationsConstants {
    static let miniInAppHeight: CGFloat = 65
    static let miniBottomPadding: CGFloat = 10
    static let miniSidePadding: CGFloat = 15
    static let miniLightBGColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    static let miniLightTextColor = #colorLiteral(red: 0.4823529412, green: 0.5725490196, blue: 0.6392156863, alpha: 1)
    static let miniLightBorderColor = #colorLiteral(red: 0.8549019608, green: 0.8745098039, blue: 0.9098039216, alpha: 1)
}
