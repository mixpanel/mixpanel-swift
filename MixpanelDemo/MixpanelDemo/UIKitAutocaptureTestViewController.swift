//
//  UIKitAutocaptureTestViewController.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

import Mixpanel
import UIKit

/// Test screen for validating UIKit autocapture functionality.
///
/// Tests all three event types ($mp_click, $mp_rage_click, $mp_dead_click)
/// and verifies $el_id resolution rules for UIKit views.
class UIKitAutocaptureTestViewController: UIViewController {

  private let scrollView = UIScrollView()
  private let stackView = UIStackView()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "UIKit Autocapture Test"
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
    // MARK: - $el_id Resolution Section

    stackView.addArrangedSubview(sectionLabel("$el_id Resolution"))

    // Rule 1: accessibilityIdentifier wins
    addButton(
      to: stackView,
      title: "Rule 1 - accessibilityIdentifier",
      identifier: "rule1_btn",
      hasAction: true
    )

    // Rule 2: accessibilityLabel fallback
    let rule2Btn = makeButton("Rule 2 - accessibilityLabel only", hasAction: true)
    rule2Btn.accessibilityLabel = "Rule Two"
    stackView.addArrangedSubview(rule2Btn)

    // Rule 3: Hash fallback (no ID, no label)
    addButton(
      to: stackView,
      title: "Rule 3 - No ID, No Label (hash)",
      identifier: nil,
      hasAction: true
    )

    // Rule 1 wins over Rule 2
    let bothBtn = makeButton("Rule 1 Wins - Both ID + Label", hasAction: true)
    bothBtn.accessibilityIdentifier = "both_id"
    bothBtn.accessibilityLabel = "Both Label"
    stackView.addArrangedSubview(bothBtn)

    // Custom UIView with tap gesture
    let customView = UIView()
    customView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
    customView.accessibilityIdentifier = "custom_view"
    customView.translatesAutoresizingMaskIntoConstraints = false
    customView.heightAnchor.constraint(equalToConstant: 44).isActive = true

    let tapLabel = UILabel()
    tapLabel.text = "Custom UIView with tap gesture"
    tapLabel.textAlignment = .center
    tapLabel.translatesAutoresizingMaskIntoConstraints = false
    customView.addSubview(tapLabel)
    NSLayoutConstraint.activate([
      tapLabel.centerXAnchor.constraint(equalTo: customView.centerXAnchor),
      tapLabel.centerYAnchor.constraint(equalTo: customView.centerYAnchor),
    ])

    customView.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(noop)))
    stackView.addArrangedSubview(customView)

    // MARK: - Dead Click Section

    stackView.addArrangedSubview(sectionLabel("Dead Click"))

    // Dead button (no action) - should emit $mp_dead_click
    addButton(
      to: stackView,
      title: "Dead Button (no action) -> $mp_dead_click",
      identifier: "dead_uikit_btn",
      hasAction: false
    )

    // MARK: - Rage Click Section

    stackView.addArrangedSubview(sectionLabel("Rage Click - tap 4+ times"))

    // Rage zone
    let rageZone = UIView()
    rageZone.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
    rageZone.accessibilityIdentifier = "rage_zone"
    rageZone.translatesAutoresizingMaskIntoConstraints = false
    rageZone.heightAnchor.constraint(equalToConstant: 80).isActive = true

    let rageLabel = UILabel()
    rageLabel.text = "Rage Zone - tap rapidly here"
    rageLabel.textAlignment = .center
    rageLabel.translatesAutoresizingMaskIntoConstraints = false
    rageZone.addSubview(rageLabel)
    NSLayoutConstraint.activate([
      rageLabel.centerXAnchor.constraint(equalTo: rageZone.centerXAnchor),
      rageLabel.centerYAnchor.constraint(equalTo: rageZone.centerYAnchor),
    ])

    rageZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(noop)))
    stackView.addArrangedSubview(rageZone)

    // Click + Rage button
    addButton(
      to: stackView,
      title: "Click + Rage - tap 4x (both events)",
      identifier: "rage_and_click_btn",
      hasAction: true
    )

    // MARK: - Excluded Controls Section (no dead click)

    stackView.addArrangedSubview(sectionLabel("Excluded Controls (no dead click)"))

    let switchControl = UISwitch()
    switchControl.accessibilityIdentifier = "test_switch"
    stackView.addArrangedSubview(switchControl)

    let textField = UITextField()
    textField.placeholder = "UITextField - no dead click"
    textField.borderStyle = .roundedRect
    textField.accessibilityIdentifier = "test_textfield"
    stackView.addArrangedSubview(textField)

    let secureTextField = UITextField()
    secureTextField.placeholder = "Secure Field - text NOT captured"
    secureTextField.isSecureTextEntry = true
    secureTextField.borderStyle = .roundedRect
    secureTextField.accessibilityIdentifier = "secure_textfield"
    stackView.addArrangedSubview(secureTextField)

    let stepper = UIStepper()
    stepper.accessibilityIdentifier = "test_stepper"
    stackView.addArrangedSubview(stepper)

    // MARK: - Privacy Section

    stackView.addArrangedSubview(sectionLabel("Privacy - zero events captured"))

    // mp-sensitive by identifier
    addButton(
      to: stackView,
      title: "mp-sensitive (by identifier)",
      identifier: "mp-sensitive",
      hasAction: true
    )

    // mp-no-track by label
    let noTrackBtn = makeButton("mp-no-track (by label)", hasAction: true)
    noTrackBtn.accessibilityLabel = "mp-no-track"
    stackView.addArrangedSubview(noTrackBtn)

    // MARK: - Instructions

    stackView.addArrangedSubview(sectionLabel("Instructions"))

    let instructions = UILabel()
    instructions.numberOfLines = 0
    instructions.font = .systemFont(ofSize: 14)
    if #available(iOS 13.0, *) {
      instructions.textColor = .secondaryLabel
    } else {
      instructions.textColor = .gray
    }
    instructions.text = """
      1. Enable Mixpanel logging to see events
      2. Tap buttons to verify $mp_click events
      3. Tap 4+ times rapidly on Rage Zone for $mp_rage_click
      4. Tap Dead Button and wait 500ms for $mp_dead_click
      5. Privacy buttons should emit NO events
      """
    stackView.addArrangedSubview(instructions)
  }

  // MARK: - Helpers

  @discardableResult
  private func addButton(
    to stack: UIStackView,
    title: String,
    identifier: String?,
    hasAction: Bool
  ) -> UIButton {
    let btn = makeButton(title, hasAction: hasAction)
    btn.accessibilityIdentifier = identifier
    stack.addArrangedSubview(btn)
    return btn
  }

  private func makeButton(_ title: String, hasAction: Bool) -> UIButton {
    let btn = UIButton(type: .system)
    btn.setTitle(title, for: .normal)
    btn.layer.borderWidth = 1
    btn.layer.cornerRadius = 8
    btn.layer.borderColor = UIColor.systemBlue.cgColor
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
    if hasAction {
      btn.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
    }
    return btn
  }

  private func sectionLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text.uppercased()
    label.font = .boldSystemFont(ofSize: 11)
    if #available(iOS 13.0, *) {
      label.textColor = .secondaryLabel
    } else {
      label.textColor = .gray
    }
    return label
  }

  @objc private func noop() {}

  @objc private func buttonTapped(_ sender: UIButton) {
    // Visual feedback
    let originalColor = sender.backgroundColor
    sender.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      sender.backgroundColor = originalColor
    }
  }
}
