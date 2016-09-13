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
    func updateNetworkActivityIndicator(_ on: Bool)
}

class Flush: AppLifecycle {

    var timer: Timer?
    var delegate: FlushDelegate?
    var useIPAddressForGeoLocation = true
    var flushRequest = FlushRequest()
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

    func flushEventsQueue(_ eventsQueue: inout Queue) {
        flushQueue(type: .Events, queue: &eventsQueue)
    }

    func flushPeopleQueue(_ peopleQueue: inout Queue) {
        flushQueue(type: .People, queue: &peopleQueue)
    }

    func flushQueue(type: FlushType, queue: inout Queue) {
        if flushRequest.requestNotAllowed() {
            return
        }
        flushQueueInBatches(&queue, type: type)
    }

    func startFlushTimer() {
        stopFlushTimer()
        if self.flushInterval > 0 {
            DispatchQueue.main.async {
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
        if let timer = self.timer {
            DispatchQueue.main.async {
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
            let requestData = JSONHandler.encodeAPIData(batch as JSONHandler.MPObjectToParse)
            if let requestData = requestData {
                let semaphore = DispatchSemaphore(value: 0)
                delegate?.updateNetworkActivityIndicator(true)
                var shadowQueue = queue
                flushRequest.sendRequest(requestData,
                                         type: type,
                                         useIP: useIPAddressForGeoLocation,
                                         completion: { success in
                                            self.delegate?.updateNetworkActivityIndicator(false)
                                            if success {
                                                shadowQueue.removeSubrange(range)
                                            }
                                            shouldContinue = success
                                            semaphore.signal()
                })
                let _ = semaphore.wait(timeout: DispatchTime(uptimeNanoseconds: DispatchTime.distantFuture.uptimeNanoseconds))
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
