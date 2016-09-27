//
//  DeviceInfoMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class DeviceInfoRequest: BaseWebSocketMessage {

    init() {
        super.init(type: MessageType.deviceInfoRequest.rawValue)
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            var response: DeviceInfoResponse? = nil

            DispatchQueue.main.sync {
                let currentDevice = UIDevice.current
                let infoResponseInput = InfoResponseInput(systemName: currentDevice.systemName,
                                                          systemVersion: currentDevice.systemVersion,
                                                          appVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                                                          appRelease: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                                                          deviceName: currentDevice.name,
                                                          deviceModel: currentDevice.model,
                                                          libVersion: AutomaticProperties.libVersion(),
                                                          availableFontFamilies: self.availableFontFamilies(),
                                                          mainBundleIdentifier: Bundle.main.bundleIdentifier)
                response = DeviceInfoResponse(infoResponseInput)
            }
            connection.send(message: response)
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

struct InfoResponseInput {
    let systemName: String
    let systemVersion: String
    let appVersion: String?
    let appRelease: String?
    let deviceName: String
    let deviceModel: String
    let libVersion: String?
    let availableFontFamilies: [[String: Any]]
    let mainBundleIdentifier: String?
}

class DeviceInfoResponse: BaseWebSocketMessage {
    init(_ infoResponse: InfoResponseInput) {
        var payload = [String: AnyObject]()
        payload["system_name"] = infoResponse.systemName as AnyObject
        payload["system_version"] = infoResponse.systemVersion as AnyObject
        payload["device_name"] = infoResponse.deviceName as AnyObject
        payload["device_model"] = infoResponse.deviceModel as AnyObject
        payload["available_font_families"] = infoResponse.availableFontFamilies as AnyObject

        if let appVersion = infoResponse.appVersion {
            payload["app_version"] = appVersion as AnyObject
        }
        if let appRelease = infoResponse.appRelease {
            payload["app_release"] = appRelease as AnyObject
        }
        if let libVersion = infoResponse.libVersion {
            payload["lib_version"] = libVersion as AnyObject
        }
        if let mainBundleIdentifier = infoResponse.mainBundleIdentifier {
            payload["main_bundle_identifier"] = mainBundleIdentifier as AnyObject
        }

        super.init(type: MessageType.deviceInfoResponse.rawValue, payload: payload)
    }
}
