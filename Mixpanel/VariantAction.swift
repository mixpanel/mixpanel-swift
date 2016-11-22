//
//  VariantAction.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

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
    static let originalCache = NSMapTable<UIView, UIImage>(keyOptions: [.weakMemory, .objectPointerPersonality],
                                                           valueOptions: [.strongMemory, .objectPointerPersonality])

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

        let cacheOriginal = object["cacheOriginal"] == nil
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
        self.swizzleClass = self.path.selectedClass() ?? UIView.self

        var shouldUseLayoutSubviews = false
        let classesToUseLayoutSubviews = [UITableViewCell.self, UINavigationBar.self] as [AnyClass]
        for klass in classesToUseLayoutSubviews {
            if self.path.pathContainsObjectOfClass(klass) {
                shouldUseLayoutSubviews = true
                break
            }
        }

        if shouldUseLayoutSubviews {
            self.swizzleSelector = NSSelectorFromString("layoutSubviews")
        } else {
            self.swizzleSelector = NSSelectorFromString("didMoveToWindow")
        }
        self.appliedTo = NSHashTable(options: [.weakMemory, .objectPointerPersonality])
    }

    func execute() {
        let executeBlock = { (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
            guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                Logger.error(message: "No apparent root view controller, cannot execute action")
                return
            }

            if self.cacheOriginal {
                self.cacheOriginalImage(view as? UIView)
            }

            let performedSelectors = VariantAction.executeSelector(self.selector,
                                                                   args: self.args,
                                                                   path: self.path,
                                                                   root: rootVC,
                                                                   leaf: view)
            for performedSelector in performedSelectors {
                guard let target = performedSelector.0 as? UIView else {
                    Logger.error(message: "Performing a selector didn't return a non-nil target")
                    continue
                }
                self.appliedTo.add(target)
            }

        }
        executeBlock(nil, #function, nil, nil)

        let swizzleBlock = { (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
            DispatchQueue.main.async {
                executeBlock(view, command, param1, param2)
            }
        }

        if swizzle {
            if swizzleSelector == NSSelectorFromString("layoutSubviews") {
                Swizzler.swizzleSelector(swizzleSelector,
                                         withSelector: #selector(UIView.newLayoutSubviews),
                                         for: swizzleClass,
                                         name: name,
                                         block: swizzleBlock)
            } else if swizzleSelector == NSSelectorFromString("didMoveToWindow") {
                Swizzler.swizzleSelector(swizzleSelector,
                                         withSelector: #selector(UIView.newDidMoveToWindow),
                                         for: swizzleClass,
                                         name: name,
                                         block: swizzleBlock)
            } else {
                Logger.error(message: "Selector \(swizzleSelector) wasn't recognized for swizzling")
            }
        }
    }

    func stop() {
        if swizzle {
            Swizzler.unswizzleSelector(swizzleSelector, aClass: swizzleClass, name: name)
        }

        if let original = original {
            VariantAction.executeSelector(selector, args: original, on: appliedTo.allObjects)
        } else if cacheOriginal {
            restoreCachedImage()
        }
        appliedTo.removeAllObjects()
    }

    required init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(forKey: "name") as? String,
            let pathString = aDecoder.decodeObject(forKey: "path") as? String,
            let selectorString = aDecoder.decodeObject(forKey: "selector") as? String,
            let args = aDecoder.decodeObject(forKey: "args") as? [Any],
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
        self.swizzle = aDecoder.decodeBool(forKey: "swizzle")
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
        var doesHaveNSValue = false
        var doesHaveNSNullValue = false
        for argument in args {
            if let argumentTuple = argument as? [AnyObject], argumentTuple.count == 2 {
                guard let type = argumentTuple[1] as? String else {
                    continue
                }
                if let transformedArg = VariantAction.transformValue(argumentTuple[0], to: type) {
                    if transformedArg is NSValue {
                        doesHaveNSValue = true
                    } else if transformedArg is NSNull {
                        doesHaveNSNullValue = true
                    }
                    transformedArgs.append(transformedArg)
                }
            }
        }

        for object in objects {
            var retValue: AnyObject? = nil
            let method: Method!
            if object is AnyClass {
                method = class_getClassMethod(object as! AnyClass, selector)
            } else {
                method = class_getInstanceMethod(type(of: object), selector)
            }

            guard method != nil else {
                Logger.error(message: "Could not find a method with that selector value")
                continue
            }
            let numArguments = method_getNumberOfArguments(method)
            guard (Int(numArguments) - 2) >= transformedArgs.count else {
                Logger.error(message: "Wrong number of arguments to invoke for selector")
                continue
            }
            if doesHaveNSValue {
                let implementation = method_getImplementation(method)
                retValue = extractAndRunMethodFromSelector(selector: selector,
                                                           implementation: implementation,
                                                           object: object,
                                                           args: transformedArgs)
            } else if !doesHaveNSNullValue {
                var unmanagedObject: Unmanaged<AnyObject>! = nil
                if transformedArgs.isEmpty {
                    unmanagedObject = object.perform(selector)
                } else if transformedArgs.count == 1 {
                    unmanagedObject = object.perform(selector, with: transformedArgs[0])
                } else if transformedArgs.count == 2 {
                    unmanagedObject = object.perform(selector, with: transformedArgs[0], with: transformedArgs[1])
                } else {
                    Logger.warn(message: "We do not support selectors that get more than 2 values")
                }

                if VariantAction.gettersForSetters.values.contains(selector) {
                    retValue = unmanagedObject?.takeUnretainedValue()
                }
            }
            targetRetValuePairs.append((object, retValue))
        }
        return targetRetValuePairs
    }

    class func extractAndRunMethodFromSelector(selector: Selector, implementation: IMP?, object: AnyObject, args: [Any]) -> AnyObject? {
        if selector.description == "setImage:forState:" {
            typealias Function = @convention(c) (AnyObject, Selector, UIImage, UIControlState) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, args[0] as! UIImage, UIControlState(rawValue: args[1] as! UInt))
        } else if selector.description == "imageForState:" {
            typealias Function = @convention(c) (AnyObject, Selector, UIControlState) -> Unmanaged<UIImage>
            let function = unsafeBitCast(implementation, to: Function.self)
            let val = function(object, #selector(UIButton.image(for:)), UIControlState(rawValue: args[0] as! UInt)).takeUnretainedValue()
            return val
        } else if selector.description == "setFrame:" {
            guard let nsValue = args[0] as? NSValue else {
                return nil
            }
            // This check is done to avoid moving and resizing UI components that you are not allowed to change.
            if object is UINavigationBar {
                return nil
            }
            (object as? UIView)?.translatesAutoresizingMaskIntoConstraints = true
            typealias Function = @convention(c) (AnyObject, Selector, CGRect) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, nsValue.cgRectValue)
        } else if selector.description == "setAlpha:" {
            typealias Function = @convention(c) (AnyObject, Selector, CGFloat) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, args[0] as! CGFloat)
        } else if selector.description == "setHidden:" {
            typealias Function = @convention(c) (AnyObject, Selector, Bool) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, args[0] as! Bool)
        } else if selector.description == "setUserInteractionEnabled:" {
            typealias Function = @convention(c) (AnyObject, Selector, Bool) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, args[0] as! Bool)
        } else if selector.description == "setBackgroundImage:forState:" {
            typealias Function = @convention(c) (AnyObject, Selector, UIImage, UIControlState) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, args[0] as! UIImage, UIControlState(rawValue: args[1] as! UInt))
        } else if selector.description == "setTextAlignment:" {
            typealias Function = @convention(c) (AnyObject, Selector, NSTextAlignment) -> Void
            let function = unsafeBitCast(implementation, to: Function.self)
            function(object, selector, NSTextAlignment(rawValue: args[0] as! Int)!)
        }
        return nil
    }

    func cacheOriginalImage(_ view: UIView?) {
        if let cacheSelector = VariantAction.gettersForSetters[selector] {
            guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                Logger.error(message: "No apparent root view controller, cannot cache image")
                return
            }
            var subsetArray = [Any]()
            if args.count > 1 {
                subsetArray = Array(args[1..<args.count])
            }
            let cachedPerformedSelectors = VariantAction.executeSelector(cacheSelector,
                                                                         args: subsetArray,
                                                                         path: path,
                                                                         root: rootVC,
                                                                         leaf: view)
            for performedSelector in cachedPerformedSelectors {
                guard let view = performedSelector.0 as? UIView else {
                    Logger.error(message: "Performing a selector didn't return a non-nil target")
                    continue
                }
                if VariantAction.originalCache.object(forKey: view) == nil {
                    if let image = performedSelector.1 as? UIImage {
                        VariantAction.originalCache.setObject(image, forKey: view)
                    }
                }
            }
        }
    }

    func restoreCachedImage() {
        for object in appliedTo.allObjects {
            if let originalImage = VariantAction.originalCache.object(forKey: object) {
                let originalArgs = args.map { arg -> Any in
                    if let arg = arg as? [AnyObject], let str = arg[1] as? String, str == "UIImage" {
                        return [originalImage, "UIImage"] as [Any]
                    }
                    return arg
                }
                VariantAction.executeSelector(selector, args: originalArgs, on: [object])
                VariantAction.originalCache.removeObject(forKey: object)
            }
        }
    }

    static func SwiftToObjectiveCConversion(_ value: AnyObject, type: String) -> NSObject? {
        if let value = value as? NSString, type == "NSString" {
            return value
        } else if let value = value as? NSValue {
            return value
        } else if let value = value as? UIImage, type == "UIImage" {
            return value
        }
        return nil
    }

    static func transformValue(_ value: AnyObject, to type: String) -> NSObject? {
        if let classType = NSClassFromString(type), type(of: value) == classType {
            return ValueTransformer(forName: NSValueTransformerName(rawValue: "IdentityTransformer"))?.transformedValue(value) as? NSObject
        }

        if let value = SwiftToObjectiveCConversion(value, type: type) {
            return value
        }

        var fromType: String? = nil
        if value is NSString {
            fromType = NSStringFromClass(NSString.self)
        } else if value is NSNumber {
            fromType = NSStringFromClass(NSNumber.self)
        } else if value is NSDictionary {
            fromType = NSStringFromClass(NSDictionary.self)
        } else if value is NSNull {
            fromType = NSStringFromClass(NSNull.self)
        }

        guard let fromTypeUnwrapped = fromType else {
            Logger.info(message: "Could not find a transformer for that 'from type'")
            return nil
        }

        let forwardTransformerName = "\(fromTypeUnwrapped)To\(type)"
        if let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: forwardTransformerName)) {
            return transformer.transformedValue(value) as? NSObject
        }

        let reverseTransformerName = "\(type)To\(fromTypeUnwrapped)"
        if let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: reverseTransformerName)) {
            return transformer.reverseTransformedValue(value) as? NSObject
        }

        return ValueTransformer(forName: NSValueTransformerName(rawValue: "IdentityTransformer"))?.transformedValue(value) as? NSObject
    }

}
