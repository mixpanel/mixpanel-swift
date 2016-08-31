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
    //let swizzleClass: Any
    var running: Bool

    //convenience init(object: [String: Any]) {
    //    if let bindingType = object["event_type"] as? String {
    //        return subclassFromString(bindingType: bindingType)
    //    }
    //}

   // func subclassFromString(bindingType: String) -> CodelessBinding {
   //     if let bindingTypeEnum = BindingType.init(rawValue: bindingType) {
   //         switch bindingTypeEnum {
   //         case .controlBinding:
   //             return UIControlBinding()
   //         case .tableViewBinding:
   //             return UITableViewBinding()
   //         default: break
    //        }
   //     }
   //     return UIControlBinding()
   // }

    init(eventName: String, path: String) {
        self.eventName = eventName
        self.path = ObjectSelector(string: path)
        self.name = UUID().uuidString
        self.running = false
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(forKey: "name") as? String,
            let path = aDecoder.decodeObject(forKey: "path") as? String,
            let eventName = aDecoder.decodeObject(forKey: "eventName") as? String else {
                return nil
        }
        
        self.eventName = eventName
        self.path = ObjectSelector(string: path)
        self.name = name
        self.running = false
        //self.swizzleClass =
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(path.string, forKey: "path")
        aCoder.encode(eventName, forKey: "eventName")
        //aCoder.encode(swizzleClass, forKey: "swizzleClass")
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



}
