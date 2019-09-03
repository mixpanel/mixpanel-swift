//
//  Tweak.swift
//  KATweak
//
//  Created by Bryan Clark on 11/4/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

/// Tweaks let you adjust things on the fly.
/// Because each T needs a UI component, we have to restrict what T can be - hence T: TweakableType.
/// If T: SignedNumberType, you can declare a min / max for a Tweak.
public struct Tweak<T: TweakableType> {
    internal let collectionName: String
    internal let groupName: String
    internal let tweakName: String
	internal let defaultValue: T
	internal let minimumValue: T?	// Only supported for T: SignedNumberType
	internal let maximumValue: T?	// Only supported for T: SignedNumberType
	internal let stepSize: T?		// Only supported for T: SignedNumberType

	internal init(tweakName: String,
	              defaultValue: T,
	              minimumValue: T? = nil,
	              maximumValue: T? = nil,
	              stepSize: T? = nil,
	              collectionName: String = "Mixpanel",
	              groupName: String = "Mixpanel") {

		[collectionName, groupName, tweakName].forEach {
			if $0.contains(TweakIdentifierSeparator) {
				assertionFailure("The substring `\(TweakIdentifierSeparator)` can't be used in a tweak name, group name, or collection name.")
			}
		}

		self.collectionName = collectionName
		self.groupName = groupName
		self.tweakName = tweakName
		self.defaultValue = defaultValue
		self.minimumValue = minimumValue
		self.maximumValue = maximumValue
		self.stepSize = stepSize
	}
}

internal let TweakIdentifierSeparator = "|"

extension Tweak {
    /**
     Initializer for a Tweak for A/B Testing

     - parameter tweakName:      name of the tweak
     - parameter defaultValue:   the default value set for the tweak
     */
	public init(tweakName: String, defaultValue: T) {
		self.init(
            tweakName: tweakName,
            defaultValue: defaultValue,
            collectionName: "Mixpanel",
            groupName: "Mixpanel"
		)
	}
}

extension Tweak where T: SignedNumeric & Comparable {
    /**
     Creates a Tweak<T> where T: SignedNumberType
     You can optionally provide a min / max / stepSize to restrict the bounds and behavior of a tweak.

     - parameter tweakName:      name of the tweak
     - parameter defaultValue:   the default value set for the tweak
     - parameter minimumValue:   minimum value to allow for the tweak
     - parameter maximumValue:   maximum value to allow for the tweak
     - parameter stepSize:       step size for the tweak (do not set, optional)
     */
	public init(tweakName: String,
	            defaultValue: T,
	            min minimumValue: T? = nil,
	            max maximumValue: T? = nil,
	            stepSize: T? = nil) {

		// Assert that the tweak's defaultValue is between its min and max (if they exist)
		if clip(defaultValue, minimumValue, maximumValue) != defaultValue {
			assertionFailure("A tweak's default value must be between its min and max. Your tweak \"\(tweakName)\" doesn't meet this requirement.")
		}

		self.init(
            tweakName: tweakName,
            defaultValue: defaultValue,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
			stepSize: stepSize,
            collectionName: "Mixpanel",
            groupName: "Mixpanel"
		)
	}
}

extension Tweak: TweakType {
    var tweak: TweakType {
		return self
	}

    var tweakDefaultData: TweakDefaultData {
		switch T.tweakViewDataType {
		case .boolean:
			return .boolean(defaultValue: (defaultValue as! Bool))
		case .integer:
			return .integer(
				defaultValue: defaultValue as! Int,
				min: minimumValue as? Int,
				max: maximumValue as? Int,
				stepSize: stepSize as? Int
			)
		case .cgFloat:
			return .float(
				defaultValue: defaultValue as! CGFloat,
				min: minimumValue as? CGFloat,
				max: maximumValue as? CGFloat,
				stepSize: stepSize as? CGFloat
			)
		case .double:
			return .doubleTweak(
				defaultValue: defaultValue as! Double,
				min: minimumValue as? Double,
				max: maximumValue as? Double,
				stepSize: stepSize as? Double
			)
        case .string:
            return .string(defaultValue: defaultValue as! String)
        }
    }

    var tweakViewDataType: TweakViewDataType {
		return T.tweakViewDataType
	}
}

extension Tweak: Hashable {
    /**
     Hashing for a Tweak for A/B Testing in order for it to be stored.
     */
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tweakIdentifier.hashValue)
    }
}

/**
 Comparator between two tweaks for A/B Testing.

 - parameter lhs: the left hand side tweak to compare
 - parameter rhs: the right hand side tweak to compare
 - returns: a boolean telling if both tweaks are equal
 */
public func == <T>(lhs: Tweak<T>, rhs: Tweak<T>) -> Bool {
	return lhs.tweakIdentifier == rhs.tweakIdentifier
}

/// Extend Tweak to support identification in bindings
extension Tweak: TweakIdentifiable {
	var persistenceIdentifier: String { return tweakIdentifier }
}

/// Extend Tweak to support easy initialization of a TweakStore
extension Tweak: TweakClusterType {
    public var tweakCluster: [AnyTweak] { return [AnyTweak.init(tweak: self)] }
}
