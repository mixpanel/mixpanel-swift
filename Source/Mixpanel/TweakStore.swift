//
//  TweakStore.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/5/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import UIKit

/// Looks up the persisted state for tweaks.
public final class TweakStore {

	/// The "tree structure" for our Tweaks UI.
    var tweakCollections: [String: TweakCollection] = [:]

	/// Useful when exporting or checking that a tweak exists in tweakCollections
    var allTweaks: Set<AnyTweak>

	/// We hold a reference to the storeName so we can have a better error message if a tweak doesn't exist in allTweaks.
	private let storeName: String

	/// Caches "single" bindings - when a tweak is updated, we'll call each of the corresponding bindings.
	private var tweakBindings: [String: [AnyTweakBinding]] = [:]

	/// Caches "multi" bindings - when any tweak in a Set is updated, we'll call each of the corresponding bindings.
	private var tweakSetBindings: [Set<AnyTweak>: [() -> Void]] = [:]

	/// Persists tweaks' currentValues and maintains them on disk.
	private let persistence: TweakPersistency

	/// Determines whether tweaks are enabled, and whether the tweaks UI is accessible
	internal let enabled: Bool

	///
	///
    /**
     Creates a TweakStore, with information persisted on-disk.
     If you want to have multiple TweakStores in your app, you can pass in a unique storeName to keep it separate from others on disk.

     - parameter storeName:     the name of the store (optional)
     - parameter enabled:       if debugging is enabled or not
     */
    init(storeName: String = "Tweaks", enabled: Bool) {
		self.persistence = TweakPersistency(identifier: storeName)
		self.storeName = storeName
		self.enabled = enabled
        self.allTweaks = Set()
    }

    /// A method for adding Tweaks to the environment
    func addTweaks(_ tweaks: [TweakClusterType]) {
        self.allTweaks.formUnion(Set(tweaks.reduce(into: []) { $0.append(contentsOf: $1.tweakCluster) }))
        self.allTweaks.forEach { tweak in
            // Find or create its TweakCollection
            var tweakCollection: TweakCollection
            if let existingCollection = tweakCollections[tweak.collectionName] {
                tweakCollection = existingCollection
            } else {
                tweakCollection = TweakCollection(title: tweak.collectionName)
                tweakCollections[tweakCollection.title] = tweakCollection
            }

            // Find or create its TweakGroup
            var tweakGroup: TweakGroup
            if let existingGroup = tweakCollection.tweakGroups[tweak.groupName] {
                tweakGroup = existingGroup
            } else {
                tweakGroup = TweakGroup(title: tweak.groupName)
            }

            // Add the tweak to the tree
            tweakGroup.tweaks[tweak.tweakName] = tweak
            tweakCollection.tweakGroups[tweakGroup.title] = tweakGroup
            tweakCollections[tweakCollection.title] = tweakCollection
        }
    }

	/// Returns the current value for a given tweak
    func assign<T>(_ tweak: Tweak<T>) -> T {
		return self.currentValueForTweak(tweak)
	}

    /**
     The bind function for Tweaks. This is meant for binding Tweaks to the relevant components.

     - parameter tweak:      the tweak to bind
     - parameter binding:    the binding to issue for the tweak
     */
    func bind<T>(_ tweak: Tweak<T>, binding: @escaping (T) -> Void) {
		// Create the TweakBinding<T>, and wrap it in our type-erasing AnyTweakBinding
		let tweakBinding = TweakBinding(tweak: tweak, binding: binding)
		let anyTweakBinding = AnyTweakBinding(tweakBinding: tweakBinding)

		// Cache the binding
		let existingTweakBindings = tweakBindings[tweak.persistenceIdentifier] ?? []
		tweakBindings[tweak.persistenceIdentifier] = existingTweakBindings + [anyTweakBinding]

		// Then immediately apply the binding on whatever current value we have
		binding(currentValueForTweak(tweak))
	}

