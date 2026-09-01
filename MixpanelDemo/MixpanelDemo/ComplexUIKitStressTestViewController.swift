//
//  ComplexUIKitStressTestViewController.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-07-27.
//  Copyright (c) Mixpanel. All rights reserved.
//

import UIKit

/// E-commerce product listing stress test screen with 500+ views in the view tree.
///
/// Uses UIScrollView + UIStackView (no cell recycling) so all views remain in memory,
/// enabling autocapture performance testing under heavy view-tree load.
class ComplexUIKitStressTestViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var viewCountLabel: UILabel?
    private var tapCount = 0
    private var tapCountLabel: UILabel?

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

    private let categories = [
        "Electronics", "Clothing", "Home & Garden", "Sports",
        "Books", "Toys", "Beauty", "Automotive", "Groceries", "Health",
    ]

    private let cardColors: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemPurple,
        .systemPink, .systemTeal, .systemIndigo, .systemRed,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Stress Test"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        setupScrollView()
        setupContent()

        // Count views after layout
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let count = self.countViews(self.view)
            self.viewCountLabel?.text = "View Count: \(count)"
        }
    }

    // MARK: - Layout

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func setupContent() {
        // MARK: - Header

        let headerLabel = UILabel()
        headerLabel.text = "Complex UI Stress Test - UIKit"
        headerLabel.font = .boldSystemFont(ofSize: 20)
        headerLabel.textAlignment = .center
        stackView.addArrangedSubview(headerLabel)

        let viewCount = UILabel()
        viewCount.text = "View Count: calculating..."
        viewCount.font = .systemFont(ofSize: 14)
        viewCount.textAlignment = .center
        if #available(iOS 13.0, *) {
            viewCount.textColor = .secondaryLabel
        } else {
            viewCount.textColor = .gray
        }
        viewCount.accessibilityIdentifier = "stress_test_view_count"
        self.viewCountLabel = viewCount
        stackView.addArrangedSubview(viewCount)

        let tapLabel = UILabel()
        tapLabel.text = "Tap Count: 0"
        tapLabel.font = .systemFont(ofSize: 14)
        tapLabel.textAlignment = .center
        if #available(iOS 13.0, *) {
            tapLabel.textColor = .secondaryLabel
        } else {
            tapLabel.textColor = .gray
        }
        tapLabel.accessibilityIdentifier = "stress_test_tap_count"
        self.tapCountLabel = tapLabel
        stackView.addArrangedSubview(tapLabel)

        // MARK: - Search Bar

        let searchContainer = UIView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            searchContainer.backgroundColor = .secondarySystemBackground
        } else {
            searchContainer.backgroundColor = UIColor(white: 0.95, alpha: 1)
        }
        searchContainer.layer.cornerRadius = 10

        let searchField = UITextField()
        searchField.placeholder = "Search products..."
        searchField.borderStyle = .none
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.accessibilityIdentifier = "stress_search_field"
        searchContainer.addSubview(searchField)

        let searchButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        } else {
            searchButton.setTitle("Search", for: .normal)
        }
        searchButton.accessibilityIdentifier = "stress_search_button"
        searchButton.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchButton)

        NSLayoutConstraint.activate([
            searchContainer.heightAnchor.constraint(equalToConstant: 44),
            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),
            searchButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            searchButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 44),
        ])

        stackView.addArrangedSubview(searchContainer)

        // MARK: - Category Chips

        let chipScroll = UIScrollView()
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let chipStack = UIStackView()
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(chipStack)

        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScroll.topAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.trailingAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.bottomAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.heightAnchor),
        ])

        for (index, category) in categories.enumerated() {
            let chip = UIButton(type: .system)
            chip.setTitle(category, for: .normal)
            chip.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            if index == 0 {
                chip.backgroundColor = .systemBlue
                chip.setTitleColor(.white, for: .normal)
            } else {
                if #available(iOS 13.0, *) {
                    chip.backgroundColor = .secondarySystemBackground
                } else {
                    chip.backgroundColor = UIColor(white: 0.93, alpha: 1)
                }
            }
            chip.layer.cornerRadius = 16
            chip.accessibilityIdentifier = "category_chip_\(index)"
            chip.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(chip)
        }

        stackView.addArrangedSubview(chipScroll)

        // MARK: - Product Grid

        let totalProducts = productNames.count  // 36 products
        let columns = 2

        for row in 0..<(totalProducts / columns) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 10
            rowStack.distribution = .fillEqually

            for col in 0..<columns {
                let index = row * columns + col
                let card = makeProductCard(index: index)
                rowStack.addArrangedSubview(card)
            }

            stackView.addArrangedSubview(rowStack)
        }
    }

    // MARK: - Product Card (~15 views each)

    private func makeProductCard(index: Int) -> UIView {
        let card = UIView()
        if #available(iOS 13.0, *) {
            card.backgroundColor = .secondarySystemBackground
        } else {
            card.backgroundColor = UIColor(white: 0.96, alpha: 1)
        }
        card.layer.cornerRadius = 10
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 4
        card.accessibilityIdentifier = "product_card_\(index)"

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 4
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])

        // Image placeholder with badge
        let imagePlaceholder = UIView()
        let color = cardColors[index % cardColors.count]
        imagePlaceholder.backgroundColor = color.withAlphaComponent(0.2)
        imagePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        imagePlaceholder.heightAnchor.constraint(equalToConstant: 100).isActive = true
        imagePlaceholder.layer.cornerRadius = 10
        imagePlaceholder.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        imagePlaceholder.clipsToBounds = true

        // Product icon in center
        let iconLabel = UILabel()
        iconLabel.text = productIcon(for: index)
        iconLabel.font = .systemFont(ofSize: 32)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        imagePlaceholder.addSubview(iconLabel)
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: imagePlaceholder.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: imagePlaceholder.centerYAnchor),
        ])

        // Badge
        if index % 3 == 0 {
            let badge = UILabel()
            badge.text = " SALE "
            badge.font = .boldSystemFont(ofSize: 10)
            badge.textColor = .white
            badge.backgroundColor = .systemRed
            badge.layer.cornerRadius = 4
            badge.clipsToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            imagePlaceholder.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: imagePlaceholder.topAnchor, constant: 6),
                badge.leadingAnchor.constraint(equalTo: imagePlaceholder.leadingAnchor, constant: 6),
            ])
        } else if index % 4 == 1 {
            let badge = UILabel()
            badge.text = " NEW "
            badge.font = .boldSystemFont(ofSize: 10)
            badge.textColor = .white
            badge.backgroundColor = .systemGreen
            badge.layer.cornerRadius = 4
            badge.clipsToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            imagePlaceholder.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: imagePlaceholder.topAnchor, constant: 6),
                badge.leadingAnchor.constraint(equalTo: imagePlaceholder.leadingAnchor, constant: 6),
            ])
        }

        cardStack.addArrangedSubview(imagePlaceholder)

        // Content padding container
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 3
        contentStack.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 0, right: 8)
        contentStack.isLayoutMarginsRelativeArrangement = true

        // Product name
        let nameLabel = UILabel()
        nameLabel.text = productNames[index % productNames.count]
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.numberOfLines = 2
        contentStack.addArrangedSubview(nameLabel)

        // Rating row
        let ratingStack = UIStackView()
        ratingStack.axis = .horizontal
        ratingStack.spacing = 1
        ratingStack.alignment = .center

        let filledStars = 3 + (index % 3)  // 3-5 stars
        for starIndex in 0..<5 {
            let star = UILabel()
            star.font = .systemFont(ofSize: 10)
            if starIndex < filledStars {
                star.text = "\u{2605}"  // filled star
                star.textColor = .systemOrange
            } else {
                star.text = "\u{2606}"  // empty star
                if #available(iOS 13.0, *) {
                    star.textColor = .tertiaryLabel
                } else {
                    star.textColor = .lightGray
                }
            }
            ratingStack.addArrangedSubview(star)
        }

        let reviewCount = UILabel()
        reviewCount.text = " (\(10 + index * 7))"
        reviewCount.font = .systemFont(ofSize: 10)
        if #available(iOS 13.0, *) {
            reviewCount.textColor = .secondaryLabel
        } else {
            reviewCount.textColor = .gray
        }
        ratingStack.addArrangedSubview(reviewCount)

        // Spacer to push content left
        let ratingSpacer = UIView()
        ratingSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ratingStack.addArrangedSubview(ratingSpacer)

        contentStack.addArrangedSubview(ratingStack)

        // Price row
        let priceStack = UIStackView()
        priceStack.axis = .horizontal
        priceStack.spacing = 6
        priceStack.alignment = .center

        let originalPrice = UILabel()
        let origPriceValue = 49 + index * 5
        let attributed = NSAttributedString(
            string: "$\(origPriceValue).99",
            attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.gray,
                .font: UIFont.systemFont(ofSize: 11),
            ]
        )
        originalPrice.attributedText = attributed
        priceStack.addArrangedSubview(originalPrice)

        let salePrice = UILabel()
        let salePriceValue = 29 + index * 4
        salePrice.text = "$\(salePriceValue).99"
        salePrice.font = .boldSystemFont(ofSize: 14)
        salePrice.textColor = .systemRed
        priceStack.addArrangedSubview(salePrice)

        let priceSpacer = UIView()
        priceSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        priceStack.addArrangedSubview(priceSpacer)

        contentStack.addArrangedSubview(priceStack)

        // Action row
        let actionStack = UIStackView()
        actionStack.axis = .horizontal
        actionStack.spacing = 6
        actionStack.distribution = .fill

        let addToCartBtn = UIButton(type: .system)
        addToCartBtn.setTitle("Add to Cart", for: .normal)
        addToCartBtn.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        addToCartBtn.backgroundColor = .systemBlue
        addToCartBtn.setTitleColor(.white, for: .normal)
        addToCartBtn.layer.cornerRadius = 6
        addToCartBtn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        addToCartBtn.accessibilityIdentifier = "add_to_cart_\(index)"
        addToCartBtn.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        actionStack.addArrangedSubview(addToCartBtn)

        let favBtn = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            favBtn.setImage(UIImage(systemName: "heart"), for: .normal)
        } else {
            favBtn.setTitle("\u{2661}", for: .normal)
        }
        favBtn.tintColor = .systemPink
        favBtn.accessibilityIdentifier = "favorite_\(index)"
        favBtn.addTarget(self, action: #selector(handleFavorite(_:)), for: .touchUpInside)
        favBtn.translatesAutoresizingMaskIntoConstraints = false
        favBtn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        actionStack.addArrangedSubview(favBtn)

        contentStack.addArrangedSubview(actionStack)

        cardStack.addArrangedSubview(contentStack)

        return card
    }

    // MARK: - Helpers

    private func productIcon(for index: Int) -> String {
        let icons = [
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
        return icons[index % icons.count]
    }

    private func countViews(_ view: UIView) -> Int {
        return 1 + view.subviews.reduce(0) { $0 + countViews($1) }
    }

    @objc private func handleTap(_ sender: UIButton) {
        tapCount += 1
        tapCountLabel?.text = "Tap Count: \(tapCount)"

        // Visual feedback
        let originalColor = sender.backgroundColor
        sender.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sender.backgroundColor = originalColor
        }
    }

    @objc private func handleFavorite(_ sender: UIButton) {
        tapCount += 1
        tapCountLabel?.text = "Tap Count: \(tapCount)"

        if #available(iOS 13.0, *) {
            let isFilled = sender.image(for: .normal) == UIImage(systemName: "heart.fill")
            let newImage = UIImage(systemName: isFilled ? "heart" : "heart.fill")
            sender.setImage(newImage, for: .normal)
        } else {
            let isFilled = sender.title(for: .normal) == "\u{2665}"
            sender.setTitle(isFilled ? "\u{2661}" : "\u{2665}", for: .normal)
        }
    }
}
