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
    
    func saveEntities(_ entities: Queue, type: PersistenceType) {
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
    
}
