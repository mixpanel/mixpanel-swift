//
//  UIControlBinding.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/24/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class UIControlBinding: CodelessBinding {

    let controlEvent: UIControlEvents
    let verifyEvent: UIControlEvents
    let verified: NSHashTable<UIControl>
    let appliedTo: NSHashTable<UIControl>

    init(eventName: String, path: String, controlEvent: UIControlEvents, verifyEvent: UIControlEvents) {
        self.controlEvent = controlEvent
        self.verifyEvent = verifyEvent
        self.verified = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        self.appliedTo = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        super.init(eventName: eventName, path: path)
    }

    convenience init?(object: [String: Any]) {
        guard let path = object["path"] as? String, path.characters.count >= 1 else {
            Logger.warn(message: "must supply a view path to bind by")
            return nil
        }

        guard let eventName = object["event_name"] as? String, eventName.characters.count >= 1 else {
            Logger.warn(message: "binding requires an event name")
            return nil
        }

        guard let controlEvent = object["control_event"] as? UInt, controlEvent & UIControlEvents.allEvents.rawValue != 0 else {
            Logger.warn(message: "must supply a valid UIControlEvents value for control_event")
            return nil
        }

        var finalVerifyEvent: UIControlEvents
        if let verifyEvent = object["control_event"] as? UInt, verifyEvent & UIControlEvents.allEvents.rawValue != 0 {
            finalVerifyEvent = UIControlEvents(rawValue: verifyEvent)
        } else if controlEvent & UIControlEvents.allTouchEvents.rawValue != 0 {
            finalVerifyEvent = UIControlEvents.touchDown
        } else if controlEvent & UIControlEvents.allEditingEvents.rawValue != 0 {
            finalVerifyEvent = UIControlEvents.editingDidBegin
        } else {
            Logger.warn(message: "wasn't able to fetch a valid verify event")
            return nil
        }

        self.init(eventName: eventName,
                  path: path,
                  controlEvent: UIControlEvents(rawValue: controlEvent),
                  verifyEvent: finalVerifyEvent)

    }

    required init?(coder aDecoder: NSCoder) {
        controlEvent = aDecoder.decodeObject(forKey: "controlEvent") as! UIControlEvents
        verifyEvent = aDecoder.decodeObject(forKey: "verifyEvent") as! UIControlEvents
        verified = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        appliedTo = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        super.init(coder: aDecoder)
    }

    override func encode(with aCoder: NSCoder) {
        aCoder.encode(controlEvent, forKey: "controlEvent")
        aCoder.encode(verifyEvent, forKey: "verifyEvent")
        super.encode(with: aCoder)
    }


    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? UIControlBinding else {
            return false
        }

        if object === self {
            return true
        } else {
            return super.isEqual(object) && self.controlEvent == object.controlEvent && self.verifyEvent == object.verifyEvent
        }
    }

    override var hash: Int {
        return super.hash ^ Int(self.controlEvent.rawValue) ^ Int(self.verifyEvent.rawValue)
    }

    override var description: String {
        return "UIControl Codeless Binding: \(eventName) for \(path)"
    }

    func execute() {
        if !self.running {

        }
    }

    func stop() {

    }

    func stopOnView(view: UIControl) {

    }

    func verifyControlMatchesPath(control: Any) {

    }

    func preVerify(sender: Any, event: UIEvent) {

    }

    func execute(sender: Any, event: UIEvent) {
        
    }


}
