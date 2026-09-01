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
    func removeProcessedEntities(type: FlushType, ids: [Int32])

    #if os(iOS)
    func updateNetworkActivityIndicator(_ on: Bool)
    #endif  // os(iOS)
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

    func flushQueue(
        _ queue: Queue, type: FlushType, headers: [String: String], queryItems: [URLQueryItem]
    ) {
        if flushRequest.requestNotAllowed() {
            return
        }
        flushQueueInBatches(queue, type: type, headers: headers, queryItems: queryItems)
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

    /// Sends `queue` as one request. The caller reads at most `flushBatchSize` rows per queue,
    /// so what arrives here is already a single request's worth; draining more than that is the
    /// caller's loop, not this method's.
    ///
    /// Rows are removed only once the server has accepted them, or when they cannot be
    /// serialized at all — an unserializable batch would otherwise be re-read and retried by
    /// every later flush forever. A failed send leaves the rows queued for the next flush.
    func flushQueueInBatches(
        _ queue: Queue, type: FlushType, headers: [String: String], queryItems: [URLQueryItem]
    ) {
        guard !queue.isEmpty else {
            return
        }
        // Drains this batch's encoding temporaries before the caller's next queue is encoded,
        // rather than letting all three (events, people, groups) accumulate in one work item.
        autoreleasepool {
            let ids: [Int32] = queue.map { entity in
                (entity["id"] as? Int32) ?? 0
            }
            MixpanelLogger.debug(message: "Sending batch of data")
            MixpanelLogger.debug(message: queue as Any)

            guard let requestData = JSONHandler.encodeAPIData(queue) else {
                MixpanelLogger.warn(message: "Failed to serialize batch, dropping \(ids.count) events")
                delegate?.removeProcessedEntities(type: type, ids: ids)
                return
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
            if success {
                delegate?.removeProcessedEntities(type: type, ids: ids)
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
