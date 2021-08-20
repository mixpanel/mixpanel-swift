//
//  MixpanelPersistence.swift
//  Mixpanel
//
//  Created by ZIHE JIA on 7/9/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

import Foundation

enum PersistenceType: String, CaseIterable {
    case events
    case people
    case groups
}

struct PersistenceConstant {
    static let unIdentifiedFlag = true
}

struct MixpanelIdentity {
    let distinctID: String
    let peopleDistinctID: String?
    let anoymousId: String?
    let userId: String?
    let alias: String?
    let hadPersistedDistinctId: Bool?
}

struct MixpanelUserDefaultsKeys {
    static let suiteName = "Mixpanel"
    static let prefix = "mixpanel"
    static let optOutStatus = "OptOutStatus"
    static let automaticEventEnabled = "AutomaticEventEnabled"
    static let automaticEventEnabledFromDecide = "AutomaticEventEnabledFromDecide"
    static let timedEvents = "timedEvents"
    static let superProperties = "superProperties"
    static let distinctID = "MPDistinctID"
    static let peopleDistinctID = "MPPeopleDistinctID"
    static let anonymousId = "MPAnonymousId"
    static let userID = "MPUserId"
    static let alias = "MPAlias"
    static let hadPersistedDistinctId = "MPHadPersistedDistinctId"
}

class MixpanelPersistence {
    
    let apiToken: String
    let mpdb: MPDB
    
    init(token: String) {
        apiToken = token
        mpdb = MPDB.init(token: apiToken)
    }
    
    func saveEntity(_ entity: InternalProperties, type: PersistenceType, flag: Bool = false) {
        if let data = JSONHandler.serializeJSONObject(entity) {
            mpdb.insertRow(type, data: data, flag: flag)
        }
    }
    
    func saveEntities(_ entities: Queue, type: PersistenceType, flag: Bool = false) {
        for entity in entities {
            saveEntity(entity, type: type)
        }
    }
    
    func loadEntitiesInBatch(type: PersistenceType, batchSize: Int = Int.max, flag: Bool = false) -> [InternalProperties] {
        return mpdb.readRows(type, numRows: batchSize, flag: flag)
    }
    
    func removeEntitiesInBatch(type: PersistenceType, ids: [Int32]) {
        mpdb.deleteRows(type, ids: ids)
    }
    
    func identifyPeople(token: String) {
        mpdb.updateRowsFlag(.people, newFlag: !PersistenceConstant.unIdentifiedFlag)
    }
    
    func resetEntities() {
        for pType in PersistenceType.allCases {
            mpdb.deleteRows(pType)
        }
    }
    
