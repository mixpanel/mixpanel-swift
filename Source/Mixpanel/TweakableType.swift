//
//  TweakableType.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/5/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

/// To add a new <T> to our Tweak<T>, make T conform to this protocol.
public protocol TweakableType {
    /// The data type of the TweakableType
	static var tweakViewDataType: TweakViewDataType { get }
}

/// The data types that are currently supported for SwiftTweaks.
/// While Tweak<T> is generic, we have to build UI for editing each kind of <T>
/// - hence the need for a protocol to restrict what can be tweaked.
/// Of course, we can add new TweakViewDataTypes over time, too!
public enum TweakViewDataType {
    /// TweakableType supports the boolean type
	case boolean
    /// TweakableType supports the integer type
	case integer
    /// TweakableType supports the cgFloat type
	case cgFloat
    /// TweakableType supports the double type
	case double
    /// TweakableType supports the string type
    case string

    static let allTypes: [TweakViewDataType] = [
		.boolean, .integer, .cgFloat, .double, .string
	]
}

/// An enum for use inside Tweaks' editing UI.
/// Our public type-erasure (AnyTweak) means that this has to be public, unfortunately
/// ...but there's no need for you to directly use this enum.
enum TweakDefaultData {
	case boolean(defaultValue: Bool)
	case integer(defaultValue: Int, min: Int?, max: Int?, stepSize: Int?)
	case float(defaultValue: CGFloat, min: CGFloat?, max: CGFloat?, stepSize: CGFloat?)
	case doubleTweak(defaultValue: Double, min: Double?, max: Double?, stepSize: Double?)
    case string(defaultValue: String)
}

// MARK: Types that conform to TweakableType

extension Bool: TweakableType {
    /// TweakableType supports the boolean type
    public static var tweakViewDataType: TweakViewDataType {
		return .boolean
	}
}

extension Int: TweakableType {
    /// TweakableType supports the integer type
    public static var tweakViewDataType: TweakViewDataType {
		return .integer
	}
}

extension CGFloat: TweakableType {
    /// TweakableType supports the cgFloat type
    public static var tweakViewDataType: TweakViewDataType {
		return .cgFloat
	}
}

extension Double: TweakableType {
    /// TweakableType supports the double type
    public static var tweakViewDataType: TweakViewDataType {
		return .double
	}
}

extension String: TweakableType {
    /// TweakableType supports the string type
    public static var tweakViewDataType: TweakViewDataType {
        return .string
    }
}
