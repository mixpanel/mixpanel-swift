//
//  ObjectSerializer.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/30/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ObjectSerializer {
    let configuration: ObjectSerializerConfig
    let objectIdentityProvider: ObjectIdentityProvider

    init(configuration: ObjectSerializerConfig, objectIdentityProvider: ObjectIdentityProvider) {
        self.configuration = configuration
        self.objectIdentityProvider = objectIdentityProvider
    }

    func getSerializedObjects(rootObject: AnyObject) -> [String: AnyObject] {
        let context = ObjectSerializerContext(object: rootObject)

        while context.hasUnvisitedObjects() {
            visitObject(context.dequeueUnvisitedObject(), context: context)
        }

        return ["objects": context.getAllSerializedObjects() as AnyObject,
                "rootObject": objectIdentityProvider.getIdentifier(object: rootObject) as AnyObject]
    }

    func visitObject(_ object: AnyObject?, context: ObjectSerializerContext) {
        guard var object = object else {
            return
        }

        context.addVisitedObject(object)

        var propertyValues = [String: AnyObject]()
        var delegate: AnyObject? = nil
        var delegateMethods = [AnyObject]()

        if let classDescription = getClassDescription(object: object) {
            for propertyDescription in classDescription.getAllPropertyDescriptions() {
                if propertyDescription.shouldReadPropertyValue(object: object), let name = propertyDescription.name {
                    let propertyValue = getPropertyValue(object: &object, propertyDescription: propertyDescription, context: context)
                    propertyValues[name] = propertyValue as AnyObject
                }
            }

            let delegateSelector: Selector = Selector("delegate")
            if !classDescription.delegateInfos.isEmpty && object.responds(to: delegateSelector) {
                let imp = object.method(for: delegateSelector)
                typealias MyCFunction = @convention(c) (AnyObject, Selector) -> AnyObject
                let curriedImplementation = unsafeBitCast(imp, to: MyCFunction.self)
                delegate = curriedImplementation(object, delegateSelector)
                for delegateInfo in classDescription.delegateInfos {
                    if let selectorName = delegateInfo.selectorName,
                       let respondsToDelegate = delegate?.responds(to: NSSelectorFromString(selectorName)), respondsToDelegate {
                        delegateMethods.append(selectorName as AnyObject)
                    }
                }
            }
        }

        let serializedObject = ["id": objectIdentityProvider.getIdentifier(object: object),
                                "class": getClassHierarchyArray(object: object),
                                "properties": propertyValues,
                                "delegate": ["class": delegate != nil ? NSStringFromClass(type(of: delegate!)) : "",
                                             "selectors": delegateMethods]
                               ] as [String : Any]

        context.addSerializedObject(serializedObject)
    }

    func getClassHierarchyArray(object: AnyObject) -> [String] {
        var classHierarchy = [String]()
        var aClass: AnyClass? = type(of: object)
        while aClass != nil {
            classHierarchy.append(NSStringFromClass(aClass!))
            aClass = aClass?.superclass()
        }
        return classHierarchy
    }

    func getAllValues(typeName: String) -> [Any] {
        let typeDescription = configuration.getType(name: typeName)
        if let enumDescription = typeDescription as? EnumDescription {
            return enumDescription.getAllValues()
        }
        return []
    }

    func getParameterVariations(propertySelectorDescription: PropertySelectorDescription) -> [Any] {
        var variations = [Any]()
        if let parameterDescription = propertySelectorDescription.parameters.first, let typeName = parameterDescription.type {
            variations = getAllValues(typeName: typeName)
        } else {
            // An empty array of parameters (for methods that have no parameters).
            variations.append([])
        }
        return variations
    }

    func getInstanceVariableValue(object: inout AnyObject, propertyDescription: PropertyDescription) -> Any? {
        if let propertyDescName = propertyDescription.name,
            let ivar = class_getInstanceVariable(type(of: object), propertyDescName) {
            let objCType = String(cString: ivar_getTypeEncoding(ivar))
            let ivarOffset = ivar_getOffset(ivar)
            let objectBaseAddress = withUnsafePointer(to: &object) {
                return $0
            }
            let ivarAddress = objectBaseAddress + ivarOffset

            switch objCType {
            case "@": return object_getIvar(object, ivar)
            case "c": return ivarAddress
            case "C": return ivarAddress
            case "s": return ivarAddress
            case "S": return ivarAddress
            case "i": return ivarAddress
            case "I": return ivarAddress
            case "l": return ivarAddress
            case "L": return ivarAddress
            case "q": return ivarAddress
            case "Q": return ivarAddress
            case "f": return ivarAddress
            case "d": return ivarAddress
            case "B": return ivarAddress
            case ":": return ivarAddress
            default: return nil
            }
        }
        return nil
    }

   // func getInvocation(object: AnyObject, selectorDescription: PropertySelectorDescription) -> NSInvocation {
   // }

    func getTransformedValue(propertyValue: Any?, propertyDescription: PropertyDescription, context: ObjectSerializerContext) -> Any? {
        if let propertyValue = propertyValue {
            if context.hasVisitedObject(propertyValue as AnyObject) {
                return objectIdentityProvider.getIdentifier(object: propertyValue as AnyObject)
            } else if isNestedObject(typeName: propertyDescription.type!) {
                context.enqueueUnvisitedObject(object: propertyValue as AnyObject)
                return objectIdentityProvider.getIdentifier(object: propertyValue as AnyObject)
            } else if propertyValue is [AnyObject] || propertyValue is Set<NSObject> {
                var arrayOfIdentifiers = [Any]()
                var values = propertyValue as? [AnyObject]
                if let propertyValue = propertyValue as? Set<NSObject> {
                    values = Array(propertyValue)
                }
                for value in values! {
                    if !context.hasVisitedObject(value) {
                        context.enqueueUnvisitedObject(object: value)
                    }
                    arrayOfIdentifiers.append(objectIdentityProvider.getIdentifier(object: value as AnyObject))
                }
                print(arrayOfIdentifiers)
                return propertyDescription.getValueTransformer()!.transformedValue(arrayOfIdentifiers)
            }
        }
        print(propertyValue)
        return propertyDescription.getValueTransformer()!.transformedValue(propertyValue)
    }

    func getPropertyValue(object: inout AnyObject, propertyDescription: PropertyDescription, context: ObjectSerializerContext) -> Any {
        var values = [Any]()
        let selectorDescription = propertyDescription.getSelectorDescription
        if propertyDescription.useKeyValueCoding {
            // the "fast" path is to use KVC
            let valueForKey = object.value(forKey: selectorDescription.selectorName!)
            if let value = getTransformedValue(propertyValue: valueForKey, propertyDescription: propertyDescription, context: context) {
                print("type of transformed Value: \(type(of: value))")
                do {
                    let data = try JSONSerialization.data(withJSONObject: ["value": value])
                } catch {

                }
                values.append(["value": value])
            }
        } else if let useInstanceVariableAccess = propertyDescription.useInstanceVariableAccess, useInstanceVariableAccess {
            let valueForIvar = getInstanceVariableValue(object: &object, propertyDescription: propertyDescription)
            if let value = getTransformedValue(propertyValue: valueForIvar, propertyDescription: propertyDescription, context: context) {
                print("type of transformed Value: \(type(of: value))")
                do {
                    let data = try JSONSerialization.data(withJSONObject: ["value": value])
                } catch {

                }
                values.append(["value": value])
            }
        } else {
            // the "slow" NSInvocation path. Required in order to invoke methods that take parameters.
        }

        return ["values": values]
    }

    func isNestedObject(typeName: String) -> Bool {
        return configuration.classes[typeName] != nil
    }

    func getClassDescription(object: AnyObject) -> ClassDescription? {
        var aClass: AnyClass? = type(of: object)
        while aClass != nil {
            if let classDescription = configuration.classes[NSStringFromClass(aClass!)] {
                return classDescription
            }
            aClass = aClass?.superclass()
        }
        return nil
    }


}
