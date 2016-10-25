//
//  AnyTweak.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/18/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import Foundation

/**
 A type-erasure around Tweak<T> for A/B Testing.
 */
public struct AnyTweak: TweakType {

    let tweak: TweakType

    var collectionName: String { return tweak.collectionName }
    var groupName: String { return tweak.groupName }
    var tweakName: String { return tweak.tweakName }

    var tweakViewDataType: TweakViewDataType { return tweak.tweakViewDataType }
    var tweakDefaultData: TweakDefaultData { return tweak.tweakDefaultData }

    init(tweak: TweakType) {
		self.tweak = tweak.tweak
	}
}

/// When combined with AnyTweak, this provides our type-erasure around Tweak<T>
protocol TweakType: TweakClusterType {
	var tweak: TweakType { get }

	var collectionName: String { get }
	var groupName: String { get }
	var tweakName: String { get }

	var tweakViewDataType: TweakViewDataType { get }
	var tweakDefaultData: TweakDefaultData { get }
}

extension TweakType {
	var tweakIdentifier: String {
		return "\(collectionName)\(TweakIdentifierSeparator)\(groupName)\(TweakIdentifierSeparator)\(tweakName)"
	}
}

extension AnyTweak: Hashable {
    public var hashValue: Int {
		return tweakIdentifier.hashValue
	}
}

/**
 Comparator between two tweaks for A/B Testing.

 - parameter lhs: the left hand side tweak to compare
 - parameter rhs: the right hand side tweak to compare
 - returns: a boolean telling if both tweaks are equal
 */
public func == (lhs: AnyTweak, rhs: AnyTweak) -> Bool {
	return lhs.tweakIdentifier == rhs.tweakIdentifier
}

/// Extend AnyTweak to support identification in disk persistence
extension AnyTweak: TweakIdentifiable {
	var persistenceIdentifier: String { return tweakIdentifier }
}

/// Extend AnyTweak to support easy initialization of a TweakStore
extension AnyTweak: TweakClusterType {
    /// Allows easy tweak initialization by clustering tweaks together for A/B Testing
    public var tweakCluster: [AnyTweak] { return [self] }
}
