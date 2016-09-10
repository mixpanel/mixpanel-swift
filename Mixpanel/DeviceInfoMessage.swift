//
//  DeviceInfoMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class DeviceInfoRequest: BaseWebSocketMessage {

    init() {
        super.init(type: "device_info_request")
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            var response: DeviceInfoResponse? = nil

            DispatchQueue.main.sync {
                let currentDevice = UIDevice.current
                response = DeviceInfoResponse(systemName: currentDevice.systemName,
                                              systemVersion: currentDevice.systemVersion,
                                              appVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                                              appRelease: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                                              deviceName: currentDevice.name,
                                              deviceModel: currentDevice.model,
                                              libVersion: AutomaticProperties.libVersion(),
                                              availableFontFamilies: self.availableFontFamilies(),
                                              mainBundleIdentifier: Bundle.main.bundleIdentifier)
            }
            connection.sendMessage(message: response)
        }

        return operation
    }

    func availableFontFamilies() -> [[String: AnyObject]] {
        var fontFamilies = [[String: AnyObject]]()
        let systemFonts = [UIFont.systemFont(ofSize: 17), UIFont.boldSystemFont(ofSize: 17), UIFont.italicSystemFont(ofSize: 17)]
        var foundSystemFamily = false

        for familyName in UIFont.familyNames {
            var fontNames = UIFont.fontNames(forFamilyName: familyName)
            if familyName == systemFonts.first!.familyName {
                for systemFont in systemFonts {
                    if !fontNames.contains(systemFont.fontName) {
                        fontNames.append(systemFont.fontName)
                    }
                }
                foundSystemFamily = true
            }
            fontFamilies.append(["family": familyName as AnyObject,
                                 "font_names": UIFont.fontNames(forFamilyName: familyName) as AnyObject])
        }

        if !foundSystemFamily {
            fontFamilies.append(["family": systemFonts.first!.familyName as AnyObject,
                                 "font_names": systemFonts.map { $0.fontName } as AnyObject])
        }

        return fontFamilies
    }
}

class DeviceInfoResponse: BaseWebSocketMessage {
    init(systemName: String,
         systemVersion: String,
         appVersion: String?,
         appRelease: String?,
         deviceName: String,
         deviceModel: String,
         libVersion: String?,
         availableFontFamilies: [[String: Any]],
         mainBundleIdentifier: String?) {
        var payload = [String: AnyObject]()
        payload["system_name"] = systemName as AnyObject
        payload["system_version"] = systemVersion as AnyObject
        payload["device_name"] = deviceName as AnyObject
        payload["device_model"] = deviceModel as AnyObject
        payload["available_font_families"] = availableFontFamilies as AnyObject

        if let appVersion = appVersion {
            payload["app_version"] = appVersion as AnyObject
        }
        if let appRelease = appRelease {
            payload["app_release"] = appRelease as AnyObject
        }
        if let libVersion = libVersion {
            payload["lib_version"] = libVersion as AnyObject
        }
        if let mainBundleIdentifier = mainBundleIdentifier {
            payload["main_bundle_identifier"] = mainBundleIdentifier as AnyObject
        }

        super.init(type: "device_info_response", payload: payload)
    }
}
