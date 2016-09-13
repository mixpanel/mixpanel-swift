//
//  Persistence.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct ArchivedProperties {
    let superProperties: Properties
    let timedEvents: Properties
    let distinctId: String
    let peopleDistinctId: String?
    let peopleUnidentifiedQueue: Queue
}

class Persistence {

    enum ArchiveType: String {
        case Events
        case People
        case Properties
    }

    class func filePathWithType(_ type: ArchiveType, token: String) -> String? {
        return filePathFor(type.rawValue, token: token)
    }

    class fileprivate func filePathFor(_ archiveType: String, token: String) -> String? {
        let filename = "mixpanel-\(token)-\(archiveType)"
        let manager = FileManager.default
        let url = manager.urls(for: FileManager.SearchPathDirectory.libraryDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last

        guard let urlUnwrapped = url?.appendingPathComponent(filename).path else {
            return nil
        }

        return urlUnwrapped
    }

    class func archive(_ eventsQueue: Queue,
                       peopleQueue: Queue,
                       properties: ArchivedProperties,
                       token: String) {
        archiveEvents(eventsQueue, token: token)
        archivePeople(peopleQueue, token: token)
        archiveProperties(properties, token: token)
    }

    class func archiveEvents(_ eventsQueue: Queue, token: String) {
        archiveToFile(.Events, object: eventsQueue, token: token)
    }

    class func archivePeople(_ peopleQueue: Queue, token: String) {
        archiveToFile(.People, object: peopleQueue, token: token)
    }

    class func archiveProperties(_ properties: ArchivedProperties, token: String) {
        var p: Properties = Properties()
        p["distinctId"] = properties.distinctId
        p["superProperties"] = properties.superProperties
        p["peopleDistinctId"] = properties.peopleDistinctId
        p["peopleUnidentifiedQueue"] = properties.peopleUnidentifiedQueue
        p["timedEvents"] = properties.timedEvents
        archiveToFile(.Properties, object: p, token: token)
    }

    class func archiveToFile(_ type: ArchiveType, object: Any, token: String) {
        let filePath = filePathWithType(type, token: token)
        guard let path = filePath else {
            Logger.error(message: "bad file path, cant fetch file")
            return
        }

        if !NSKeyedArchiver.archiveRootObject(object, toFile: path) {
            Logger.error(message: "failed to archive \(type.rawValue)")
        }

    }

    class func unarchive(token: String) -> (eventsQueue: Queue,
        peopleQueue: Queue,
        superProperties: Properties,
        timedEvents: Properties,
        distinctId: String,
        peopleDistinctId: String?,
        peopleUnidentifiedQueue: Queue) {
        let eventsQueue = unarchiveEvents(token: token)
        let peopleQueue = unarchivePeople(token: token)

        let (superProperties,
            timedEvents,
            distinctId,
            peopleDistinctId,
            peopleUnidentifiedQueue) = unarchiveProperties(token: token)

        return (eventsQueue,
                peopleQueue,
                superProperties,
                timedEvents,
                distinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue)
    }

    class fileprivate func unarchiveWithFilePath(_ filePath: String) -> Any? {
        let unarchivedData: Any? = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as Any?
        if unarchivedData == nil {
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch {
                Logger.info("unable to remove file")
            }
        }

        return unarchivedData
    }

    class fileprivate func unarchiveEvents(token: String) -> Queue {
        return unarchiveWithType(.Events, token: token) as? Queue ?? []
    }

    class fileprivate func unarchivePeople(token: String) -> Queue {
        return unarchiveWithType(.People, token: token) as? Queue ?? []
    }

    class fileprivate func unarchiveProperties(token: String) -> (Properties, Properties, String, String?, Queue) {
        let properties = unarchiveWithType(.Properties, token: token) as? Properties
        let superProperties =
            properties?["superProperties"] as? Properties ?? Properties()
        let timedEvents =
            properties?["timedEvents"] as? Properties ?? Properties()
        let distinctId =
            properties?["distinctId"] as? String ?? ""
        let peopleDistinctId =
            properties?["peopleDistinctId"] as? String ?? nil
        let peopleUnidentifiedQueue =
            properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()

        return (superProperties,
                timedEvents,
                distinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue)
    }

    class fileprivate func unarchiveWithType(_ type: ArchiveType, token: String) -> Any? {
        let filePath = filePathWithType(type, token: token)
        guard let path = filePath else {
            Logger.info("bad file path, cant fetch file")
            return nil
        }

        guard let unarchivedData = unarchiveWithFilePath(path) else {
            Logger.info("can't unarchive file")
            return nil
        }

        return unarchivedData
    }

}
