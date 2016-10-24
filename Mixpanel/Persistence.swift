//
//  Persistence.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct ArchivedProperties {
    let superProperties: InternalProperties
    let timedEvents: InternalProperties
    let distinctId: String
    let peopleDistinctId: String?
    let peopleUnidentifiedQueue: Queue
    let shownNotifications: Set<Int>
}

class Persistence {

    enum ArchiveType: String {
        case events
        case people
        case properties
        case codelessBindings
        case variants
    }

    class func filePathWithType(_ type: ArchiveType, token: String) -> String? {
        return filePathFor(type.rawValue, token: token)
    }

    class private func filePathFor(_ archiveType: String, token: String) -> String? {
        let filename = "mixpanel-\(token)-\(archiveType)"
        let manager = FileManager.default

        #if os(iOS)
            let url = manager.urls(for: .libraryDirectory, in: .userDomainMask).last
        #else
            let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).last
        #endif

        guard let urlUnwrapped = url?.appendingPathComponent(filename).path else {
            return nil
        }

        return urlUnwrapped
    }

    class func archive(eventsQueue: Queue,
                       peopleQueue: Queue,
                       properties: ArchivedProperties,
                       codelessBindings: Set<CodelessBinding>,
                       variants: Set<Variant>,
                       token: String) {
        archiveEvents(eventsQueue, token: token)
        archivePeople(peopleQueue, token: token)
        archiveProperties(properties, token: token)
        archiveVariants(variants, token: token)
        archiveCodelessBindings(codelessBindings, token: token)
    }

    class func archiveEvents(_ eventsQueue: Queue, token: String) {
        archiveToFile(.events, object: eventsQueue, token: token)
    }

    class func archivePeople(_ peopleQueue: Queue, token: String) {
        archiveToFile(.people, object: peopleQueue, token: token)
    }

    class func archiveProperties(_ properties: ArchivedProperties, token: String) {
        var p = InternalProperties()
        p["distinctId"] = properties.distinctId
        p["superProperties"] = properties.superProperties
        p["peopleDistinctId"] = properties.peopleDistinctId
        p["peopleUnidentifiedQueue"] = properties.peopleUnidentifiedQueue
        p["timedEvents"] = properties.timedEvents
        p["shownNotifications"] = properties.shownNotifications
        archiveToFile(.properties, object: p, token: token)
    }

    class func archiveVariants(_ variants: Set<Variant>, token: String) {
        archiveToFile(.variants, object: variants, token: token)
    }

    class func archiveCodelessBindings(_ codelessBindings: Set<CodelessBinding>, token: String) {
        archiveToFile(.codelessBindings, object: codelessBindings, token: token)
    }

    class private func archiveToFile(_ type: ArchiveType, object: Any, token: String) {
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
                                            superProperties: InternalProperties,
                                            timedEvents: InternalProperties,
                                            distinctId: String,
                                            peopleDistinctId: String?,
                                            peopleUnidentifiedQueue: Queue,
                                            shownNotifications: Set<Int>,
                                            codelessBindings: Set<CodelessBinding>,
                                            variants: Set<Variant>) {

        let eventsQueue = unarchiveEvents(token: token)
        let peopleQueue = unarchivePeople(token: token)
        let codelessBindings = unarchiveCodelessBindings(token: token)
        let variants = unarchiveVariants(token: token)

        let (superProperties,
            timedEvents,
            distinctId,
            peopleDistinctId,
            peopleUnidentifiedQueue,
            shownNotifications) = unarchiveProperties(token: token)

        return (eventsQueue,
                peopleQueue,
                superProperties,
                timedEvents,
                distinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                shownNotifications,
                codelessBindings,
                variants)
    }

    class private func unarchiveWithFilePath(_ filePath: String) -> Any? {
        let unarchivedData: Any? = NSKeyedUnarchiver.unarchiveObject(withFile: filePath)
        if unarchivedData == nil {
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch {
                Logger.info(message: "Unable to remove file at path: \(filePath)")
            }
        }

        return unarchivedData
    }

    class private func unarchiveEvents(token: String) -> Queue {
        let data = unarchiveWithType(.events, token: token)
        return data as? Queue ?? []
    }

    class private func unarchivePeople(token: String) -> Queue {
        let data = unarchiveWithType(.people, token: token)
        return data as? Queue ?? []
    }

    class private func unarchiveProperties(token: String) -> (InternalProperties, InternalProperties, String, String?, Queue, Set<Int>) {
        let properties = unarchiveWithType(.properties, token: token) as? InternalProperties
        let superProperties =
            properties?["superProperties"] as? InternalProperties ?? InternalProperties()
        let timedEvents =
            properties?["timedEvents"] as? InternalProperties ?? InternalProperties()
        let distinctId =
            properties?["distinctId"] as? String ?? ""
        let peopleDistinctId =
            properties?["peopleDistinctId"] as? String ?? nil
        let peopleUnidentifiedQueue =
            properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()
        let shownNotifications =
            properties?["shownNotifications"] as? Set<Int> ?? Set<Int>()

        return (superProperties,
                timedEvents,
                distinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                shownNotifications)
    }

    class private func unarchiveCodelessBindings(token: String) -> Set<CodelessBinding> {
        let data = unarchiveWithType(.codelessBindings, token: token)
        return data as? Set<CodelessBinding> ?? Set()
    }

    class private func unarchiveVariants(token: String) -> Set<Variant> {
        let data = unarchiveWithType(.variants, token: token) as? Set<Variant>
        return data ?? Set()
    }

    class private func unarchiveWithType(_ type: ArchiveType, token: String) -> Any? {
        let filePath = filePathWithType(type, token: token)
        guard let path = filePath else {
            Logger.info(message: "bad file path, cant fetch file")
            return nil
        }

        guard let unarchivedData = unarchiveWithFilePath(path) else {
            Logger.info(message: "can't unarchive file")
            return nil
        }

        return unarchivedData
    }

}
