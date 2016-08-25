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
        while let filter = nextFilter() {
            filters.append(filter)
        }
    }

    /*
     Starting at a leaf node, determine if it would be selected
     by this selector starting from the root object given.
    */
    func isLeafSelected(leaf: AnyObject, root: AnyObject) -> Bool {
        return isLeafSelected(leaf: leaf, root: root, finalPredicate: true)
    }

    func fuzzyIsLeafSelected(leaf: AnyObject, root: AnyObject) -> Bool {
        return isLeafSelected(leaf: leaf, root: root, finalPredicate: false)
    }

    func isLeafSelected(leaf: AnyObject, root: AnyObject, finalPredicate: Bool) -> Bool {
        var isSelected = true
        var views = [leaf]
        for i in stride(from: filters.count - 1, to: 0, by: -1) {
            let filter = filters[i]
            filter.nameOnly = i == filters.count - 1 && !finalPredicate
            if !filter.appliesToAny(views: views) {
                isSelected = false
                break
            }
            views = filter.applyReverse(views: views)
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

        if scanner.scanUpToCharacters(from: predicateStartChar, into: nil) {
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
