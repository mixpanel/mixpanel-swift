//
//  SnapshotMessage.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/26/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

class SnapshotRequest: BaseWebSocketMessage {

    init?(payload: [String: AnyObject]?) {
        guard let payload = payload else {
            return nil
        }
        super.init(type: MessageType.snapshotRequest.rawValue, payload: payload)
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
        guard let sharedApplication = MixpanelInstance.sharedUIApplication() else {
            return nil
        }
        var serializerConfig = configurarion
        let imageHash = payload["image_hash"] as? String

        let operation = BlockOperation { [weak connection] in
            guard let connection = connection else {
                return
            }

            // Update the class descriptions in the connection session if provided as part of the message.
            if serializerConfig != nil {
                connection.setSessionObjectSynchronized(with: serializerConfig!, for: "snapshot_class_descriptions")
            } else if let sessionObject = connection.getSessionObjectSynchronized(for: "snapshot_class_descriptions") {
                // Get the class descriptions from the connection session store.
                serializerConfig = sessionObject as? ObjectSerializerConfig
            } else {
                // If neither place has a config, this is probably a stale message and we can't create a snapshot.
                return
            }

            // Get the object identity provider from the connection's session store or create one if there is none already.
            var objectIdentityProvider = connection.getSessionObjectSynchronized(for: "object_identity_provider")
            if objectIdentityProvider == nil {
                objectIdentityProvider = ObjectIdentityProvider()
                connection.setSessionObjectSynchronized(with: objectIdentityProvider!, for: "object_identity_provider")
            }

            let serializer = ApplicationStateSerializer(application: sharedApplication,
                                                        configuration: serializerConfig!,
                                                        objectIdentityProvider: objectIdentityProvider as! ObjectIdentityProvider)

            let response = SnapshotResponse()
            var screenshot: UIImage? = nil
            var serializedObjects: [String: AnyObject]!

            DispatchQueue.main.sync {
                screenshot = serializer.getScreenshotForWindow(at: 0)
            }
            response.screenshot = screenshot

            if imageHash == response.imageHash {
                serializedObjects = connection.getSessionObjectSynchronized(for: "snapshot_hierarchy") as? [String: AnyObject]
            } else {
                DispatchQueue.main.sync {
                    serializedObjects = serializer.getObjectHierarchyForWindow(at: 0)
                }
                connection.setSessionObjectSynchronized(with: serializedObjects!, for: "snapshot_hierarchy")
            }

            response.serializedObjects = serializedObjects
            connection.send(message: response)
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
                if let jpegSnapshotImageData = snapshot.jpegData(compressionQuality: 0.5) {
                    payload["screenshot"] = jpegSnapshotImageData.base64EncodedString(options: [.lineLength64Characters]) as AnyObject
                    self.imageHash = getImageHash(imageData: jpegSnapshotImageData)
                    payload["image_hash"] = self.imageHash as AnyObject
                }
            }
        }
    }
    var serializedObjects: [String: AnyObject] {
        get {
            return payload["serialized_objects"] as! [String: AnyObject]
        }
        set {
            payload["serialized_objects"] = newValue as AnyObject
        }
    }
    var imageHash: String!

    init() {
        super.init(type: MessageType.snapshotResponse.rawValue)
    }

    func getImageHash(imageData: Data) -> String {
        return imageData.md5().toHexString()
    }

}
