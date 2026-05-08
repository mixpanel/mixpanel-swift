//
//  AutomaticProperties.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
  import UIKit
#elseif os(macOS)
  import Cocoa
#elseif canImport(WatchKit)
  import WatchKit
#endif

class AutomaticProperties {
  static let automaticPropertiesLock = ReadWriteLock(label: "automaticPropertiesLock")

  // Track whether screen size has been captured to ensure idempotency
  private static var screenSizeCaptured = false

  static var properties: InternalProperties = {
    var p = InternalProperties()

    #if os(iOS) || os(tvOS)
      // Skip screen size in lazy initializer to avoid
      // SwiftUI accent color interference (synchronous UIScreen access during App.init)
      // Screen size will be captured asynchronously below.
      // See: https://github.com/mixpanel/mixpanel-swift/issues/522

      #if targetEnvironment(macCatalyst)
        p["$os"] = "macOS"
        p["$os_version"] = ProcessInfo.processInfo.operatingSystemVersionString
      #else
        if AutomaticProperties.isiOSAppOnMac() {
          // iOS App Running on Apple Silicon Mac
          p["$os"] = "macOS"
          // unfortunately, there is no API that reports the correct macOS version
          // for "Designed for iPad" apps running on macOS, so we omit it here rather than mis-report
        } else {
          p["$os"] = UIDevice.current.systemName
          p["$os_version"] = UIDevice.current.systemVersion
        }
      #endif
    #elseif os(macOS)
      // Skip screen size in lazy initializer (same reasons as iOS/tvOS)
      p["$os"] = "macOS"
      p["$os_version"] = ProcessInfo.processInfo.operatingSystemVersionString
    #elseif os(watchOS)
      // WatchKit APIs are thread-safe, capture screen size immediately
      let watchDevice = WKInterfaceDevice.current()
      p["$os"] = watchDevice.systemName
      p["$os_version"] = watchDevice.systemVersion
      p["$watch_model"] = AutomaticProperties.watchModel()
      let screenSize = watchDevice.screenBounds.size
      p["$screen_width"] = Int(screenSize.width)
      p["$screen_height"] = Int(screenSize.height)
    #elseif os(visionOS)
      p["$os"] = "visionOS"
      p["$os_version"] = UIDevice.current.systemVersion
    #endif

    let infoDict = Bundle.main.infoDictionary ?? [:]
    p["$app_build_number"] = infoDict["CFBundleVersion"] as? String ?? "Unknown"
    p["$app_version_string"] = infoDict["CFBundleShortVersionString"] as? String ?? "Unknown"

    p["mp_lib"] = "swift"
    p["$lib_version"] = AutomaticProperties.libVersion()
    p["$manufacturer"] = "Apple"
    p["$model"] = AutomaticProperties.deviceModel()

    // Schedule async screen size capture for platforms that require main thread access
    // Using async (not sync) prevents deadlock and allows SwiftUI initialization to complete
    #if os(iOS) || os(tvOS) || os(macOS)
      DispatchQueue.main.async {
        captureScreenSize()
      }
    #endif
      
    return p
  }()

  static var peopleProperties: InternalProperties = {
    var p = InternalProperties()
    let infoDict = Bundle.main.infoDictionary
    if let infoDict = infoDict {
      p["$ios_app_version"] = infoDict["CFBundleVersion"]
      p["$ios_app_release"] = infoDict["CFBundleShortVersionString"]
    }
    p["$ios_device_model"] = AutomaticProperties.deviceModel()
    #if !os(OSX) && !os(watchOS) && !os(visionOS)
      p["$ios_version"] = UIDevice.current.systemVersion
    #else
      p["$ios_version"] = ProcessInfo.processInfo.operatingSystemVersionString
    #endif
    p["$ios_lib_version"] = AutomaticProperties.libVersion()
    p["$swift_lib_version"] = AutomaticProperties.libVersion()

    return p
  }()

  /// Captures screen size on main thread and updates properties dictionary.
  /// This method is called asynchronously after properties initialization to avoid
  /// interfering with SwiftUI initialization and to prevent deadlock scenarios.
  private static func captureScreenSize() {
    // Defensive guard: ensure we're on main thread
    // This should always be true since we only call via main.async,
    // but guard defensively and reschedule if needed
    guard Thread.isMainThread else {
      DispatchQueue.main.async { captureScreenSize() }
      return
    }

    // IMPORTANT: Capture screen size on main thread BEFORE entering write lock.
    // The write lock executes closures on its internal queue (background thread),
    // so we must access UIScreen/NSScreen here while still on main thread.
    #if os(iOS) || os(tvOS)
      let screenSize = UIScreen.main.bounds.size
      let height = Int(screenSize.height)
      let width = Int(screenSize.width)
    #elseif os(macOS)
      let screenSize = NSScreen.main?.frame.size
      let height = screenSize.map { Int($0.height) }
      let width = screenSize.map { Int($0.width) }
    #endif

    // Now update properties dictionary under lock (with already-captured values)
    automaticPropertiesLock.write {
      // Ensure we only capture screen size once (idempotency)
      guard !screenSizeCaptured else { return }

      #if os(iOS) || os(tvOS)
        properties["$screen_height"] = height
        properties["$screen_width"] = width
      #elseif os(macOS)
        if let height = height, let width = width {
          properties["$screen_height"] = height
          properties["$screen_width"] = width
        }
      #endif

      screenSizeCaptured = true
    }
  }

  class func deviceModel() -> String {
    var modelCode: String = "Unknown"
    if AutomaticProperties.isiOSAppOnMac() {
      // iOS App Running on Apple Silicon Mac
      var size = 0
      sysctlbyname("hw.model", nil, &size, nil, 0)
      var model = [CChar](repeating: 0, count: size)
      sysctlbyname("hw.model", &model, &size, nil, 0)
      modelCode = String(cString: model)
    } else {
      var systemInfo = utsname()
      uname(&systemInfo)
      let size = MemoryLayout<CChar>.size
      modelCode = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: size) {
          String(cString: UnsafePointer<CChar>($0))
        }
      }
    }
    return modelCode
  }

  #if os(watchOS)
    class func watchModel() -> String {
      let watchSize38mm = Int(136)
      let watchSize40mm = Int(162)
      let watchSize42mm = Int(156)
      let watchSize44mm = Int(184)

      let screenWidth = Int(WKInterfaceDevice.current().screenBounds.size.width)
      switch screenWidth {
      case watchSize38mm:
        return "Apple Watch 38mm"
      case watchSize40mm:
        return "Apple Watch 40mm"
      case watchSize42mm:
        return "Apple Watch 42mm"
      case watchSize44mm:
        return "Apple Watch 44mm"
      default:
        return "Apple Watch"
      }
    }
  #endif

  class func isiOSAppOnMac() -> Bool {
    var isiOSAppOnMac = false
    if #available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, *) {
      isiOSAppOnMac = ProcessInfo.processInfo.isiOSAppOnMac
    }
    return isiOSAppOnMac
  }

  class func libVersion() -> String {
    return "6.3.0"
  }

}
