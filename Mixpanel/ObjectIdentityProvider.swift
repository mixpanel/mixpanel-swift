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
    let sequenceGenerator = SequenceGenerator()

    init() {
        objectToIdentifierMap = NSMapTable(keyOptions: .weakMemory, valueOptions: .strongMemory)
    }

    func getIdentifier(for object: AnyObject) -> String {
        if let object = object as? String {
            return object
        }
        if let identifier = objectToIdentifierMap.object(forKey: object) {
            return identifier as String
        } else {
            let identifier = "$\(sequenceGenerator.next())" as NSString
            objectToIdentifierMap.setObject(identifier, forKey: object)
            return identifier as String
        }
    }

}

class SequenceGenerator {
    var value: Int32 = 0

    init() {
        value = 0
    }

    func next() -> Int32 {
        return OSAtomicAdd32(1, &value)
    }
}
