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

    // Cache for persistent device ID - populated once at app launch
    private var cachedPersistentDeviceId: String?

    /// Option 1: PERSISTENT Device ID - survives reset() and app reinstalls
    /// IMPORTANT: Cache is populated BEFORE Mixpanel init to avoid blocking in the provider.
    /// In production, use Keychain instead of UserDefaults for reinstall persistence.
    private lazy var persistentDeviceIdProvider: (() -> String?) = { [weak self] in
        print("📱 [Persistent] Returning cached device ID: \(self?.cachedPersistentDeviceId ?? "nil")")
        return self?.cachedPersistentDeviceId
    }

    /// Populate the device ID cache - call this BEFORE initializing Mixpanel
    private func loadPersistentDeviceId() {
        let key = "com.mixpanel.demo.persistentDeviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            print("📱 [Persistent] Loaded existing device ID: \(existingId)")
            cachedPersistentDeviceId = existingId
            return
        }
        let newId = "persistent-\(UUID().uuidString)"
        UserDefaults.standard.set(newId, forKey: key)
        print("📱 [Persistent] Created new device ID: \(newId)")
        cachedPersistentDeviceId = newId
    }

    /// Option 2: EPHEMERAL Device ID - changes on every reset()
    /// A new UUID is generated each time the provider is called
    private lazy var ephemeralDeviceIdProvider: (() -> String?) = {
        let newId = "ephemeral-\(UUID().uuidString)"
        print("📱 [Ephemeral] Generated new device ID: \(newId)")
        return newId
    }

    /// Option 3: FAILING Provider - returns nil to test fallback behavior
    /// Simulates a provider that cannot generate a device ID (e.g., server fetch failed)
    private lazy var failingDeviceIdProvider: (() -> String?) = {
        print("📱 [Failing] Returning nil - will use SDK default")
        return nil
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
        // loadPersistentDeviceId()  // ⚠️ MUST call before Mixpanel init!
        // let deviceIdProvider = persistentDeviceIdProvider

        // Test 2: EPHEMERAL - Device ID changes on every reset() call
        // let deviceIdProvider = ephemeralDeviceIdProvider

        // Test 3: FAILING Provider - returns nil to test SDK fallback
        // let deviceIdProvider = failingDeviceIdProvider

        // Test 4: NO PROVIDER - Default SDK behavior (UUID or IDFV)
        let deviceIdProvider: (() -> String?)? = nil

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