    func bindMultiple(_ tweaks: [TweakType], binding: @escaping () -> Void) {
		// Convert the array (which makes it easier to call a `bindTweakSet`) into a set (which makes it possible to cache the tweakSet)
		let tweakSet = Set(tweaks.map(AnyTweak.init))

		// Cache the cluster binding
		let existingTweakSetBindings = tweakSetBindings[tweakSet] ?? []
		tweakSetBindings[tweakSet] = existingTweakSetBindings + [binding]

		// Immediately call the binding
		binding()
	}

	// MARK: - Internal

	/// Resets all tweaks to their `defaultValue`
	internal func reset() {
		persistence.clearAllData()

		// Go through all tweaks in our library, and call any bindings they're attached to.
		tweakCollections.values.reduce(into: []) {
			$0.append(contentsOf: $1.sortedTweakGroups.reduce(into: []) { 
				$0.append(contentsOf: $1.sortedTweaks) 
			})
		}
		.forEach { updateBindingsForTweak($0) }
	}

	internal func currentValueForTweak<T>(_ tweak: Tweak<T>) -> T {
		if allTweaks.contains(AnyTweak(tweak: tweak)) {
			return enabled ? persistence.currentValueForTweak(tweak) ?? tweak.defaultValue : tweak.defaultValue
		} else {
            Logger.error(message: "Error: the tweak \"\(tweak.tweakIdentifier)\" isn't included in the tweak store \"\(storeName)\"." +
                "Returning the default value.")
			return tweak.defaultValue
		}
	}

	internal func currentViewDataForTweak(_ tweak: AnyTweak) -> TweakViewData {
		let cachedValue = persistence.persistedValueForTweakIdentifiable(tweak)

		switch tweak.tweakDefaultData {
		case let .boolean(defaultValue: defaultValue):
			let currentValue = cachedValue as? Bool ?? defaultValue
			return .boolean(value: currentValue, defaultValue: defaultValue)
		case let .integer(defaultValue: defaultValue, min: min, max: max, stepSize: step):
			let currentValue = cachedValue as? Int ?? defaultValue
			return .integer(value: currentValue, defaultValue: defaultValue, min: min, max: max, stepSize: step)
		case let .float(defaultValue: defaultValue, min: min, max: max, stepSize: step):
			let currentValue = cachedValue as? CGFloat ?? defaultValue
			return .float(value: currentValue, defaultValue: defaultValue, min: min, max: max, stepSize: step)
		case let .doubleTweak(defaultValue: defaultValue, min: min, max: max, stepSize: step):
			let currentValue = cachedValue as? Double ?? defaultValue
			return .doubleTweak(value: currentValue, defaultValue: defaultValue, min: min, max: max, stepSize: step)
        case let .string(defaultValue: defaultValue):
            let currentValue = cachedValue as? String ?? defaultValue
            return .string(value: currentValue, defaultValue: defaultValue)
		}
	}

	internal func setValue(_ viewData: TweakViewData, forTweak tweak: AnyTweak) {
		persistence.setValue(viewData.value, forTweakIdentifiable: tweak)
		updateBindingsForTweak(tweak)
	}

	// MARK - Private

    /// Update Bindings for the Tweaks when a change is needed.
	private func updateBindingsForTweak(_ tweak: AnyTweak) {
		// Find any 1-to-1 bindings and update them
		tweakBindings[tweak.persistenceIdentifier]?.forEach {
			$0.applyBindingWithValue(currentViewDataForTweak(tweak).value)
		}

		// Find any cluster bindings and update them
		for (tweakSet, bindingsArray) in tweakSetBindings {
			if tweakSet.contains(tweak) {
				bindingsArray.forEach { $0() }
			}
		}
	}
}

extension TweakStore {
	internal var sortedTweakCollections: [TweakCollection] {
		return tweakCollections
			.sorted { $0.0 < $1.0 }
			.map { return $0.1 }
	}
}
