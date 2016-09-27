//
//  UIViewSelectors.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    func mp_encryptHelper(input: String?) -> NSString {
        let encryptedStuff = NSMutableString(capacity: 64)
        guard let input = input else {
            return encryptedStuff
        }
        let SALT = "1l0v3c4a8s4n018cl3d93kxled3kcle3j19384jdo2dk3"
        let data = (input + SALT).data(using: .ascii)
        if let digest = data?.sha256()?.bytes {
            for i in 0..<20 {
                encryptedStuff.appendFormat("%02x", digest[i])
            }
        }
        return encryptedStuff
    }

    func mp_fingerprintVersion() -> NSNumber {
        return NSNumber(value: 1)
    }

    func mp_varA() -> NSString? {
        return mp_encryptHelper(input: mp_viewId())
    }

    func mp_varB() -> NSString? {
        return mp_encryptHelper(input: mp_controllerVariable())
    }

    func mp_varC() -> NSString? {
        return mp_encryptHelper(input: mp_imageFingerprint())
    }

    func mp_varSetD() -> NSArray {
        return mp_targetActions().map {
            mp_encryptHelper(input: $0)
        } as NSArray
    }

    func mp_varE() -> NSString? {
        return mp_encryptHelper(input: mp_text())
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
                        if let value = attr.value as? UIView, value == self {
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
        let imageSelector = Selector("image")

        if let button = self as? UIButton {
            originalImage = button.image(for: UIControlState.normal)
        } else if let superviewUnwrapped = self.superview,
            NSStringFromClass(type(of: superviewUnwrapped)) == "UITabBarButton" && self.responds(to: imageSelector) {
            originalImage = self.perform(imageSelector).takeRetainedValue() as? UIImage
        }

        if let originalImage = originalImage, let cgImage = originalImage.cgImage {
            let space = CGColorSpaceCreateDeviceRGB()
            let data32 = UnsafeMutablePointer<UInt32>.allocate(capacity: 64)
            let data4 = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            let context = CGContext(data: data32,
                                    width: 8,
                                    height: 8,
                                    bitsPerComponent: 8,
                                    bytesPerRow: 8*4,
                                    space: space,
                                    bitmapInfo: bitmapInfo)
            context?.setAllowsAntialiasing(false)
            context?.clear(CGRect(x: 0, y: 0, width: 8, height: 8))
            context?.interpolationQuality = .none
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 8, height: 8))
            for i in 0..<32 {
                let j = 2*i
                let k = 2*i + 1
                let part1 = ((data32[j] & 0x80000000) >> 24) | ((data32[j] & 0x800000) >> 17) | ((data32[j] & 0x8000) >> 10)
                let part2 = ((data32[j] & 0x80) >> 3) | ((data32[k] & 0x80000000) >> 28) | ((data32[k] & 0x800000) >> 21)
                let part3 = ((data32[k] & 0x8000) >> 14) | ((data32[k] & 0x80) >> 7)
                data4[i] = UInt8(part1 | part2 | part3)
            }
            let arr = Array(UnsafeBufferPointer(start: data4, count: 32))
            result = Data(bytes: arr).base64EncodedString()
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
