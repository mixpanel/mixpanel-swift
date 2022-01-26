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

let kFakeServerUrl = "https://34a272abf23d.com"

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
        waitForExpectations(timeout: 0.5, handler: nil)
        Assertions.assertClosure = Assertions.swiftAssertClosure
    }

}
