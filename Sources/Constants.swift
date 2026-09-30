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
#endif  // !os(OSX)

struct QueueConstants {
    static var queueSize = 5000
}

struct APIConstants {
    /// Rows read from the database per batch, and events sent per network request — the two are
    /// the same by design. A flush drains the queue by repeating read → send → delete in batches
    /// of this size until the queue is empty or a request fails, so this bounds per-iteration
    /// memory, not how much a flush can move in total. Matches the Android SDK's flushBatchSize.
    static let maxBatchSize = 50
    /// Largest single queued row the SDK will attempt to deserialize, in bytes.
    ///
    /// Rows above this are dropped when read instead of being parsed. Parsing one can exhaust
    /// memory, and Foundation reports that as an `NSMallocException` — an Objective-C exception
    /// that no Swift `do`/`catch` can intercept, so the process dies. Such a row also exceeds
    /// what the ingestion API accepts, so it could never drain: every later flush would reach it
    /// and crash again.
    static let maxRowByteSize = 1_000_000
    /// Upper bound on the cumulative bytes a single `MPDB.readRows` call will deserialize.
    ///
    /// `maxBatchSize` bounds a read in rows, but rows that are individually legal (each under
    /// `maxRowByteSize`) can still sum to hundreds of megabytes, and JSON parsing inflates raw
    /// bytes several-fold once materialized as Foundation objects. This budget bounds the read in
    /// bytes as well; rows past it stay in SQLite for the following flush. At least one row is
    /// always read, so a flush can never stall.
    static let maxReadBatchByteSize = 5_000_000
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

#if !os(OSX) && !os(watchOS) && !os(visionOS)
extension UIDevice {
    var iPhoneX: Bool {
        return UIScreen.main.nativeBounds.height == 2436
    }
}
#endif  // !os(OSX)
