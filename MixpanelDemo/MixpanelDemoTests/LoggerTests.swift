//
//  LoggerTests.swift
//  MixpanelDemo
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import XCTest
@testable import Mixpanel

class LoggerTests: XCTestCase {


    func testEnableDebug() {
        let counter = CounterLogging()
        MPLogger.addLogging(counter)
        MPLogger.enableLevel(.debug)

        MPLogger.debug(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testEnableInfo() {
        let counter = CounterLogging()
        MPLogger.addLogging(counter)
        MPLogger.enableLevel(.info)
        MPLogger.info(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testEnableWarning() {
        let counter = CounterLogging()
        MPLogger.addLogging(counter)
        MPLogger.enableLevel(.warning)
        MPLogger.warn(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testEnableError() {
        let counter = CounterLogging()
        MPLogger.addLogging(counter)
        MPLogger.enableLevel(.error)
        MPLogger.error(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testDisabledLogging() {
        let counter = CounterLogging()
        MPLogger.addLogging(counter)
        MPLogger.disableLevel(.debug)
        MPLogger.debug(message: "not logged")
        XCTAssertEqual(0, counter.count)

        MPLogger.disableLevel(.error)
        MPLogger.error(message: "not logged")
        XCTAssertEqual(0, counter.count)

        MPLogger.disableLevel(.info)
        MPLogger.info(message: "not logged")
        XCTAssertEqual(0, counter.count)

        MPLogger.disableLevel(.warning)
        MPLogger.warn(message: "not logged")
        XCTAssertEqual(0, counter.count)
    }
}

/// This is a stub that implements `Logging` to be passed to our `Logger` instance for testing
class CounterLogging: MPLogging {
    var count = 0

    func addMessage(message: MPLogMessage) {
        count = count + 1
    }
}
