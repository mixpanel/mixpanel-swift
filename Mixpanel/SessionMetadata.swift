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
    var sessionID: String = String.randomId()
    var sessionStartEpoch: UInt64 = 0
    var trackingQueue: DispatchQueue

    init(trackingQueue: DispatchQueue) {
        self.trackingQueue = trackingQueue
    }
    
    func applicationWillEnterForeground() {
        trackingQueue.async { [weak self] in

            guard let hasSelf = self else {
                return /// Self DNE
            }

            hasSelf.eventsCounter = 0
            hasSelf.peopleCounter = 0
            hasSelf.sessionID = String.randomId()
            hasSelf.sessionStartEpoch = UInt64(Date().timeIntervalSince1970)
        }
    }

    func toDict(isEvent: Bool = true) -> InternalProperties {
        let dict : [String: Any] = ["$mp_metadata":["$mp_event_id":  String.randomId(),
                    "$mp_session_id": sessionID,
                    "$mp_session_seq_id": (isEvent ? eventsCounter : peopleCounter),
                    "$mp_session_start_sec": sessionStartEpoch]]
        isEvent ? (eventsCounter += 1) : (peopleCounter += 1)
        return dict
    }
}

private extension String {
    static func randomId() -> String {
        return String(format: "%08x%08x", arc4random(), arc4random())
    }
}
