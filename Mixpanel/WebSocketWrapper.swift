//
//  WebSocketWrapper.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/25/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import UIKit

enum MessageType: String {
    case bindingRequest = "event_binding_request"
    case bindingResponse = "event_binding_response"
    case deviceInfoRequest = "device_info_request"
    case deviceInfoResponse = "device_info_response"
    case disconnect = "disconnect"
    case snapshotRequest = "snapshot_request"
    case snapshotResponse = "snapshot_response"
    case changeRequest = "change_request"
    case changeResponse = "change_response"
    case tweakRequest = "tweak_request"
    case tweakResponse = "tweak_response"
    case clearRequest = "clear_request"
    case clearResponse = "clear_response"
}

class WebSocketWrapper: WebSocketDelegate {
    static let sessionVariantKey = "session_variant"
    static let startLoadingAnimationKey = "connectivityBarLoading"
    static let finishLoadingAnimationKey = "connectivtyBarFinished"
    static var retries = 0
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

    func setSessionObjectSynchronized(with value: Any, for key: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        session[key] = value
    }

    func getSessionObjectSynchronized(for key: String) -> Any? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        return session[key]
    }

    func open(initiate: Bool, maxInterval: Int = 0, maxRetries: Int = 0) {
        Logger.debug(message: "In opening connection. Initiate: \(initiate), "
            + "retries: \(WebSocketWrapper.retries), maxRetries: \(maxRetries), "
            + "maxInterval: \(maxInterval), connected: \(connected)")

        if connected || WebSocketWrapper.retries > maxRetries {
            // exit retry loop if any of the conditions are met
            WebSocketWrapper.retries = 0
        } else if initiate || WebSocketWrapper.retries > 0 {
            if !open {
                Logger.debug(message: "Attempting to open WebSocket to \(url), try \(WebSocketWrapper.retries) out of \(maxRetries)")
                open = true
                webSocket.connect()
            }
        }
        if WebSocketWrapper.retries < maxRetries {
            DispatchQueue.main.asyncAfter(deadline: .now() + min(pow(1.4, Double(WebSocketWrapper.retries)), Double(maxInterval))) {
                self.open(initiate: false, maxInterval: maxInterval, maxRetries: maxRetries)
            }
            WebSocketWrapper.retries += 1
        }
    }

    func close() {
        webSocket.disconnect()
        for value in session.values {
            if let value = value as? CodelessBindingCollection {
                value.cleanup()
            }
        }
    }

    deinit {
        webSocket.delegate = nil
        close()
    }

    func send(message: BaseWebSocketMessage?) {
        if connected {
            Logger.debug(message: "Sending message: \(message.debugDescription)")
            if let data = message?.JSONData(), let jsonString = String(data: data, encoding: String.Encoding.utf8) {
                webSocket.write(string: jsonString)
            }
        }
    }

    class func getMessageType(for message: Data) -> BaseWebSocketMessage? {
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
                case .snapshotRequest:
                    webSocketMessage = SnapshotRequest(payload: payload)
                case .deviceInfoRequest:
                    webSocketMessage = DeviceInfoRequest()
                case .disconnect:
                    webSocketMessage = DisconnectMessage()
                case .bindingRequest:
                    webSocketMessage = BindingRequest(payload: payload)
                case .changeRequest:
                    webSocketMessage = ChangeRequest(payload: payload)
                case .tweakRequest:
                    webSocketMessage = TweakRequest(payload: payload)
                case .clearRequest:
                    webSocketMessage = ClearRequest(payload: payload)
                default:
                    Logger.debug(message: "the type that was not parsed: \(type)")
                    break
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

            UIView.animate(withDuration: 0.3) {
                self.connectivityIndiciatorWindow?.alpha = 1
            }
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
                               fromValue: indeterminateLayer?.presentation()?.value(forKey: "bounds.size.width") ?? 0.0,
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
        var shouldShowUI = false
        if !connected {
            connected = true
            showConnectedView(loading: true)
            shouldShowUI = true
            if let callback = connectCallback {
                callback()
            }
        }
        if let messageData = text.data(using: String.Encoding.utf8) {
            let message = WebSocketWrapper.getMessageType(for: messageData)
            Logger.info(message: "WebSocket received message: \(message.debugDescription)")
            if let commandOperation = message?.responseCommand(connection: self) {
                commandQueue.addOperation(commandOperation)
                if shouldShowUI {
                    showConnectedView(loading: false)
                }
            } else if shouldShowUI {
                hideConnectedView()
            }
        }
    }

    func websocketDidReceiveData(_ socket: WebSocket, data: Data) {
        var shouldShowUI = false
        if !connected {
            connected = true
            showConnectedView(loading: true)
            shouldShowUI = true
            if let callback = connectCallback {
                callback()
            }
        }

        let message = WebSocketWrapper.getMessageType(for: data)
        Logger.info(message: "WebSocket received message: \(message.debugDescription)")
        if let commandOperation = message?.responseCommand(connection: self) {
            commandQueue.addOperation(commandOperation)
            if shouldShowUI {
                showConnectedView(loading: false)
            }
        } else {
            hideConnectedView()
        }

    }

    func websocketDidConnect(_ socket: WebSocket) {
        Logger.info(message: "WebSocket \(socket) did open")
        commandQueue.isSuspended = false
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
