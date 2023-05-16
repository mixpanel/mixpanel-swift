//
//  MixpanelPersistence.swift
//  Mixpanel
//
//  Created by ZIHE JIA on 7/9/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

import Foundation

enum LegacyArchiveType: String {
    case events
    case people
    case groups
    case properties
    case optOutStatus
}

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
    let anonymousId: String?
    let userId: String?
    let alias: String?
    let hadPersistedDistinctId: Bool?
}

struct MixpanelUserDefaultsKeys {
    static let suiteName = "Mixpanel"
    static let prefix = "mixpanel"
    static let optOutStatus = "OptOutStatus"
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
    
    let instanceName: String
    let mpdb: MPDB
    private static let archivedClasses = [NSArray.self, NSDictionary.self, NSSet.self, NSString.self, NSDate.self, NSURL.self, NSNumber.self, NSNull.self]
    
    init(instanceName: String) {
        self.instanceName = instanceName
        mpdb = MPDB.init(token: instanceName)
    }
    
    deinit {
        mpdb.close()
    }
    
    func closeDB() {
        mpdb.close()
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
    
    func loadEntitiesInBatch(type: PersistenceType, batchSize: Int = Int.max, flag: Bool = false, excludeAutomaticEvents: Bool = false) -> [InternalProperties] {
        var entities = mpdb.readRows(type, numRows: batchSize, flag: flag)
        if excludeAutomaticEvents && type == .events {
            entities = entities.filter { !($0["event"] as! String).hasPrefix("$ae_") }
        }
        if type == PersistenceType.people {
            let distinctId = MixpanelPersistence.loadIdentity(instanceName: instanceName).distinctID
            return entities.map { entityWithDistinctId($0, distinctId: distinctId) }
        }
        return entities
    }
    
    private func entityWithDistinctId(_ entity: InternalProperties, distinctId: String) -> InternalProperties {
        var result = entity;
        result["$distinct_id"] = distinctId
        return result
    }
    
    func removeEntitiesInBatch(type: PersistenceType, ids: [Int32]) {
        mpdb.deleteRows(type, ids: ids)
    }
    
    func identifyPeople(token: String) {
        mpdb.updateRowsFlag(.people, newFlag: !PersistenceConstant.unIdentifiedFlag)
    }
    
    func resetEntities() {
        for pType in PersistenceType.allCases {
            mpdb.deleteRows(pType, isDeleteAll: true)
        }
    }
    
    static func saveOptOutStatusFlag(value: Bool, instanceName: String) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        defaults.setValue(value, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.optOutStatus)")
        defaults.synchronize()
    }
    
    static func loadOptOutStatusFlag(instanceName: String) -> Bool? {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return nil
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        return defaults.object(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.optOutStatus)") as? Bool
    }
    
