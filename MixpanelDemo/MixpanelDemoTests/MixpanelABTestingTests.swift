//
//  MixpanelABTestingTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 10/17/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla


@testable import Mixpanel
@testable import MixpanelDemo

class ClassA: NSObject {
    var count = 0

    func incrementCount() {
        count += 1
    }
}

class ClassB: ClassA {

}

class ClassC: ClassB {
    override func incrementCount() {
        count += 2
    }
}

class MixpanelABTestingTests: MixpanelBaseTests {

    @discardableResult func stubDecide(_ path: String = "") -> LSStubResponseDSL {
        let responseURL = Bundle(for: type(of: self)).url(forResource: path, withExtension: "json")
        let data = NSData(contentsOf: responseURL!)
        return stubRequest("GET", kDefaultServerDecideString()).withHeader("Accept-Encoding", "gzip")!.andReturn(200)!.withBody(data)!
    }

    func testInvocation() {
        let imageView = UIImageView()
        XCTAssertNil(imageView.image, "Image should not be set")
        let dataStr = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/TQBcNTh/AAAAAXRSTlPM0j" +
        "RW/QAAAApJREFUeJxjYgAAAAYAAzY3fKgAAAAASUVORK5CYII="
        VariantAction.executeSelector(#selector(setter: UIImageView.image),
                                      args: [[["images": [["scale": 1.0,
                                                           "mime_type": "image/png",
                                                           "data": dataStr]]],
                                              "UIImage"]], on: [imageView])
        XCTAssertNotNil(imageView.image!, "Image should be set")
        XCTAssertEqual(imageView.image!.cgImage!.width, 1, "Image should be 1px wide")
        let urlImageView = UIImageView()
        XCTAssertNil(urlImageView.image, "Image should not be set")
        let args = [[["images": [["scale": 1.0, "mime_type": "image/png", "dimensions": ["Height": 10.0, "Width": 10.0],
                                  "url":
                                    Bundle(for: type(of: self)).url(forResource: "checkerboard", withExtension: "jpg")!.absoluteString]]],
                     "UIImage"]]
        VariantAction.executeSelector(#selector(setter: UIImageView.image), args: args, on: [urlImageView])
        XCTAssertNotNil(urlImageView.image!, "Image should be set")
        XCTAssertEqual(imageView.image!.cgImage!.width, 1, "Image should be 1px wide")
        let label = UILabel()
        VariantAction.executeSelector(#selector(setter: UILabel.text), args: [["TEST", "NSString"]], on: [label])
        XCTAssertEqual(label.text!, "TEST")
        VariantAction.executeSelector(#selector(setter: UILabel.textColor), args: [["rgba(108,200,100,0.5)", "UIColor"]], on: [label])
        XCTAssertEqual(Int(label.textColor.cgColor.components![0] * 255), 108, "Label text color should be set")
        let button = UIButton()
        VariantAction.executeSelector(#selector(setter: UIButton.frame),
                                      args: [[["X": 10, "Y": 10, "Width": 10, "Height": 10], "CGRect"]],
                                      on: [button])
        XCTAssert(button.frame.size.width == 10.0, "Button width should be set")
    }

    func testVariant() {
        // This label added before the Variant is created.
        let label = UILabel()
        label.text = "Old Text"
        topViewController().view.addSubview(label)
        let data = try! Data(contentsOf: Bundle(for: type(of: self)).url(forResource: "test_variant", withExtension: "json")!)
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        let variant = Variant(JSONObject: object as? [String: Any])
        variant?.execute()
        // This label added after the Variant was created.
        let label2 = UILabel()
        label2.text = "Old Text 2"
        topViewController().view.addSubview(label2)
        let expect = self.expectation(description: "Text Updated")
        DispatchQueue.main.async(execute: {() -> Void in
            XCTAssertEqual(label.text!, "New Text")
            XCTAssertEqual(label2.text!, "New Text")
            expect.fulfill()
        })
        self.waitForExpectations(timeout: 0.5, handler: nil)
        variant?.stop()
    }

    func testStopVariant() {
        // This label added before the Variant is created.
        let label = UILabel()
        label.text = "Old Text"
        topViewController().view.addSubview(label)
        let data = try! Data(contentsOf: Bundle(for: type(of: self)).url(forResource: "test_variant", withExtension: "json")!)
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        let variant = Variant(JSONObject: object as? [String: Any])
        variant?.execute()
        variant?.stop()
        // This label added after the Variant was stopped.
        let label2 = UILabel()
        label2.text = "Old Text 2"
        topViewController().view.addSubview(label2)
        let expect = self.expectation(description: "Text Updated")
        DispatchQueue.main.async(execute: {() -> Void in
            XCTAssertEqual(label.text!, "Old Text")
            XCTAssertEqual(label2.text!, "Old Text 2")
            expect.fulfill()
        })
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testDecideVariants() {
        LSNocilla.sharedInstance().clearStubs()
        self.stubDecide("test_decide_response")
        self.mixpanel.identify(distinctId: "ABC")
        let expect = self.expectation(description: "wait for variants to be executed")
        self.mixpanel.checkDecide(completion: { (response: DecideResponse?) -> Void in
            XCTAssertEqual(response!.newVariants.count, 2, "Should have got 2 new variants from decide")
            DispatchQueue.main.sync {
                for variant: Variant in response!.newVariants {
                    variant.execute()
                }
            }
            expect.fulfill()
        })
        self.waitForExpectations(timeout: 0.5, handler: nil)
        // Test that calling again uses the cache (no extra requests to decide).
        self.mixpanel.checkDecide(completion: { _ in })
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.count, 2, "no variants found")
        // Test that we make another request if useCache is off
        self.mixpanel.checkDecide(forceFetch: true, completion: { (response: DecideResponse?) -> Void in
            XCTAssertEqual(response!.newVariants.count,
                           0,
                           "Should not get any *new* variants if the decide response was the same")})
        self.waitForSerialQueue()
        LSNocilla.sharedInstance().clearStubs()
        self.stubDecide("test_decide_response_2")
        var completionCalled = false
        self.mixpanel.checkDecide(forceFetch: true, completion: { (response: DecideResponse?) -> Void in
            completionCalled = true
            XCTAssertEqual(response!.newVariants.count,
                           1,
                           "Should have got 1 new variants from decide (new variant for same experiment)")})
        self.waitForSerialQueue()
        XCTAssert(completionCalled, "completion block should have been called")
        // Reset to default decide response
        self.stubDecide("test_decide_response")
    }

    func testRunExperimentFromDecide() {
        LSNocilla.sharedInstance().clearStubs()
        self.stubDecide("test_decide_response")
        // This view should be modified by the variant returned from decide.
        let button = UIButton()
        button.backgroundColor = UIColor.black
        topViewController().view.addSubview(button)
        self.mixpanel.identify(distinctId: "ABC")
        waitForSerialQueue()
        let expect = self.expectation(description: "Finish join experiments")
        self.mixpanel.joinExperiments() {
            XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.count, 2, "Should have 2 variants")
            XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.filter {
                return $0.ID == 1 && $0.running
                }.count, 1, "We should be running variant 1")
            XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.filter {
                return $0.ID == 2 && $0.running && !$0.finished
                }.count, 1, "We should be running variant 2")
            XCTAssertEqual(Int(((button.backgroundColor?.cgColor)?.components?[0])! * 255), 255, "Button background should be red")
            // Returning a new variant for the same experiment from decide should override the old one
            LSNocilla.sharedInstance().clearStubs()
            self.stubDecide("test_decide_response_2")
            var lastCall = false
            self.mixpanel.joinExperiments() {
                XCTAssert(lastCall, "callback should run after variants have been processed")
                self.waitForSerialQueue()
                XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.count, 3, "Should have 3 variants")
                XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.filter {
                    return $0.ID == 1 && $0.running
                    }.count, 1, "We should be running variant 1")
                XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.filter {
                    return $0.ID == 2 && !$0.running && $0.finished
                    }.count, 1, "Variant 2 should be stopped but marked as finished.")
                XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.filter {
                    return $0.ID == 3 && $0.running
                    }.count, 1, "We should be running variant 3")
                XCTAssertEqual(Int(((button.backgroundColor?.cgColor)?.components?[2])! * 255), 255, "Button background should be blue")
                expect.fulfill()
            }
            lastCall = true
        }
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testVariantsTracked() {
        LSNocilla.sharedInstance().clearStubs()
        self.stubDecide("test_decide_response")
        self.mixpanel.identify(distinctId: "DEF")
        waitForSerialQueue()
        self.mixpanel.checkDecide(completion: { (response: DecideResponse?) -> Void in
            DispatchQueue.main.async {
                for variant: Variant in response!.newVariants {
                    variant.execute()
                    self.mixpanel.markVariantRun(variant)
                }
            }
        })
        self.waitForSerialQueue()
        let expect = self.expectation(description: "decide variants tracked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertEqual(self.mixpanel.decideInstance.ABTestingInstance.variants.count, 2, "no variants found")
            XCTAssertNotNil(self.mixpanel.superProperties["$experiments"], "$experiments super property should not be nil")
            let experiments = self.mixpanel.superProperties["$experiments"] as! [String: Any]
            XCTAssert(experiments["1"] as! Int == 1, "super properties should have { 1: 1 }")
            XCTAssertTrue(self.mixpanel.eventsQueue.count == 2, "$experiment_started events not tracked")
            for event: [AnyHashable: Any] in self.mixpanel.eventsQueue {
                XCTAssertTrue(((event["event"] as! String) == "$experiment_started"), "incorrect event name")
                let properties = event["properties"] as! [String: Any]
                XCTAssertNotNil(properties["$experiments"], "$experiments super-property not set on $experiment_started event")
            }
            expect.fulfill()
        }
        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testObjectSelection() {
        /*
         w___vc___v1___v2___l1
         \    \__l2
         \_v3___l3
         \__l4
         */
        let w = UIWindow()
        let vc = UIViewController()
        let v1 = UIView()
        let v2 = UIView()
        let v3 = UIView()
        let l1 = UILabel()
        l1.text = "Label 1"
        let l2 = UILabel()
        l2.text = "Label 2"
        let l3 = UILabel()
        l3.text = "Label 3"
        let l4 = UILabel()
        l4.text = "Label 4"
        v2.addSubview(l1)
        v2.addSubview(l2)
        v3.addSubview(l3)
        v3.addSubview(l4)
        v1.addSubview(v2)
        v1.addSubview(v3)
        vc.view = v1
        w.rootViewController = vc
        // Basic selection
        var selector = ObjectSelector(string: "/UIView/UIView/UILabel")
        XCTAssert(selector.isSelected(leaf: l2, from: vc), "l2 should be selected from viewcontroller")
        selector = ObjectSelector(string: "/UIViewController/UIView/UIView/UILabel")
        XCTAssertEqual(selector.selectFrom(root: w)[0] as! UILabel, l1, "l1 should be selected from window")
        // Selection by index
        // This selector will get both l2 and l4 as they are the [1]th UILabel in their respective views
        selector = ObjectSelector(string: "/UIView/UIView/UILabel[1]")
        XCTAssertEqual(selector.selectFrom(root: vc)[0] as! UILabel, l2, "l2 should be selected by index")
        XCTAssertEqual(selector.selectFrom(root: vc)[1] as! UILabel, l4, "l4 should be selected by index")
        XCTAssert(selector.isSelected(leaf: l2, from: vc), "l2 should be selected by index")
        XCTAssert(selector.isSelected(leaf: l4, from: vc), "l4 should be selected by indezx")
        XCTAssertFalse(selector.isSelected(leaf: l1, from: vc), "l1 should not be selected by index")
        // Selection by multiple indexes
        selector = ObjectSelector(string: "/UIView/UIView[0]/UILabel[1]")
        XCTAssert(selector.selectFrom(root: vc).contains(where: { $0 === l2 }), "l2 should be selected by index")
        XCTAssertFalse(selector.selectFrom(root: vc).contains(where: { $0 === l4 }), "l4 should not be selected by index")
        XCTAssert(selector.isSelected(leaf: l2, from: vc), "l2 should be selected by index")
        XCTAssertFalse(selector.isSelected(leaf: l4, from: vc), "l4 should be selected by index")
        XCTAssertFalse(selector.isSelected(leaf: l1, from: vc), "l1 should not be selected by index")
        // Invalid index selection (Parent of objects selected by index must be UIViews)
        selector = ObjectSelector(string: "/UIView[0]/UIView/UILabel")
        XCTAssertEqual(selector.selectFrom(root: vc).count, (0 ), "l2 should be selected by index")
        // Select view by predicate
        selector = ObjectSelector(string: "/UIView/UIView/UILabel[text == \"Label 1\"]")
        XCTAssertEqual(selector.selectFrom(root: vc)[0] as! UILabel, l1, "l1 should be selected by predicate")
        XCTAssert(selector.isSelected(leaf: l1, from: vc), "l1 should be selected by predicate")
        XCTAssert(!selector.isSelected(leaf: l2, from: vc), "l2 should not be selected by predicate")
    }

    func testHelpers() {
        let v1 = UIView()
        XCTAssert(v1.responds(to: #selector(UIView.mp_fingerprintVersion)))
        XCTAssert(v1.mp_fingerprintVersion() == 1)
        //#pragma clang diagnostic push
        //#pragma clang diagnostic ignored "-Wundeclared-selector"
        XCTAssert(v1.responds(to: #selector(UIView.mp_varA)))
        XCTAssert(v1.responds(to: #selector(UIView.mp_varB)))
        XCTAssert(v1.responds(to: #selector(UIView.mp_varC)))
        XCTAssert(v1.responds(to: #selector(UIView.mp_varSetD)))
        XCTAssert(v1.responds(to: #selector(UIView.mp_varE)))
        //#pragma clang diagnostic pop
    }

    func testUITableViewCellOrdering() {
        var sel = ObjectSelector(string: "/UITableViewController/UITableView/UITableViewWrapperView/" +
            "UITableViewCell[0]/UITableViewCellContentView/UILabel")
        if ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 11, minorVersion: 0, patchVersion: 0)) {
            sel = ObjectSelector(string: "/UITableViewController/UITableView/" +
                "UITableViewCell[0]/UITableViewCellContentView/UILabel")
        }
        var selected = sel.selectFrom(root: UIApplication.shared.keyWindow?.rootViewController!)
        XCTAssertEqual(selected.count, 1, "Should have selected one object")
        XCTAssert((selected[0] is UILabel), "object should be UITableViewCell")
        XCTAssert(((selected[0] as! UILabel).text! == "Tracking"),
                  "Should have selected the topmost cell (which is not the same as the first in the subview list)")
    }

    func testValueTransformers() {
        // Bad Rect (inf, -inf, and NaN values) Main test is that we don't crash on converting this to JSON
        let error: Error? = nil
        let rect = NSValue(cgRect: CGRect(x: 1.0 / 0.0, y: -1.0 / 0.0, width: 0.0 / 0.0, height: 1.0))
        let rekt = CGRectToNSDictionary().transformedValue(rect) as! NSDictionary
        try! JSONSerialization.data(withJSONObject: rekt, options: [])
        XCTAssertNil(error, "Should be no errors")
        XCTAssert((rekt is [AnyHashable: Any]), "Should be converted to NSDictionary")
        XCTAssertEqual(rekt["X"] as! CFloat, 0.0, "Infinite value should be converted to 0")
        // Serialize and deserialize a UIImage
        let imageString = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/TQBcNTh/AAAAAXRSTlPM0jRW/" +
        "QAAAApJREFUeJxjYgAAAAYAAzY3fKgAAAAASUVORK5CYII="
        let data = Data(base64Encoded: imageString, options: [.ignoreUnknownCharacters])!
        var image = UIImage(data: data)!
        var imgDict = UIImageToNSDictionary().transformedValue(image) as! [String: Any]
        let imagesArr = imgDict["images"] as! [[String: Any]]
        XCTAssertNotNil(imagesArr[0]["data"], "base64 representations should exist")
        image = UIImageToNSDictionary().reverseTransformedValue(imgDict) as! UIImage
        XCTAssert(image.size.equalTo(CGSize(width: 1.0, height: 1.0)), "Image should be 1x1")
        // Deserialize a UIImage with a URL
        let url = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21" +
        "bKAAAAA1BMVEX/TQBcNTh/AAAAAXRSTlPM0jRW/QAAAApJREFUeJxjYgAAAAYAAzY3fKgAAAAASUVORK5CYII="
        imgDict = ["imageOrientation": 0, "images": [["url": url,
                                                      "mime_type": "image/png",
                                                      "scale": 1]],
                   "renderingMode": 0,
                   "resizingMode": 0,
                   "size": ["Height": 1.0, "Width": 1.0]]
        image = UIImageToNSDictionary().reverseTransformedValue(imgDict) as! UIImage
        XCTAssert(image.size.equalTo(CGSize(width: 1.0, height: 1.0)), "Image should be 1x1")
        // Deserialize a UIImage with a URL and dimensions
        imgDict = ["imageOrientation": 0, "images": [["url": url,
                                                      "mime_type": "image/png",
                                                      "scale": 1,
                                                      "dimensions": ["Height": 2.0, "Width": 2.0]]],
                   "renderingMode": 0,
                   "resizingMode": 0,
                   "size": ["Height": 1.0, "Width": 1.0]]
        image = UIImageToNSDictionary().reverseTransformedValue(imgDict) as! UIImage
        XCTAssert(image.size.equalTo(CGSize(width: 2.0, height: 2.0)), "Image should be 2x2")
        // Serialize a blank image.
        let nilImage = UIImage()
        var nilImgDict = UIImageToNSDictionary().transformedValue(nilImage) as! [String: Any]
        let nilImagesArr = nilImgDict["images"] as? [[String: Any]]
        XCTAssertEqual(nilImagesArr?.count, 0)
    }
}
