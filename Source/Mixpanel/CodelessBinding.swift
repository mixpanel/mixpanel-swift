//
//  CodelessBinding.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/22/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation


class CodelessBinding: NSObject, NSCoding {
    var name: String
    var path: ObjectSelector
    var eventName: String
    var swizzleClass: AnyClass!
    var running: Bool

    init(eventName: String, path: String) {
        self.eventName = eventName
        self.path = ObjectSelector(string: path)
        self.name = UUID().uuidString
        self.running = false
        self.swizzleClass = nil
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(forKey: "name") as? String,
            let path = aDecoder.decodeObject(forKey: "path") as? String,
            let eventName = aDecoder.decodeObject(forKey: "eventName") as? String,
            let swizzleString = aDecoder.decodeObject(forKey: "swizzleClass") as? String,
            let swizzleClass = NSClassFromString(swizzleString) else {
                return nil
        }

        self.eventName = eventName
        self.path = ObjectSelector(string: path)
        self.name = name
        self.running = false
        self.swizzleClass = swizzleClass
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(path.string, forKey: "path")
        aCoder.encode(eventName, forKey: "eventName")
        aCoder.encode(NSStringFromClass(swizzleClass), forKey: "swizzleClass")
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? CodelessBinding else {
            return false
        }

        if object === self {
            return true
        } else {
            return self.eventName == object.eventName && self.path == object.path
        }
    }

    override var hash: Int {
        return eventName.hash ^ path.hash
    }

    func execute() {}

    func stop() {}

    func track(event: String, properties: Properties) {
        var bindingProperties = properties
        bindingProperties["$from_binding"] = true
        Mixpanel.mainInstance().track(event: event, properties: bindingProperties)
    }



}