    static func saveTimedEvents(timedEvents: InternalProperties, instanceName: String) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        do {
            let timedEventsData = try NSKeyedArchiver.archivedData(withRootObject: timedEvents, requiringSecureCoding: false)
            defaults.set(timedEventsData, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.timedEvents)")
            defaults.synchronize()
        } catch {
            Logger.warn(message: "Failed to archive timed events")
        }
    }
    
    static func loadTimedEvents(instanceName: String) -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return InternalProperties()
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        guard let timedEventsData  = defaults.data(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.timedEvents)") else {
            return InternalProperties()
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: archivedClasses, from: timedEventsData) as? InternalProperties ?? InternalProperties()
        } catch {
            Logger.warn(message: "Failed to unarchive timed events")
            return InternalProperties()
        }
    }
    
    static func saveSuperProperties(superProperties: InternalProperties, instanceName: String) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        do {
            let superPropertiesData = try NSKeyedArchiver.archivedData(withRootObject: superProperties, requiringSecureCoding: false)
            defaults.set(superPropertiesData, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.superProperties)")
            defaults.synchronize()
        } catch {
            Logger.warn(message: "Failed to archive super properties")
        }
    }
    
    static func loadSuperProperties(instanceName: String) -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return InternalProperties()
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        guard let superPropertiesData  = defaults.data(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.superProperties)") else {
            return InternalProperties()
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: archivedClasses, from: superPropertiesData) as? InternalProperties ?? InternalProperties()
        } catch {
            Logger.warn(message: "Failed to unarchive super properties")
            return InternalProperties()
        }
    }
    
    static func saveIdentity(_ mixpanelIdentity: MixpanelIdentity, instanceName: String) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        defaults.set(mixpanelIdentity.distinctID, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.distinctID)")
        defaults.set(mixpanelIdentity.peopleDistinctID, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.peopleDistinctID)")
        defaults.set(mixpanelIdentity.anonymousId, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.anonymousId)")
        defaults.set(mixpanelIdentity.userId, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.userID)")
        defaults.set(mixpanelIdentity.alias, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.alias)")
        defaults.set(mixpanelIdentity.hadPersistedDistinctId, forKey: "\(prefix)\(MixpanelUserDefaultsKeys.hadPersistedDistinctId)")
        defaults.synchronize()
    }
    
    static func loadIdentity(instanceName: String) -> MixpanelIdentity {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return MixpanelIdentity.init(distinctID: "",
                                         peopleDistinctID: nil,
                                         anonymousId: nil,
                                         userId: nil,
                                         alias: nil,
                                         hadPersistedDistinctId: nil)
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        return MixpanelIdentity.init(
            distinctID: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.distinctID)") ?? "",
            peopleDistinctID: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.peopleDistinctID)"),
            anonymousId: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.anonymousId)"),
            userId: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.userID)"),
            alias: defaults.string(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.alias)"),
            hadPersistedDistinctId: defaults.bool(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.hadPersistedDistinctId)"))
    }
    
    static func deleteMPUserDefaultsData(instanceName: String) {
        guard let defaults = UserDefaults(suiteName: MixpanelUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = "\(MixpanelUserDefaultsKeys.prefix)-\(instanceName)-"
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.distinctID)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.peopleDistinctID)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.anonymousId)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.userID)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.alias)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.hadPersistedDistinctId)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.optOutStatus)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.timedEvents)")
        defaults.removeObject(forKey: "\(prefix)\(MixpanelUserDefaultsKeys.superProperties)")
        defaults.synchronize()
    }
    
    // code for unarchiving from legacy archive files and migrating to SQLite / NSUserDefaults persistence
    func migrate() {
        if !needMigration() {
            return
        }
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
             optOutStatus) = unarchiveFromLegacy()
        saveEntities(eventsQueue, type: PersistenceType.events)
        saveEntities(peopleUnidentifiedQueue, type: PersistenceType.people, flag: PersistenceConstant.unIdentifiedFlag)
        saveEntities(peopleQueue, type: PersistenceType.people)
        saveEntities(groupsQueue, type: PersistenceType.groups)
        MixpanelPersistence.saveSuperProperties(superProperties: superProperties, instanceName: instanceName)
        MixpanelPersistence.saveTimedEvents(timedEvents: timedEvents, instanceName: instanceName)
        MixpanelPersistence.saveIdentity(MixpanelIdentity.init(
            distinctID: distinctId,
            peopleDistinctID: peopleDistinctId,
            anonymousId: anonymousId,
            userId: userId,
            alias: alias,
            hadPersistedDistinctId: hadPersistedDistinctId), instanceName: instanceName)
        if let optOutFlag = optOutStatus {
            MixpanelPersistence.saveOptOutStatusFlag(value: optOutFlag, instanceName: instanceName)
        }
        return
    }
    
    private func filePathWithType(_ type: String) -> String? {
        let filename = "mixpanel-\(instanceName)-\(type)"
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
    
    private func unarchiveFromLegacy() -> (eventsQueue: Queue,
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
                                           optOutStatus: Bool?) {
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
             peopleUnidentifiedQueue) = unarchiveProperties()
        
        if let eventsFile = filePathWithType(PersistenceType.events.rawValue) {
            removeArchivedFile(atPath: eventsFile)
        }
        if let peopleFile = filePathWithType(PersistenceType.people.rawValue) {
            removeArchivedFile(atPath: peopleFile)
        }
        if let groupsFile = filePathWithType(PersistenceType.groups.rawValue) {
            removeArchivedFile(atPath: groupsFile)
        }
        if let propsFile = filePathWithType("properties") {
            removeArchivedFile(atPath: propsFile)
        }
        if let optOutFile = filePathWithType("optOutStatus") {
            removeArchivedFile(atPath: optOutFile)
        }
        
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
                optOutStatus)
    }
    
    private func unarchiveWithFilePath(_ filePath: String) -> Any? {
        if #available(iOS 11.0, macOS 10.13, watchOS 4.0, tvOS 11.0, *) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let unarchivedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: MixpanelPersistence.archivedClasses, from: data) else {
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
                                           Queue) {
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
        
        return (superProperties,
                timedEvents,
                distinctId,
                anonymousId,
                userId,
                alias,
                hadPersistedDistinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue)
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
    
    private func needMigration() -> Bool {
        return fileExists(type: LegacyArchiveType.events.rawValue) ||
        fileExists(type: LegacyArchiveType.people.rawValue) ||
        fileExists(type: LegacyArchiveType.people.rawValue) ||
        fileExists(type: LegacyArchiveType.groups.rawValue) ||
        fileExists(type: LegacyArchiveType.properties.rawValue) ||
        fileExists(type: LegacyArchiveType.optOutStatus.rawValue)
    }
    
    private func fileExists(type: String) -> Bool {
        return FileManager.default.fileExists(atPath: filePathWithType(type) ?? "")
    }
    
}
