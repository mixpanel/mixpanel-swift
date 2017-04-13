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
    #if os(iOS) && !APP_EXTENSION
    func updateNetworkActivityIndicator(_ on: Bool)
    #endif // os(iOS) && !APP_EXTENSION
}

class Flush: AppLifecycle {

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

    required init(basePathIdentifier: String) {
        self.flushRequest = FlushRequest(basePathIdentifier: basePathIdentifier)
    }

    func flushEventsQueue(_ eventsQueue: inout Queue) {
        removeAutomaticTracking(queue: &eventsQueue)
        flushQueue(type: .events, queue: &eventsQueue)
    }

    func removeAutomaticTracking(queue: inout Queue) {
//        if Decide.automaticEvents == false {
        for (i, item) in queue.enumerated().reversed()
        {
            if let event = item["event"] as? String, event.hasPrefix("MP: ") {
                queue.remove(at: i)
            }
        }
//        }
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
                #if os(iOS) && !APP_EXTENSION
                    delegate?.updateNetworkActivityIndicator(true)
                #endif // os(iOS) && !APP_EXTENSION
                var shadowQueue = queue
                flushRequest.sendRequest(requestData,
                                         type: type,
                                         useIP: useIPAddressForGeoLocation,
                                         completion: { success in
                                            #if os(iOS) && !APP_EXTENSION
                                                self.delegate?.updateNetworkActivityIndicator(false)
                                            #endif // os(iOS && !APP_EXTENSION
                                            if success {
                                                if let lastIndex = range.last, shadowQueue.count < lastIndex {
                                                    shadowQueue.removeSubrange(range)
                                                } else {
                                                    shadowQueue.removeAll()
                                                }
                                            }
                                            shouldContinue = success
                                            semaphore.signal()
                })
                _ = semaphore.wait(timeout: DispatchTime.distantFuture)
                queue = shadowQueue
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
