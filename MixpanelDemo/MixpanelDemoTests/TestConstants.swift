//
//  TestConstants.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Nocilla
import XCTest

@testable import Mixpanel

let kTestToken = "abc123"
let kDefaultServerString = "https://api.mixpanel.com"
let kDefaultServerTrackString = "https://api.mixpanel.com/track/"
let kDefaultServerEngageString = "https://api.mixpanel.com/engage/"

func stubEngage() -> LSStubRequestDSL {
    return stubRequest("POST", kDefaultServerEngageString).withHeader("Accept-Encoding", "gzip")!
}

func stubTrack() -> LSStubRequestDSL {
    return stubRequest("POST", kDefaultServerTrackString).withHeader("Accept-Encoding", "gzip")!
}


extension XCTestCase {

    func XCTExpectAssert(expectedMessage: String, file: StaticString = #file, line: UInt = #line, block: () -> ()) {
        let exp = expectationWithDescription(expectedMessage)

        Assertions.assertClosure = {
            (condition, message, file, line) in
            if !condition {
                exp.fulfill()
            }
        }

        // Call code.
        block()
        waitForExpectationsWithTimeout(0.5, handler: nil)
        Assertions.assertClosure = Assertions.swiftAssertClosure
    }

}
