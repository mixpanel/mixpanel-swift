//
//  AutomaticProperties.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

#if os(iOS) || TV_OS
import UIKit
#elseif MAC_OS
import Cocoa
#else
import WatchKit
#endif


class AutomaticProperties {
    static let automaticPropertiesLock = ReadWriteLock(label: "automaticPropertiesLock")

    static var properties: InternalProperties = {
        objc_sync_enter(AutomaticProperties.self); defer { objc_sync_exit(AutomaticProperties.self) }
        var p = InternalProperties()
        #if os(iOS) || TV_OS
        let screenSize = UIScreen.main.bounds.size
        p["$screen_height"]     = Int(screenSize.height)
        p["$screen_width"]      = Int(screenSize.width)
        p["$os"]                = UIDevice.current.systemName
        p["$os_version"]        = UIDevice.current.systemVersion

        #elseif MAC_OS
        if let screenSize = NSScreen.main?.frame.size {
            p["$screen_height"]     = Int(screenSize.height)
            p["$screen_width"]      = Int(screenSize.width)
        }
        p["$os"]                = "macOS"
        p["$os_version"]        = ProcessInfo.processInfo.operatingSystemVersionString

        #elseif WATCH_OS
        let watchDevice = WKInterfaceDevice.current()
        p["$os"]                = watchDevice.systemName
        p["$os_version"]        = watchDevice.systemVersion
        p["$watch_model"]       = AutomaticProperties.watchModel()
        let screenSize = watchDevice.screenBounds.size
        p["$screen_width"]      = Int(screenSize.width)
        p["$screen_height"]     = Int(screenSize.height)
        
        #endif

        let infoDict = Bundle.main.infoDictionary
        if let infoDict = infoDict {
            p["$app_build_number"]     = infoDict["CFBundleVersion"]
            p["$app_version_string"]   = infoDict["CFBundleShortVersionString"]
        }
        p["mp_lib"]             = "swift"
        p["$lib_version"]       = AutomaticProperties.libVersion()
        p["$manufacturer"]      = "Apple"
        p["$model"]             = AutomaticProperties.deviceModel()
        return p
    }()

    static var peopleProperties: InternalProperties = {
        objc_sync_enter(AutomaticProperties.self); defer { objc_sync_exit(AutomaticProperties.self) }
        var p = InternalProperties()
        let infoDict = Bundle.main.infoDictionary
        if let infoDict = infoDict {
            p["$ios_app_version"] = infoDict["CFBundleVersion"]
            p["$ios_app_release"] = infoDict["CFBundleShortVersionString"]
        }
        p["$ios_device_model"]  = AutomaticProperties.deviceModel()
        #if !os(OSX) && !WATCH_OS
        p["$ios_version"]       = UIDevice.current.systemVersion
        #else
        p["$ios_version"]       = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        p["$ios_lib_version"]   = AutomaticProperties.libVersion()
        p["$swift_lib_version"] = AutomaticProperties.libVersion()

        return p
    }()

    class func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = MemoryLayout<CChar>.size
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: size) {
                String(cString: UnsafePointer<CChar>($0))
            }
        }
        if let model = String(validatingUTF8: modelCode) {
            return model
        }
        return ""
    }

    #if WATCH_OS
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

    class func libVersion() -> String? {
        return Bundle(for: self).infoDictionary?["CFBundleShortVersionString"] as? String
    }

}
