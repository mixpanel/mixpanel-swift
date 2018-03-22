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
    #if os(iOS)
    static let telephonyInfo = CTTelephonyNetworkInfo()
    #endif // os(iOS)

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
        var ifa: String? = AutomaticProperties.IFA()

        #if os(iOS)
        p["$carrier"] = AutomaticProperties.telephonyInfo.subscriberCellularProvider?.carrierName
        #endif // os(iOS)

        #else
        if let size = NSScreen.main?.frame.size {
            p["$screen_height"]     = Int(size.height)
            p["$screen_width"]      = Int(size.width)
        }
        p["$os"]                = "macOS"
        p["$os_version"]        = ProcessInfo.processInfo.operatingSystemVersionString
        let ifa = AutomaticProperties.macOSIdentifier()
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
        if ifa != nil  {
            p["$ios_ifa"] = ifa
        }

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
        var ifa: String? = AutomaticProperties.IFA()
        #else
        p["$ios_version"]       = ProcessInfo.processInfo.operatingSystemVersionString
        let ifa = AutomaticProperties.macOSIdentifier()
        #endif // os(OSX)
        p["$ios_lib_version"]   = AutomaticProperties.libVersion()
        p["$swift_lib_version"] = AutomaticProperties.libVersion()
        if ifa != nil  {
            p["$ios_ifa"] = ifa
        }

        return p
    }()

    #if os(iOS)
    class func getCurrentRadio() -> String {
        var radio = telephonyInfo.currentRadioAccessTechnology ?? "None"
        let prefix = "CTRadioAccessTechnology"
        if radio.hasPrefix(prefix) {
            radio = (radio as NSString).substring(from: prefix.count)
        }
        return radio
    }
    #endif // os(iOS)

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

    #if !os(OSX)
    class func IFA() -> String? {
        var ifa: String? = nil
        if let ASIdentifierManagerClass = NSClassFromString("ASIdentifierManager") {
            let sharedManagerSelector = NSSelectorFromString("sharedManager")
            if let sharedManagerIMP = ASIdentifierManagerClass.method(for: sharedManagerSelector) {
                typealias sharedManagerFunc = @convention(c) (AnyObject, Selector) -> AnyObject!
                let curriedImplementation = unsafeBitCast(sharedManagerIMP, to: sharedManagerFunc.self)
                if let sharedManager = curriedImplementation(ASIdentifierManagerClass.self, sharedManagerSelector) {
                    let advertisingTrackingEnabledSelector = NSSelectorFromString("isAdvertisingTrackingEnabled")
                    if let isTrackingEnabledIMP = sharedManager.method(for: advertisingTrackingEnabledSelector) {
                        typealias isTrackingEnabledFunc = @convention(c) (AnyObject, Selector) -> Bool
                        let curriedImplementation2 = unsafeBitCast(isTrackingEnabledIMP, to: isTrackingEnabledFunc.self)
                        let isTrackingEnabled = curriedImplementation2(self, advertisingTrackingEnabledSelector)
                        if isTrackingEnabled {
                            let advertisingIdentifierSelector = NSSelectorFromString("advertisingIdentifier")
                            if let advertisingIdentifierIMP = sharedManager.method(for: advertisingIdentifierSelector) {
                                typealias adIdentifierFunc = @convention(c) (AnyObject, Selector) -> NSUUID
                                let curriedImplementation3 = unsafeBitCast(advertisingIdentifierIMP, to: adIdentifierFunc.self)
                                ifa = curriedImplementation3(self, advertisingIdentifierSelector).uuidString
                            }
                        }
                    }
                }
            }
        }
        return ifa
    }
    #else
    class func macOSIdentifier() -> String? {
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString!, kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
        return (serialNumberAsCFString?.takeUnretainedValue() as? String)
    }
    #endif // os(OSX)

}
