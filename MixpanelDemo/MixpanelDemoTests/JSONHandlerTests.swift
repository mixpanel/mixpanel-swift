//
//  JSONHandlerTests.swift
//  MixpanelDemoTests
//
//  Created by Jared McFarland on 5/28/21.
//  Copyright © 2021 Mixpanel. All rights reserved.
//
import XCTest
@testable import Mixpanel
@testable import MixpanelDemo

class JSONHandlerTests: XCTestCase {

    func testSerializeJSONObject() {
        let nSNumberProp: NSNumber = NSNumber(value: 1)
        let doubleProp: Double = 2.0
        let floatProp: Float = Float(3.5)
        let stringProp: String = "string"
        let intProp: Int = -4
        let uIntProp: UInt = 4
        let uInt64Prop: UInt64 = 5000000000
        let boolProp: Bool = true
        let optArrayProp: Array<Double?> = [nil, 1.0, 2.0]
        let arrayProp: Array<Double> = [0.0, 1.0, 2.0]
        let dictProp: Dictionary<String, String?> = ["nil": nil, "a": "a", "b": "b"]
        let dateProp: Date = Date()
        let urlProp: URL = URL(string: "https://www.mixpanel.com")!
        let nilProp: String? = nil
        let nestedDictProp: Dictionary<String, Dictionary<String, String?>> = ["nested": dictProp]
        let nestedArraryProp: Array<Array<Double?>> = [optArrayProp]

        let event: Dictionary<String, Any> = ["event": "test",
                                              "properties": ["nSNumberProp": nSNumberProp,
                                                             "doubleProp": doubleProp,
                                                             "floatProp": floatProp,
                                                             "stringProp": stringProp,
                                                             "intProp": intProp,
                                                             "uIntProp": uIntProp,
                                                             "uInt64Prop": uInt64Prop,
                                                             "boolProp": boolProp,
                                                             "optArrayProp": optArrayProp,
                                                             "arrayProp": arrayProp,
                                                             "dictProp": dictProp,
                                                             "dateProp": dateProp,
                                                             "urlProp": urlProp,
                                                             "nilProp": nilProp as Any,
                                                             "nestedDictProp": nestedDictProp,
                                                             "nestedArraryProp": nestedArraryProp,
                                              ]]

        let serializedQueue = JSONHandler.serializeJSONObject([event])
        let deserializedQueue = try! JSONSerialization.jsonObject(with: serializedQueue!, options: []) as! Array<Dictionary<String, Any>>
        XCTAssertEqual(deserializedQueue[0]["event"] as! String, "test")
        let props = deserializedQueue[0]["properties"] as! [String : Any]
        XCTAssertEqual(props["nSNumberProp"] as! NSNumber, nSNumberProp)
        XCTAssertEqual(props["doubleProp"] as! Double, doubleProp)
        XCTAssertEqual(props["floatProp"] as! Float, floatProp)
        XCTAssertEqual(props["stringProp"] as! String, stringProp)
        XCTAssertEqual(props["intProp"] as! Int, intProp)
        XCTAssertEqual(props["uIntProp"] as! UInt, uIntProp)
        XCTAssertEqual(props["uInt64Prop"] as! UInt64, uInt64Prop)
        XCTAssertEqual(props["boolProp"] as! Bool, boolProp)
        // nil should be dropped from Array properties
        XCTAssertEqual(props["optArrayProp"] as! Array, [1.0, 2.0])
        XCTAssertEqual(props["arrayProp"] as! Array, arrayProp)
        let deserializedDictProp = props["dictProp"] as! [String : Any]
        // nil should be convereted to NSNull() inside Dictionary properties
        XCTAssertEqual(deserializedDictProp["nil"] as! NSNull, NSNull())
        XCTAssertEqual(deserializedDictProp["a"] as! String, "a")
        XCTAssertEqual(deserializedDictProp["b"] as! String, "b")
        XCTAssertEqual(props["urlProp"] as! String, urlProp.absoluteString)
        // nil properties themselves should also be converted to NSNull()
        XCTAssertEqual(props["nilProp"] as! NSNull, NSNull())
        let deserializedNestedDictProp = props["nestedDictProp"] as! [String : [String : Any]]
        let nestedDict = deserializedNestedDictProp["nested"]!
        // the same nil logic from above should be applied to nested Collections as well
        XCTAssertEqual(nestedDict["nil"] as! NSNull, NSNull())
        XCTAssertEqual(nestedDict["a"] as! String, "a")
        XCTAssertEqual(nestedDict["b"] as! String, "b")
        let deserializednestedArraryProp = props["nestedArraryProp"] as! [[Double?]]
        XCTAssertEqual(deserializednestedArraryProp[0] as! Array, [1.0, 2.0])
    }

}
