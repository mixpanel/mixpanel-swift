//
//  UIViewSelectors.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

extension UIView {
    func mp_fingerprintVersion() -> Int {
        return 1
    }

    func mp_varA() -> String? {
        return mp_encryptHelper(input: mp_viewId())
    }

    func mp_varB() -> String? {
        return mp_encryptHelper(input: mp_controllerVariable())
    }

    func mp_varC() -> String? {
        return mp_encryptHelper(input: mp_imageFingerprint())
    }

    func mp_varSetD() -> [String] {
        let targetActions = mp_targetActions()
        return targetActions.map {
            mp_encryptHelper(input: $0)!
        }
    }

    func mp_varE() -> String? {
        return mp_encryptHelper(input: mp_text())
    }

    func mp_encryptHelper(input: String?) -> String? {
        let SALT = "1l0v3c4a8s4n018cl3d93kxled3kcle3j19384jdo2dk3"
        //var encryptedStuff: String? = nil
        if let input = input {
            return input + SALT
        }
        return nil
    }

    func mp_viewId() -> String? {
        return objc_getAssociatedObject(self, "mixpanelViewId") as? String
    }

    func mp_controllerVariable() -> String? {
        if self is UIControl {
            var responder = self.next
            while responder != nil && !(responder is UIViewController) {
                responder = responder?.next
            }
            if let responder = responder {
                let mirrored_object = Mirror(reflecting: responder)

                for (_, attr) in mirrored_object.children.enumerated() {
                    if let property_name = attr.label {
                        if let value = attr.value as? UIView, value == self { //TODO:value type??
                            return property_name
                        }
                    }
                }
            }
        }
        return nil
    }

    func mp_imageFingerprint() -> String? {
        var result: String? = nil
        var originalImage: UIImage? = nil

        if let button = self as? UIButton {
            originalImage = button.image(for: UIControlState.normal)
        } else if let superviewUnwrapped = self.superview,
            NSStringFromClass(type(of: superviewUnwrapped)) == "UITabBarButton" && self.responds(to: Selector("image")) {
            originalImage = self.perform(Selector("image")).takeRetainedValue() as? UIImage
        }

        if let originalImage = originalImage, let imageData = UIImageJPEGRepresentation(originalImage, 0.5) {
            let array = imageData.withUnsafeBytes {
                [UInt8](UnsafeBufferPointer(start: $0, count: imageData.count))
            }
            let hash = NSMutableString()
            for i in 0..<16 {
                hash.appendFormat("%02X", array[i])
            }
            result = hash as String
        }
        return result
    }

    func mp_targetActions() -> [String] {
        var targetActions = [String]()
        if let control = self as? UIControl {
            for target in control.allTargets {
                let allEvents: UIControlEvents = [.allTouchEvents, .allEditingEvents]
                let allEventsRaw = allEvents.rawValue
                var e: UInt = 0
                while allEventsRaw >> e > 0 {
                    let event = allEventsRaw & (0x01 << e)
                    let controlEvent = UIControlEvents(rawValue: event)
                    let ignoreActions = ["preVerify:forEvent:", "execute:forEvent:"]
                    if let actions = control.actions(forTarget: target, forControlEvent: controlEvent) {
                        for action in actions {
                            if ignoreActions.index(of: action) == nil {
                                targetActions.append("\(event)/\(action)")
                            }
                        }
                    }
                    e += 1
                }
            }
        }
        return targetActions
    }

    func mp_text() -> String? {
        var text: String? = nil
        let titleSelector = Selector("title")
        if let label = self as? UILabel {
            text = label.text
        } else if let button = self as? UIButton {
            text = button.title(for: .normal)
        } else if self.responds(to: titleSelector) {
            if let titleImp = self.perform(titleSelector).takeUnretainedValue() as? String {
                text = titleImp
            }
        }
        return text
    }
}
