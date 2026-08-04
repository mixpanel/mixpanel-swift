//
//  SwiftUIWalkUpTestView.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-08-03.
//  Copyright (c) Mixpanel. All rights reserved.
//

import SwiftUI

/// Test screen for validating walk-up-to-clickable-parent behavior in SwiftUI.
///
/// When the SDK detects a tap on a non-interactive leaf view, it walks up to
/// the nearest interactive ancestor for $el_id.
@available(iOS 14.0, *)
struct SwiftUIWalkUpTestView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                // MARK: - 1. Basic Walk-Up
                SectionHeader("Basic Walk-Up")

                Text("Tap the button. $el_id should be \"add_to_cart\".")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button("Add to Cart") {}
                    .accessibilityLabel("add_to_cart")
                    .buttonStyle(TestButtonStyle())

                // MARK: - 2. Nested Clickables
                SectionHeader("Nested Clickables")

                Text(
                    "Tap \"Delete\". Walk-up stops at inner button (\"delete_item\"), not outer card (\"product_card\")."
                )
                .font(.caption)
                .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Product Name")
                        .font(.headline)

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                    }
                    .accessibilityLabel("delete_item")
                    .buttonStyle(TestButtonStyle(color: .red))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .onTapGesture {}
                .accessibilityLabel("product_card")

                // MARK: - 3. Clickable Container with Icon + Text
                SectionHeader("Clickable Container with Icon + Text")

                Text("Tap icon or text. $el_id should be \"checkout_action\".")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: {}) {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.green)
                        Text("Proceed to Checkout")
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityLabel("checkout_action")
                .buttonStyle(TestButtonStyle())

                // MARK: - 4. No Clickable Ancestor
                SectionHeader("No Clickable Ancestor")

                Text("Tap below. No clickable ancestor. $el_id = hash fallback.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("Terms and Conditions apply.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(8)

                // MARK: - 5. Leaf Has Own Identity
                SectionHeader("Leaf Has Own Identity")

                Text(
                    "Tap the text. Even though it has its own accessibilityLabel (\"inner_label\"), walk-up still activates and takes the clickable parent's identity. $el_id = \"outer_button\"."
                )
                .font(.caption)
                .foregroundColor(.gray)

                Button(action: {}) {
                    Text("I have my own identity")
                        .accessibilityLabel("inner_label")
                }
                .accessibilityLabel("outer_button")
                .buttonStyle(TestButtonStyle())
            }
            .padding()
        }
        .navigationTitle("SwiftUI Walk-Up Test")
    }
}

// MARK: - Local Helper Views

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

private struct TestButtonStyle: ButtonStyle {
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(configuration.isPressed ? 0.2 : 0.1))
            .foregroundColor(color)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Hosting Controller Wrapper

@available(iOS 14.0, *)
class SwiftUIWalkUpTestHostingController: UIHostingController<SwiftUIWalkUpTestView> {
    init() {
        super.init(rootView: SwiftUIWalkUpTestView())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
