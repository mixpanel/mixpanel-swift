//
//  VariantAction.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class VariantAction: NSObject, NSCoding {
    let name: String
    let path: ObjectSelector
    let selector: Selector
    let args: [Any]
    let original: [Any]?
    let cacheOriginal: Bool
    let swizzle: Bool
    let swizzleClass: AnyClass
    let swizzleSelector: Selector
    let appliedTo: NSHashTable<UIView>

    static let gettersForSetters = [NSSelectorFromString("setImage:forState:"):           NSSelectorFromString("imageForState:"),
                                    NSSelectorFromString("setImage:"):                    NSSelectorFromString("image"),
                                    NSSelectorFromString("setBackgroundImage:forState:"): NSSelectorFromString("imageForState:")]
    static var originalCache = [UIView: UIImage]()

    convenience init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "variant action json object should not be nil")
            return nil
        }

        guard let pathString = object["path"] as? String else {
            Logger.error(message: "invalid action path")
            return nil
        }
        let path = ObjectSelector(string: pathString)

        guard let selectorString = object["selector"] as? String else {
            Logger.error(message: "invalid action selector")
            return nil
        }
        let selector = NSSelectorFromString(selectorString)

        guard let args = object["args"] as? [Any] else {
            Logger.error(message: "invalid action arguments")
            return nil
        }

        var cacheOriginal = false
        if let cacheOrig = object["cacheOriginal"] as? Bool {
            cacheOriginal = !cacheOrig
        }

        let original = object["original"] as? [Any]
        let name = object["name"] as? String

        self.init(name: name, path: path, selector: selector, args: args, cacheOriginal: cacheOriginal, original: original)
    }

    init(name: String?, path: ObjectSelector, selector: Selector, args: [Any], cacheOriginal: Bool, original: [Any]?) {
        self.path = path
        self.selector = selector
        self.args = args
        self.original = original
        self.swizzle = true
        self.cacheOriginal = cacheOriginal
        self.name = name ?? UUID().uuidString
        self.swizzleClass = UIView.self
        self.swizzleSelector = NSSelectorFromString("didMoveToWindow")
        self.appliedTo = NSHashTable(options: [.weakMemory, .objectPointerPersonality])
    }

    func execute() {
        let executeBlock = { (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
            if self.cacheOriginal {
//                self.cacheOriginalImage(view)
//                let invocations...
            }

        }
        executeBlock(nil, #function, nil, nil)

        let swizzleBlock = { (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
            DispatchQueue.main.async {
                executeBlock(view, command, param1, param2)
            }
        }

        if swizzle {
            Swizzler.swizzleSelector(swizzleSelector,
                                     withSelector: #selector(UIView.newDidMoveToWindow),
                                     for: swizzleClass,
                                     name: name,
                                     block: swizzleBlock)
        }
    }

    func stop() {
        if swizzle {
            Swizzler.unswizzleSelector(swizzleSelector, aClass: swizzleClass, name: name)
        }

        if let original = original {
            //
        } else if cacheOriginal {
            //
        }

        appliedTo.removeAllObjects()
    }

    required init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(forKey: "name") as? String,
            let pathString = aDecoder.decodeObject(forKey: "path") as? String,
            let selectorString = aDecoder.decodeObject(forKey: "selector") as? String,
            let args = aDecoder.decodeObject(forKey: "args") as? [Any],
            let swizzle = aDecoder.decodeObject(forKey: "swizzle") as? Bool,
            let swizzleClassString = aDecoder.decodeObject(forKey: "swizzleClass") as? String,
            let swizzleClass = NSClassFromString(swizzleClassString),
            let swizzleSelectorString = aDecoder.decodeObject(forKey: "swizzleSelector") as? String
            else {
                return nil
        }

        self.name = name
        self.path = ObjectSelector(string: pathString)
        self.selector = NSSelectorFromString(selectorString)
        self.args = args
        self.original = aDecoder.decodeObject(forKey: "original") as? [Any]
        self.swizzle = swizzle
        self.swizzleClass = swizzleClass
        self.swizzleSelector = NSSelectorFromString(swizzleSelectorString)
        self.cacheOriginal = false
        self.appliedTo = NSHashTable(options: [.weakMemory, .objectPointerPersonality])
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(path.string, forKey: "path")
        aCoder.encode(NSStringFromSelector(selector), forKey: "selector")
        aCoder.encode(args, forKey: "args")
        aCoder.encode(original, forKey: "original")
        aCoder.encode(swizzle, forKey: "swizzle")
        aCoder.encode(NSStringFromClass(swizzleClass), forKey: "swizzleClass")
        aCoder.encode(NSStringFromSelector(swizzleSelector), forKey: "swizzleSelector")
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? VariantAction else {
            return false
        }

        if object === self {
            return true
        } else {
            return self.name == object.name
        }
    }

    override var hash: Int {
        return self.name.hash
    }

    class func executeSelector(_ selector: Selector,
                               args: [Any],
                               path: ObjectSelector,
                               root: AnyObject,
                               leaf: AnyObject?) -> [(AnyObject, AnyObject?)] {
        if let leaf = leaf {
            if path.isSelected(leaf: leaf, from: root) {
                return executeSelector(selector, args: args, on: [leaf])
            } else {
                return []
            }
        } else {
            return executeSelector(selector, args: args, on: path.selectFrom(root: root))
        }
    }

    @discardableResult
    class func executeSelector(_ selector: Selector, args: [Any], on objects: [AnyObject]) -> [(AnyObject, AnyObject?)] {
        var targetRetValuePairs = [(AnyObject, AnyObject?)]()
        var transformedArgs = [Any]()
        for argument in args {
            if let argumentTuple = argument as? [AnyObject], argumentTuple.count == 2 {
                guard let type = argumentTuple[1] as? String else {
                    continue
                }
                let transformedArg = argumentTuple[0]
                if let valueType = transformedArg as? NSValue {
                    print("WE ARE FUCKED LOL")
                }
                transformedArgs.append(transformedArg)
            }
        }
        for object in objects {
            var retValue: AnyObject? = nil
            if transformedArgs.isEmpty {
                retValue = object.perform(selector)?.takeRetainedValue()
            } else if transformedArgs.count == 1 {
                retValue = object.perform(selector, with: transformedArgs[0])?.takeRetainedValue()
            } else if transformedArgs.count == 2 {
                retValue = object.perform(selector, with: transformedArgs[0], with: transformedArgs[1])?.takeRetainedValue()
            } else {
                print("WE ARE FUCKED 222 LOL")
            }

            targetRetValuePairs.append((object, retValue))
        }
        return targetRetValuePairs
    }

    func cacheOriginalImage(_ view: UIView) {
        if let cacheSelector = VariantAction.gettersForSetters[selector] {
            guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                print("WTF JUST HAPPENED")
                return
            }
            let cachedPerformedSelectors = VariantAction.executeSelector(cacheSelector, args: args, path: path, root: rootVC, leaf: view)
            for performedSelector in cachedPerformedSelectors {
                guard let view = performedSelector.0 as? UIView else {
                    print("SOOOO FUCKED HAHA")
                    continue
                }
                if VariantAction.originalCache[view] == nil {
                    if let image = performedSelector.1 as? UIImage {
                        VariantAction.originalCache[view] = image
                    }
                }
            }
        }
    }

    func restoreCachedImage() {
        for object in appliedTo.allObjects {
            if let originalImage = VariantAction.originalCache[object] {
                let originalArgs = args.map { arg -> Any in
                    if let arg = arg as? [AnyObject], let str = arg[1] as? String, str == "UIImage" {
                        return [originalImage, "UIImage"] as [Any]
                    }
                    return arg
                }
                VariantAction.executeSelector(selector, args: originalArgs, on: [object])
                VariantAction.originalCache.removeValue(forKey: object)
            }
        }
    }

}
