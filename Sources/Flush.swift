//
//  Flush.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol FlushDelegate {
    func flush(completion: (() -> Void)?)
    func flushSuccess(_ queueSize: Int, type: PersistenceType)
    
    #if os(iOS)
    func updateNetworkActivityIndicator(_ on: Bool)
    #endif // os(iOS)
}

class Flush: AppLifecycle {
    var timer: Timer?
    var delegate: FlushDelegate?
    var useIPAddressForGeoLocation = true
    var flushRequest: FlushRequest
    var flushOnBackground = true
    var _flushInterval = 0.0
    private let flushIntervalReadWriteLock: DispatchQueue

    var flushInterval: Double {
        set {
            flushIntervalReadWriteLock.sync(flags: .barrier, execute: {
                _flushInterval = newValue
            })

            delegate?.flush(completion: nil)
            startFlushTimer()
        }
        get {
            flushIntervalReadWriteLock.sync {
                return _flushInterval
            }
        }
    }

    required init(basePathIdentifier: String) {
        self.flushRequest = FlushRequest(basePathIdentifier: basePathIdentifier)
        flushIntervalReadWriteLock = DispatchQueue(label: "com.mixpanel.flush_interval.lock", qos: .utility, attributes: .concurrent)
    }


    func flushQueue(type: PersistenceType, queue: Queue) {
        if flushRequest.requestNotAllowed() {
            return
        }
        flushQueueInBatches(queue, type: type)
    }

    func startFlushTimer() {
        stopFlushTimer()
        if flushInterval > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }

                self.timer = Timer.scheduledTimer(timeInterval: self.flushInterval,
                                                     target: self,
                                                     selector: #selector(self.flushSelector),
                                                     userInfo: nil,
                                                     repeats: true)
            }
        }
    }

    @objc func flushSelector() {
        delegate?.flush(completion: nil)
    }

    func stopFlushTimer() {
        if let timer = timer {
            DispatchQueue.main.async { [weak self, timer] in
                timer.invalidate()
                self?.timer = nil
            }
        }
    }

    func flushQueueInBatches(_ queue: Queue, type: PersistenceType) {
            let batchSize = min(queue.count, APIConstants.batchSize)
            let range = 0..<batchSize
            let batch = Array(queue[range])
            // Log data payload sent
            Logger.debug(message: "Sending batch of data")
            Logger.debug(message: batch as Any)
            let requestData = JSONHandler.encodeAPIData(batch)
            if let requestData = requestData {
                let semaphore = DispatchSemaphore(value: 0)
                #if os(iOS)
                    if !MixpanelInstance.isiOSAppExtension() {
                        delegate?.updateNetworkActivityIndicator(true)
                    }
                #endif // os(iOS)
                flushRequest.sendRequest(requestData,
                                         type: type,
                                         useIP: useIPAddressForGeoLocation,
                                         completion: { [weak self, semaphore] success in
                                            guard let self = self else { return }
                                            #if os(iOS)
                                                if !MixpanelInstance.isiOSAppExtension() {
                                                    self.delegate?.updateNetworkActivityIndicator(false)
                                                }
                                            #endif // os(iOS)
                                            if success {
                                                // remove
                                                self.delegate?.flushSuccess(batchSize, type: type)
                                            }
                                            semaphore.signal()
                })
                _ = semaphore.wait(timeout: DispatchTime.distantFuture)
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
