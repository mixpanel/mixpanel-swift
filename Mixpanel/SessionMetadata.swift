//
//  Metadata.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 10/24/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation

class SessionMetadata {
    var eventsCounter: UInt64 = 0
    var peopleCounter: UInt64 = 0
    var sessionID: UInt64 = 0
    var sessionStartEpoch: UInt64 = 0

    func applicationDidBecomeActive() {
        eventsCounter = 0
        peopleCounter = 0
        sessionID = UInt64.random
        sessionStartEpoch = UInt64(Date().timeIntervalSince1970)
    }

    func toDict(isEvent: Bool = true) -> InternalProperties {
        let dict = ["$mp_event_id": UInt64.random,
                    "$mp_session_id": sessionID,
                    "$mp_session_seq_id": (isEvent ? eventsCounter : peopleCounter),
                    "$mp_session_start_sec": sessionStartEpoch]
        isEvent ? (eventsCounter += 1) : (peopleCounter += 1)
        print(dict)
        return dict
    }
}

extension UInt64 {
    static var random: UInt64 {
        let hex = UUID().uuidString
            .components(separatedBy: "-")
            .suffix(2)
            .joined()
        return UInt64(hex, radix: 0x10)!
    }
}
