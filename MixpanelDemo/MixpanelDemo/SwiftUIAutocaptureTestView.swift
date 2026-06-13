//
//  SwiftUIAutocaptureTestView.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

import SwiftUI

/// Test screen for validating SwiftUI autocapture functionality.
///
/// Tests all three event types ($mp_click, $mp_rage_click, $mp_dead_click)
/// and verifies $el_id resolution rules for SwiftUI views.
@available(iOS 14.0, *)
struct SwiftUIAutocaptureTestView: View {
  @State private var toggleOn = false
  @State private var text = ""
  @State private var password = ""
  @State private var tapCount = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {

        // MARK: - $el_id Resolution

        SectionHeader("$el_id Resolution")

        Button("Rule 1 - accessibilityLabel (primary)") {}
          .accessibilityLabel("swiftui_rule1")
          .buttonStyle(TestButtonStyle())

        Button("Rule 2 - identifier only (-> hash, needs VoiceOver)") {}
          .accessibilityIdentifier("ident_only")
          .buttonStyle(TestButtonStyle())

        Button("Label Wins over Identifier") {}
          .accessibilityLabel("label_wins")
          .accessibilityIdentifier("id_loses")
          .buttonStyle(TestButtonStyle())

        Button("Rule 3 - No ID, No Label (hash)") {}
          .buttonStyle(TestButtonStyle())

        Image(systemName: "star.fill")
          .resizable()
          .frame(width: 44, height: 44)
          .foregroundColor(.yellow)
          .accessibilityLabel("tappable_image")
          .onTapGesture {}

        // MARK: - Dead Click

        SectionHeader("Dead Click")

        Button("Dead Button (empty action) -> $mp_dead_click") {}
          .accessibilityLabel("swiftui_dead_btn")
          .buttonStyle(TestButtonStyle())

        // MARK: - Rage Click

        SectionHeader("Rage Click - tap 4+ times")

        Button("Rage Zone - tap rapidly") {}
          .accessibilityLabel("swiftui_rage_btn")
          .frame(maxWidth: .infinity, minHeight: 80)
          .background(Color.red.opacity(0.12))

        Button("Click + Rage - tap 4x (both events): \(tapCount)x") {
          tapCount += 1
        }
        .accessibilityLabel("swiftui_rage_click_btn")
        .buttonStyle(TestButtonStyle())

        // MARK: - Excluded Controls

        SectionHeader("Excluded Controls (no dead click)")

        Toggle("Toggle (no dead click)", isOn: $toggleOn)

        TextField("TextField - no dead click, text not captured", text: $text)
          .textFieldStyle(.roundedBorder)

        SecureField("Password - text NOT captured", text: $password)
          .textFieldStyle(.roundedBorder)

        // MARK: - Privacy

        SectionHeader("Privacy - zero events captured")

        Button("mp-sensitive (by label)") {}
          .accessibilityLabel("mp-sensitive")
          .buttonStyle(TestButtonStyle())

        Button("mp-no-track (by identifier)") {}
          .accessibilityIdentifier("mp-no-track")
          .buttonStyle(TestButtonStyle())

        // MARK: - Instructions

        SectionHeader("Instructions")

        Text(
          """
          1. Enable Mixpanel logging to see events
          2. Tap buttons to verify $mp_click events
          3. Tap 4+ times rapidly on Rage Zone for $mp_rage_click
          4. Tap Dead Button and wait 500ms for $mp_dead_click
          5. Privacy buttons should emit NO events

          Note: SwiftUI uses accessibilityLabel as primary $el_id
          (accessibilityIdentifier requires VoiceOver to be active)
          """
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }
      .padding()
    }
    .navigationTitle("SwiftUI Autocapture Test")
  }
}

/// Simple bordered button style compatible with iOS 14+
@available(iOS 14.0, *)
private struct TestButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.blue.opacity(configuration.isPressed ? 0.2 : 0.1))
      .foregroundColor(.blue)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.blue.opacity(0.5), lineWidth: 1)
      )
  }
}

@available(iOS 14.0, *)
private struct SectionHeader: View {
  let title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title.uppercased())
      .font(.caption.bold())
      .foregroundColor(.secondary)
      .padding(.top, 8)
  }
}

/// UIKit wrapper to present SwiftUI view from storyboard
@available(iOS 14.0, *)
class SwiftUIAutocaptureTestHostingController: UIHostingController<SwiftUIAutocaptureTestView> {
  required init?(coder: NSCoder) {
    super.init(coder: coder, rootView: SwiftUIAutocaptureTestView())
  }

  init() {
    super.init(rootView: SwiftUIAutocaptureTestView())
  }
}
