//
//  WebSocketWrapper.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/25/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class WebSocketWrapper: WebSocketDelegate {
    static let sessionVariantKey = "session_variant"
    static let startLoadingAnimationKey = "connectivityBarLoading"
    static let finishLoadingAnimationKey = "connectivtyBarFinished"
    var open: Bool
    var connected: Bool
    let url: URL
    var session: [String: Any]
    let webSocket: WebSocket
    let commandQueue: OperationQueue
    var recordingView: UIView? = nil
    var indeterminateLayer: CALayer? = nil
    var connectivityIndiciatorWindow: UIWindow? = nil
    let connectCallback: (() -> Void)?
    let disconnectCallback: (() -> Void)?

    enum MessageType: String {
        case snapshot = "snapshot_request"
        case changeRequest = "change_request"
        case deviceInfo = "device_info_request"
        case disconnect = "disconnect"
        case binding = "event_binding_request"
    }


    init(url: URL, keepTrying: Bool, connectCallback: (() -> Void)?, disconnectCallback: (() -> Void)?) {
        open = false
        connected = false
        session = [String: Any]()
        self.url = url
        self.connectCallback = connectCallback
        self.disconnectCallback = disconnectCallback

        commandQueue = OperationQueue()
        commandQueue.maxConcurrentOperationCount = 1
        commandQueue.isSuspended = true

        webSocket = WebSocket(url: url)
        webSocket.delegate = self

        if keepTrying {
            open(initiate: true, maxInterval: 30, maxRetries: 40)
        } else {
            open(initiate: true)
        }
    }

    func setSessionObjectSynchronized(value: Any, key: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        session[key] = value
    }

    func getSessionObjectSynchronized(key: String) -> Any? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        return session[key]
    }

    func open(initiate: Bool, maxInterval: Int = 0, maxRetries: Int = 0) {
        var retries = 0

        Logger.debug(message: "In opening connection. Initiate: \(initiate), "
            + "retries: \(retries), maxRetries: \(maxRetries), "
            + "maxInterval: \(maxInterval), connected: \(connected)")

        if connected || retries > maxRetries {
            // exit retry loop if any of the conditions are met
            retries = 0
        } else if initiate || retries > 0 {
            if !open {
                Logger.debug(message: "Attempting to open WebSocket to \(url), try \(retries) out of \(maxRetries)")
                open = true
                webSocket.connect()
            }
        }
        if retries < maxRetries {
            DispatchQueue.main.asyncAfter(deadline: .now() + min(pow(1.4, Double(retries)), Double(maxInterval))) {
                self.open(initiate: false, maxInterval: maxInterval, maxRetries: maxRetries)
            }
            retries += 1
        }
    }

    func close() {
        webSocket.disconnect()
    }

    func sendMessage(message: BaseWebSocketMessage?) {
        if connected {
            Logger.debug(message: "Sending message: \(message.debugDescription)")
            if let data = message?.JSONData(), let jsonString = String(data: data, encoding: String.Encoding.utf8) {
                webSocket.write(string: jsonString)
            }
        }
    }

    class func getMessageType(message: Data) -> BaseWebSocketMessage? {
        Logger.info(message: "raw message \(message)")
        var webSocketMessage: BaseWebSocketMessage? = nil

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: message, options: [])
            if let messageDict = jsonObject as? [String: Any] {
                guard let type = messageDict["type"] as? String,
                    let typeEnum = MessageType.init(rawValue: type) else {
                        return nil
                }
                let payload = messageDict["payload"] as? [String: AnyObject]

                switch typeEnum {
                case .snapshot:
                    webSocketMessage = SnapshotRequest(payload: payload)
                case .changeRequest:
                    break
                case .deviceInfo:
                    webSocketMessage = DeviceInfoRequest()
                case .disconnect:
                    webSocketMessage = DisconnectMessage()
                case .binding:
                    webSocketMessage = BindingRequest(payload: payload)
                }
            } else {
                Logger.warn(message: "Badly formed socket message, expected JSON dictionary.")
            }
        } catch {
            Logger.warn(message: "Badly formed socket message, can't serialize object.")
        }

        return webSocketMessage
    }

    func showConnectedView(loading: Bool) {
        if connectivityIndiciatorWindow == nil {
            guard let mainWindow = UIApplication.shared.delegate?.window, let window = mainWindow else {
                return
            }
            connectivityIndiciatorWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: window.frame.size.width, height: 4))
            connectivityIndiciatorWindow?.backgroundColor = UIColor.clear
            connectivityIndiciatorWindow?.windowLevel = UIWindowLevelAlert
            connectivityIndiciatorWindow?.alpha = 0
            connectivityIndiciatorWindow?.isHidden = false
            recordingView = UIView(frame: connectivityIndiciatorWindow!.frame)
            recordingView?.backgroundColor = UIColor.clear
            indeterminateLayer = CALayer()
            indeterminateLayer?.backgroundColor = UIColor(red: 1/255.0, green: 179/255.0, blue: 109/255.0, alpha: 1).cgColor
            indeterminateLayer?.frame = CGRect(x: 0, y: 0, width: 0, height: 4)
            recordingView?.layer.addSublayer(indeterminateLayer!)
            connectivityIndiciatorWindow?.addSubview(recordingView!)
            connectivityIndiciatorWindow?.bringSubview(toFront: recordingView!)
        }
        animateConnecting(loading: loading)
    }

    func animateConnecting(loading: Bool) {
        if loading {
            loadBasicAnimation(duration: 10,
                               fromValue: 0,
                               toValue: connectivityIndiciatorWindow!.bounds.size.width * 1.9,
                               animationKey: WebSocketWrapper.startLoadingAnimationKey)
        } else {
            indeterminateLayer?.removeAnimation(forKey: WebSocketWrapper.startLoadingAnimationKey)
            loadBasicAnimation(duration: 0.4,
                               fromValue: indeterminateLayer?.presentation()?.value(forKey: "bounds.size.width"),
                               toValue: connectivityIndiciatorWindow!.bounds.size.width * 2,
                               animationKey: WebSocketWrapper.finishLoadingAnimationKey)
        }
    }

    func loadBasicAnimation(duration: Double, fromValue: Any, toValue: Any, animationKey: String) {
        let myAnimation = CABasicAnimation(keyPath: "bounds.size.width")
        myAnimation.duration = duration
        myAnimation.fromValue = fromValue
        myAnimation.toValue = toValue
        myAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        myAnimation.fillMode = kCAFillModeForwards
        myAnimation.isRemovedOnCompletion = false
        indeterminateLayer?.add(myAnimation, forKey: animationKey)
    }

    func hideConnectedView() {
        if connectivityIndiciatorWindow != nil {
            indeterminateLayer?.removeFromSuperlayer()
            recordingView?.removeFromSuperview()
            connectivityIndiciatorWindow?.isHidden = true
        }
        connectivityIndiciatorWindow = nil
    }

    func websocketDidReceiveMessage(_ socket: WebSocket, text: String) {
        if !connected {
            connected = true
            showConnectedView(loading: false)
            if let callback = connectCallback {
                callback()
            }
        }
        if let messageData = text.data(using: String.Encoding.utf8) {
            let message = WebSocketWrapper.getMessageType(message: messageData)
            Logger.info(message: "WebSocket received message: \(message.debugDescription)")
            if let commandOperation = message?.responseCommand(connection: self) {
                commandQueue.addOperation(commandOperation)
            }
        }
    }

    func websocketDidReceiveData(_ socket: WebSocket, data: Data) {
        if !connected {
            connected = true
            showConnectedView(loading: false)
            if let callback = connectCallback {
                callback()
            }
        }

        let message = WebSocketWrapper.getMessageType(message: data)
        Logger.info(message: "WebSocket received message: \(message.debugDescription)")
        if let commandOperation = message?.responseCommand(connection: self) {
            commandQueue.addOperation(commandOperation)
        }

    }

    func websocketDidConnect(_ socket: WebSocket) {
        Logger.info(message: "WebSocket \(socket) did open")
        commandQueue.isSuspended = false
        showConnectedView(loading: true)
    }

    func websocketDidDisconnect(_ socket: WebSocket, error: NSError?) {
        Logger.debug(message: "WebSocket disconnected because of: \(error?.description)")

        commandQueue.isSuspended = true
        commandQueue.cancelAllOperations()
        hideConnectedView()
        open = false
        if connected {
            connected = false
            open(initiate: true, maxInterval: 10, maxRetries: 10)
            if let callback = disconnectCallback {
                callback()
            }
        }
    }



}
