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
            Logger.warn(message: "couldn't serialize object")
            return nil
        }

        let base64Encoded = d.base64EncodedString(options: .lineLength64Characters)

        guard let b64 = base64Encoded
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
            Logger.warn(message: "couldn't replace characters to allowed URL character set")
            return nil
        }

        return b64
    }

     class func serializeJSONObject(_ obj: MPObjectToParse) -> Data? {
        let serializableJSONObject = makeObjectSerializable(obj)

        guard JSONSerialization.isValidJSONObject(serializableJSONObject) else {
            Logger.warn(message: "object isn't valid and can't be serialzed to JSON")
            return nil
        }
        var serializedObject: Data? = nil
        do {
            serializedObject = try JSONSerialization
                .data(withJSONObject: serializableJSONObject, options: [])
        } catch {
            Logger.warn(message: "exception encoding api data")
        }
        return serializedObject
    }

    private class func makeObjectSerializable(_ obj: MPObjectToParse) -> MPObjectToParse {
        switch obj {
        case let obj as Double where obj.isFinite:
            return obj
            
        case is String, is Int, is UInt, is UInt64, is Float, is Bool:
            return obj

        case let obj as Array<Any>:
            return obj.map() { makeObjectSerializable($0) }

        case let obj as InternalProperties:
            var serializedDict = InternalProperties()
            _ = obj.map() { e in
                serializedDict[e.key] =
                    makeObjectSerializable(e.value) }
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
            Logger.info(message: "enforcing string on object")
            return String(describing: obj)
        }
    }

}
