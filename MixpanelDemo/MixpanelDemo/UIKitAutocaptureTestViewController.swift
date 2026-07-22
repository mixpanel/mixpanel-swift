//
//  UIKitAutocaptureTestViewController.swift
//  MixpanelDemo
//
//  Created by Mixpanel on 2026-06-13.
//  Copyright (c) Mixpanel. All rights reserved.
//

import Mixpanel
import SwiftUI
import UIKit

/// Test screen for validating UIKit autocapture functionality.
///
/// Tests all three event types ($mp_click, $mp_rage_click, $mp_dead_click)
/// and verifies $el_id resolution rules for UIKit views.
class UIKitAutocaptureTestViewController: UIViewController, UIPopoverPresentationControllerDelegate {

  private let scrollView = UIScrollView()
  private let stackView = UIStackView()

  // Mixed framework test state
  private var uikitCounter = 0
  private var uikitCounterLabel: UILabel?
  private var swiftUICounterModel: AnyObject?  // MixedFrameworkCounterModel (iOS 13+)

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

    // MARK: - Multi-Window / Overlay Section

    stackView.addArrangedSubview(sectionLabel("Multi-Window / Overlay"))

    // Show Alert
    let alertBtn = makeButton("Show UIAlertController (Alert)", hasAction: false)
    alertBtn.accessibilityIdentifier = "uikit_alert_trigger"
    alertBtn.addTarget(self, action: #selector(showAlert), for: .touchUpInside)
    stackView.addArrangedSubview(alertBtn)

    // Show Action Sheet
    let actionSheetBtn = makeButton("Show UIAlertController (Action Sheet)", hasAction: false)
    actionSheetBtn.accessibilityIdentifier = "uikit_actionsheet_trigger"
    actionSheetBtn.addTarget(self, action: #selector(showActionSheet(_:)), for: .touchUpInside)
    stackView.addArrangedSubview(actionSheetBtn)

    // Show Popover
    let popoverBtn = makeButton("Show Popover", hasAction: false)
    popoverBtn.accessibilityIdentifier = "uikit_popover_trigger"
    popoverBtn.addTarget(self, action: #selector(showPopover(_:)), for: .touchUpInside)
    stackView.addArrangedSubview(popoverBtn)

    // Show Share Sheet
    let shareBtn = makeButton("Show Share Sheet", hasAction: false)
    shareBtn.accessibilityIdentifier = "uikit_share_trigger"
    shareBtn.addTarget(self, action: #selector(showShareSheet(_:)), for: .touchUpInside)
    stackView.addArrangedSubview(shareBtn)

    // MARK: - Mixed Framework Dead Click Tests

    setupMixedFrameworkTests()

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

  func adaptivePresentationStyle(
    for controller: UIPresentationController
  ) -> UIModalPresentationStyle {
    return .none
  }

  @objc private func showAlert() {
    let alert = UIAlertController(
      title: "Test Alert",
      message: "Tap buttons inside this alert",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Confirm", style: .default))
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }

  @objc private func showActionSheet(_ sender: UIButton) {
    let sheet = UIAlertController(
      title: "Test Action Sheet",
      message: "Choose an option",
      preferredStyle: .actionSheet
    )
    sheet.addAction(UIAlertAction(title: "Option 1", style: .default))
    sheet.addAction(UIAlertAction(title: "Option 2", style: .default))
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = sender
      popover.sourceRect = sender.bounds
    }
    present(sheet, animated: true)
  }

  @objc private func showPopover(_ sender: UIButton) {
    let contentVC = UIViewController()
    if #available(iOS 13.0, *) {
      contentVC.view.backgroundColor = .systemBackground
    } else {
      contentVC.view.backgroundColor = .white
    }
    contentVC.preferredContentSize = CGSize(width: 250, height: 150)

    let dismissBtn = UIButton(type: .system)
    dismissBtn.setTitle("Dismiss Popover", for: .normal)
    dismissBtn.translatesAutoresizingMaskIntoConstraints = false
    contentVC.view.addSubview(dismissBtn)
    NSLayoutConstraint.activate([
      dismissBtn.centerXAnchor.constraint(equalTo: contentVC.view.centerXAnchor),
      dismissBtn.centerYAnchor.constraint(equalTo: contentVC.view.centerYAnchor),
    ])

    contentVC.modalPresentationStyle = .popover
    if let popover = contentVC.popoverPresentationController {
      popover.sourceView = sender
      popover.sourceRect = sender.bounds
      popover.permittedArrowDirections = .any
      popover.delegate = self
    }
    present(contentVC, animated: true)
  }

  @objc private func showShareSheet(_ sender: UIButton) {
    let items: [Any] = ["Sample text for sharing", URL(string: "https://mixpanel.com")!]
    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = sender
      popover.sourceRect = sender.bounds
    }
    present(activityVC, animated: true)
  }

  @objc private func buttonTapped(_ sender: UIButton) {
    // Visual feedback
    let originalColor = sender.backgroundColor
    sender.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      sender.backgroundColor = originalColor
    }
  }

  // MARK: - Mixed Framework Dead Click Tests

  private func setupMixedFrameworkTests() {
    stackView.addArrangedSubview(sectionLabel("Mixed Framework Dead Click Tests"))

    let subtitle = UILabel()
    subtitle.text = "None of these should trigger $mp_dead_click"
    subtitle.font = .systemFont(ofSize: 12)
    if #available(iOS 13.0, *) {
      subtitle.textColor = .secondaryLabel
    } else {
      subtitle.textColor = .gray
    }
    stackView.addArrangedSubview(subtitle)

    // UIKit counter label (updated by cases 1 & 3)
    let counterLabel = UILabel()
    counterLabel.text = "UIKit counter: 0"
    counterLabel.accessibilityIdentifier = "uikit_text_counter_in_uikit"
    self.uikitCounterLabel = counterLabel

    // Case 1: UIKit Button -> UIKit Text
    let btn1 = makeButton("1. UIKit Btn -> UIKit Text", hasAction: false)
    btn1.accessibilityIdentifier = "uikit_btn_uikit_text_in_uikit"
    btn1.addTarget(self, action: #selector(mixedUikitBtnUikitText), for: .touchUpInside)
    stackView.addArrangedSubview(btn1)

    stackView.addArrangedSubview(counterLabel)

    // Case 2: UIKit Button -> SwiftUI Text
    let btn2 = makeButton("2. UIKit Btn -> SwiftUI Text", hasAction: false)
    btn2.accessibilityIdentifier = "uikit_btn_swiftui_text_in_uikit"
    btn2.addTarget(self, action: #selector(mixedUikitBtnSwiftUIText), for: .touchUpInside)
    stackView.addArrangedSubview(btn2)

    // SwiftUI content embedded via UIHostingController (Cases 3 & 4 + SwiftUI counter)
    if #available(iOS 14.0, *) {
      let model = MixedFrameworkCounterModel()
      self.swiftUICounterModel = model

      let swiftUIContent = MixedFrameworkSwiftUIContent(model: model) { [weak self] in
        self?.uikitCounter += 1
        self?.uikitCounterLabel?.text = "UIKit counter: \(self?.uikitCounter ?? 0)"
      }

      let hostingController = UIHostingController(rootView: swiftUIContent)
      addChild(hostingController)
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      hostingController.view.backgroundColor = .clear

      // Wrap in a container with green background to visually distinguish SwiftUI content
      let container = UIView()
      container.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)
      container.layer.cornerRadius = 8
      container.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(hostingController.view)

      NSLayoutConstraint.activate([
        hostingController.view.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
        hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
        hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
        hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
      ])

      stackView.addArrangedSubview(container)
      hostingController.didMove(toParent: self)
    }
  }

