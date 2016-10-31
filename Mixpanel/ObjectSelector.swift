//
//  ObjectSelector.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/24/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class ObjectSelector: NSObject {
    let classAndPropertyChars: CharacterSet
    let separatorChars: CharacterSet
    let predicateStartChar: CharacterSet
    let predicateEndChar: CharacterSet
    let flagStartChar: CharacterSet
    let flagEndChar: CharacterSet

    let scanner: Scanner
    var filters: [ObjectFilter]

    let string: String

    init(string: String) {
        self.string = string
        scanner = Scanner(string: string)
        classAndPropertyChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.*")
        separatorChars = CharacterSet(charactersIn: "/")
        predicateStartChar = CharacterSet(charactersIn: "[")
        predicateEndChar = CharacterSet(charactersIn: "]")
        flagStartChar = CharacterSet(charactersIn: "(")
        flagEndChar = CharacterSet(charactersIn: ")")
        filters = [ObjectFilter]()
        super.init()

        while let filter = nextFilter() {
            filters.append(filter)
        }
    }

    /*
     Starting at a leaf node, determine if it would be selected
     by this selector starting from the root object given.
    */
    func isSelected(leaf: AnyObject, from root: AnyObject, isFuzzy: Bool = false) -> Bool {
        return isLeafSelected(leaf: leaf, root: root, finalPredicate: !isFuzzy)
    }

    func isLeafSelected(leaf: AnyObject, root: AnyObject, finalPredicate: Bool) -> Bool {
        var isSelected = true
        var views = [leaf]
        for i in stride(from: filters.count - 1, to: -1, by: -1) {
            let filter = filters[i]
            filter.nameOnly = i == filters.count - 1 && !finalPredicate
            if !filter.doesApply(on: views) {
                isSelected = false
                break
            }
            views = filter.applyReverse(on: views)
            if views.isEmpty {
                break
            }
        }
        return isSelected && views.contains(where: {$0 === root})
    }

    func nextFilter() -> ObjectFilter? {
        guard scanner.scanCharacters(from: separatorChars, into: nil) else {
            return nil
        }

        let filter = ObjectFilter()
        var name: NSString? = nil
        if scanner.scanCharacters(from: classAndPropertyChars, into: &name) {
            filter.name = name as? String
        } else {
            filter.name = "*"
        }

        if scanner.scanCharacters(from: flagStartChar, into: nil) {
            var flags: NSString? = nil
            if scanner.scanUpToCharacters(from: flagEndChar, into: &flags) {
                for flag in flags!.components(separatedBy: "|") {
                    if flag == "unique" {
                        filter.unique = true
                    }
                }
            }
        }

        if scanner.scanCharacters(from: predicateStartChar, into: nil) {
            var predicateFormat: NSString? = nil
            var index = 0

            if scanner.scanInt(&index) && scanner.scanCharacters(from: predicateEndChar, into: nil) {
                filter.index = index
            } else if scanner.scanUpToCharacters(from: predicateEndChar, into: &predicateFormat) {
                let parsedPredicate = NSPredicate(format: predicateFormat as! String)
                filter.predicate = NSPredicate { (evaluatedObject, bindings) in
                    return parsedPredicate.evaluate(with: evaluatedObject, substitutionVariables: bindings)
                }
                scanner.scanCharacters(from: predicateEndChar, into: nil)
            }
        }

        return filter
    }

    func selectedClass() -> AnyClass? {
        if let filterName = filters.last?.name {
            return NSClassFromString(filterName)
        }
        return nil
    }

    func pathContainsObjectOfClass(_ klass: AnyClass) -> Bool {
        for filter in filters {
            if let filterName = filter.name {
                if let isSubclass = NSClassFromString(filterName)?.isSubclass(of: klass) {
                    if isSubclass {
                        return true
                    }
                }
            }
        }
        return false
    }

    func selectFrom(root: AnyObject?, evaluateFinalPredicate: Bool = true) -> [AnyObject] {
        var views = [AnyObject]()
        if let root = root {
            views = [root]
            for i in 0..<filters.count {
                filters[i].nameOnly = (i == filters.count - 1) && !evaluateFinalPredicate
                views = filters[i].apply(on: views)
                if views.isEmpty {
                    break
                }
            }
        }
        return views
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ObjectSelector else {
            return false
        }

        if object === self {
            return true
        } else {
            return self.string == object.string
        }
    }

    override var hash: Int {
        return string.hash
    }


}
