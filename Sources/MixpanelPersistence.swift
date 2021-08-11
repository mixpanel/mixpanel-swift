//
//  MixpanelPersistence.swift
//  Mixpanel
//
//  Created by ZIHE JIA on 7/9/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//

import Foundation

enum PersistenceType: String {
    case events
    case people
    case unIdentifiedPeople
    case groups
    case properties
    case optOutStatus
}


class MixpanelPersistence {
    
    static let sharedInstance: MixpanelPersistence = {
        let instance = MixpanelPersistence()
        
        
        return instance
    }()
    
    
    func saveEntity(_ entity: InternalProperties, type: PersistenceType, token: String) {
        
    }
    
    func saveEntities(_ entities: Queue, type: PersistenceType, token: String) {
        
        
    }
    
    func updateEntitiesType(oldType: PersistenceType, newType: PersistenceType) {
        
    }
    
    func loadEntity(_ type: PersistenceType, token: String) -> InternalProperties {
        return [:]
    }
    
    func loadEntitiesInBatch(_ batchSize: Int = 50, type: PersistenceType, token: String) -> Queue {
        
        return []
    }
    
    func removeEventsInBatch(_ batchSize: Int, type: PersistenceType, token: String) {
      
    }
    
    func resetEvents() {
        
    }
    
    static func saveOptOutStatusFlag(value: Bool, token: String) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(token)-"
        defaults.setValue(value, forKey: prefix + "OptOutStatus")
        defaults.synchronize()
    }
    
    static func loadOptOutStatusFlag(token: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return false
        }
        let prefix = "mixpanel-\(token)-"
        return defaults.bool(forKey: prefix + "OptOutStatus")
    }
    
    
    static func saveAutomacticEventsEnabledFlag(value: Bool, fromDecide: Bool, token: String) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(token)-"
        if fromDecide {
            defaults.setValue(value, forKey: prefix + "AutomaticEventEnabledFromDecide")
        } else {
            defaults.setValue(value, forKey: prefix + "AutomaticEventEnabled")
        }
        defaults.synchronize()
    }
    
    static func loadAutomacticEventsEnabledFlag(token: String) -> Bool {
        #if TV_AUTO_EVENTS
        return true
        #else
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return false
        }
        return defaults.bool(forKey: "AutomaticEventEnabled" + token) || defaults.bool(forKey: "AutomaticEventEnabledFromDecide" + token)
        #endif
    }
    
    static func saveTimedEvents(timedEvents: InternalProperties, token: String) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(token)-"
        let timedEventsData = NSKeyedArchiver.archivedData(withRootObject: timedEvents)
        defaults.set(timedEventsData, forKey: prefix + "timedEvents")
    }
    
    static func loadTimedEvents(token: String) -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return InternalProperties()
        }
        let prefix = "mixpanel-\(token)-"
        return defaults.object(forKey: prefix + "timedEvents") as? InternalProperties ?? InternalProperties()
    }

    static func saveSuperProperties(superProperties: InternalProperties, token: String) {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return
        }
        let prefix = "mixpanel-\(token)-"
        let timedEventsData = NSKeyedArchiver.archivedData(withRootObject: superProperties)
        defaults.set(timedEventsData, forKey: prefix + "superProperties")
    }
    
    static func loadSuperProperties(token: String) -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: "Mixpanel") else {
            return InternalProperties()
        }
        let prefix = "mixpanel-\(token)-"
        return defaults.object(forKey: prefix + "superProperties") as? InternalProperties ?? InternalProperties()
    }
    
    
    static func saveIdentity(token: String, distinctID: String, peopleDistinctID: String?, anonymousID: String?, userID: String?, alias: String?, hadPersistedDistinctId: Bool?) {
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

    static func loadIdentity(token: String) -> (String, String?, String?, String?, String?, Bool?) {
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

    static func deleteMPUserDefaultsData(token: String) {
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
        defaults.removeObject(forKey: prefix + "AutomaticEventEnabled")
        defaults.removeObject(forKey: prefix + "AutomaticEventEnabledFromDecide")
        defaults.removeObject(forKey: prefix + "OptOutStatus")
        defaults.removeObject(forKey: prefix + "timedEvents")
        defaults.removeObject(forKey: prefix + "superProperties")
        defaults.synchronize()
    }
    
}
