//
//  TweakPersistency.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 11/16/15.
//  Copyright © 2015 Khan Academy. All rights reserved.
//

import UIKit

/// Identifies tweaks in TweakPersistency
internal protocol TweakIdentifiable {
	var persistenceIdentifier: String { get }
}

/// Caches Tweak values
internal typealias TweakCache = [String: TweakableType]


/// Persists state for tweaks in a TweakCache
internal final class TweakPersistency {
	private let diskPersistency: TweakDiskPersistency

	private var tweakCache: TweakCache = [:]

	init(identifier: String) {
		self.diskPersistency = TweakDiskPersistency(identifier: identifier)
		self.tweakCache = self.diskPersistency.loadFromDisk()
	}

	internal func currentValueForTweak<T>(_ tweak: Tweak<T>) -> T? {
		return persistedValueForTweakIdentifiable(AnyTweak(tweak: tweak)) as? T
	}

	internal func currentValueForTweak<T>(_ tweak: Tweak<T>) -> T? where T: SignedNumeric & Comparable {
		if let currentValue = persistedValueForTweakIdentifiable(AnyTweak(tweak: tweak)) as? T {
				// If the tweak can be clipped, then we'll need to clip it - because
				// the tweak might've been persisted without a min / max, but then you changed the tweak definition.
				// example: you tweaked it to 11, then set a max of 10 - the persisted value is still 11!
				return clip(currentValue, tweak.minimumValue, tweak.maximumValue)
		}

		return nil
	}

	internal func persistedValueForTweakIdentifiable(_ tweakID: TweakIdentifiable) -> TweakableType? {
		return tweakCache[tweakID.persistenceIdentifier]
	}

	internal func setValue(_ value: TweakableType?, forTweakIdentifiable tweakID: TweakIdentifiable) {
		tweakCache[tweakID.persistenceIdentifier] = value
		self.diskPersistency.saveToDisk(tweakCache)
	}

	internal func clearAllData() {
		tweakCache = [:]
		self.diskPersistency.saveToDisk(tweakCache)
	}
}

/// Persists a TweakCache on disk using NSCoding
private final class TweakDiskPersistency {
	private let fileURL: URL

	private static func fileURLForIdentifier(_ identifier: String) -> URL {
        return try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			.appendingPathComponent("MPSwiftTweaks")
			.appendingPathComponent("\(identifier)")
			.appendingPathExtension("db")
	}

	private let queue = DispatchQueue(label: "org.khanacademy.swift_tweaks.disk_persistency", attributes: [])

	init(identifier: String) {
		self.fileURL = TweakDiskPersistency.fileURLForIdentifier(identifier)
		self.ensureDirectoryExists()
	}

	/// Creates a directory (if needed) for our persisted TweakCache on disk
	private func ensureDirectoryExists() {
		(self.queue).async {
			try! FileManager.default.createDirectory(at: self.fileURL.deletingLastPathComponent(),
			                                         withIntermediateDirectories: true,
			                                         attributes: nil)
		}
	}

    func loadFromDisk() -> TweakCache {
        var result: TweakCache!

        self.queue.sync {
            NSKeyedUnarchiver.setClass(Data.self, forClassName: "Data")
            result = (try? Foundation.Data(contentsOf: self.fileURL))
                .flatMap(NSKeyedUnarchiver.unarchiveObject(with:))
                .flatMap { $0 as? Data }
                .map { $0.cache }
                ?? [:]
        }

        return result
    }

    func saveToDisk(_ data: TweakCache) {
        self.queue.async {
            let data = Data(cache: data)
            NSKeyedArchiver.setClassName("Data", for: type(of: data))
            let nsData = NSKeyedArchiver.archivedData(withRootObject: data)
            try? nsData.write(to: self.fileURL, options: [.atomic])
        }
    }

	/// Implements NSCoding for TweakCache.
	/// TweakCache a flat dictionary: [String: TweakableType].
	/// However, because re-hydrating TweakableType from its underlying NSNumber gets Bool & Int mixed up,
    /// we have to persist a different structure on disk: [TweakViewDataType: [String: AnyObject]]
	/// This ensures that if something was saved as a Bool, it's read back as a Bool.
	@objc(TweakDiskPersistencyData) private final class Data: NSObject, NSCoding {
		let cache: TweakCache

		init(cache: TweakCache) {
			self.cache = cache
		}

		@objc convenience init?(coder aDecoder: NSCoder) {
			var cache: TweakCache = [:]

			// Read through each TweakViewDataType...
			for dataType in TweakViewDataType.allTypes {
				// If a sub-dictionary exists for that type,
				if let dataTypeDictionary = aDecoder.decodeObject(forKey: dataType.nsCodingKey) as? Dictionary<String, AnyObject> {
					// Read through each entry and populate the cache
					for (key, value) in dataTypeDictionary {
						if let value = Data.tweakableTypeWithAnyObject(value, withType: dataType) {
							cache[key] = value
						}
					}
				}
			}

			self.init(cache: cache)
		}

		@objc fileprivate func encode(with aCoder: NSCoder) {

			// Our "dictionary of dictionaries" that is persisted on disk
			var diskPersistedDictionary: [TweakViewDataType : [String: AnyObject]] = [:]

			// For each thing in our TweakCache,
			for (key, value) in cache {
				let dataType = type(of: value).tweakViewDataType

				// ... create the "sub-dictionary" if it doesn't already exist for a particular TweakViewDataType
				if diskPersistedDictionary[dataType] == nil {
					diskPersistedDictionary[dataType] = [:]
				}

				// ... and set the cached value inside the sub-dictionary.
				diskPersistedDictionary[dataType]![key] = value.nsCoding
			}

			// Now we persist the "dictionary of dictionaries" on disk!
			for (key, value) in diskPersistedDictionary {
				aCoder.encode(value, forKey: key.nsCodingKey)
			}
		}

		// Reads from the cache, casting to the appropriate TweakViewDataType
		private static func tweakableTypeWithAnyObject(_ anyObject: AnyObject, withType type: TweakViewDataType) -> TweakableType? {
			switch type {
			case .integer: return anyObject as? Int
			case .boolean: return anyObject as? Bool
			case .cgFloat: return anyObject as? CGFloat
			case .double: return anyObject as? Double
            case .string: return anyObject as? String
			}
		}
	}
}

private extension TweakViewDataType {
	/// Identifies our TweakViewDataType when in NSCoding. See implementation of TweakDiskPersistency.Data
	var nsCodingKey: String {
		switch self {
		case .boolean: return "boolean"
		case .integer: return "integer"
		case .cgFloat: return "cgfloat"
		case .double: return "double"
        case .string: return "string"
		}
	}
}

private extension TweakableType {
	/// Gets the underlying value from a Tweakable Type
	var nsCoding: AnyObject {
		switch type(of: self).tweakViewDataType {
			case .boolean: return self as AnyObject
			case .integer: return self as AnyObject
			case .cgFloat: return self as AnyObject
			case .double: return self as AnyObject
            case .string: return self as AnyObject
		}
	}
}
