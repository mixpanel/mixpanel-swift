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
    #if os(iOS)
    func updateNetworkActivityIndicator(_ on: Bool)
    #endif // os(iOS)
}

class Flush: AppLifecycle {
    let lock: ReadWriteLock
    var timer: Timer?
    var delegate: FlushDelegate?
    var useIPAddressForGeoLocation = true
    var flushRequest: FlushRequest
    var flushOnBackground = true
    var _flushInterval = 0.0
    var flushInterval: Double {
        set {
            objc_sync_enter(self)
            _flushInterval = newValue
            objc_sync_exit(self)

            delegate?.flush(completion: nil)
            startFlushTimer()
        }
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            return _flushInterval
        }
    }

    required init(basePathIdentifier: String, lock: ReadWriteLock) {
        self.flushRequest = FlushRequest(basePathIdentifier: basePathIdentifier)
        self.lock = lock
    }

    func flushEventsQueue(_ eventsQueue: inout Queue, automaticEventsEnabled: Bool?) {
        let automaticEventsQueue = orderAutomaticEvents(queue: &eventsQueue,
                                                        automaticEventsEnabled: automaticEventsEnabled)
        flushQueue(type: .events, queue: &eventsQueue)
        if let automaticEventsQueue = automaticEventsQueue {
            eventsQueue.append(contentsOf: automaticEventsQueue)
        }
    }

    func orderAutomaticEvents(queue: inout Queue, automaticEventsEnabled: Bool?) -> Queue? {
        if automaticEventsEnabled == nil || !automaticEventsEnabled! {
            var discardedItems = Queue()
            for (i, ev) in queue.enumerated().reversed() {
                if let eventName = ev["event"] as? String, eventName.hasPrefix("$ae_") {
                    discardedItems.append(ev)
                    queue.remove(at: i)
                }
            }
            if automaticEventsEnabled == nil {
                return discardedItems
            }
        }
        return nil
    }

    func flushPeopleQueue(_ peopleQueue: inout Queue) {
        flushQueue(type: .people, queue: &peopleQueue)
    }

    func flushQueue(type: FlushType, queue: inout Queue) {
        if flushRequest.requestNotAllowed() {
            return
        }
        flushQueueInBatches(&queue, type: type)
    }

    func startFlushTimer() {
        stopFlushTimer()
        if flushInterval > 0 {
            DispatchQueue.main.async() {
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
            DispatchQueue.main.async() {
                timer.invalidate()
                self.timer = nil
            }
        }
    }

    func flushQueueInBatches(_ queue: inout Queue, type: FlushType) {
        while !queue.isEmpty {
            var shouldContinue = false
            let batchSize = min(queue.count, APIConstants.batchSize)
            let range = 0..<batchSize
            let batch = Array(queue[range])
            let requestData = JSONHandler.encodeAPIData(batch)
            if let requestData = requestData {
                let semaphore = DispatchSemaphore(value: 0)
                #if os(iOS)
                    if !MixpanelInstance.isiOSAppExtension() {
                        delegate?.updateNetworkActivityIndicator(true)
                    }
                #endif // os(iOS)
                var shadowQueue = queue
                flushRequest.sendRequest(requestData,
                                         type: type,
                                         useIP: useIPAddressForGeoLocation,
                                         completion: { success in
                                            #if os(iOS)
                                                if !MixpanelInstance.isiOSAppExtension() {
                                                    self.delegate?.updateNetworkActivityIndicator(false)
                                                }
                                            #endif // os(iOS)
                                            if success {
                                                if let lastIndex = range.last, shadowQueue.count - 1 > lastIndex {
                                                    shadowQueue.removeSubrange(range)
                                                } else {
                                                    shadowQueue.removeAll()
                                                }
                                            }
                                            shouldContinue = success
                                            semaphore.signal()
                })
                _ = semaphore.wait(timeout: DispatchTime.distantFuture)
                self.lock.write {
                    queue = shadowQueue
                }
            }

            if !shouldContinue {
                break
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
