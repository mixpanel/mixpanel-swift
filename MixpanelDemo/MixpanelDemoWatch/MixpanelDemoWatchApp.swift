//
//  MixpanelDemoWatchApp.swift
//  MixpanelDemoWatch
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import SwiftUI

@main
struct MixpanelDemoWatchApp: App {

    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
