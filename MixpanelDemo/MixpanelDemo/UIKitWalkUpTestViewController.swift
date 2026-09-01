//
//  UIKitWalkUpTestViewController.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-08-03.
//  Copyright (c) Mixpanel. All rights reserved.
//

import UIKit

/// Test screen for validating walk-up-to-clickable-parent behavior in UIKit.
///
/// When the SDK detects a tap on a non-interactive leaf view (e.g., UILabel inside
/// a UIButton), it walks up to the nearest interactive ancestor for $el_id.
class UIKitWalkUpTestViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Walk-Up Test"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        setupScrollView()
        setupTestElements()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
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

    private func setupTestElements() {

        // MARK: - 1. Basic Walk-Up
        stackView.addArrangedSubview(sectionLabel("Basic Walk-Up"))
        stackView.addArrangedSubview(
            descriptionLabel(
                "Tap the button. The UILabel inside is the hit-test target. "
                    + "$el_id should be \"add_to_cart\" from the UIButton's accessibilityLabel."
            ))

        let addToCartBtn = UIButton(type: .system)
        addToCartBtn.setTitle("Add to Cart", for: .normal)
        addToCartBtn.accessibilityLabel = "add_to_cart"
        addToCartBtn.addTarget(self, action: #selector(noOp), for: .touchUpInside)
        addToCartBtn.backgroundColor = .systemBlue
        addToCartBtn.setTitleColor(.white, for: .normal)
        addToCartBtn.layer.cornerRadius = 8
        addToCartBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stackView.addArrangedSubview(addToCartBtn)

        // MARK: - 2. Nested Clickables
        stackView.addArrangedSubview(sectionLabel("Nested Clickables"))
        stackView.addArrangedSubview(
            descriptionLabel(
                "Tap \"Delete\". Walk-up should stop at the inner button (\"delete_item\"), "
                    + "NOT continue to the outer card (\"product_card\")."
            ))

        let card = UIView()
        card.backgroundColor = .systemGray6
        card.layer.cornerRadius = 12
        card.isUserInteractionEnabled = true
        card.accessibilityLabel = "product_card"
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(noOp))
        card.addGestureRecognizer(cardTap)

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        let productLabel = UILabel()
        productLabel.text = "Product Name"
        productLabel.font = .boldSystemFont(ofSize: 16)
        cardStack.addArrangedSubview(productLabel)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setTitle("Delete", for: .normal)
        deleteBtn.accessibilityLabel = "delete_item"
        deleteBtn.addTarget(self, action: #selector(noOp), for: .touchUpInside)
        deleteBtn.backgroundColor = .systemRed
        deleteBtn.setTitleColor(.white, for: .normal)
        deleteBtn.layer.cornerRadius = 8
        deleteBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        cardStack.addArrangedSubview(deleteBtn)

        stackView.addArrangedSubview(card)

        // MARK: - 3. Clickable Container with Icon + Text
        stackView.addArrangedSubview(sectionLabel("Clickable Container with Icon + Text"))
        stackView.addArrangedSubview(
            descriptionLabel(
                "Tap the icon or text. $el_id should be \"checkout_action\" from the container."
            ))

        let checkoutRow = UIView()
        checkoutRow.isUserInteractionEnabled = true
        checkoutRow.accessibilityLabel = "checkout_action"
        let checkoutTap = UITapGestureRecognizer(target: self, action: #selector(noOp))
        checkoutRow.addGestureRecognizer(checkoutTap)

        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        checkoutRow.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: checkoutRow.topAnchor, constant: 16),
            rowStack.leadingAnchor.constraint(equalTo: checkoutRow.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: checkoutRow.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: checkoutRow.bottomAnchor, constant: -16),
        ])

        if #available(iOS 13.0, *) {
            let icon = UIImageView(image: UIImage(systemName: "cart.fill"))
            icon.tintColor = .systemGreen
            icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
            rowStack.addArrangedSubview(icon)
        }

        let checkoutLabel = UILabel()
        checkoutLabel.text = "Proceed to Checkout"
        checkoutLabel.font = .systemFont(ofSize: 16)
        rowStack.addArrangedSubview(checkoutLabel)

        stackView.addArrangedSubview(checkoutRow)

        // MARK: - 4. No Clickable Ancestor
        stackView.addArrangedSubview(sectionLabel("No Clickable Ancestor"))
        stackView.addArrangedSubview(
            descriptionLabel(
                "Tap below. No clickable ancestor exists. $el_id should be a hash fallback."
            ))

        let plainText = UILabel()
        plainText.text = "Terms and Conditions apply."
        plainText.textColor = .gray
        plainText.font = .systemFont(ofSize: 14)
        stackView.addArrangedSubview(plainText)

        // MARK: - 5. Leaf Has Own Identity
        stackView.addArrangedSubview(sectionLabel("Leaf Has Own Identity"))
        stackView.addArrangedSubview(
            descriptionLabel(
                "Tap the label. Even though it has its own accessibilityLabel (\"inner_label\"), "
                    + "walk-up still activates and takes the clickable parent's identity. "
                    + "$el_id should be \"outer_container\"."
            ))

        let outerView = UIView()
        outerView.isUserInteractionEnabled = true
        outerView.accessibilityLabel = "outer_container"
        let outerTap = UITapGestureRecognizer(target: self, action: #selector(noOp))
        outerView.addGestureRecognizer(outerTap)
        outerView.backgroundColor = .systemGray6
        outerView.layer.cornerRadius = 8

        let innerLabel = UILabel()
        innerLabel.text = "I have my own identity"
        innerLabel.accessibilityLabel = "inner_label"
        innerLabel.translatesAutoresizingMaskIntoConstraints = false
        outerView.addSubview(innerLabel)
        NSLayoutConstraint.activate([
            innerLabel.topAnchor.constraint(equalTo: outerView.topAnchor, constant: 16),
            innerLabel.leadingAnchor.constraint(equalTo: outerView.leadingAnchor, constant: 16),
            innerLabel.trailingAnchor.constraint(equalTo: outerView.trailingAnchor, constant: -16),
            innerLabel.bottomAnchor.constraint(equalTo: outerView.bottomAnchor, constant: -16),
        ])
        stackView.addArrangedSubview(outerView)
    }

    // MARK: - Helpers

    @objc private func noOp() {}

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 18)
        return label
    }

    private func descriptionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.numberOfLines = 0
        return label
    }
}
