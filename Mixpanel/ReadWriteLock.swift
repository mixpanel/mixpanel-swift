//
//  ReadWriteLock.swift
//  Mixpanel
//
//  Created by Hairuo Sang on 8/9/17.
//  Copyright © 2017 Mixpanel. All rights reserved.
//

import Foundation

class ReadWriteLock{
    //A placeholder object that tracking/archiving/flushing threads lock on
    let conccurentQueue: DispatchQueue
    
    init(label: String) {
        self.conccurentQueue = DispatchQueue(label: label, attributes: .concurrent)
    }
    
    func read(closure: () -> ()) {
        self.conccurentQueue.sync {
            closure();
        }
    }
    
    func write(closure: () -> ()) {
        self.conccurentQueue.sync(flags: .barrier, execute: {
            closure()
        })
    }
    
}
