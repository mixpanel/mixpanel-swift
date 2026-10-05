//
//  Flush.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol FlushDelegate: AnyObject {
    func flush(performFullFlush: Bool, completion: (() -> Void)?)

    #if os(iOS)
    func updateNetworkActivityIndicator(_ on: Bool)
    #endif  // os(iOS)
}

/// Outcome of sending one batch. Tells the flush loop whether to delete the batch and
/// whether to keep going.
enum FlushBatchResult {
    /// Delivered; delete the rows.
    case sent
    /// Could not be serialized and would never succeed; delete the rows.
    case dropped
    /// The request failed; keep the rows for a later flush.
    case failed
    /// Backoff is active or tracking is opted out; nothing was sent.
    case notAllowed
}

class Flush: AppLifecycle {
    var timer: Timer?
    weak var delegate: FlushDelegate?
    var useIPAddressForGeoLocation = true
    var flushRequest: FlushRequest
    var flushOnBackground = true
    var _flushInterval = 0.0
    var _flushBatchSize = APIConstants.maxBatchSize
    private var _serverURL = BasePath.DefaultMixpanelAPI
    private var _backupHost: String?
    private let flushRequestReadWriteLock: DispatchQueue

    var useGzipCompression: Bool

    var serverURL: String {
        get {
            flushRequestReadWriteLock.sync {
                return _serverURL
            }
        }
        set {
            flushRequestReadWriteLock.sync(
                flags: .barrier,
                execute: {
                    _serverURL = newValue
                    self.flushRequest.serverURL = newValue
                })
        }
    }

    var backupHost: String? {
        get {
            flushRequestReadWriteLock.sync {
                return _backupHost
            }
        }
        set {
            flushRequestReadWriteLock.sync(
                flags: .barrier,
                execute: {
                    _backupHost = newValue
                    self.flushRequest.backupHost = newValue
                })
        }
    }

    var flushInterval: Double {
        get {
            flushRequestReadWriteLock.sync {
                return _flushInterval
            }
        }
        set {
            flushRequestReadWriteLock.sync(
                flags: .barrier,
                execute: {
                    _flushInterval = newValue
                })

            if self.flushInterval > 0 {
                delegate?.flush(performFullFlush: false, completion: nil)
            }
            startFlushTimer()
        }
    }

    var flushBatchSize: Int {
        get {
            return _flushBatchSize
        }
        set {
            _flushBatchSize = newValue
        }
    }

    required init(serverURL: String, useGzipCompression: Bool) {
        self.flushRequest = FlushRequest(serverURL: serverURL)
        self.useGzipCompression = useGzipCompression
        _serverURL = serverURL
        flushRequestReadWriteLock = DispatchQueue(
            label: "com.mixpanel.flush_interval.lock", qos: .utility, attributes: .concurrent,
            autoreleaseFrequency: .workItem)
    }

    /// Sends a single batch synchronously and reports the outcome. Deleting rows is left to the
    /// caller, which owns database access.
    func sendBatch(
        _ batch: Queue, type: FlushType, headers: [String: String], queryItems: [URLQueryItem]
    ) -> FlushBatchResult {
        if flushRequest.requestNotAllowed() {
            return .notAllowed
        }
        MixpanelLogger.debug(message: "Sending batch of data")
        MixpanelLogger.debug(message: batch as Any)
        guard let requestData = autoreleasepool(invoking: { JSONHandler.encodeAPIData(batch) }) else {
            MixpanelLogger.warn(message: "Failed to serialize batch, dropping \(batch.count) records")
            return .dropped
        }

        #if os(iOS)
        if !MixpanelInstance.isiOSAppExtension() {
            delegate?.updateNetworkActivityIndicator(true)
        }
        #endif  // os(iOS)
        let success = flushRequest.sendRequest(
            requestData,
            type: type,
            useIP: useIPAddressForGeoLocation,
            headers: headers,
            queryItems: queryItems, useGzipCompression: useGzipCompression)
        #if os(iOS)
        if !MixpanelInstance.isiOSAppExtension() {
            delegate?.updateNetworkActivityIndicator(false)
        }
        #endif  // os(iOS)
        return success ? .sent : .failed
    }

    func startFlushTimer() {
        stopFlushTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            if self.flushInterval > 0 {
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(
                    timeInterval: self.flushInterval,
                    target: self,
                    selector: #selector(self.flushSelector),
                    userInfo: nil,
                    repeats: true)
            }
        }
    }

    @objc func flushSelector() {
        delegate?.flush(performFullFlush: true, completion: nil)
    }

    func stopFlushTimer() {
        if let timer = timer {
            DispatchQueue.main.async { [weak self, timer] in
                timer.invalidate()
                self?.timer = nil
            }
        }
    }

    // MARK: - Lifecycle
    func applicationDidBecomeActive() {
        startFlushTimer()
    }

    func applicationWillResignActive() {
        stopFlushTimer()
    }

}