  @objc private func mixedUikitBtnUikitText() {
    uikitCounter += 1
    uikitCounterLabel?.text = "UIKit counter: \(uikitCounter)"
  }

  @objc private func mixedUikitBtnSwiftUIText() {
    if #available(iOS 13.0, *),
       let model = swiftUICounterModel as? MixedFrameworkCounterModel {
      model.counter += 1
    }
  }
}

// MARK: - Mixed Framework Support

/// Observable model shared between UIKit and SwiftUI for cross-framework state updates.
@available(iOS 13.0, *)
class MixedFrameworkCounterModel: ObservableObject {
  @Published var counter = 0
}

/// SwiftUI content embedded in UIKit screen for mixed-framework dead click testing.
/// Case 3: SwiftUI Button -> UIKit Text (via closure)
/// Case 4: SwiftUI Button -> SwiftUI Text (via ObservableObject)
@available(iOS 14.0, *)
private struct MixedFrameworkSwiftUIContent: View {
  @ObservedObject var model: MixedFrameworkCounterModel
  let onUikitTextUpdate: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Case 3: SwiftUI Button -> UIKit Text
      Button("3. SwiftUI Btn -> UIKit Text") {
        onUikitTextUpdate()
      }
      .accessibilityLabel("swiftui_btn_uikit_text_in_uikit")
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.blue.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.blue.opacity(0.5), lineWidth: 1)
      )

      // Case 4: SwiftUI Button -> SwiftUI Text
      Button("4. SwiftUI Btn -> SwiftUI Text") {
        model.counter += 1
      }
      .accessibilityLabel("swiftui_btn_swiftui_text_in_uikit")
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.blue.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.blue.opacity(0.5), lineWidth: 1)
      )

      // SwiftUI text counter (updated by cases 2 & 4)
      Text("SwiftUI counter: \(model.counter)")
        .accessibilityLabel("swiftui_text_counter_in_uikit")
    }
  }
}
