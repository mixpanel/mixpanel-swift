//
//  ObjectSerializerConfig.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

extension Bool {
    init?<T: Integer>(_ integer: T?) {
        guard let integer = integer else {
            return nil
        }
        if integer == 0 {
            self.init(false)
        } else {
            self.init(true)
        }
    }
}

class ObjectSerializerConfig {
    var classes: [String: ClassDescription]
    var enums: [String: EnumDescription]

    init(dict: [String: Any]) {
        classes = [String: ClassDescription]()
        if let classDescs = dict["classes"] as? [[String: Any]] {
            for classDesc in classDescs {
                var superclassDescription: ClassDescription? = nil
                if let superclassName = classDesc["superclass"] as? String, let superclassDesc = classes[superclassName] {
                    superclassDescription = superclassDesc
                }
                let classDescription = ClassDescription(dict: classDesc, superclassDescription: superclassDescription)
                if let key = classDescription.name {
                    classes[key] = classDescription
                }
            }
        }

        enums = [String: EnumDescription]()
        if let enumDescs = dict["enums"] as? [[String: Any]] {
            for enumDesc in enumDescs {
                let enumDescription = EnumDescription(dict: enumDesc)
                if let key = enumDescription.name {
                    enums[key] = enumDescription
                }
            }
        }
    }

    func getType(_ name: String) -> TypeDescription? {
        if let enumDescription = enums[name] {
            return enumDescription
        }

        if let classDescription = classes[name] {
            return classDescription
        }

        return nil
    }
}

class TypeDescription {
    let name: String?

    init(dict: [String: Any]) {
        name = dict["name"] as? String
    }
}

class EnumDescription: TypeDescription {
    let flagSet: Bool?
    let baseType: String?
    var values: [Int: Any]

    override init(dict: [String: Any]) {
        flagSet = dict["flag_set"] as? Bool
        baseType = dict["base_type"] as? String
        values = [Int: Any]()

        if let dictValues = dict["values"] as? [[String: Any]] {
            for value in dictValues {
                if let key = value["value"] as? Int {
                    values[key] = value["display_name"]
                }
            }
        }

        super.init(dict: dict)
    }

    func getAllValues() -> [Any] {
        return Array(values.keys)
    }
}

class ClassDescription: TypeDescription {
    let superclassDescription: ClassDescription?
    var propertyDescriptions: [PropertyDescription]
    var delegateInfos: [DelegateInfo]

    init(dict: [String: Any], superclassDescription: ClassDescription?) {
        self.superclassDescription = superclassDescription
        propertyDescriptions = [PropertyDescription]()
        if let propertyDescs = dict["properties"] as? [[String: Any]] {
            for propertyDesc in propertyDescs {
                propertyDescriptions.append(PropertyDescription(dict: propertyDesc))
            }
        }

        delegateInfos = [DelegateInfo]()
        if let delegateDictInfos = dict["delegateImplements"] as? [[String: Any]] {
            for delegateDictInfo in delegateDictInfos {
                delegateInfos.append(DelegateInfo(dict: delegateDictInfo))
            }
        }

        super.init(dict: dict)
    }

    func getAllPropertyDescriptions() -> [PropertyDescription] {
        var allPropertyDescriptions = [String: PropertyDescription]()
        var description: ClassDescription? = self
        while let desc = description {
            for propertyDescription in desc.propertyDescriptions {
                if let key = propertyDescription.name {
                    if allPropertyDescriptions[key] == nil {
                        allPropertyDescriptions[key] = propertyDescription
                    }
                }
            }
            description = desc.superclassDescription
        }
        return Array(allPropertyDescriptions.values)
    }
}

class DelegateInfo {
    let selectorName: String?

    init(dict: [String: Any]) {
        selectorName = dict["selector"] as? String
    }
}

class PropertyDescription {
    var type: String? {
        get {
            return getSelectorDescription.returnType
        }
    }
    let readOnly: Bool?
    let noFollow: Bool?
    let useKeyValueCoding: Bool
    let name: String?
    let getSelectorDescription: PropertySelectorDescription
    let setSelectorDescription: PropertySelectorDescription?
    let predicate: NSPredicate?

    init(dict: [String: Any]) {
        let name = dict["name"] as? String
        readOnly = Bool(dict["readonly"] as? Int)
        noFollow = Bool(dict["nofollow"] as? Int)

        var predicate: NSPredicate? = nil
        if let predicateFormat = dict["predicate"] as? String {
            predicate = NSPredicate(format: predicateFormat)
        }

        let getDict = dict["get"] as? [String: Any] ?? ["selector": name ?? "",
                                                        "result": ["type": dict["type"],
                                                                   "name": "value"],
                                                        "parameters": []]
        let getSelectorDescription = PropertySelectorDescription(dict: getDict)

        var setDict = dict["set"] as? [String: Any]
        let capitalizedName = name != nil ? name!.capitalized : ""
        if let readOnly = readOnly, !readOnly, setDict == nil {
            setDict = ["selector": "set\(capitalizedName):",
                       "parameters": [["name": "value",
                                       "type": dict["type"]]]]
        }

        var setSelectorDescription: PropertySelectorDescription? = nil
        if let setDict = setDict {
            setSelectorDescription = PropertySelectorDescription(dict: setDict)
        }

        var useKVC = true
        if let useKVCBool = Bool(dict["use_kvc"] as? Int) {
            useKVC = useKVCBool
        }

        useKeyValueCoding = useKVC && getSelectorDescription.parameters.isEmpty &&
            (setSelectorDescription == nil || setSelectorDescription!.parameters.count == 1)

        self.name = name
        self.getSelectorDescription = getSelectorDescription
        self.setSelectorDescription = setSelectorDescription
        self.predicate = predicate
    }

    class func valueTransformer(for typeName: String) -> ValueTransformer? {
        for toTypeName in ["NSDictionary", "NSNumber", "NSString"] {
            let toTransformerName = NSValueTransformerName(rawValue: "\(typeName)To\(toTypeName)")
            if let toTransformer = ValueTransformer(forName: toTransformerName) {
                return toTransformer
            }
        }
        let valueTransformerName = NSValueTransformerName("IdentityTransformer")
        return ValueTransformer(forName: valueTransformerName)
    }

    func getValueTransformer() -> ValueTransformer? {
        guard let type = type else {
            return nil
        }
        let transformedValue = PropertyDescription.valueTransformer(for: type)
        return transformedValue
    }

    func shouldReadPropertyValue(of object: AnyObject) -> Bool {
        if let noFollow = noFollow, noFollow {
            return false
        } else if let predicate = predicate {
            return predicate.evaluate(with: object)
        }
        return true
    }
}

class PropertySelectorDescription {
    let selectorName: String?
    let returnType: String?
    var parameters: [PropertySelectorParameterDescription]

    init(dict: [String: Any]) {
        selectorName = dict["selector"] as? String
        returnType = (dict["result"] as? [String: String])?["type"]
        parameters = [PropertySelectorParameterDescription]()

        if let params = dict["parameters"] as? [[String: Any]] {
            for param in params {
                parameters.append(PropertySelectorParameterDescription(dict: param))
            }
        }
    }
}

class PropertySelectorParameterDescription {
    let name: String?
    let type: String?

    init(dict: [String: Any]) {
        name = dict["name"] as? String
        type = dict["type"] as? String
    }
}
