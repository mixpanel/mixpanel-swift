//
//  NSLock+extension.swift
//  Mixpanel
//
//  Created by Muukii on 2022/07/25.
//  Copyright © 2022 Mixpanel. All rights reserved.
//

import Foundation

extension NSLocking {
    
    @inline(__always)
    func with<Return>(_ perform: () throws -> Return) rethrows -> Return {
        lock()
        defer {
            unlock()
        }
        
        let result = try perform()
        
        return result
    }
    
}
