//
//  JSONHandler.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class JSONHandler {

    typealias MPObjectToParse = AnyObject

    class func encodeAPIData(obj: MPObjectToParse) -> String? {
        let data: NSData? = serializeJSONObject(obj)

        guard let d = data else {
            Logger.warn(message: "couldn't serialize object")
            return nil
        }

        let base64Encoded = d.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)

        guard let b64 = base64Encoded
            .stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) else {
                Logger.warn(message: "couldn't replace characters to allowed URL character set")
                return nil
        }

        return b64
    }

     class func serializeJSONObject(obj: MPObjectToParse) -> NSData? {
        let serializableJSONObject = makeObjectSerializable(obj)

        guard NSJSONSerialization.isValidJSONObject(serializableJSONObject) else {
            Logger.warn(message: "object isn't valid and can't be serialzed to JSON")
            return nil
        }
        var serializedObject: NSData? = nil
        do {
            serializedObject = try NSJSONSerialization
                .dataWithJSONObject(serializableJSONObject, options: [])
        } catch {
            Logger.warn(message: "exception encoding api data")
        }
        return serializedObject
    }

    private class func makeObjectSerializable(obj: MPObjectToParse) -> MPObjectToParse {
        switch obj {
        case is String, is Int, is UInt, is Double, is Float:
            return obj

        case let obj as Array<AnyObject>:
            return obj.map() { makeObjectSerializable($0) }

        case let obj as Properties:
            var serializedDict = Properties()
            _ = obj.map() { (k, v) in
                serializedDict[k] =
                    makeObjectSerializable(v) }
            return serializedDict

        case let obj as NSDate:
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC")
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
            return dateFormatter.stringFromDate(obj)

        case let obj as NSURL:
            return obj.absoluteString

        default:
            Logger.info(message: "enforcing string on object")
            return obj.description
        }
    }

}
