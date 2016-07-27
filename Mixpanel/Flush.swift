//
//  Flush.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol FlushDelegate {
    func flush(completion completion: (() -> Void)?)
    func updateNetworkActivityIndicator(on: Bool)
}

class Flush: AppLifecycle {

    var timer: NSTimer?
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

    func flushEventsQueue(inout eventsQueue: Queue) {
        flushQueue(type: .Events, queue: &eventsQueue)
    }

    func flushPeopleQueue(inout peopleQueue: Queue) {
        flushQueue(type: .People, queue: &peopleQueue)
    }

    func flushQueue(type type: FlushType, inout queue: Queue) {
        if flushRequest.requestNotAllowed() {
            return
        }
        flushQueueInBatches(&queue, type: type)
    }

    func startFlushTimer() {
        stopFlushTimer()
        if self.flushInterval > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                self.timer = NSTimer.scheduledTimerWithTimeInterval(self.flushInterval,
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
            dispatch_async(dispatch_get_main_queue()) {
                timer.invalidate()
                self.timer = nil
            }
        }
    }

    func flushQueueInBatches(inout queue: Queue, type: FlushType) {
        while !queue.isEmpty {
            var shouldContinue = false
            let batchSize = min(queue.count, APIConstants.batchSize)
            let range = 0..<batchSize
            let batch = Array(queue[range])
            let requestData = JSONHandler.encodeAPIData(batch)
            if let requestData = requestData {
                let semaphore = dispatch_semaphore_create(0)
                delegate?.updateNetworkActivityIndicator(true)
                var shadowQueue = queue
                flushRequest.sendRequest(requestData,
                                         type: type,
                                         useIP: useIPAddressForGeoLocation,
                                         completion: { success in
                                            self.delegate?.updateNetworkActivityIndicator(false)
                                            if success {
                                                shadowQueue.removeRange(range)
                                            }
                                            shouldContinue = success
                                            dispatch_semaphore_signal(semaphore)
                })
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
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
