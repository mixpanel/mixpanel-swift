//
//  TweakLibrary.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/6/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import Foundation

/// Create a public struct in your application that conforms to this protocol to declare your own tweaks!
protocol TweakLibraryType {
	static var defaultStore: TweakStore { get }
}

extension TweakLibraryType {
	/// Returns the current value for a tweak from the TweakLibrary's default store.
	public static func assign<T>(_ tweak: Tweak<T>) -> T {
		return self.defaultStore.currentValueForTweak(tweak)
	}

	/// Immediately binds the currentValue of a given tweak, and then continues to update whenever the tweak changes.
	public static func bind<T>(_ tweak: Tweak<T>, binding: @escaping (T) -> Void) {
		self.defaultStore.bind(tweak, binding: binding)
	}

	//  Accepts a collection of Tweaks, and immediately calls the updateHandler.
	/// The updateHandler is then re-called each time any of the collection's tweaks change.
	/// Inside the updateHandler, you'll need to use `assign` to get the tweaks' current values.
	internal static func bindMultiple(_ tweaks: [TweakType], binding: @escaping () -> Void) {
		self.defaultStore.bindMultiple(tweaks, binding: binding)
	}
}
