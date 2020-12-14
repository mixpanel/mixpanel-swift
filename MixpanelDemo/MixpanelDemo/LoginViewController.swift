import UIKit
import Mixpanel
import UserNotifications

class LoginViewController: UIViewController {
    
    let delegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var projectTokenTextField: UITextField!
    
    @IBOutlet weak var distinctIdTextField: UITextField!
    
    @IBOutlet weak var nameTextField: UITextField!
    
    @IBOutlet weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let token = Mixpanel.mainInstance().apiToken
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
    

    
    func registerDeviceForPush() {
        guard let deviceToken = delegate.pushDeviceToken else {
            NSLog("%@ Push device token not set")
            return
        }
        
        Mixpanel.mainInstance().people.addPushDeviceToken(deviceToken)
        Mixpanel.mainInstance().flush()
        
        let tokenChars = (deviceToken as NSData).bytes.assumingMemoryBound(to: CChar.self)
        var tokenString = ""
        for i in 0..<deviceToken.count {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        debugPrint("did register for remote notification with device token: \(tokenString)")
    }
    
    @IBAction func start(_ sender: Any) {
        Mixpanel.mainInstance().identify(distinctId: distinctIdTextField.text ?? "")
        Mixpanel.mainInstance().people.set(property: "$name", to: nameTextField.text ?? "")
        Mixpanel.mainInstance().track(event: "Logged in")
        Mixpanel.mainInstance().flush()
        
        registerDeviceForPush()
        
        goToMainView()
    }
}
