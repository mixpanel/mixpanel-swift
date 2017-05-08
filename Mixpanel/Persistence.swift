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
    let alias: String?
    let peopleDistinctId: String?
    let peopleUnidentifiedQueue: Queue
    #if DECIDE
    let shownNotifications: Set<Int>
    let automaticEventsEnabled: Bool?
    #endif // DECIDE
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
        #endif // os(iOS)

        guard let urlUnwrapped = url?.appendingPathComponent(filename).path else {
            return nil
        }

        return urlUnwrapped
    }

    #if DECIDE
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
    #else
    class func archive(eventsQueue: Queue,
                       peopleQueue: Queue,
                       properties: ArchivedProperties,
                       token: String) {
        archiveEvents(eventsQueue, token: token)
        archivePeople(peopleQueue, token: token)
        archiveProperties(properties, token: token)
    }
    #endif // DECIDE

    class func archiveEvents(_ eventsQueue: Queue, token: String) {
        archiveToFile(.events, object: eventsQueue, token: token)
    }

    class func archivePeople(_ peopleQueue: Queue, token: String) {
        archiveToFile(.people, object: peopleQueue, token: token)
    }

    class func archiveProperties(_ properties: ArchivedProperties, token: String) {
        var p = InternalProperties()
        p["distinctId"] = properties.distinctId
        p["alias"] = properties.alias
        p["superProperties"] = properties.superProperties
        p["peopleDistinctId"] = properties.peopleDistinctId
        p["peopleUnidentifiedQueue"] = properties.peopleUnidentifiedQueue
        p["timedEvents"] = properties.timedEvents
        #if DECIDE
        p["shownNotifications"] = properties.shownNotifications
        p["automaticEvents"] = properties.automaticEventsEnabled
        #endif // DECIDE
        archiveToFile(.properties, object: p, token: token)
    }

    #if DECIDE
    class func archiveVariants(_ variants: Set<Variant>, token: String) {
        archiveToFile(.variants, object: variants, token: token)
    }

    class func archiveCodelessBindings(_ codelessBindings: Set<CodelessBinding>, token: String) {
        archiveToFile(.codelessBindings, object: codelessBindings, token: token)
    }
    #endif // DECIDE

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

    #if DECIDE
    class func unarchive(token: String) -> (eventsQueue: Queue,
                                            peopleQueue: Queue,
                                            superProperties: InternalProperties,
                                            timedEvents: InternalProperties,
                                            distinctId: String,
                                            alias: String?,
                                            peopleDistinctId: String?,
                                            peopleUnidentifiedQueue: Queue,
                                            shownNotifications: Set<Int>,
                                            codelessBindings: Set<CodelessBinding>,
                                            variants: Set<Variant>,
                                            automaticEventsEnabled: Bool?) {
        let eventsQueue = unarchiveEvents(token: token)
        let peopleQueue = unarchivePeople(token: token)
        let codelessBindings = unarchiveCodelessBindings(token: token)
        let variants = unarchiveVariants(token: token)

        let (superProperties,
            timedEvents,
            distinctId,
            alias,
            peopleDistinctId,
            peopleUnidentifiedQueue,
            shownNotifications,
            automaticEventsEnabled) = unarchiveProperties(token: token)

        return (eventsQueue,
                peopleQueue,
                superProperties,
                timedEvents,
                distinctId,
                alias,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                shownNotifications,
                codelessBindings,
                variants,
                automaticEventsEnabled)
    }
    #else
    class func unarchive(token: String) -> (eventsQueue: Queue,
                                            peopleQueue: Queue,
                                            superProperties: InternalProperties,
                                            timedEvents: InternalProperties,
                                            distinctId: String,
                                            alias: String?,
                                            peopleDistinctId: String?,
                                            peopleUnidentifiedQueue: Queue) {
            let eventsQueue = unarchiveEvents(token: token)
            let peopleQueue = unarchivePeople(token: token)

            let (superProperties,
                timedEvents,
                distinctId,
                alias,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                _) = unarchiveProperties(token: token)

            return (eventsQueue,
                    peopleQueue,
                    superProperties,
                    timedEvents,
                    distinctId,
                    alias,
                    peopleDistinctId,
                    peopleUnidentifiedQueue)
    }
    #endif // DECIDE

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

    #if DECIDE
    class private func unarchiveProperties(token: String) -> (InternalProperties,
                                                              InternalProperties,
                                                              String,
                                                              String?,
                                                              String?,
                                                              Queue,
                                                              Set<Int>,
                                                              Bool?) {
        let properties = unarchiveWithType(.properties, token: token) as? InternalProperties
        let (superProperties,
             timedEvents,
             distinctId,
             alias,
             peopleDistinctId,
             peopleUnidentifiedQueue,
             automaticEventsEnabled) = unarchivePropertiesHelper(token: token)
        let shownNotifications =
            properties?["shownNotifications"] as? Set<Int> ?? Set<Int>()

        return (superProperties,
                timedEvents,
                distinctId,
                alias,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                shownNotifications,
                automaticEventsEnabled)
    }
    #else
    class private func unarchiveProperties(token: String) -> (InternalProperties,
        InternalProperties,
        String,
        String?,
        String?,
        Queue,
        Bool?) {
        return unarchivePropertiesHelper(token: token)
    }
    #endif // DECIDE

    class private func unarchivePropertiesHelper(token: String) -> (InternalProperties,
        InternalProperties,
        String,
        String?,
        String?,
        Queue,
        Bool?) {
            let properties = unarchiveWithType(.properties, token: token) as? InternalProperties
            let superProperties =
                properties?["superProperties"] as? InternalProperties ?? InternalProperties()
            let timedEvents =
                properties?["timedEvents"] as? InternalProperties ?? InternalProperties()
            let distinctId =
                properties?["distinctId"] as? String ?? ""
            let alias =
                properties?["alias"] as? String ?? nil
            let peopleDistinctId =
                properties?["peopleDistinctId"] as? String ?? nil
            let peopleUnidentifiedQueue =
                properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()
            let automaticEventsEnabled =
                properties?["automaticEvents"] as? Bool ?? nil
            return (superProperties,
                    timedEvents,
                    distinctId,
                    alias,
                    peopleDistinctId,
                    peopleUnidentifiedQueue,
                    automaticEventsEnabled)
    }

    #if DECIDE
    class private func unarchiveCodelessBindings(token: String) -> Set<CodelessBinding> {
        let data = unarchiveWithType(.codelessBindings, token: token)
        return data as? Set<CodelessBinding> ?? Set()
    }

    class private func unarchiveVariants(token: String) -> Set<Variant> {
        let data = unarchiveWithType(.variants, token: token) as? Set<Variant>
        return data ?? Set()
    }
    #endif // DECIDE

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
