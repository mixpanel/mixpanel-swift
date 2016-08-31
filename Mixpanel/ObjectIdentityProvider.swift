//
//  ObjectIdentityProvider.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/29/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ObjectIdentityProvider {
    let objectToIdentifierMap: NSMapTable<AnyObject, NSString>

    init() {
        objectToIdentifierMap = NSMapTable(keyOptions: .weakMemory, valueOptions: .strongMemory)
    }

    func getIdentifier(object: AnyObject) -> String {
        if let object = object as? String {
            return object
        }
        if let identifier = objectToIdentifierMap.object(forKey: object) {
            return identifier as String
        } else {
            return UUID().uuidString
        }
    }

}
