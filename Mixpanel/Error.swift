//
//  Error.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/10/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

enum PropertyError: ErrorType {
    case InvalidType(type: AnyObject)
}

class Assertions {
    static var assertClosure      = swiftAssertClosure
    static let swiftAssertClosure = { Swift.assert($0, $1, file: $2, line: $3) }
}

func MPAssert(condition: Bool,
              message: String = "",
              file: StaticString = #file,
              line: UInt = #line) {
    Assertions.assertClosure(condition, message, file, line)
}

class ErrorHandler {
    class func wrap<ReturnType>(f: () throws -> ReturnType?) -> ReturnType? {
        do {
            return try f()
        } catch let error {
            logError(error)
            return nil
        }
    }

    class func logError(error: ErrorType) {
        let stackSymbols = NSThread.callStackSymbols
        Logger.error(message: "Error: \(error) \n Stack Symbols: \(stackSymbols)")
    }

}
