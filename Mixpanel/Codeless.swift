//
//  Codeless.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/25/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class Codeless {

    var codelessBindings = Set<CodelessBinding>()

    enum BindingType: String {
        case controlBinding = "ui_control"
        case tableViewBinding = "ui_table_view"
    }

    class func createBinding(object: [String: Any]) -> CodelessBinding? {
        guard let bindingType = object["event_type"] as? String,
              let bindingTypeEnum = BindingType.init(rawValue: bindingType) else {
            return UIControlBinding(object: object)
        }

        switch bindingTypeEnum {
        case .controlBinding:
            return UIControlBinding(object: object)
        case .tableViewBinding:
            return UITableViewBinding(object: object)
        }
    }

}
