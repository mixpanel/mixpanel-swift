//
//  ApplicationStateSerializer.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ApplicationStateSerializer {

    let serializer: ObjectSerializer
    let application: UIApplication

    init(application: UIApplication, configuration: ObjectSerializerConfig, objectIdentityProvider: ObjectIdentityProvider) {
        self.application = application
        self.serializer = ObjectSerializer(configuration: configuration, objectIdentityProvider: objectIdentityProvider)
    }

    func getScreenshotForWindow(index: Int) -> UIImage? {
        var image: UIImage? = nil

        if let window = getWindow(index: index), !window.frame.equalTo(CGRect.zero) {
            UIGraphicsBeginImageContextWithOptions(window.bounds.size, true, window.screen.scale)
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) {
                Logger.error(message: "Unable to get a screenshot for window at index \(index)")
            }
            image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        return image
    }

    func getWindow(index: Int) -> UIWindow? {
        return application.windows[index]
    }

    func getObjectHierarchyForWindow(index: Int) -> [String: AnyObject] {
        if let window = getWindow(index: index) {
            return serializer.getSerializedObjects(rootObject: window)
        }

        return [:]
    }

}
