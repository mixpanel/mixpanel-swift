//
//  JSONHandler.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class JSONHandler {

  typealias MPObjectToParse = Any

  class func encodeAPIData(_ obj: MPObjectToParse) -> String? {
    let data: Data? = serializeJSONObject(obj)

    guard let d = data else {
      MixpanelLogger.warn(message: "couldn't serialize object")
      return nil
    }

    return String(decoding: d, as: UTF8.self)
  }

  class func deserializeData(_ data: Data) -> MPObjectToParse? {
    var object: MPObjectToParse?
    do {
      object = try JSONSerialization.jsonObject(with: data, options: [])
    } catch {
      MixpanelLogger.warn(message: "exception decoding object data")
    }
    return object
  }

  class func serializeJSONObject(_ obj: MPObjectToParse) -> Data? {
    let serializableJSONObject: MPObjectToParse
    if let jsonObject = makeObjectSerializable(obj) as? [Any] {
      serializableJSONObject = jsonObject.filter {
        JSONSerialization.isValidJSONObject($0)
      }
    } else {
      serializableJSONObject = makeObjectSerializable(obj)
    }

    guard JSONSerialization.isValidJSONObject(serializableJSONObject) else {
      MixpanelLogger.warn(message: "object isn't valid and can't be serialzed to JSON")
      return nil
    }

    var serializedObject: Data?
    do {
      serializedObject =
        try JSONSerialization
        .data(withJSONObject: serializableJSONObject, options: [])
    } catch {
      MixpanelLogger.warn(message: "exception encoding api data")
    }
    return serializedObject
  }

  private class func makeObjectSerializable(_ obj: MPObjectToParse) -> MPObjectToParse {
    switch obj {
    case let obj as NSNumber:
      if isBoolNumber(obj) {
        return obj.boolValue
      } else if isInvalidNumber(obj) {
        return String(describing: obj)
      } else {
        return obj
      }

    case let obj as Double where obj.isFinite && !obj.isNaN:
      return obj

    case let obj as Float where obj.isFinite && !obj.isNaN:
      return obj

    case is String, is Int, is UInt, is UInt64, is Bool:
      return obj

    case let obj as [Any?]:
      // nil values in Array properties are dropped
      let nonNilEls: [Any] = obj.compactMap({ $0 })
      return nonNilEls.map { makeObjectSerializable($0) }

    case let obj as [Any]:
      return obj.map { makeObjectSerializable($0) }

    case let obj as InternalProperties:
      var serializedDict = InternalProperties()
      _ = obj.map { e in
        serializedDict[e.key] =
          makeObjectSerializable(e.value)
      }
      return serializedDict

    case let obj as Date:
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
      dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
      dateFormatter.locale = Locale(identifier: "en_US_POSIX")
      return dateFormatter.string(from: obj)

    case let obj as URL:
      return obj.absoluteString

    default:
      let objString = String(describing: obj)
      if objString == "nil" {
        // all nil properties outside of Arrays are converted to NSNull()
        return NSNull()
      } else {
        MixpanelLogger.info(message: "enforcing string on object")
        return objString
      }
    }
  }

  private class func isBoolNumber(_ num: NSNumber) -> Bool {
    let boolID = CFBooleanGetTypeID()
    let numID = CFGetTypeID(num)
    return numID == boolID
  }

  private class func isInvalidNumber(_ num: NSNumber) -> Bool {
    return num.doubleValue.isInfinite || num.doubleValue.isNaN
  }
}
