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
  @State private var showAlert = false
  @State private var showSheet = false
  @State private var showConfirmationDialog = false
  @State private var showPopover = false

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

        // MARK: - Multi-Window / Overlay

        SectionHeader("Multi-Window / Overlay")

        Button("Show Alert") {
          showAlert = true
        }
        .accessibilityLabel("swiftui_alert_trigger")
        .buttonStyle(TestButtonStyle())

        Button("Show Sheet") {
          showSheet = true
        }
        .accessibilityLabel("swiftui_sheet_trigger")
        .buttonStyle(TestButtonStyle())

        Button("Show Confirmation Dialog") {
          showConfirmationDialog = true
        }
        .accessibilityLabel("swiftui_confirmation_trigger")
        .buttonStyle(TestButtonStyle())

        Button("Show Popover") {
          showPopover = true
        }
        .accessibilityLabel("swiftui_popover_trigger")
        .buttonStyle(TestButtonStyle())

        // MARK: - Instructions

        SectionHeader("Instructions")

        Text(
          """
          1. Enable Mixpanel logging to see events
          2. Tap buttons to verify $mp_click events
          3. Tap 4+ times rapidly on Rage Zone for $mp_rage_click
          4. Tap Dead Button and wait 500ms for $mp_dead_click

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
    .modifier(AlertModifier(isPresented: $showAlert))
    .sheet(isPresented: $showSheet) {
      NavigationView {
        VStack(spacing: 12) {
          Button("Sheet Action 1") {}
            .accessibilityLabel("swiftui_sheet_action_1")
            .buttonStyle(TestButtonStyle())

          Button("Sheet Action 2") {}
            .accessibilityLabel("swiftui_sheet_action_2")
            .buttonStyle(TestButtonStyle())

          Button("Sheet Action 3") {}
            .accessibilityLabel("swiftui_sheet_action_3")
            .buttonStyle(TestButtonStyle())

          Button("Close") {
            showSheet = false
          }
          .buttonStyle(TestButtonStyle())
        }
        .padding()
        .navigationTitle("Test Sheet")
      }
    }
    .modifier(ConfirmationDialogModifier(isPresented: $showConfirmationDialog))
    .popover(isPresented: $showPopover) {
      VStack(spacing: 12) {
        Text("Popover Content")
        Button("Close") {
          showPopover = false
        }
      }
      .padding()
    }
  }
}

/// ViewModifier that presents an alert using the iOS 15+ API when available,
/// falling back to the iOS 14 Alert struct.
@available(iOS 14.0, *)
private struct AlertModifier: ViewModifier {
  @Binding var isPresented: Bool

  func body(content: Content) -> some View {
    if #available(iOS 15.0, *) {
      content
        .alert("Test Alert", isPresented: $isPresented) {
          Button("Confirm") {}
            .accessibilityLabel("swiftui_alert_confirm")
          Button("Cancel", role: .cancel) {}
        }
    } else {
      content
        .alert(isPresented: $isPresented) {
          Alert(
            title: Text("Test Alert"),
            primaryButton: .default(Text("Confirm")),
            secondaryButton: .cancel()
          )
        }
    }
  }
}

/// ViewModifier that presents a confirmationDialog on iOS 15+,
/// falling back to an actionSheet on iOS 14.
@available(iOS 14.0, *)
private struct ConfirmationDialogModifier: ViewModifier {
  @Binding var isPresented: Bool

  func body(content: Content) -> some View {
    if #available(iOS 15.0, *) {
      content
        .confirmationDialog("Choose Option", isPresented: $isPresented) {
          Button("Option 1") {}
            .accessibilityLabel("swiftui_dialog_option_1")
          Button("Option 2") {}
            .accessibilityLabel("swiftui_dialog_option_2")
          Button("Option 3") {}
            .accessibilityLabel("swiftui_dialog_option_3")
          Button("Cancel", role: .cancel) {}
        }
    } else {
      content
        .actionSheet(isPresented: $isPresented) {
          ActionSheet(
            title: Text("Choose Option"),
            buttons: [
              .default(Text("Option 1")),
              .default(Text("Option 2")),
              .default(Text("Option 3")),
              .cancel()
            ]
          )
        }
    }
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
