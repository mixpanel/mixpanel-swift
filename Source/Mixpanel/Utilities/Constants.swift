//
//  Constants.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
#if !os(OSX)
import UIKit
#endif // !os(OSX)

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

#if !os(OSX) && !WATCH_OS
struct InAppNotificationsConstants {
    static let miniInAppHeight: CGFloat = 65
    static let miniBottomPadding: CGFloat = 10 + (UIDevice.current.iPhoneX ? 34 : 0)
    static let miniSidePadding: CGFloat = 15
}

extension UIDevice {
    var iPhoneX: Bool {
        return UIScreen.main.nativeBounds.height == 2436
    }
}
#endif // !os(OSX)

struct ConnectIntegrationsConstants {
    static let uaMaxRetries = 3
}
