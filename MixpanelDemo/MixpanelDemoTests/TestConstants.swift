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
let kDefaultServerString = "^https://api.mixpanel.com"
let kDefaultServerTrackString = "^https://api.mixpanel.com/track/".regex
let kDefaultServerEngageString = "^https://api.mixpanel.com/engage/?ip=1".regex
let kDefaultServerGroupsString = "^https://api.mixpanel.com/groups/".regex
let kDefaultServerDecideString = "^https://api.mixpanel.com/decide(.*?)".regex

@discardableResult func stubEngage() -> LSStubRequestDSL {
    return stubRequest("POST", kDefaultServerEngageString()).withHeader("Content-Type", "application/json")!
}

@discardableResult func stubGroups() -> LSStubRequestDSL {
    return stubRequest("POST", kDefaultServerGroupsString()).withHeader("Content-Type", "application/json")!
}

@discardableResult func stubTrack() -> LSStubRequestDSL {
    return stubRequest("POST", kDefaultServerTrackString()).withHeader("Content-Type", "application/json")!
}

@discardableResult func stubDecide() -> LSStubRequestDSL {
    return stubRequest("GET", kDefaultServerDecideString()).withHeader("Content-Type", "application/json")!
}

extension XCTestCase {

    func XCTExpectAssert(_ expectedMessage: String, file: StaticString = #file, line: UInt = #line, block: () -> ()) {
        let exp = expectation(description: expectedMessage)

        Assertions.assertClosure = {
            (condition, message, file, line) in
            if !condition {
                exp.fulfill()
            }
        }

        // Call code.
        block()
        waitForExpectations(timeout: 60, handler: nil)
        Assertions.assertClosure = Assertions.swiftAssertClosure
    }

}
