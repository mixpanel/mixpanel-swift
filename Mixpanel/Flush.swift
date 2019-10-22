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

    func flushEventsQueue(_ eventsQueue: Queue, automaticEventsEnabled: Bool?) -> Queue? {
        let (automaticEventsQueue, eventsQueue) = orderAutomaticEvents(queue: eventsQueue,
                                                        automaticEventsEnabled: automaticEventsEnabled)
        var mutableEventsQueue = flushQueue(type: .events, queue: eventsQueue)
        if let automaticEventsQueue = automaticEventsQueue {
            mutableEventsQueue?.append(contentsOf: automaticEventsQueue)
        }
        return mutableEventsQueue
    }
    
    func orderAutomaticEvents(queue: Queue, automaticEventsEnabled: Bool?) ->
        (automaticEventQueue: Queue?, eventsQueue: Queue) {
            var eventsQueue = queue
            if automaticEventsEnabled == nil || !automaticEventsEnabled! {
                var discardedItems = Queue()
                for (i, ev) in eventsQueue.enumerated().reversed() {
                    if let eventName = ev["event"] as? String, eventName.hasPrefix("$ae_") {
                        discardedItems.append(ev)
                        eventsQueue.remove(at: i)
                    }
                }
                if automaticEventsEnabled == nil {
                    return (discardedItems, eventsQueue)
                }
            }
            return (nil, eventsQueue)
    }

    func flushPeopleQueue(_ peopleQueue: Queue) -> Queue? {
        return flushQueue(type: .people, queue: peopleQueue)
    }

    func flushGroupsQueue(_ groupsQueue: Queue) -> Queue? {
        return flushQueue(type: .groups, queue: groupsQueue)
    }

    func flushQueue(type: FlushType, queue: Queue) -> Queue? {
        if flushRequest.requestNotAllowed() {
            return queue
        }
        return flushQueueInBatches(queue, type: type)
    }

    func startFlushTimer() {
        stopFlushTimer()
        if flushInterval > 0 {
            DispatchQueue.main.async() { [weak self] in
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
            DispatchQueue.main.async() { [weak self, timer] in
                timer.invalidate()
                self?.timer = nil
            }
        }
    }

    func flushQueueInBatches(_ queue: Queue, type: FlushType) -> Queue {
        var mutableQueue = queue
        while !mutableQueue.isEmpty {
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
                var shadowQueue = mutableQueue
                flushRequest.sendRequest(requestData,
                                         type: type,
                                         useIP: useIPAddressForGeoLocation,
                                         completion: { [weak self, semaphore, range] success in
                                            #if os(iOS)
                                                if !MixpanelInstance.isiOSAppExtension() {
                                                    guard let self = self else { return }
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
                mutableQueue = shadowQueue
            }

            if !shouldContinue {
                break
            }
        }
        return mutableQueue
    }

    // MARK: - Lifecycle
    func applicationDidBecomeActive() {
        startFlushTimer()
    }

    func applicationWillResignActive() {
        stopFlushTimer()
    }

}
