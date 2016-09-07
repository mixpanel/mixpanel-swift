//
//  Swizzle.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/25/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

public extension DispatchQueue {
    private static var _onceTracker = [String]()

    public class func once(token: String, block: () -> Void) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }
        if _onceTracker.contains(token) {
            return
        }
        _onceTracker.append(token)
        block()
    }
}

class Swizzler {
    //static var swizzles: NSMapTable<AnyObject, Swizzle>?
    static var swizzles = [Method: Swizzle]()
    //class func load() {
    //    swizzles = NSMapTable(keyOptions: [.opaqueMemory, .opaquePersonality], valueOptions: [.strongMemory, .objectPointerPersonality])
    //}

    class func printSwizzles() {
        //guard let enumerator = swizzles?.objectEnumerator() else {
        //    return
        //}
        //while let swizzle = enumerator.nextObject() {
        for (_, swizzle) in swizzles {
            Logger.debug(message: "\(swizzle)")
        }
    }

    class func getSwizzle(method: Method) -> Swizzle? {
        //return swizzles?.object(forKey: method as AnyObject)
        return swizzles[method]
    }

    class func removeSwizzle(method: Method) {
        //swizzles?.removeObject(forKey: method as AnyObject)
        swizzles.removeValue(forKey: method)
    }

    class func setSwizzle(swizzle: Swizzle, method: Method) {
        //swizzles?.setObject(swizzle, forKey: method as AnyObject)
        swizzles[method] = swizzle
    }

    class func swizzleSelector(selector: Selector,
                               aClass: AnyClass,
                               block: ((_ view: AnyObject?, _ command: Selector, _ param1: AnyObject?, _ param2: AnyObject?) -> Void),
                               name: String) {
        if let originalMethod = class_getInstanceMethod(aClass, selector) {
            let numArgs = method_getNumberOfArguments(originalMethod) - 2
            if numArgs >= 0 && numArgs <= 2 {
                var swizzledSelector: Selector?
                switch numArgs {
                case 0:
                    swizzledSelector = #selector(self.swizzledMethodNoParams)
                case 1:
                    swizzledSelector = #selector(self.swizzledMethodOneParam)
                case 2:
                    swizzledSelector = #selector(self.swizzledMethodTwoParams)
                default: break
                }
                let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
                let originalMethodImplementation = method_getImplementation(originalMethod)
                var swizzle = getSwizzle(method: originalMethod)
                if swizzle == nil {
                    swizzle = Swizzle(block: block,
                                      name: name,
                                      aClass: aClass,
                                      selector: selector,
                                      originalMethod: originalMethodImplementation!,
                                      numArgs: Int(numArgs))
                    setSwizzle(swizzle: swizzle!, method: originalMethod)
                } else {
                    swizzle?.blocks[name] = block
                    //swizzle?.blocks.setObject(block as AnyObject, forKey: name as NSString)
                }

                let didAddMethod = class_addMethod(aClass, selector, swizzledMethod, method_getTypeEncoding(swizzledMethod))

                if didAddMethod {
                    class_replaceMethod(aClass,
                                        swizzledSelector,
                                        method_getImplementation(originalMethod),
                                        method_getTypeEncoding(originalMethod))
                } else {
                    method_exchangeImplementations(originalMethod, swizzledMethod)
                }

            } else {
                Logger.error(message: "We don't support swizzling of methods with more than 2 parameters")
            }
        } else {
            Logger.error(message: "Swizzling error: Cannot find method for "
                + "\(NSStringFromSelector(selector)) on \(NSStringFromClass(aClass))")
        }

    }

    @objc class func swizzledMethodNoParams(owner: AnyObject, selector: Selector) {
        let swizzledSelector = #selector(self.swizzledMethodNoParams)

