//
//  ApplicationStateSerializer.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class ApplicationStateSerializer {

    let serializer: ObjectSerializer
    let application: UIApplication

    init(application: UIApplication, configuration: ObjectSerializerConfig, objectIdentityProvider: ObjectIdentityProvider) {
        self.application = application
        self.serializer = ObjectSerializer(configuration: configuration, objectIdentityProvider: objectIdentityProvider)
    }

    func getScreenshotForWindow(at index: Int) -> UIImage? {
        var image: UIImage? = nil

        if let window = getWindow(at: index), !window.frame.equalTo(CGRect.zero) {
            UIGraphicsBeginImageContextWithOptions(window.bounds.size, true, window.screen.scale)
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) {
                Logger.error(message: "Unable to get a screenshot for window at index \(index)")
            }
            image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        return image
    }

    func getWindow(at index: Int) -> UIWindow? {
        return application.windows[index]
    }

    func getObjectHierarchyForWindow(at index: Int) -> [String: AnyObject] {
        if let window = getWindow(at: index) {
            return serializer.getSerializedObjects(rootObject: window)
        }

        return [:]
    }

}
