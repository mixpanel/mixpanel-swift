//
//  ComplexSwiftUIStressTestView.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-07-27.
//  Copyright (c) Mixpanel. All rights reserved.
//

import SwiftUI

/// E-commerce product listing stress test screen with 500+ views in the view tree.
///
/// Uses ScrollView + VStack + ForEach (no view recycling via List/LazyVGrid) so all
/// views remain in memory, enabling autocapture performance testing under heavy load.
@available(iOS 14.0, *)
struct ComplexSwiftUIStressTestView: View {
    @State private var tapCount = 0
    @State private var searchText = ""
    @State private var selectedCategory = 0

    private let categories = [
        "Electronics", "Clothing", "Home & Garden", "Sports",
        "Books", "Toys", "Beauty", "Automotive", "Groceries", "Health",
    ]

    private let productNames = [
        "Wireless Headphones", "Smart Watch Pro", "Laptop Stand", "USB-C Hub",
        "Mechanical Keyboard", "4K Monitor", "Bluetooth Speaker", "Phone Case",
        "Tablet Sleeve", "Power Bank", "Camera Lens Kit", "LED Desk Lamp",
        "Ergonomic Mouse", "Portable SSD", "Noise Canceller", "Smart Plug",
        "Fitness Tracker", "Drone Mini", "VR Headset", "Action Camera",
        "Ring Light", "Mic Stand", "Stream Deck", "Drawing Tablet",
        "Webcam HD", "Router Mesh", "Charger Pad", "Cable Organizer",
        "Monitor Arm", "Desk Mat", "Key Finder", "Smart Scale",
        "Air Purifier", "Humidifier", "Projector Mini", "E-Reader",
    ]

    private let productIcons = [
        "\u{1F3A7}", "\u{231A}", "\u{1F4BB}", "\u{1F50C}",
        "\u{2328}", "\u{1F5A5}", "\u{1F50A}", "\u{1F4F1}",
        "\u{1F4BC}", "\u{1F50B}", "\u{1F4F7}", "\u{1F4A1}",
        "\u{1F5B1}", "\u{1F4BE}", "\u{1F507}", "\u{1F50C}",
        "\u{231A}", "\u{1F681}", "\u{1F453}", "\u{1F3A5}",
        "\u{1F4A1}", "\u{1F3A4}", "\u{1F3AE}", "\u{1F58C}",
        "\u{1F4F7}", "\u{1F310}", "\u{1F50B}", "\u{1F4CE}",
        "\u{1F5A5}", "\u{1F4D0}", "\u{1F50D}", "\u{2696}",
        "\u{1F32C}", "\u{1F4A7}", "\u{1F4FD}", "\u{1F4D6}",
    ]

    private let cardColors: [Color] = [
        .blue, .green, .orange, .purple,
        .pink, .init(red: 0, green: 0.7, blue: 0.7), .init(red: 0.3, green: 0.3, blue: 0.8), .red,
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // MARK: - Header

                Text("Complex UI Stress Test - SwiftUI")
                    .font(.headline)
                    .padding(.top, 8)

                Text("Tap Count: \(tapCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("stress_test_tap_count_swiftui")

                // MARK: - Search Bar

                HStack(spacing: 8) {
                    TextField("Search products...", text: $searchText)
                        .padding(8)
                        .accessibilityIdentifier("stress_search_field_swiftui")

                    Button(action: { tapCount += 1 }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                    }
                    .accessibilityIdentifier("stress_search_button_swiftui")
                    .padding(.trailing, 8)
                }
                .background(Color.gray.opacity(0.12))
                .cornerRadius(10)
                .padding(.horizontal, 4)

                // MARK: - Category Chips

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<categories.count, id: \.self) { index in
                            Button(action: {
                                selectedCategory = index
                                tapCount += 1
                            }) {
                                Text(categories[index])
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(index == selectedCategory ? Color.blue : Color.gray.opacity(0.15))
                                    .foregroundColor(index == selectedCategory ? .white : .primary)
                                    .cornerRadius(16)
                            }
                            .accessibilityIdentifier("category_chip_swiftui_\(index)")
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // MARK: - Product Grid (2 columns, 18 rows = 36 cards)

                ForEach(0..<18, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<2, id: \.self) { col in
                            StressTestProductCard(
                                index: row * 2 + col,
                                name: productNames[(row * 2 + col) % productNames.count],
                                icon: productIcons[(row * 2 + col) % productIcons.count],
                                cardColor: cardColors[(row * 2 + col) % cardColors.count],
                                tapCount: $tapCount
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .navigationTitle("SwiftUI Stress Test")
    }
}

// MARK: - Product Card (~15 views each)

@available(iOS 14.0, *)
private struct StressTestProductCard: View {
    let index: Int
    let name: String
    let icon: String
    let cardColor: Color
    @Binding var tapCount: Int
    @State private var isFavorite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Image placeholder with badge
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(cardColor.opacity(0.15))
                    .frame(height: 100)
                    .cornerRadius(10, corners: [.topLeft, .topRight])

                Text(icon)
                    .font(.system(size: 32))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 100)

                if index % 3 == 0 {
                    Text(" SALE ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .background(Color.red)
                        .cornerRadius(4)
                        .padding(6)
                } else if index % 4 == 1 {
                    Text(" NEW ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                // Product name
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                // Rating row
                HStack(spacing: 1) {
                    let filledStars = 3 + (index % 3)
                    ForEach(0..<5, id: \.self) { starIndex in
                        Text(starIndex < filledStars ? "\u{2605}" : "\u{2606}")
                            .font(.system(size: 10))
                            .foregroundColor(starIndex < filledStars ? .orange : .gray)
                    }
                    Text("(\(10 + index * 7))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Price row
                HStack(spacing: 6) {
                    Text("$\(49 + index * 5).99")
                        .font(.system(size: 11))
                        .strikethrough()
                        .foregroundColor(.gray)

                    Text("$\(29 + index * 4).99")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                }

                // Action row
                HStack(spacing: 6) {
                    Button(action: {
                        tapCount += 1
                    }) {
                        Text("Add to Cart")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                    .accessibilityIdentifier("add_to_cart_swiftui_\(index)")

                    Spacer()

                    Button(action: {
                        isFavorite.toggle()
                        tapCount += 1
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(.pink)
                    }
                    .accessibilityIdentifier("favorite_swiftui_\(index)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .background(Color.gray.opacity(0.06))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Product \(index) \(name)")
    }
}

// MARK: - Corner Radius Helper

@available(iOS 14.0, *)
extension View {
    fileprivate func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

@available(iOS 14.0, *)
private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Hosting Controller

/// UIKit wrapper to present the SwiftUI stress test view from storyboard or programmatic navigation.
@available(iOS 14.0, *)
class ComplexSwiftUIStressTestHostingController: UIHostingController<ComplexSwiftUIStressTestView> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: ComplexSwiftUIStressTestView())
    }

    init() {
        super.init(rootView: ComplexSwiftUIStressTestView())
    }
}
