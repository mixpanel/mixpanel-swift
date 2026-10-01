//
//  ContentView.swift
//  MixpanelDemoWatch
//
//  Copyright © 2026 Mixpanel. All rights reserved.
//

import Mixpanel
import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var currentlyTiming = false

    var body: some View {
        VStack(spacing: 12) {
            Button("Track") {
                Mixpanel.mainInstance().track(event: "trackButtonTapped")
            }
            Button(currentlyTiming ? "Finish Timing" : "Time Something") {
                if !currentlyTiming {
                    Mixpanel.mainInstance().time(event: "time something")
                } else {
                    Mixpanel.mainInstance().track(event: "time something")
                }
                currentlyTiming.toggle()
            }
            Button("Identify") {
                let watchName = WKInterfaceDevice.current().systemName
                Mixpanel.mainInstance().people.set(properties: ["watch": watchName])
                Mixpanel.mainInstance().identify(distinctId: Mixpanel.mainInstance().distinctId)
            }
        }
    }
}
