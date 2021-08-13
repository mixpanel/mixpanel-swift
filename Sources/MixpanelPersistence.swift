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
            if let data = JSONHandler.serializeJSONObject(entity) {
                mpdb.insertRow(type, data: data)
            }
        }
    }
    
    func loadEntitiesInBatch(type: PersistenceType, batchSize: Int = 50, flag: Bool = false) -> [InternalProperties] {
        let dataMap = mpdb.readRows(type, numRows: batchSize, flag: flag)
        var jsonArray : [InternalProperties] = []
        for (key, value) in dataMap {
            if let jsonObject = JSONHandler.deserializeData(value) as? InternalProperties {
                var entity = jsonObject
                entity["id"] = key
                jsonArray.append(entity)
            }
        }
        return jsonArray
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
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(apiToken)-"
        defaults.setValue(value, forKey: prefix + "OptOutStatus")
        defaults.synchronize()
    }
    
    func loadOptOutStatusFlag() -> Bool {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return false
        }
        let prefix = "mixpanel-\(apiToken)-"
        return defaults.bool(forKey: prefix + "OptOutStatus")
    }
    
    
    func saveAutomacticEventsEnabledFlag(value: Bool, fromDecide: Bool) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(apiToken)-"
        if fromDecide {
            defaults.setValue(value, forKey: prefix + "AutomaticEventEnabledFromDecide")
        } else {
            defaults.setValue(value, forKey: prefix + "AutomaticEventEnabled")
        }
        defaults.synchronize()
    }
    
    func loadAutomacticEventsEnabledFlag() -> Bool {
        #if TV_AUTO_EVENTS
        return true
        #else
        let prefix = "mixpanel-\(apiToken)-"
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return false
        }
        return defaults.bool(forKey: prefix + "AutomaticEventEnabled") || defaults.bool(forKey: prefix + "AutomaticEventEnabledFromDecide")
        #endif
    }
    
    func saveTimedEvents(timedEvents: InternalProperties) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(apiToken)-"
        let timedEventsData = NSKeyedArchiver.archivedData(withRootObject: timedEvents)
        defaults.set(timedEventsData, forKey: prefix + "timedEvents")
        defaults.synchronize()
    }
    
    func loadTimedEvents() -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return InternalProperties()
        }
        let prefix = "mixpanel-\(apiToken)-"
        guard let timedEventsData  = defaults.data(forKey: prefix + "timedEvents") else {
            return InternalProperties()
        }
        return NSKeyedUnarchiver.unarchiveObject(with: timedEventsData) as? InternalProperties ?? InternalProperties()
    }
    
    func saveSuperProperties(superProperties: InternalProperties) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(apiToken)-"
        let superPropertiesData = NSKeyedArchiver.archivedData(withRootObject: superProperties)
        defaults.set(superPropertiesData, forKey: prefix + "superProperties")
        defaults.synchronize()
    }
    
    func loadSuperProperties() -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return InternalProperties()
        }
        let prefix = "mixpanel-\(apiToken)-"
        guard let superPropertiesData  = defaults.data(forKey: prefix + "superProperties") else {
            return InternalProperties()
        }
        return NSKeyedUnarchiver.unarchiveObject(with: superPropertiesData) as? InternalProperties ?? InternalProperties()
    }
    
    func saveIdentity(distinctID: String, peopleDistinctID: String?, anonymousID: String?, userID: String?, alias: String?, hadPersistedDistinctId: Bool?) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(apiToken)-"
        defaults.set(distinctID, forKey: prefix + "MPDistinctID")
        defaults.set(peopleDistinctID, forKey: prefix + "MPPeopleDistinctID")
        defaults.set(anonymousID, forKey: prefix + "MPAnonymousId")
        defaults.set(userID, forKey: prefix + "MPUserId")
        defaults.set(alias, forKey: prefix + "MPAlias")
        defaults.set(hadPersistedDistinctId, forKey: prefix + "MPHadPersistedDistinctId")
        defaults.synchronize()
    }
    
    func loadIdentity() -> (String, String?, String?, String?, String?, Bool?) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return ("", nil, nil, nil, nil, nil)
        }
        let prefix = "mixpanel-\(apiToken)-"
        return (defaults.string(forKey: prefix + "MPDistinctID") ?? "",
                defaults.string(forKey: prefix + "MPPeopleDistinctID"),
                defaults.string(forKey: prefix + "MPAnonymousId"),
                defaults.string(forKey: prefix + "MPUserId"),
                defaults.string(forKey: prefix + "MPAlias"),
                defaults.bool(forKey: prefix + "MPHadPersistedDistinctId"))
    }
    
    func deleteMPUserDefaultsData() {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(apiToken)-"
        defaults.removeObject(forKey: prefix + "MPDistinctID")
        defaults.removeObject(forKey: prefix + "MPPeopleDistinctID")
        defaults.removeObject(forKey: prefix + "MPAnonymousId")
        defaults.removeObject(forKey: prefix + "MPUserId")
        defaults.removeObject(forKey: prefix + "MPAlias")
        defaults.removeObject(forKey: prefix + "MPHadPersistedDistinctId")
        defaults.removeObject(forKey: prefix + "AutomaticEventEnabled")
        defaults.removeObject(forKey: prefix + "AutomaticEventEnabledFromDecide")
        defaults.removeObject(forKey: prefix + "OptOutStatus")
        defaults.removeObject(forKey: prefix + "timedEvents")
        defaults.removeObject(forKey: prefix + "superProperties")
        defaults.synchronize()
    }
    
}
