//
//  MixpanelLoggerTests.swift
//  MixpanelDemo
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import XCTest
@testable import Mixpanel

class MixpanelLoggerTests: XCTestCase {


    func testEnableDebug() {
        let counter = CounterLogging()
        MixpanelLogger.addLogging(counter)
        MixpanelLogger.enableLevel(.debug)

        MixpanelLogger.debug(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testEnableInfo() {
        let counter = CounterLogging()
        MixpanelLogger.addLogging(counter)
        MixpanelLogger.enableLevel(.info)
        MixpanelLogger.info(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testEnableWarning() {
        let counter = CounterLogging()
        MixpanelLogger.addLogging(counter)
        MixpanelLogger.enableLevel(.warning)
        MixpanelLogger.warn(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testEnableError() {
        let counter = CounterLogging()
        MixpanelLogger.addLogging(counter)
        MixpanelLogger.enableLevel(.error)
        MixpanelLogger.error(message: "logged")
        XCTAssertEqual(1, counter.count)
    }

    func testDisabledLogging() {
        let counter = CounterLogging()
        MixpanelLogger.addLogging(counter)
        MixpanelLogger.disableLevel(.debug)
        MixpanelLogger.debug(message: "not logged")
        XCTAssertEqual(0, counter.count)

        MixpanelLogger.disableLevel(.error)
        MixpanelLogger.error(message: "not logged")
        XCTAssertEqual(0, counter.count)

        MixpanelLogger.disableLevel(.info)
        MixpanelLogger.info(message: "not logged")
        XCTAssertEqual(0, counter.count)

        MixpanelLogger.disableLevel(.warning)
        MixpanelLogger.warn(message: "not logged")
        XCTAssertEqual(0, counter.count)
    }
}

/// This is a stub that implements `MixpanelLogging` to be passed to our `MixpanelLogger` instance for testing
class CounterLogging: MixpanelLogging {
    var count = 0

    func addMessage(message: MixpanelLogMessage) {
        count = count + 1
    }
}
