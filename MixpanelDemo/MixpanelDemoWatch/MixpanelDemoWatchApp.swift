//
//  MixpanelDemoWatchApp.swift
//  MixpanelDemoWatch
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import Mixpanel
import SwiftUI

@main
struct MixpanelDemoWatchApp: App {
    init() {
        Mixpanel.initialize(token: "MIXPANEL_TOKEN")
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().registerSuperProperties(["super watch properties": 1])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
