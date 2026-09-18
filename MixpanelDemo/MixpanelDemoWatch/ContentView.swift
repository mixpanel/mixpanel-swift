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
    @State private var timeButtonTitle = "Time Something"

    var body: some View {
        VStack(spacing: 8) {
            Button("Track Something") {
                trackButtonTapped()
            }
            Button(timeButtonTitle) {
                timeButtonTapped()
            }
            Button("Identify User") {
                identifyButtonTapped()
            }
        }
        .buttonStyle(.bordered)
        .tint(Color(red: 0.298, green: 0.376, blue: 0.447))
    }

    private func trackButtonTapped() {
        Mixpanel.mainInstance().track(event: "trackButtonTapped")
    }

    private func timeButtonTapped() {
        if !currentlyTiming {
            Mixpanel.mainInstance().time(event: "time something")
            timeButtonTitle = "Finish Timing"
        } else {
            Mixpanel.mainInstance().track(event: "time something")
            timeButtonTitle = "Time Something"
        }
        currentlyTiming.toggle()
    }

    private func identifyButtonTapped() {
        let watchName = WKInterfaceDevice.current().systemName
        Mixpanel.mainInstance().people.set(properties: ["watch": watchName])
        Mixpanel.mainInstance().identify(distinctId: Mixpanel.mainInstance().distinctId)
    }
}

#Preview {
    ContentView()
}
