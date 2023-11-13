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
    static let maxBatchSize = 50
    static let flushSize = 1000
    static let minRetryBackoff = 60.0
    static let maxRetryBackoff = 600.0
    static let failuresTillBackoff = 2
}

struct BundleConstants {
    static let ID = "com.mixpanel.Mixpanel"
}

struct InternalKeys {
    static let mpDebugTrackedKey = "mpDebugTrackedKey"
    static let mpDebugInitCountKey = "mpDebugInitCountKey"
    static let mpDebugImplementedKey = "mpDebugImplementedKey"
    static let mpDebugIdentifiedKey = "mpDebugIdentifiedKey"
    static let mpDebugAliasedKey = "mpDebugAliasedKey"
    static let mpDebugUsedPeopleKey = "mpDebugUsedPeopleKey"
}


#if !os(OSX) && !os(watchOS) && !os(visionOS)
extension UIDevice {
    var iPhoneX: Bool {
        return UIScreen.main.nativeBounds.height == 2436
    }
}
#endif // !os(OSX)
