//
//  Error.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/10/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

enum PropertyError: Error {
    case invalidType(type: Any)
}

class Assertions {
    static var assertClosure      = swiftAssertClosure
    static let swiftAssertClosure = { Swift.assert($0, $1, file: $2, line: $3) }
}

func MPAssert(_ condition: @autoclosure() -> Bool,
              _ message: @autoclosure() -> String = "",
              file: StaticString = #file,
              line: UInt = #line) {
    Assertions.assertClosure(condition(), message(), file, line)
}

class ErrorHandler {
    class func wrap<ReturnType>(_ f: () throws -> ReturnType?) -> ReturnType? {
        do {
            return try f()
        } catch let error {
            logError(error)
            return nil
        }
    }

    class func logError(_ error: Error) {
        let stackSymbols = Thread.callStackSymbols
        Logger.error(message: "Error: \(error) \n Stack Symbols: \(stackSymbols)")
    }

}
