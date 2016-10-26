//
//  TweakLibrary.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/6/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import Foundation

/// Create a public struct in your application that conforms to this protocol to declare your own tweaks!
public protocol TweakLibraryType {
	static var defaultStore: TweakStore { get }
}

extension TweakLibraryType {
	/**
    Returns the current value for a tweak from the TweakLibrary's default store.

    - parameter tweak:      the tweak to assign
    */
	public static func assign<T>(_ tweak: Tweak<T>) -> T {
		return self.defaultStore.currentValueForTweak(tweak)
	}

	/**
    Immediately binds the currentValue of a given tweak, and then continues to update whenever the tweak changes.

    - parameter tweak:      the tweak to bind
    - parameter binding:    the binding to issue for the tweak
    */
	public static func bind<T>(_ tweak: Tweak<T>, binding: @escaping (T) -> Void) {
		self.defaultStore.bind(tweak, binding: binding)
	}

    internal static func bindMultiple(_ tweaks: [TweakType], binding: @escaping () -> Void) {
		self.defaultStore.bindMultiple(tweaks, binding: binding)
	}
}
