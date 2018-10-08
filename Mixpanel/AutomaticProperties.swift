//
//  AutomaticProperties.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

#if !os(OSX)
import UIKit
#else
import Cocoa
#endif // os(OSX)

#if os(iOS)
import CoreTelephony
#endif // os(iOS

class AutomaticProperties {
    static let automaticPropertiesLock = ReadWriteLock(label: "automaticPropertiesLock")

    static var properties: InternalProperties = {
        objc_sync_enter(AutomaticProperties.self); defer { objc_sync_exit(AutomaticProperties.self) }
        var p = InternalProperties()
        #if !os(OSX)
        let size = UIScreen.main.bounds.size
        p["$screen_height"]     = Int(size.height)
        p["$screen_width"]      = Int(size.width)
        p["$os"]                = UIDevice.current.systemName
        p["$os_version"]        = UIDevice.current.systemVersion

        #else
        if let size = NSScreen.main?.frame.size {
            p["$screen_height"]     = Int(size.height)
            p["$screen_width"]      = Int(size.width)
        }
        p["$os"]                = "macOS"
        p["$os_version"]        = ProcessInfo.processInfo.operatingSystemVersionString
        #endif // os(OSX)

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
        #if !os(OSX)
        p["$ios_version"]       = UIDevice.current.systemVersion
        #else
        p["$ios_version"]       = ProcessInfo.processInfo.operatingSystemVersionString
        #endif // os(OSX)
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

    class func libVersion() -> String? {
        return Bundle(for: self).infoDictionary?["CFBundleShortVersionString"] as? String
    }

}
