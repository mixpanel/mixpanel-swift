//
//  AutomaticProperties.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import CoreTelephony

class AutomaticProperties {

    static let telephonyInfo = CTTelephonyNetworkInfo()

    static var properties: Properties = {
        var p = Properties()
        let size = UIScreen.mainScreen().bounds.size
        let infoDict = NSBundle.mainBundle().infoDictionary
        if let infoDict = infoDict {
            p["$app_build_number"]     = infoDict["CFBundleVersion"]
            p["$app_version_string"]   = infoDict["CFBundleShortVersionString"]
        }
        p["$carrier"]           = AutomaticProperties.telephonyInfo.subscriberCellularProvider?.carrierName
        p["mp_lib"]             = "swift"
        p["$lib_version"]       = AutomaticProperties.libVersion()
        p["$manufacturer"]      = "Apple"
        p["$os"]                = UIDevice.currentDevice().systemName
        p["$os_version"]        = UIDevice.currentDevice().systemVersion
        p["$model"]             = AutomaticProperties.deviceModel()
        p["$screen_height"]     = Int(size.height)
        p["$screen_width"]      = Int(size.width)
        return p
    }()

    static var peopleProperties: Properties = {
        var p = Properties()
        let infoDict = NSBundle.mainBundle().infoDictionary
        if let infoDict = infoDict {
            p["$ios_app_version"] = infoDict["CFBundleVersion"]
            p["$ios_app_release"] = infoDict["CFBundleShortVersionString"]
        }
        p["$ios_device_model"]  = AutomaticProperties.deviceModel()
        p["$ios_version"]       = UIDevice.currentDevice().systemVersion
        p["$ios_lib_version"]   = AutomaticProperties.libVersion()

        return p
    }()

    class func getCurrentRadio() -> String? {
        var radio = telephonyInfo.currentRadioAccessTechnology
        let prefix = "CTRadioAccessTechnology"
        if radio == nil {
            radio = "None"
        } else if radio!.hasPrefix(prefix) {
            radio = (radio! as NSString).substringFromIndex(prefix.characters.count)
        }
        return radio
    }

    class func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafeMutablePointer(&systemInfo.machine) {
            ptr in String.fromCString(UnsafePointer<CChar>(ptr))
        }
        if let model = modelCode {
            return model
        }
        return ""
    }

    class func libVersion() -> String? {
        return NSBundle(forClass: self).infoDictionary?["CFBundleShortVersionString"] as? String
    }

}
