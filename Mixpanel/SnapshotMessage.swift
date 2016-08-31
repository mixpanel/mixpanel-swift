//
//  SnapshotMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class SnapshotRequest: BaseWebSocketMessage {

    init() {
        super.init(type: "snapshot_request")
    }

    var configurarion: ObjectSerializerConfig? {
        get {
            if let config = payload["config"] as? [String: Any] {
                return ObjectSerializerConfig(dict: config)
            }
            return nil
        }
    }

    override func responseCommand(connection: WebSocketWrapper) -> Operation? {
        var serializerConfig = configurarion
        let imageHash = payload["image_hash"] as? String

        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            // Update the class descriptions in the connection session if provided as part of the message.
            if serializerConfig != nil {
                connection.setSessionObjectSynchronized(value: serializerConfig!, key: "snapshot_class_descriptions")
            } else if let sessionObject = connection.getSessionObjectSynchronized(key: "snapshot_class_descriptions") {
                // Get the class descriptions from the connection session store.
                serializerConfig = sessionObject as? ObjectSerializerConfig
            } else {
                // If neither place has a config, this is probably a stale message and we can't create a snapshot.
                return
            }

            // Get the object identity provider from the connection's session store or create one if there is none already.
            var objectIdentityProvider = connection.getSessionObjectSynchronized(key: "object_identity_provider")
            if objectIdentityProvider == nil {
                objectIdentityProvider = ObjectIdentityProvider()
                connection.setSessionObjectSynchronized(value: objectIdentityProvider, key: "object_identity_provider")
            }

            let serializer = ApplicationStateSerializer(application: UIApplication.shared,
                                                        configuration: serializerConfig!,
                                                        objectIdentityProvider: objectIdentityProvider as! ObjectIdentityProvider)

            let response = SnapshotResponse()
            var screenshot: UIImage? = nil
            var serializedObjects: [String: AnyObject]? = nil

            DispatchQueue.main.sync {
                screenshot = serializer.getScreenshotForWindow(index: 0)
            }
            response.screenshot = screenshot

            if imageHash == response.imageHash {
                serializedObjects = connection.getSessionObjectSynchronized(key: "snapshot_hierarchy") as? [String: AnyObject]
            } else {
                DispatchQueue.main.sync {
                    serializedObjects = serializer.getObjectHierarchyForWindow(index: 0)
                }
                connection.setSessionObjectSynchronized(value: serializedObjects, key: "snapshot_hierarchy")
            }

            response.serializedObjects = serializedObjects
            connection.sendMessage(message: response)
        }

        return operation
    }
}

class SnapshotResponse: BaseWebSocketMessage {
    var screenshot: UIImage? {
        get {
            if let base64Image = payload["screenshot"] as? String,
                let imageData = Data(base64Encoded: base64Image, options: [.ignoreUnknownCharacters]) {
                return UIImage(data: imageData)
            }
            return nil
        }
        set {
            if let snapshot = newValue {
                if let jpegSnapshotImageData = UIImageJPEGRepresentation(snapshot, 0.5) {
                    payload["screenshot"] = jpegSnapshotImageData.base64EncodedString(options: [.lineLength64Characters]) as AnyObject
                    self.imageHash = getImageHash(imageData: jpegSnapshotImageData)
                    payload["image_hash"] = self.imageHash as AnyObject
                }
            }
        }
    }
    var serializedObjects: [String: AnyObject]? {
        get {
            return payload["serialized_objects"] as? [String: AnyObject]
        }
        set {
            payload["serialized_objects"] = newValue as AnyObject
        }
    }
    var imageHash: String? = nil

    init() {
        super.init(type: "snapshot_response")
    }

    func getImageHash(imageData: Data) -> String {
        let array = imageData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: imageData.count))
        }
        let hash = NSMutableString()
        for i in 0..<16 {
            hash.appendFormat("%02X", array[i])
        }
        return hash as String
    }

}
