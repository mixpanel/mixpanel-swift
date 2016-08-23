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

    static var properties: InternalProperties = {
        var p = InternalProperties()
        let size = UIScreen.main.bounds.size
        let infoDict = Bundle.main.infoDictionary
        if let infoDict = infoDict {
            p["$app_build_number"]     = infoDict["CFBundleVersion"]
            p["$app_version_string"]   = infoDict["CFBundleShortVersionString"]
        }
        #if os(iOS)
            p["$carrier"] = AutomaticProperties.telephonyInfo.subscriberCellularProvider?.carrierName
        #endif
        p["mp_lib"]             = "swift"
        p["$lib_version"]       = AutomaticProperties.libVersion()
        p["$manufacturer"]      = "Apple"
        p["$os"]                = UIDevice.current.systemName
        p["$os_version"]        = UIDevice.current.systemVersion
        p["$model"]             = AutomaticProperties.deviceModel()
        p["$screen_height"]     = Int(size.height)
        p["$screen_width"]      = Int(size.width)
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
        p["$ios_version"]       = UIDevice.current.systemVersion
        p["$ios_lib_version"]   = AutomaticProperties.libVersion()

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
