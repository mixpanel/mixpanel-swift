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
    let anonymousId: String?
    let userId: String?
    let alias: String?
    let hadPersistedDistinctId: Bool?
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
        case groups
        case properties
        case codelessBindings
        case variants
        case optOutStatus
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
                       groupsQueue: Queue,
                       properties: ArchivedProperties,
                       codelessBindings: Set<CodelessBinding>,
                       variants: Set<Variant>,
                       token: String) {
        archiveEvents(eventsQueue, token: token)
        archivePeople(peopleQueue, token: token)
        archiveGroups(groupsQueue, token: token)
        archiveProperties(properties, token: token)
        archiveVariants(variants, token: token)
        archiveCodelessBindings(codelessBindings, token: token)
    }
    #else
    class func archive(eventsQueue: Queue,
                       peopleQueue: Queue,
                       groupsQueue: Queue,
                       properties: ArchivedProperties,
                       token: String) {
        archiveEvents(eventsQueue, token: token)
        archivePeople(peopleQueue, token: token)
        archiveGroups(groupsQueue, token: token)
        archiveProperties(properties, token: token)
    }
    #endif // DECIDE

    class func archiveEvents(_ eventsQueue: Queue, token: String) {
        objc_sync_enter(self)
        archiveToFile(.events, object: eventsQueue, token: token)
        objc_sync_exit(self)
    }

    class func archivePeople(_ peopleQueue: Queue, token: String) {
        objc_sync_enter(self)
        archiveToFile(.people, object: peopleQueue, token: token)
        objc_sync_exit(self)
    }

    class func archiveGroups(_ groupsQueue: Queue, token: String) {
        objc_sync_enter(self)
        archiveToFile(.groups, object: groupsQueue, token: token)
        objc_sync_exit(self)
    }

    class func archiveOptOutStatus(_ optOutStatus: Bool, token: String) {
        objc_sync_enter(self)
        archiveToFile(.optOutStatus, object: optOutStatus, token: token)
        objc_sync_exit(self)
    }

    class func archiveProperties(_ properties: ArchivedProperties, token: String) {
        objc_sync_enter(self)
        var p = InternalProperties()
        p["distinctId"] = properties.distinctId
        p["anonymousId"] = properties.anonymousId
        p["userId"] = properties.userId
        p["alias"] = properties.alias
        p["hadPersistedDistinctId"] = properties.hadPersistedDistinctId
        p["superProperties"] = properties.superProperties
        p["peopleDistinctId"] = properties.peopleDistinctId
        p["peopleUnidentifiedQueue"] = properties.peopleUnidentifiedQueue
        p["timedEvents"] = properties.timedEvents
        #if DECIDE
        p["shownNotifications"] = properties.shownNotifications
        p["automaticEvents"] = properties.automaticEventsEnabled
        #endif // DECIDE
        archiveToFile(.properties, object: p, token: token)
        objc_sync_exit(self)
    }

    #if DECIDE
    class func archiveVariants(_ variants: Set<Variant>, token: String) {
        objc_sync_enter(self)
        archiveToFile(.variants, object: variants, token: token)
        objc_sync_exit(self)
    }

    class func archiveCodelessBindings(_ codelessBindings: Set<CodelessBinding>, token: String) {
        objc_sync_enter(self)
        archiveToFile(.codelessBindings, object: codelessBindings, token: token)
        objc_sync_exit(self)
    }
    #endif // DECIDE

    class private func archiveToFile(_ type: ArchiveType, object: Any, token: String) {
        let filePath = filePathWithType(type, token: token)
        guard let path = filePath else {
            Logger.error(message: "bad file path, cant fetch file")
            return
        }

        ExceptionWrapper.try({ [cObject = object, cPath = path, cType = type] in
            if !NSKeyedArchiver.archiveRootObject(cObject, toFile: cPath) {
                Logger.error(message: "failed to archive \(cType.rawValue)")
                return
            }
        }, catch: { [cType = type] (error) in
            Logger.error(message: "failed to archive \(cType.rawValue) due to an uncaught exception")
            return
        }, finally: {})
        
        addSkipBackupAttributeToItem(at: path)
    }

    class private func addSkipBackupAttributeToItem(at path: String) {
        var url = URL.init(fileURLWithPath: path)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try url.setResourceValues(resourceValues)
        } catch {
            Logger.info(message: "Error excluding \(path) from backup.")
        }
    }

    #if DECIDE
    class func unarchive(token: String) -> (eventsQueue: Queue,
                                            peopleQueue: Queue,
                                            groupsQueue: Queue,
                                            superProperties: InternalProperties,
                                            timedEvents: InternalProperties,
                                            distinctId: String,
                                            anonymousId: String?,
                                            userId: String?,
                                            alias: String?,
                                            hadPersistedDistinctId: Bool?,
                                            peopleDistinctId: String?,
                                            peopleUnidentifiedQueue: Queue,
                                            shownNotifications: Set<Int>,
                                            codelessBindings: Set<CodelessBinding>,
                                            variants: Set<Variant>,
                                            optOutStatus: Bool?,
                                            automaticEventsEnabled: Bool?) {
        let eventsQueue = unarchiveEvents(token: token)
        let peopleQueue = unarchivePeople(token: token)
        let groupsQueue = unarchiveGroups(token: token)
        let codelessBindings = unarchiveCodelessBindings(token: token)
        let variants = unarchiveVariants(token: token)
        let optOutStatus = unarchiveOptOutStatus(token: token)

        let (superProperties,
            timedEvents,
            distinctId,
            anonymousId,
            userId,
            alias,
            hadPersistedDistinctId,
            peopleDistinctId,
            peopleUnidentifiedQueue,
            shownNotifications,
            automaticEventsEnabled) = unarchiveProperties(token: token)

        return (eventsQueue,
                peopleQueue,
                groupsQueue,
                superProperties,
                timedEvents,
                distinctId,
                anonymousId,
                userId,
                alias,
                hadPersistedDistinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                shownNotifications,
                codelessBindings,
                variants,
                optOutStatus,
                automaticEventsEnabled)
    }
    #else
    class func unarchive(token: String) -> (eventsQueue: Queue,
                                            peopleQueue: Queue,
                                            groupsQueue: Queue,
                                            superProperties: InternalProperties,
                                            timedEvents: InternalProperties,
                                            distinctId: String,
                                            anonymousId: String?,
                                            userId: String?,
                                            alias: String?,
                                            hadPersistedDistinctId: Bool?,
                                            peopleDistinctId: String?,
                                            peopleUnidentifiedQueue: Queue) {
            let eventsQueue = unarchiveEvents(token: token)
            let peopleQueue = unarchivePeople(token: token)
            let groupsQueue = unarchiveGroups(token: token)

            let (superProperties,
                timedEvents,
                distinctId,
                anonymousId,
                userId,
                alias,
                hadPersistedDistinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue,
                _) = unarchiveProperties(token: token)

            return (eventsQueue,
                    peopleQueue,
                    groupsQueue,
                    superProperties,
                    timedEvents,
                    distinctId,
                    anonymousId,
                    userId,
                    alias,
                    hadPersistedDistinctId,
                    peopleDistinctId,
                    peopleUnidentifiedQueue)
    }
    #endif // DECIDE

    class private func unarchiveWithFilePath(_ filePath: String) -> Any? {
        var unarchivedData: Any? = nil
        ExceptionWrapper.try({ [filePath] in
            unarchivedData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath)
            if unarchivedData == nil {
                Logger.info(message: "Unable to read file at path: \(filePath)")
                removeArchivedFile(atPath: filePath)
            }
        }, catch: { [filePath] (error) in
            removeArchivedFile(atPath: filePath)
            Logger.info(message: "Unable to read file at path: \(filePath), error: \(String(describing: error))")
        }, finally: {})
        return unarchivedData
    }

    class private func removeArchivedFile(atPath filePath: String) {
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch let err {
            Logger.info(message: "Unable to remove file at path: \(filePath), error: \(err)")
        }
    }

    class private func unarchiveEvents(token: String) -> Queue {
        let data = unarchiveWithType(.events, token: token)
        return data as? Queue ?? []
    }

    class private func unarchivePeople(token: String) -> Queue {
        let data = unarchiveWithType(.people, token: token)
        return data as? Queue ?? []
    }

    class private func unarchiveGroups(token: String) -> Queue {
        let data = unarchiveWithType(.groups, token: token)
        return data as? Queue ?? []
    }

    class private func unarchiveOptOutStatus(token: String) -> Bool? {
        return unarchiveWithType(.optOutStatus, token: token) as? Bool
    }

    #if DECIDE
    class private func unarchiveProperties(token: String) -> (InternalProperties,
                                                              InternalProperties,
                                                              String,
                                                              String?,
                                                              String?,
                                                              String?,
                                                              Bool?,
                                                              String?,
                                                              Queue,
                                                              Set<Int>,
                                                              Bool?) {
        let properties = unarchiveWithType(.properties, token: token) as? InternalProperties
        let (superProperties,
             timedEvents,
             distinctId,
             anonymousId,
             userId,
             alias,
             hadPersistedDistinctId,
             peopleDistinctId,
             peopleUnidentifiedQueue,
             automaticEventsEnabled) = unarchivePropertiesHelper(token: token)
        let shownNotifications =
            properties?["shownNotifications"] as? Set<Int> ?? Set<Int>()

        return (superProperties,
                timedEvents,
                distinctId,
                anonymousId,
                userId,
                alias,
                hadPersistedDistinctId,
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
        String?,
        Bool?,
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
        String?,
        Bool?,
        String?,
        Queue,
        Bool?) {
            let properties = unarchiveWithType(.properties, token: token) as? InternalProperties
            let superProperties =
                properties?["superProperties"] as? InternalProperties ?? InternalProperties()
            let timedEvents =
                properties?["timedEvents"] as? InternalProperties ?? InternalProperties()
            var distinctId =
                properties?["distinctId"] as? String ?? ""
            var anonymousId =
                properties?["anonymousId"] as? String ?? nil
            var userId =
                properties?["userId"] as? String ?? nil
            var alias =
                properties?["alias"] as? String ?? nil
            var hadPersistedDistinctId =
                properties?["hadPersistedDistinctId"] as? Bool ?? nil
            var peopleDistinctId =
                properties?["peopleDistinctId"] as? String ?? nil
            let peopleUnidentifiedQueue =
                properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()
            let automaticEventsEnabled =
                properties?["automaticEvents"] as? Bool ?? nil

            if properties == nil {
                (distinctId, peopleDistinctId, anonymousId, userId, alias, hadPersistedDistinctId) = restoreIdentity(token: token)
            }

            return (superProperties,
                    timedEvents,
                    distinctId,
                    anonymousId,
                    userId,
                    alias,
                    hadPersistedDistinctId,
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

    class func storeIdentity(token: String, distinctID: String, peopleDistinctID: String?, anonymousID: String?, userID: String?, alias: String?, hadPersistedDistinctId: Bool?) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(token)-"
        defaults.set(distinctID, forKey: prefix + "MPDistinctID")
        defaults.set(peopleDistinctID, forKey: prefix + "MPPeopleDistinctID")
        defaults.set(anonymousID, forKey: prefix + "MPAnonymousId")
        defaults.set(userID, forKey: prefix + "MPUserId")
        defaults.set(alias, forKey: prefix + "MPAlias")
        defaults.set(hadPersistedDistinctId, forKey: prefix + "MPHadPersistedDistinctId")
        defaults.synchronize()
    }

    class func restoreIdentity(token: String) -> (String, String?, String?, String?, String?, Bool?) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return ("", nil, nil, nil, nil, nil)
        }
        let prefix = "mixpanel-\(token)-"
        return (defaults.string(forKey: prefix + "MPDistinctID") ?? "",
                defaults.string(forKey: prefix + "MPPeopleDistinctID"),
                defaults.string(forKey: prefix + "MPAnonymousId"),
                defaults.string(forKey: prefix + "MPUserId"),
                defaults.string(forKey: prefix + "MPAlias"),
                defaults.bool(forKey: prefix + "MPHadPersistedDistinctId"))
    }

    class func deleteMPUserDefaultsData(token: String) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(token)-"
        defaults.removeObject(forKey: prefix + "MPDistinctID")
        defaults.removeObject(forKey: prefix + "MPPeopleDistinctID")
        defaults.removeObject(forKey: prefix + "MPAnonymousId")
        defaults.removeObject(forKey: prefix + "MPUserId")
        defaults.removeObject(forKey: prefix + "MPAlias")
        defaults.removeObject(forKey: prefix + "MPHadPersistedDistinctId")
        defaults.synchronize()
    }

}
