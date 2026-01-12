//
//  AppDelegate.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Mixpanel
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  // MARK: - Device ID Provider Options (uncomment ONE to test)

  /// Option 1: PERSISTENT Device ID - survives reset() and app reinstalls
  /// The same device ID is returned every time, stored in UserDefaults (use Keychain in production)
  private lazy var persistentDeviceIdProvider: (() -> String) = {
    let key = "com.mixpanel.demo.persistentDeviceId"
    if let existingId = UserDefaults.standard.string(forKey: key) {
      print("📱 [Persistent] Returning existing device ID: \(existingId)")
      return existingId
    }
    let newId = "persistent-\(UUID().uuidString)"
    UserDefaults.standard.set(newId, forKey: key)
    print("📱 [Persistent] Created new device ID: \(newId)")
    return newId
  }

  /// Option 2: EPHEMERAL Device ID - changes on every reset()
  /// A new UUID is generated each time the provider is called
  private lazy var ephemeralDeviceIdProvider: (() -> String) = {
    let newId = "ephemeral-\(UUID().uuidString)"
    print("📱 [Ephemeral] Generated new device ID: \(newId)")
    return newId
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    var ADD_YOUR_MIXPANEL_TOKEN_BELOW_🛠🛠🛠🛠🛠🛠: String

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 🧪 DEVICE ID PROVIDER QA - Uncomment ONE of the following:
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Test 1: PERSISTENT - Device ID survives reset() calls
    // let deviceIdProvider = persistentDeviceIdProvider

    // Test 2: EPHEMERAL - Device ID changes on every reset() call
    // let deviceIdProvider = ephemeralDeviceIdProvider

    // Test 3: NO PROVIDER - Default SDK behavior (UUID or IDFV)
    let deviceIdProvider: (() -> String)? = nil

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    let mixpanelOptions = MixpanelOptions(
      token: "MIXPANEL_TOKEN",
      trackAutomaticEvents: true,
      deviceIdProvider: deviceIdProvider
    )
    Mixpanel.initialize(options: mixpanelOptions)
    Mixpanel.mainInstance().loggingEnabled = true

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Mixpanel initialized")
    print("   anonymousId: \(Mixpanel.mainInstance().anonymousId ?? "nil")")
    print("   distinctId:  \(Mixpanel.mainInstance().distinctId)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    return true
  }
}
