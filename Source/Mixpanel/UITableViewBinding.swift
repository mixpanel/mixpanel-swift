//
//  UITableViewBinding.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/24/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class UITableViewBinding: CodelessBinding {


    init(eventName: String, path: String, delegate: AnyClass) {
        super.init(eventName: eventName, path: path)
        self.swizzleClass = delegate
    }

    convenience init?(object: [String: Any]) {
        guard let path = object["path"] as? String, path.count >= 1 else {
            Logger.warn(message: "must supply a view path to bind by")
            return nil
        }

        guard let eventName = object["event_name"] as? String, eventName.count >= 1 else {
            Logger.warn(message: "binding requires an event name")
            return nil
        }

        guard let tableDelegate = object["table_delegate"] as? String, let tableDelegateClass = NSClassFromString(tableDelegate) else {
            Logger.warn(message: "binding requires a table_delegate class")
            return nil
        }

        self.init(eventName: eventName,
                  path: path,
                  delegate: tableDelegateClass)

    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func execute() {
        if !running {
            let executeBlock = { (view: AnyObject?, command: Selector, tableView: AnyObject?, indexPath: AnyObject?) in
                guard let tableView = tableView as? UITableView, let indexPath = indexPath as? IndexPath else {
                    return
                }
                if let root = MixpanelInstance.sharedUIApplication()?.keyWindow?.rootViewController {
                    // select targets based off path
                    if self.path.isSelected(leaf: tableView, from: root) {
                        var label = ""
                        if let cell = tableView.cellForRow(at: indexPath) {
                            if let cellText = cell.textLabel?.text {
                                label = cellText
                            } else {
                                for subview in cell.contentView.subviews {
                                    if let lbl = subview as? UILabel, let text = lbl.text {
                                        label = text
                                        break
                                    }
                                }
                            }
                        }
                        self.track(event: self.eventName, properties: ["Cell Index": "\(indexPath.row)",
                                                                       "Cell Section": "\(indexPath.section)",
                                                                       "Cell Label": label])
                    }
                }
            }

            //swizzle
            Swizzler.swizzleSelector(NSSelectorFromString("tableView:didSelectRowAtIndexPath:"),
                                     withSelector:
                                        #selector(UIViewController.newDidSelectRowAtIndexPath(tableView:indexPath:)),
                                     for: swizzleClass,
                                     name: name,
                                     block: executeBlock)

            running = true
        }
    }

    override func stop() {
        if running {
            //unswizzle
            Swizzler.unswizzleSelector(NSSelectorFromString("tableView:didSelectRowAtIndexPath:"),
                aClass: swizzleClass,
                name: name)
            running = false
        }
    }

    override var description: String {
        return "UITableView Codeless Binding: \(eventName) for \(path)"
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? UITableViewBinding else {
            return false
        }

        if object === self {
            return true
        } else {
            return super.isEqual(object)
        }
    }

    override var hash: Int {
        return super.hash
    }
}

extension UIViewController {

    @objc func newDidSelectRowAtIndexPath(tableView: UITableView, indexPath: IndexPath) {
        let originalSelector = NSSelectorFromString("tableView:didSelectRowAtIndexPath:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UITableView, IndexPath) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, tableView, indexPath)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, tableView, indexPath as AnyObject?)
            }
        }
    }

}
