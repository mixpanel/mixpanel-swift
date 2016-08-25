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
    var path: Any
    var eventName: String
    //let swizzleClass: Any
    var running: Bool

    enum BindingType: String {
        case controlBinding = "ui_control"
        case tableViewBinding = "ui_table_view"
    }


   // convenience init(object: [String: Any]) {
   //     if let bindingType = object["event_type"] as? String {
   //         return subclassFromString(bindingType: bindingType)
   //     }

   // }

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
        self.path = path
        self.name = UUID().uuidString
        self.running = false
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        self.path = aDecoder.decodeObject(forKey: "path")
        self.eventName = aDecoder.decodeObject(forKey: "eventName") as! String
        self.running = false
        self.name = aDecoder.decodeObject(forKey: "name") as! String
        //self.swizzleClass =
    }

    func encode(with aCoder: NSCoder) {

    }



}
