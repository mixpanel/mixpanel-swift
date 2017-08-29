//
//  FileLogging.swift
//  MPLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// Logs all messages to a file
class FileLogging: Logging {
    private let fileHandle: FileHandle

    init(path: String) {
        if let handle = FileHandle(forWritingAtPath: path) {
            fileHandle = handle
        } else {
            fileHandle = FileHandle.standardError
        }

        // Move to the end of the file so we can append messages
        fileHandle.seekToEndOfFile()
    }

    deinit {
        // Ensure we close the file handle to clear the resources
        fileHandle.closeFile()
    }

    func addMessage(message: LogMessage) {
        let string = "File: \(message.file) - Func: \(message.function) - " +
                     "Level: \(message.level.rawValue) - Message: \(message.text)"
        if let data = string.data(using: String.Encoding.utf8) {
            // Write the message as data to the file
            fileHandle.write(data)
        }
    }
}
