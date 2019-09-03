//
//  ObjectFilter.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/24/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class ObjectFilter: CustomStringConvertible {
    var name: String? = nil
    var predicate: NSPredicate? = nil
    var index: Int? = nil
    var unique: Bool
    var nameOnly: Bool


    init() {
        self.unique = false
        self.nameOnly = false
    }

    var description: String {
        var desc = ""
        if let name = name {
            desc += "name: \(name),"
        }
        if let index = index {
            desc += "index: \(index),"
        }
        if let predicate = predicate {
            desc += "predicate: \(predicate)"
        }
        return desc
    }


    func apply(on views: [AnyObject]) -> [AnyObject] {
        var result = [AnyObject]()

        let currentClass: AnyClass? = NSClassFromString(name!)
        if currentClass != nil || name == "*" {
            for view in views {
                var children = getChildren(of: view, searchClass: currentClass)
                if let index = index, index < children.count {
                    if view.isKind(of: UIView.self) {
                        children = [children[index]]
                    } else {
                        children = []
                    }
                }
                result += children
            }
        }

        if !nameOnly {
            if unique && result.count != 1 {
                return []
            }

            if let predicate = predicate {
                return result.filter { predicate.evaluate(with: $0) }
            }
        }

        return result
    }

    /*
     Apply this filter to the views. For any view that
     matches this filter's class / predicate pattern, return
     its parents.
     */
    func applyReverse(on views: [AnyObject]) -> [AnyObject] {
        var result = [AnyObject]()
        for view in views {
            if doesApply(on: view) {
                result += getParents(of: view)
            }
        }
        return result
    }

    /*
     Returns whether the given view would pass this filter.
     */
    func doesApply(on view: AnyObject) -> Bool {
        let typeValidation = name == "*" || (name != nil && NSClassFromString(name!) != nil && view.isKind(of: NSClassFromString(name!)!))
        let predicateValidation = predicate == nil || predicate!.evaluate(with: view)
        let indexValidation = index == nil || isSibling(view, at: index!)
        let uniqueValidation = !unique || isSibling(view, of: 1)

        return typeValidation && (nameOnly || (predicateValidation && indexValidation && uniqueValidation))
    }

    /*
     Returns whether any of the given views would pass this filter
     */
    func doesApply(on views: [AnyObject]) -> Bool {
        for view in views {
            if doesApply(on: view) {
                return true
            }
        }
        return false
    }

    /*
     Returns true if the given view is at the index given by number in
     its parent's subviews. The view's parent must be of type UIView
     */
    func isSibling(_ view: AnyObject, at index: Int) -> Bool {
        return isSibling(view, at: index, of: nil)
    }

    func isSibling(_ view: AnyObject, of count: Int) -> Bool {
        return isSibling(view, at: nil, of: count)
    }

    func isSibling(_ view: AnyObject, at index: Int?, of count: Int?) -> Bool {
        guard let name = name else {
            return false
        }

        let parents = self.getParents(of: view)
        for parent in parents {
            if let parent = parent as? UIView {
                let siblings = getChildren(of: parent, searchClass: NSClassFromString(name))
                if index == nil || (index! < siblings.count && siblings[index!] === view) && (count == nil || siblings.count == count!) {
                    return true
                }
            }
        }
        return false
    }

    func getParents(of object: AnyObject) -> [AnyObject] {
        var result = [AnyObject]()
        if let object = object as? UIView {
            if let superview = object.superview {
                result.append(superview)
            }

            if let nextResponder = object.next, nextResponder != object.superview {
                result.append(nextResponder)
            }
        } else if let object = object as? UIViewController {
            if let parentViewController = object.parent {
                result.append(parentViewController)
            }

            if let presentingViewController = object.presentingViewController {
                result.append(presentingViewController)
            }

            if let keyWindow = MixpanelInstance.sharedUIApplication()?.keyWindow, keyWindow.rootViewController == object {
                result.append(keyWindow)
            }
        }
        return result
    }

    func getChildren(of object: AnyObject, searchClass: AnyClass?) -> [AnyObject] {
        var children = [AnyObject]()

        if let window = object as? UIWindow,
            let rootVC = window.rootViewController,
            let sClass = searchClass,
            rootVC.isKind(of: sClass) {
            children.append(rootVC)
        } else if let view = object as? UIView {
            for subview in view.subviews {
                if searchClass == nil || subview.isKind(of: searchClass!) {
                    children.append(subview)
                }
            }
        } else if let viewController = object as? UIViewController {
            for child in viewController.children {
                if searchClass == nil || child.isKind(of: searchClass!) {
                    children.append(child)
                }
            }
            if let presentedVC = viewController.presentedViewController,
                (searchClass == nil || presentedVC.isKind(of: searchClass!)) {
                children.append(presentedVC)
            }
            if viewController.isViewLoaded && (searchClass == nil || viewController.view.isKind(of: searchClass!)) {
                children.append(viewController.view)
            }
        }

        // Reorder the cells in a table view so that they are arranged by y position
        if let sClass = searchClass, sClass.isSubclass(of: UITableViewCell.self) {
            children.sort {
                return ($0 as! UITableViewCell).frame.origin.y < ($1 as! UITableViewCell).frame.origin.y
            }
        }
        return children
    }

}