        //if let swizzle = swizzles?.object(forKey: swizzleMethod as AnyObject) {
        if let swizzleMethod = class_getInstanceMethod(self, swizzledSelector),
            let swizzle = swizzles[swizzleMethod] {
            // run original method
            let implementation = method_getImplementation(swizzleMethod)
            typealias Function = @convention(c) (AnyObject, Selector) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(owner, selector)

            //if let enumerator = swizzle.blocks.objectEnumerator() {
            //while let block = enumerator.nextObject() as? (() -> Void) {
            for (_, block) in swizzle.blocks {
                block(owner, selector, nil, nil)
            }
            //}
        }
    }

    @objc class func swizzledMethodOneParam(owner: AnyObject, selector: Selector, param1: AnyObject) {
        let swizzledSelector = #selector(self.swizzledMethodOneParam)
        //let swizzleMethod = class_getInstanceMethod(self, swizzledSelector)
        //if let swizzle = swizzles?.object(forKey: swizzleMethod as AnyObject) {
        if let swizzleMethod = class_getInstanceMethod(self, swizzledSelector),
            let swizzle = swizzles[swizzleMethod] {
            // run original method
            let implementation = method_getImplementation(swizzleMethod)
            typealias Function = @convention(c) (AnyObject, Selector, AnyObject) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(owner, selector, param1)

            //if let enumerator = swizzle.blocks.objectEnumerator() {
                //while let block = enumerator.nextObject() as? (() -> Void) {
                for (_, block) in swizzle.blocks {
                    block(owner, selector, param1, nil)
                }
            //}
        }
    }

    @objc class func swizzledMethodTwoParams(owner: AnyObject, selector: Selector, param1: AnyObject, param2: AnyObject) {
        let swizzledSelector = #selector(self.swizzledMethodTwoParams)
        //let swizzleMethod = class_getInstanceMethod(self, swizzledSelector)
        //if let swizzle = swizzles?.object(forKey: swizzleMethod as AnyObject) {
        if let swizzleMethod = class_getInstanceMethod(self, swizzledSelector),
            let swizzle = swizzles[swizzleMethod] {
            // run original method
            let implementation = method_getImplementation(swizzleMethod)
            typealias Function = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(owner, selector, param1, param2)

            //if let enumerator = swizzle.blocks.objectEnumerator() {
                //while let block = enumerator.nextObject() as? (() -> Void) {
                for (_, block) in swizzle.blocks {
                    block(owner, selector, param1, param2)
                }
            //}
        }
    }

    class func unswizzleSelector(selector: Selector, aClass: AnyClass, name: String? = nil) {
        if let method = class_getInstanceMethod(aClass, selector),
            let swizzle = getSwizzle(method: method) {
            if let name = name {
                //swizzle.blocks.removeObject(forKey: name as NSString)
                swizzle.blocks.removeValue(forKey: name)
            }

            if name == nil || swizzle.blocks.count < 1 {
                method_setImplementation(method, swizzle.originalMethod)
                removeSwizzle(method: method)
            }
        }
    }

}

class Swizzle: CustomStringConvertible {
    let aClass: AnyClass
    let selector: Selector
    let originalMethod: IMP
    let numArgs: Int
    //let blocks = NSMapTable<NSString, AnyObject>(keyOptions: [.strongMemory, .objectPersonality],
    //                                              valueOptions: [.strongMemory, .objectPointerPersonality])
    var blocks = [String: ((view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) -> Void)]()

    init(block: ((_ view: AnyObject?, _ command: Selector, _ param1: AnyObject?, _ param2: AnyObject?) -> Void),
         name: String,
         aClass: AnyClass,
         selector: Selector,
         originalMethod: IMP,
         numArgs: Int) {
        self.aClass = aClass
        self.selector = selector
        self.originalMethod = originalMethod
        self.numArgs = numArgs
        self.blocks[name] = block
    }

    var description: String {
        var retValue = "Swizzle on \(NSStringFromClass(type(of: self)))::\(NSStringFromSelector(selector)) ["
        //guard let enumerator = blocks.objectEnumerator() else {
        //    return retValue
        //}
        //while let key = enumerator.nextObject() {
        for (key, value) in blocks {
            retValue += "\t\(key) : \(value)\n"
        }
        return retValue + "]"
    }


}
