import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(mixpanel_swiftTests.allTests),
    ]
}
#endif
