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
    let appliedTo: NSHashTable<AnyObject>

    static let gettersForSetters = [NSSelectorFromString("setImage:forState:"):           NSSelectorFromString("imageForState:"),
                                    NSSelectorFromString("setImage:"):                    NSSelectorFromString("image"),
                                    NSSelectorFromString("setBackgroundImage:forState:"): NSSelectorFromString("imageForState:")]
    static let originalCache = [UIView: UIImage]()

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
//TODO
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

}
