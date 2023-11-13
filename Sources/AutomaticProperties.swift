//
//  AutomaticProperties.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import Cocoa
#elseif canImport(WatchKit)
import WatchKit
#endif

class AutomaticProperties {
    static let automaticPropertiesLock = ReadWriteLock(label: "automaticPropertiesLock")

    static var properties: InternalProperties = {
        var p = InternalProperties()

        #if os(iOS) || os(tvOS)
            var screenSize: CGSize? = nil
            screenSize = UIScreen.main.bounds.size
            if let screenSize = screenSize {
                p["$screen_height"]     = Int(screenSize.height)
                p["$screen_width"]      = Int(screenSize.width)
            }
            #if targetEnvironment(macCatalyst)
                p["$os"]                = "macOS"
                p["$os_version"]        = ProcessInfo.processInfo.operatingSystemVersionString
            #else
                if AutomaticProperties.isiOSAppOnMac() {
                    // iOS App Running on Apple Silicon Mac
                    p["$os"]                = "macOS"
                    // unfortunately, there is no API that reports the correct macOS version
                    // for "Designed for iPad" apps running on macOS, so we omit it here rather than mis-report
                } else {
                    p["$os"]                = UIDevice.current.systemName
                    p["$os_version"]        = UIDevice.current.systemVersion
                }
            #endif
        #elseif os(macOS)
            if let screenSize = NSScreen.main?.frame.size {
                p["$screen_height"]     = Int(screenSize.height)
                p["$screen_width"]      = Int(screenSize.width)
            }
            p["$os"]                = "macOS"
            p["$os_version"]        = ProcessInfo.processInfo.operatingSystemVersionString
        #elseif os(watchOS)
            let watchDevice = WKInterfaceDevice.current()
            p["$os"]                = watchDevice.systemName
            p["$os_version"]        = watchDevice.systemVersion
            p["$watch_model"]       = AutomaticProperties.watchModel()
            let screenSize = watchDevice.screenBounds.size
            p["$screen_width"]      = Int(screenSize.width)
            p["$screen_height"]     = Int(screenSize.height)
        #endif

        let infoDict = Bundle.main.infoDictionary ?? [:]
        p["$app_build_number"]     = infoDict["CFBundleVersion"] as? String ?? "Unknown"
        p["$app_version_string"]   = infoDict["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        p["mp_lib"]             = "swift"
        p["$lib_version"]       = AutomaticProperties.libVersion()
        p["$manufacturer"]      = "Apple"
        p["$model"]             = AutomaticProperties.deviceModel()
        return p
    }()

    static var peopleProperties: InternalProperties = {
        var p = InternalProperties()
        let infoDict = Bundle.main.infoDictionary
        if let infoDict = infoDict {
            p["$ios_app_version"] = infoDict["CFBundleVersion"]
            p["$ios_app_release"] = infoDict["CFBundleShortVersionString"]
        }
        p["$ios_device_model"]  = AutomaticProperties.deviceModel()
        #if !os(OSX) && !os(watchOS) && !os(visionOS)
        p["$ios_version"]       = UIDevice.current.systemVersion
        #else
        p["$ios_version"]       = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        p["$ios_lib_version"]   = AutomaticProperties.libVersion()
        p["$swift_lib_version"] = AutomaticProperties.libVersion()

        return p
    }()

    class func deviceModel() -> String {
        var modelCode : String = "Unknown"
        if AutomaticProperties.isiOSAppOnMac() {
            // iOS App Running on Apple Silicon Mac
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var model = [CChar](repeating: 0,  count: size)
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
        return "4.2.0"
    }

}
