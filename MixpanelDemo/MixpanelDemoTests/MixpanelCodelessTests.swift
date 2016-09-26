//
//  MixpanelCodelessTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 9/14/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla


@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelStub {
    var calls = [[String: Any]]()

    func track(event: String) {
        self.calls.append(["event": event])
    }

    func track(event: String, properties: [NSObject : AnyObject]) {
        self.calls.append(["event": event, "properties": properties])
    }

    func resetCalls() {
        self.calls.removeAll()
    }
}

class TableController: UITableViewController {
    dynamic override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("selected something")
    }

    dynamic override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

    dynamic override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
}

class MixpanelCodelessTests: MixpanelBaseTests {

    func testUIControlBindings() {
        /*
         nc__vc__v1___v2___c1
         \    \...c3
         \__c2
         */
        let c1_path = "/UIViewController/UIView/UIView/UIControl"
        let c2_path = "/UIViewController/UIView/UIControl"
        let eventParams = ["event_type": "ui_control",
                           "event_name": "ui control",
                           "path": c1_path,
                           "control_event": UInt(64)] as [String : Any]
        // Create elements in window
        let vc = UIViewController()
        let v1 = UIView()
        let v2 = UIView()
        let c1 = UIControl()
        let c2 = UIControl()
        v2.addSubview(c1)
        v1.addSubview(v2)
        v1.addSubview(c2)
        vc.view = v1
        let rootViewController = UIApplication.shared.keyWindow?.rootViewController!
        (rootViewController as! UINavigationController).viewControllers = [vc]
        // Check paths of elements c1 and c2
        var selector = ObjectSelector(string: c1_path)
        XCTAssertEqual(selector.selectFrom(root: rootViewController)[0] as! UIControl, c1, "c1 should be selected by path")
        selector = ObjectSelector(string: c2_path)
        XCTAssertEqual(selector.selectFrom(root: rootViewController)[0] as! UIControl, c2, "c2 should be selected by path")
        // Create binding and check state
        let binding = UIControlBinding(object: eventParams)
        binding?.execute()
        XCTAssertEqual(binding?.running, true, "Binding should be running")
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 0, "Mixpanel track should not have been called.")
        // Fire event
        c1.sendActions(for: .touchDown)
        c1.sendActions(for: .touchUpInside)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 1, "A track call should have been fired")
        // test that event doesnt fire for other UIControl
        c2.sendActions(for: .touchUpInside)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 1, "Should not have fired event for c2")
        // test `didMoveToWindow`
        let c3 = UIControl()
        v2.addSubview(c3)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 1, "Mixpanel track should not have been called.")
        c3.sendActions(for: .touchDown)
        c3.sendActions(for: .touchUpInside)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 2, "A track call should have been fired")
        /*
         nc__vc__v1___v2___c1
         \...c3
         \__c2
         */
        // test moving element to different path
        v1.addSubview(c3)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 2, "Mixpanel track should not have been called.")
        c3.sendActions(for: .touchUpInside)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 2, "A track call should not have been fired")
        // test `stop` with c1
        binding?.stop()
        XCTAssertEqual(binding?.running, false, "Binding should NOT be running")
        c1.sendActions(for: .touchUpInside)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 2, "Target action should have been unbound")
        c1.removeFromSuperview()
        v2.addSubview(c1)
        // -- remove and replace
        selector = ObjectSelector(string: c1_path)
        XCTAssertEqual(selector.selectFrom(root: rootViewController)[0] as! UIControl, c1, "c1 should have been replaced")
        c1.sendActions(for: .touchUpInside)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 2, "didMoveToWindow should have been unSwizzled")
        // Test archive
        let archive = NSKeyedArchiver.archivedData(withRootObject: binding!)
        let unarchivedBinding = NSKeyedUnarchiver.unarchiveObject(with: archive)!
        XCTAssertEqual(NSStringFromClass(type(of: binding!)),
                       NSStringFromClass(type(of: unarchivedBinding) as! AnyClass),
                       "Binding should have correct serialized properties after archive")
        XCTAssertTrue((binding!.name == (unarchivedBinding as AnyObject).name),
                      "Binding should have correct serialized properties after archive")
        XCTAssertTrue((binding?.path == (unarchivedBinding as AnyObject).path!),
                      "Binding should have correct serialized properties after archive")
        XCTAssertEqual(binding?.controlEvent,
                       (unarchivedBinding as AnyObject).controlEvent,
                       "Binding should have correct serialized properties after archive")
        XCTAssertEqual(binding?.verifyEvent,
                       (unarchivedBinding as AnyObject).verifyEvent,
                       "Binding should have correct serialized properties after archive")
    }

    func testUITableViewBindings() {
        /*
         nc__vc__tv
         */
        let tv_path = "/UIViewController/UITableView"
        let eventParams = ["event_type": "ui_table_view",
                           "event_name": "ui table view",
                           "table_delegate": NSStringFromClass(TableController.self),
                           "path": tv_path]
        // Create elements in window
        let vc = TableController()
        let tv = vc.tableView
        // table view has two cells
        vc.view = tv
        let rootViewController = UIApplication.shared.keyWindow?.rootViewController!
        (rootViewController as! UINavigationController).viewControllers = [vc]
        // Check paths of elements va and vb
        let selector = ObjectSelector(string: tv_path)
        XCTAssertEqual(selector.selectFrom(root: rootViewController)[0] as? UITableView,
                       tv,
                       "va should be selected by path")
        // Create binding and check state
        let binding = UITableViewBinding(object: eventParams)
        binding?.execute()
        XCTAssertEqual(binding?.running, true, "Binding should be running")
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 0, "No track calls should be fired")
        // test row selection
        var indexPath = IndexPath(row: 1, section: 0)
        vc.perform(#selector(UITableViewDelegate.tableView(_:didSelectRowAt:)), with: tv!, with: indexPath)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 1, "One track call should be fired")
        // test stop binding
        binding?.stop()
        XCTAssertEqual(binding?.running, false, "Binding should NOT be running")
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 1, "No track calls should be fired")
        // test row selection
        indexPath = IndexPath(row: 2, section: 0)
        vc.perform(#selector(UITableViewDelegate.tableView(_:didSelectRowAt:)), with: tv!, with: indexPath)
        waitForSerialQueue()
        XCTAssertEqual(Int(mixpanel.eventsQueue.count), 1, "No track calls should be fired")
        // Test archive
        let archive = NSKeyedArchiver.archivedData(withRootObject: binding!)
        let unarchivedBinding = NSKeyedUnarchiver.unarchiveObject(with: archive)!
        XCTAssertEqual(NSStringFromClass(type(of: binding!)),
                       NSStringFromClass(type(of: unarchivedBinding) as! AnyClass),
                       "Binding should have correct serialized properties after archive")
        XCTAssertTrue((binding!.name == (unarchivedBinding as AnyObject).name),
                      "Binding should have correct serialized properties after archive")
        XCTAssertTrue((binding?.path == (unarchivedBinding as AnyObject).path!),
                      "Binding should have correct serialized properties after archive")
    }

    func testFingerprinting() {
        var format: String
        /*
         This adds some tests for the fingerprint versioning.
         */
        let v1 = UIView()
        let b1 = UIButton(frame: CGRect(x: 2, y: 3, width: 4, height: 5))
        b1.setTitle("button", for: .normal)
        v1.addSubview(b1)
        let image = UIImage(named: "checkerboard")
        b1.setImage(image, for: .normal)
        // Assert that we have versioning available and we are at least at v1
        XCTAssert(b1.responds(to: NSSelectorFromString("mp_fingerprintVersion")))
        XCTAssert(Int(b1.perform(#selector(UIView.mp_fingerprintVersion)).takeUnretainedValue() as! NSNumber) >= 1)
        // Test a versioned predicate where the first clause passes and the second would fail
        format = "(mp_fingerprintVersion >= 1 AND true == true) OR 1 = 2"
        XCTAssert(NSPredicate(format: format).evaluate(with: b1))
        XCTAssert(ObjectSelector(string: ("/UIButton[\(format)]")).isSelected(leaf: b1, from: v1),
                  "Selector should have selected object matching predicate")
        // Test where the version check fails (running an older version of the lib than the one called for in the predicate)
        format = "(mp_fingerprintVersion >= 9999999 AND mp_crashOlderApps = \"crash\") OR 1 = 1"
        XCTAssert(NSPredicate(format: format).evaluate(with: b1))
        XCTAssert(ObjectSelector(string: ("/UIButton[\(format)]")).isSelected(leaf: b1, from: v1),
                  "Selector should have selected object matching predicate")
        // Test where the version check passes but the version-sensitive predicate fails
        format = "(mp_fingerprintVersion >= 1 AND mp_varA = \"not a real return value\") OR 1 = 2"
        XCTAssertFalse(NSPredicate(format: format).evaluate(with: b1))
        XCTAssertFalse(ObjectSelector(string: ("/UIButton[\(format)]")).isSelected(leaf: b1, from: v1),
                       "Selector should have selected object matching predicate")
    }

}
