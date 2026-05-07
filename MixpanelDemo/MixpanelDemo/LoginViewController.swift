import Mixpanel
import UIKit

class LoginViewController: UIViewController {

  let delegate = UIApplication.shared.delegate as! AppDelegate

  @IBOutlet weak var projectTokenTextField: UITextField!

  @IBOutlet weak var distinctIdTextField: UITextField!

  @IBOutlet weak var nameTextField: UITextField!

  @IBOutlet weak var startButton: UIButton!

    @IBOutlet weak var prefetchSwitch: UISwitch!
    @IBOutlet weak var cacheTTLTextField: UITextField!
    @IBOutlet weak var cachePolicySegmentControl: UISegmentedControl!
    
    override func viewDidLoad() {
    super.viewDidLoad()
    let token = "project_token"
    projectTokenTextField.text = token

    distinctIdTextField.text = "demo_user"
    nameTextField.text = "Demo User"
  }

  open func goToMainView() {
    if let vc = storyboard?.instantiateViewController(withIdentifier: "mainNav") {
      self.view.window?.rootViewController = vc
    } else {
      NSLog("Unable to find view controller with name \"mainView\"")
    }
  }

  @IBAction func start(_ sender: Any) {
    initializeMixpanel()

      
      
    Mixpanel.mainInstance().identify(distinctId: distinctIdTextField.text ?? "demo_user")
    Mixpanel.mainInstance().people.set(property: "$name", to: nameTextField.text ?? "")
    Mixpanel.mainInstance().track(event: "Logged in")
    Mixpanel.mainInstance().flush()

    goToMainView()
  }
    
    func initializeMixpanel() {
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
        var ttl:Double = 3600
        if let text = cacheTTLTextField.text, let ttlValue = Double(text) {
            ttl = ttlValue
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        let cachePolicy:VariantLookupPolicy = switch cachePolicySegmentControl.selectedSegmentIndex {
        case 0: .networkOnly
        case 1: .persistenceUntilNetworkSuccess(persistenceTtl: ttl)
        case 2: .networkFirst(persistenceTtl: ttl)
        default:
                .networkOnly
        }
        
        let mixpanelOptions = MixpanelOptions(
            token: projectTokenTextField.text!,
            trackAutomaticEvents: true,
            deviceIdProvider: deviceIdProvider,
            featureFlagOptions: FeatureFlagOptions(
                enabled: true,
                prefetchFlags: prefetchSwitch.isOn, variantLookupPolicy: cachePolicy
            )
        )
        Mixpanel.initialize(options: mixpanelOptions)
        Mixpanel.mainInstance().loggingEnabled = true

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 Mixpanel initialized")
        print("   anonymousId: \(Mixpanel.mainInstance().anonymousId ?? "nil")")
        print("   distinctId:  \(Mixpanel.mainInstance().distinctId)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

  @IBAction func rateDevX(_ sender: Any) {
    if let url = URL(string: "https://www.mixpanel.com/devnps") {
      UIApplication.shared.open(url)
    }
  }
    
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
}
