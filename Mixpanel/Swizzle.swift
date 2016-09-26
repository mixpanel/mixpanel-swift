//
//  Swizzle.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/25/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

extension DispatchQueue {
    private static var _onceTracker = [String]()

    class func once(token: String, block: () -> Void) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }
        if _onceTracker.contains(token) {
            return
        }
        _onceTracker.append(token)
        block()
    }
}

class Swizzler {
    static var swizzles = [Method: Swizzle]()

    class func printSwizzles() {
        for (_, swizzle) in swizzles {
            Logger.debug(message: "\(swizzle)")
        }
    }

    class func getSwizzle(for method: Method) -> Swizzle? {
        return swizzles[method]
    }

    class func removeSwizzle(for method: Method) {
        swizzles.removeValue(forKey: method)
    }

    class func setSwizzle(_ swizzle: Swizzle, for method: Method) {
        swizzles[method] = swizzle
    }

    class func swizzleSelector(_ originalSelector: Selector,
                               withSelector newSelector: Selector,
                               for aClass: AnyClass,
                               name: String,
                               block: @escaping ((_ view: AnyObject?,
                                                  _ command: Selector,
                                                  _ param1: AnyObject?,
                                                  _ param2: AnyObject?) -> Void)) {

        if let originalMethod = class_getInstanceMethod(aClass, originalSelector),
            let swizzledMethod = class_getInstanceMethod(aClass, newSelector),
            let swizzledMethodImplementation = method_getImplementation(swizzledMethod),
            let originalMethodImplementation = method_getImplementation(originalMethod) {

            var swizzle = getSwizzle(for: originalMethod)
            if swizzle == nil {
                swizzle = Swizzle(block: block,
                                  name: name,
                                  aClass: aClass,
                                  selector: originalSelector,
                                  originalMethod: originalMethodImplementation)
                setSwizzle(swizzle!, for: originalMethod)
            } else {
                swizzle?.blocks[name] = block
            }

            let didAddMethod = class_addMethod(aClass,
                                               originalSelector,
                                               swizzledMethodImplementation,
                                               method_getTypeEncoding(swizzledMethod))
            if didAddMethod {
                setSwizzle(swizzle!, for: class_getInstanceMethod(aClass, originalSelector))
            } else {
                method_setImplementation(originalMethod, swizzledMethodImplementation)
            }
        } else {
            Logger.error(message: "Swizzling error: Cannot find method for "
                + "\(NSStringFromSelector(originalSelector)) on \(NSStringFromClass(aClass))")
        }
    }

    class func unswizzleSelector(_ selector: Selector, aClass: AnyClass, name: String? = nil) {
        if let method = class_getInstanceMethod(aClass, selector),
            let swizzle = getSwizzle(for: method) {
            if let name = name {
                swizzle.blocks.removeValue(forKey: name)
            }

            if name == nil || swizzle.blocks.count < 1 {
                method_setImplementation(method, swizzle.originalMethod)
                removeSwizzle(for: method)
            }
        }
    }

}

class Swizzle: CustomStringConvertible {
    let aClass: AnyClass
    let selector: Selector
    let originalMethod: IMP
    var blocks = [String: ((view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) -> Void)]()

    init(block: @escaping ((_ view: AnyObject?, _ command: Selector, _ param1: AnyObject?, _ param2: AnyObject?) -> Void),
         name: String,
         aClass: AnyClass,
         selector: Selector,
         originalMethod: IMP) {
        self.aClass = aClass
        self.selector = selector
        self.originalMethod = originalMethod
        self.blocks[name] = block
    }

    var description: String {
        var retValue = "Swizzle on \(NSStringFromClass(type(of: self)))::\(NSStringFromSelector(selector)) ["
        for (key, value) in blocks {
            retValue += "\t\(key) : \(value)\n"
        }
        return retValue + "]"
    }


}