    func saveOptOutStatusFlag(value: Bool) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        defaults.setValue(value, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.optOutStatus)")
        defaults.synchronize()
    }
    
    func loadOptOutStatusFlag() -> Bool? {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return nil
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        return defaults.object(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.optOutStatus)") as? Bool
    }
    
    
    func saveAutomacticEventsEnabledFlag(value: Bool, fromDecide: Bool) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        if fromDecide {
            defaults.setValue(value, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabledFromDecide)")
        } else {
            defaults.setValue(value, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabled)")
        }
        defaults.synchronize()
    }
    
    func loadAutomacticEventsEnabledFlag() -> Bool {
        #if TV_AUTO_EVENTS
        return true
        #else
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return true
        }
        if defaults.object(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabled)") == nil && defaults.object(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabledFromDecide)") == nil {
            return true // default true
        }
        if defaults.object(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabled)") != nil {
            return defaults.bool(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabled)")
        } else { // if there is no local settings, get the value from Decide
            return defaults.bool(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabledFromDecide)")
        }
        #endif
    }
    
    func saveTimedEvents(timedEvents: InternalProperties) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        let timedEventsData = NSKeyedArchiver.archivedData(withRootObject: timedEvents)
        defaults.set(timedEventsData, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.timedEvents)")
        defaults.synchronize()
    }
    
    func loadTimedEvents() -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return InternalProperties()
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        guard let timedEventsData  = defaults.data(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.timedEvents)") else {
            return InternalProperties()
        }
        return NSKeyedUnarchiver.unarchiveObject(with: timedEventsData) as? InternalProperties ?? InternalProperties()
    }
    
    func saveSuperProperties(superProperties: InternalProperties) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        let superPropertiesData = NSKeyedArchiver.archivedData(withRootObject: superProperties)
        defaults.set(superPropertiesData, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.superProperties)")
        defaults.synchronize()
    }
    
    func loadSuperProperties() -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return InternalProperties()
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        guard let superPropertiesData  = defaults.data(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.superProperties)") else {
            return InternalProperties()
        }
        return NSKeyedUnarchiver.unarchiveObject(with: superPropertiesData) as? InternalProperties ?? InternalProperties()
    }
    
    func saveIdentity(mixpanelIdentity: MixpanelIdentity) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        defaults.set(mixpanelIdentity.distinctID, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.distinctID)")
        defaults.set(mixpanelIdentity.peopleDistinctID, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.peopleDistinctID)")
        defaults.set(mixpanelIdentity.anoymousId, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.anonymousId)")
        defaults.set(mixpanelIdentity.userId, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.userID)")
        defaults.set(mixpanelIdentity.alias, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.alias)")
        defaults.set(mixpanelIdentity.hadPersistedDistinctId, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.hadPersistedDistinctId)")
        defaults.synchronize()
    }
    
    func loadIdentity() -> MixpanelIdentity {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return MixpanelIdentity.init(distinctID: "", peopleDistinctID: nil, anoymousId: nil, userId: nil, alias: nil, hadPersistedDistinctId: nil)
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        return MixpanelIdentity.init(
            distinctID: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.distinctID)") ?? "",
            peopleDistinctID: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.peopleDistinctID)"),
            anoymousId: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.anonymousId)"),
            userId: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.userID)"),
            alias: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.alias)"),
            hadPersistedDistinctId: defaults.bool(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.hadPersistedDistinctId)"))
    }
    
    func deleteMPUserDefaultsData() {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(apiToken)-"
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.distinctID)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.peopleDistinctID)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.anonymousId)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.userID)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.alias)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.hadPersistedDistinctId)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabled)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.automaticEventEnabledFromDecide)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.optOutStatus)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.timedEvents)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.superProperties)")
        defaults.synchronize()
    }
    
    // code for unarchiving from legacy archive files and migrating to SQLite / NSUserDefaults persistence
    func migrate() {
        let (eventsQueue,
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
             optOutStatus,
             automaticEventsEnabled) = unarchive()
        
        saveEntities(eventsQueue, type: PersistenceType.events)
        saveEntities(peopleUnidentifiedQueue, type: PersistenceType.people, flag: true)
        saveEntities(peopleQueue, type: PersistenceType.people)
        saveEntities(groupsQueue, type: PersistenceType.groups)
        saveSuperProperties(superProperties: superProperties)
        saveTimedEvents(timedEvents: timedEvents)
        saveIdentity(distinctID: distinctId, peopleDistinctID: peopleDistinctId, anonymousID: anonymousId, userID: userId, alias: alias, hadPersistedDistinctId: hadPersistedDistinctId)
        if let optOutFlag = optOutStatus {
            saveOptOutStatusFlag(value: optOutFlag)
        }
        if let automaticEventsFlag = automaticEventsEnabled {
            saveAutomacticEventsEnabledFlag(value: automaticEventsFlag, fromDecide: false) // shoulde fromDecide = false here?
        }
        return
    }
    
    private func filePathWithType(_ type: String) -> String? {
            return filePathFor(type)
        }

    private func filePathFor(_ persistenceType: String) -> String? {
        let filename = "mixpanel-\(apiToken)-\(persistenceType)"
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
    
    private func unarchive() -> (eventsQueue: Queue,
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
                                            optOutStatus: Bool?,
                                            automaticEventsEnabled: Bool?) {
        let eventsQueue = unarchiveEvents()
        let peopleQueue = unarchivePeople()
        let groupsQueue = unarchiveGroups()
        let optOutStatus = unarchiveOptOutStatus()

        let (superProperties,
            timedEvents,
            distinctId,
            anonymousId,
            userId,
            alias,
            hadPersistedDistinctId,
            peopleDistinctId,
            peopleUnidentifiedQueue,
            automaticEventsEnabled) = unarchiveProperties()
        
        removeArchivedFile(atPath: filePathFor(PersistenceType.events.rawValue)!)
        removeArchivedFile(atPath: filePathFor(PersistenceType.people.rawValue)!)
        removeArchivedFile(atPath: filePathFor(PersistenceType.groups.rawValue)!)
        removeArchivedFile(atPath: filePathFor("codelessBindings")!)
        removeArchivedFile(atPath: filePathFor("variants")!)
        removeArchivedFile(atPath: filePathFor("optOutStatus")!)
        removeArchivedFile(atPath: filePathFor("properties")!)

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
                optOutStatus,
                automaticEventsEnabled)
    }

    private func unarchiveWithFilePath(_ filePath: String) -> Any? {
        if #available(iOS 11.0, macOS 10.13, watchOS 4.0, tvOS 11.0, *) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let unarchivedData = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)  else {
                Logger.info(message: "Unable to read file at path: \(filePath)")
                removeArchivedFile(atPath: filePath)
                return nil
            }
            return unarchivedData
        } else {
            guard let unarchivedData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) else {
                Logger.info(message: "Unable to read file at path: \(filePath)")
                removeArchivedFile(atPath: filePath)
                return nil
            }
            return unarchivedData
        }
    }

    private func removeArchivedFile(atPath filePath: String) {
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch let err {
            Logger.info(message: "Unable to remove file at path: \(filePath), error: \(err)")
        }
    }

    private func unarchiveEvents() -> Queue {
        let data = unarchiveWithType(PersistenceType.events.rawValue)
        return data as? Queue ?? []
    }

    private func unarchivePeople() -> Queue {
        let data = unarchiveWithType(PersistenceType.people.rawValue)
        return data as? Queue ?? []
    }

    private func unarchiveGroups() -> Queue {
        let data = unarchiveWithType(PersistenceType.groups.rawValue)
        return data as? Queue ?? []
    }

    private func unarchiveOptOutStatus() -> Bool? {
        return unarchiveWithType("optOutStatus") as? Bool
    }

    private func unarchiveProperties() -> (InternalProperties,
        InternalProperties,
        String,
        String?,
        String?,
        String?,
        Bool?,
        String?,
        Queue,
        Bool?) {
        return unarchivePropertiesHelper()
    }

    private func unarchivePropertiesHelper() -> (InternalProperties,
        InternalProperties,
        String,
        String?,
        String?,
        String?,
        Bool?,
        String?,
        Queue,
        Bool?) {
            let properties = unarchiveWithType("properties") as? InternalProperties
            let superProperties =
                properties?["superProperties"] as? InternalProperties ?? InternalProperties()
            let timedEvents =
                properties?["timedEvents"] as? InternalProperties ?? InternalProperties()
            let distinctId =
                properties?["distinctId"] as? String ?? ""
            let anonymousId =
                properties?["anonymousId"] as? String ?? nil
            let userId =
                properties?["userId"] as? String ?? nil
            let alias =
                properties?["alias"] as? String ?? nil
            let hadPersistedDistinctId =
                properties?["hadPersistedDistinctId"] as? Bool ?? nil
            let peopleDistinctId =
                properties?["peopleDistinctId"] as? String ?? nil
            let peopleUnidentifiedQueue =
                properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()
            let automaticEventsEnabled =
                properties?["automaticEvents"] as? Bool ?? nil
        
//            we dont't need to worry about this during migration right?
//            if properties == nil {
//                (distinctId, peopleDistinctId, anonymousId, userId, alias, hadPersistedDistinctId) = restoreIdentity(token: token)
//            }

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

    private func unarchiveWithType(_ type: String) -> Any? {
        let filePath = filePathWithType(type)
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
