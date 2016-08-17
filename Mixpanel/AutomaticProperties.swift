//
//  AutomaticProperties.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit
#if os(iOS)
    import CoreTelephony
#endif

class AutomaticProperties {
    #if os(iOS)
    static let telephonyInfo = CTTelephonyNetworkInfo()
    #endif

    static var properties: Properties = {
        var p = Properties()
        let size = UIScreen.main.bounds.size
        let infoDict = Bundle.main.infoDictionary
        if let infoDict = infoDict {
            p["$app_build_number"]     = infoDict["CFBundleVersion"] as AnyObject
            p["$app_version_string"]   = infoDict["CFBundleShortVersionString"] as AnyObject
        }
        #if os(iOS)
            p["$carrier"]           = AutomaticProperties.telephonyInfo.subscriberCellularProvider?.carrierName as AnyObject
        #endif
        p["mp_lib"]             = "swift" as AnyObject
        p["$lib_version"]       = AutomaticProperties.libVersion() as AnyObject
        p["$manufacturer"]      = "Apple" as AnyObject
        p["$os"]                = UIDevice.current.systemName as AnyObject
        p["$os_version"]        = UIDevice.current.systemVersion as AnyObject
        p["$model"]             = AutomaticProperties.deviceModel() as AnyObject
        p["$screen_height"]     = Int(size.height) as AnyObject
        p["$screen_width"]      = Int(size.width) as AnyObject
        return p
    }()

    static var peopleProperties: Properties = {
        var p = Properties()
        let infoDict = Bundle.main.infoDictionary
        if let infoDict = infoDict {
            p["$ios_app_version"] = infoDict["CFBundleVersion"] as AnyObject
            p["$ios_app_release"] = infoDict["CFBundleShortVersionString"] as AnyObject
        }
        p["$ios_device_model"]  = AutomaticProperties.deviceModel() as AnyObject
        p["$ios_version"]       = UIDevice.current.systemVersion as AnyObject
        p["$ios_lib_version"]   = AutomaticProperties.libVersion() as AnyObject

        return p
    }()

    #if os(iOS)
    class func getCurrentRadio() -> String? {
        var radio = telephonyInfo.currentRadioAccessTechnology
        let prefix = "CTRadioAccessTechnology"
        if radio == nil {
            radio = "None"
        } else if radio!.hasPrefix(prefix) {
            radio = (radio! as NSString).substring(from: prefix.characters.count)
        }
        return radio
    }
    #endif

    class func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = MemoryLayout<CChar>.size
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
          $0.withMemoryRebound(to: CChar.self, capacity: size) {
            String(cString:  UnsafePointer<CChar>($0))
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
