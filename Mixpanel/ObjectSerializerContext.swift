//
//  ObjectSerializerContext.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/30/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ObjectSerializerContext {
    var visitedObjects: Set<AnyHashable>
    var unvisitedObjects: Set<AnyHashable>
    var serializedObjects: [String: AnyObject]

    init(object: AnyObject) {
        visitedObjects = Set()
        unvisitedObjects = Set()
        unvisitedObjects.insert(object as! AnyHashable)
        serializedObjects = [:]
    }

    func hasUnvisitedObjects() -> Bool {
        return !unvisitedObjects.isEmpty
    }

    func enqueueUnvisitedObject(_ object: AnyObject) {
        unvisitedObjects.insert(object as! AnyHashable)
    }

    func dequeueUnvisitedObject() -> AnyObject? {
        return unvisitedObjects.removeFirst() as AnyObject
    }

    func addVisitedObject(_ object: AnyObject) {
        visitedObjects.insert(object as! AnyHashable)
    }

    func hasVisitedObject(_ object: AnyObject) -> Bool {
        return visitedObjects.contains(object as! AnyHashable)
    }

    func addSerializedObject(_ serializedObject: [String: Any]) {
        serializedObjects[serializedObject["id"] as! String] = serializedObject as AnyObject
    }

    func getAllSerializedObjects() -> [AnyObject] {
        return Array(serializedObjects.values)
    }
}
