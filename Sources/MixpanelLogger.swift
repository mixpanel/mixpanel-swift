//
//  MixpanelLogger.swift
//  MixpanelLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// This defines the various levels of logging that a message may be tagged with. This allows hiding and
/// showing different logging levels at run time depending on the environment
public enum MixpanelLogLevel: String {
  /// MixpanelLogging displays *all* logs and additional debug information that may be useful to a developer
  case debug

  /// MixpanelLogging displays *all* logs (**except** debug)
  case info

  /// MixpanelLogging displays *only* warnings and above
  case warning

  /// MixpanelLogging displays *only* errors and above
  case error
}

/// This holds all the data for each log message, since the formatting is up to each
/// logging object. It is a simple bag of data
public struct MixpanelLogMessage {
  /// The file where this log message was created
  public let file: String

  /// The function where this log message was created
  public let function: String

  /// The text of the log message
  public let text: String

  /// The level of the log message
  public let level: MixpanelLogLevel

  init(path: String, function: String, text: String, level: MixpanelLogLevel) {
    if let file = path.components(separatedBy: "/").last {
      self.file = file
    } else {
      self.file = path
    }
    self.function = function
    self.text = text
    self.level = level
  }
}

/// Any object that conforms to this protocol may log messages
public protocol MixpanelLogging {
  func addMessage(message: MixpanelLogMessage)
}

public class MixpanelLogger {
  private static var loggers = [MixpanelLogging]()
  private static var enabledLevels = Set<MixpanelLogLevel>()
  private static let readWriteLock: ReadWriteLock = ReadWriteLock(label: "loggerLock")

  /// Add a `MixpanelLogging` object to receive all log messages
  public class func addLogging(_ logging: MixpanelLogging) {
    readWriteLock.write {
      loggers.append(logging)
    }
  }

  /// Enable log messages of a specific `LogLevel` to be added to the log
  class func enableLevel(_ level: MixpanelLogLevel) {
    readWriteLock.write {
      enabledLevels.insert(level)
    }
  }

  /// Disable log messages of a specific `LogLevel` to prevent them from being logged
  class func disableLevel(_ level: MixpanelLogLevel) {
    readWriteLock.write {
      enabledLevels.remove(level)
    }
  }

  /// debug: Adds a debug message to the Mixpanel log
  /// - Parameter message: The message to be added to the log
  class func debug(
    message: @autoclosure () -> Any, _ path: String = #file, _ function: String = #function
  ) {
    var enabledLevels = Set<MixpanelLogLevel>()
    readWriteLock.read {
      enabledLevels = self.enabledLevels
    }
    guard enabledLevels.contains(.debug) else { return }
    forwardLogMessage(
      MixpanelLogMessage(
        path: path, function: function, text: "\(message())",
        level: .debug))
  }

  /// info: Adds an informational message to the Mixpanel log
  /// - Parameter message: The message to be added to the log
  class func info(
    message: @autoclosure () -> Any, _ path: String = #file, _ function: String = #function
  ) {
    var enabledLevels = Set<MixpanelLogLevel>()
    readWriteLock.read {
      enabledLevels = self.enabledLevels
    }
    guard enabledLevels.contains(.info) else { return }
    forwardLogMessage(
      MixpanelLogMessage(
        path: path, function: function, text: "\(message())",
        level: .info))
  }

  /// warn: Adds a warning message to the Mixpanel log
  /// - Parameter message: The message to be added to the log
  class func warn(
    message: @autoclosure () -> Any, _ path: String = #file, _ function: String = #function
  ) {
    var enabledLevels = Set<MixpanelLogLevel>()
    readWriteLock.read {
      enabledLevels = self.enabledLevels
    }
    guard enabledLevels.contains(.warning) else { return }
    forwardLogMessage(
      MixpanelLogMessage(
        path: path, function: function, text: "\(message())",
        level: .warning))
  }

  /// error: Adds an error message to the Mixpanel log
  /// - Parameter message: The message to be added to the log
  class func error(
    message: @autoclosure () -> Any, _ path: String = #file, _ function: String = #function
  ) {
    var enabledLevels = Set<MixpanelLogLevel>()
    readWriteLock.read {
      enabledLevels = self.enabledLevels
    }
    guard enabledLevels.contains(.error) else { return }
    forwardLogMessage(
      MixpanelLogMessage(
        path: path, function: function, text: "\(message())",
        level: .error))
  }

  /// This forwards a `MixpanelLogMessage` to each logger that has been added
  class private func forwardLogMessage(_ message: MixpanelLogMessage) {
    // Forward the log message to every registered MixpanelLogging instance
    var loggers = [MixpanelLogging]()
    readWriteLock.read {
      loggers = self.loggers
    }
    readWriteLock.write {
      loggers.forEach { $0.addMessage(message: message) }
    }
  }
}
