//
//  Variant.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 9/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class Variant: NSObject, NSCoding {
    let ID: Int
    let experimentID: Int
    var running: Bool
    var finished: Bool

    var actions: NSMutableOrderedSet
    var tweaks: [VariantTweak]

    convenience init?(JSONObject: [String: Any]?) {
        guard let object = JSONObject else {
            Logger.error(message: "variant json object should not be nil")
            return nil
        }

        guard let ID = object["id"] as? Int, ID > 0 else {
            Logger.error(message: "invalid variant id")
            return nil
        }

        guard let experimentID = object["experiment_id"] as? Int, experimentID > 0 else {
            Logger.error(message: "invalid experiment id")
            return nil
        }

        guard let actions = object["actions"] as? [[String: Any]] else {
            Logger.error(message: "variant requires an array of actions")
            return nil
        }

        guard let tweaks = object["tweaks"] as? [[String: Any]] else {
            Logger.error(message: "variant requires an array of tweaks")
            return nil
        }

        self.init(ID: ID, experimentID: experimentID, actions: actions, tweaks: tweaks)
    }

    init(ID: Int, experimentID: Int, actions: [[String: Any]], tweaks: [[String: Any]]) {
        self.ID = ID
        self.experimentID = experimentID
        self.actions = NSMutableOrderedSet()
        self.tweaks = [VariantTweak]()
        self.running = false
        self.finished = false
        super.init()
        addActions(JSONObject: actions)
        addTweaks(JSONObject: tweaks)
    }

    required init?(coder aDecoder: NSCoder) {
        guard let actions = aDecoder.decodeObject(forKey: "actions") as? NSMutableOrderedSet,
            let tweaks = aDecoder.decodeObject(forKey: "tweaks") as? [VariantTweak] else {
                return nil
        }

        self.ID = aDecoder.decodeInteger(forKey: "ID")
        self.experimentID = aDecoder.decodeInteger(forKey: "experimentID")
        self.actions = actions
        self.tweaks = tweaks
        self.finished = aDecoder.decodeBool(forKey: "finished")
        self.running = false
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(ID, forKey: "ID")
        aCoder.encode(experimentID, forKey: "experimentID")
        aCoder.encode(actions, forKey: "actions")
        aCoder.encode(tweaks, forKey: "tweaks")
        aCoder.encode(finished, forKey: "finished")
    }

    func addActions(JSONObject: [[String: Any]], execute: Bool = false) {
        for object in JSONObject {
            if let action = VariantAction(JSONObject: object) {
                actions.remove(action)
                actions.add(action)
                if execute {
                    action.execute()
                }
            }
        }
    }

    func removeAction(name: String) {
        for action in actions {
            guard let action = action as? VariantAction else {
                continue
            }
            if action.name == name {
                action.stop()
                actions.remove(action)
                break
            }
        }
    }

    func addTweaks(JSONObject: [[String: Any]], execute: Bool = false) {
        for object in JSONObject {
            if let tweak = VariantTweak(JSONObject: object) {
                tweaks.append(tweak)
                if execute {
                    tweak.execute()
                }
            }
        }
    }

    func execute() {
        if !running && !finished {
            for tweak in tweaks {
                tweak.execute()
            }
            for action in actions {
                guard let action = action as? VariantAction else {
                    continue
                }
                action.execute()
            }
            running = true
        }
    }

    func stop() {
        for action in actions {
            guard let action = action as? VariantAction else {
                continue
            }
            action.stop()
        }
        for tweak in tweaks {
            tweak.stop()
        }
        running = false
    }

    func finish() {
        stop()
        finished = true
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Variant else {
            return false
        }

        if object === self {
            return true
        } else {
            return self.ID == object.ID
        }
    }

    override var hash: Int {
        return self.ID
    }

}
