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
    static let maxBatchSize = 50
    static let flushSize = 1000
    static let minRetryBackoff = 60.0
    static let maxRetryBackoff = 600.0
    static let failuresTillBackoff = 2
}

struct BundleConstants {
    static let ID = "com.mixpanel.Mixpanel"
}

struct GzipSettings {
    static let gzipHeaderOffset = Int32(16)
}
