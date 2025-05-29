//
//  PrintLogging.swift
//  MPLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// Simply formats and prints the object by calling `print`
class PrintLogging: MixpanelLogging {
  func addMessage(message: MixpanelLogMessage) {
    print(
      "[Mixpanel - \(message.file) - func \(message.function)] (\(message.level.rawValue)) - \(message.text)"
    )
  }
}

/// Simply formats and prints the object by calling `debugPrint`, this makes things a bit easier if you
/// need to print data that may be quoted for instance.
class PrintDebugLogging: MixpanelLogging {
  func addMessage(message: MixpanelLogMessage) {
    debugPrint(
      "[Mixpanel - \(message.file) - func \(message.function)] (\(message.level.rawValue)) - \(message.text)"
    )
  }
}
