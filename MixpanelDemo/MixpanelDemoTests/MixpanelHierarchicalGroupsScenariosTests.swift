//
//  MixpanelHierarchicalGroupsScenariosTests.swift
//  MixpanelDemoTests
//

import XCTest

@testable import Mixpanel

/// The hierarchical groups scenarios from the Notion testing doc, one test per section and in the
/// same order.
///
/// Each test asserts the endpoint a call hits and the request it sends, or that nothing is sent.
/// Edge cases beyond the doc live in MixpanelHierarchicalGroupsTests.
class MixpanelHierarchicalGroupsScenariosTests: MixpanelBaseTests {

    private let track = FlushType.events.rawValue
    private let engage = FlushType.people.rawValue
    private let groups = FlushType.groups.rawValue

    private let userId = "my_user_id"
    private let companyId = "my_company_id"
    private let teamId = "my_team_id"

    // Every /groups write has these top-level keys beside its one operation. "id" is the row id
    // of this SDK's local queue, which is sent with every record.
    private let groupMessageKeys: Set<String> = [
        "$token", "$time", "$group_key", "$group_id", "$company_id", "$mp_metadata", "id",
    ]

    /// One request the SDK queued, with the endpoint its queue is sent to.
    private struct Sent {
        let endpoint: String
        let body: InternalProperties

        var eventName: String? { return body["event"] as? String }
        var properties: InternalProperties { return body["properties"] as? InternalProperties ?? [:] }
    }

    private var mixpanel: MixpanelInstance!

    override func setUp() {
        super.setUp()
        let options = MixpanelOptions(token: randomId(), flushInterval: 60, hierarchicalGroups: true)
        mixpanel = Mixpanel.initialize(options: options)
        // Keep everything queued so the tests can read it
        mixpanel.delegate = self
        waitForTrackingQueue(mixpanel)
    }

    override func tearDown() {
        waitForTrackingQueue(mixpanel)
        MixpanelPersistence.deleteMPUserDefaultsData(instanceName: mixpanel.apiToken)
        Mixpanel.removeInstance(name: mixpanel.apiToken)
        removeDBfile(mixpanel.apiToken)
        mixpanel = nil
        super.tearDown()
    }

    private func identify() {
        mixpanel.identify(identity: MixpanelIdentity(userId: userId, companyId: companyId))
        waitForTrackingQueue(mixpanel)
    }

    // Every request queued for each endpoint. Each queue is sent to its own endpoint, so the
    // order is only kept within an endpoint.
    private func sent() -> [Sent] {
        // Twice, since identify tracks $identify from a block it queues on the tracking queue
        waitForTrackingQueue(mixpanel)
        waitForTrackingQueue(mixpanel)
        let token = mixpanel.apiToken
        return eventQueue(token: token).map { Sent(endpoint: track, body: $0) }
            + (peopleQueue(token: token) + unIdentifiedPeopleQueue(token: token))
            .map { Sent(endpoint: engage, body: $0) }
            + groupQueue(token: token).map { Sent(endpoint: groups, body: $0) }
    }

    // Starts a scenario from what the steps before it set up, so it asserts only its own requests
    private func clearSent() {
        waitForTrackingQueue(mixpanel)
        mixpanel.trackingQueue.sync {
            let persistence = mixpanel.mixpanelPersistence
            for type in PersistenceType.allCases {
                var rows = persistence.loadEntitiesInBatch(type: type)
                if type == .people {
                    rows += persistence.loadEntitiesInBatch(
                        type: type, flag: PersistenceConstant.unIdentifiedFlag)
                }
                let ids = rows.compactMap { $0["id"] as? Int32 }
                if !ids.isEmpty {
                    persistence.removeEntitiesInBatch(type: type, ids: ids)
                }
            }
        }
        XCTAssertEqual(sent().count, 0)
    }

    private func assertNothingSent(file: StaticString = #filePath, line: UInt = #line) {
        let sent = self.sent()
        XCTAssertEqual(sent.count, 0, "Expected no requests, got \(sent.map { $0.body })", file: file, line: line)
    }

    private func onlySent(_ endpoint: String, file: StaticString = #filePath, line: UInt = #line)
        -> Sent?
    {
        let sent = self.sent()
        XCTAssertEqual(sent.count, 1, "Expected exactly one request", file: file, line: line)
        guard sent.count == 1 else { return nil }
        XCTAssertEqual(sent[0].endpoint, endpoint, file: file, line: line)
        return sent[0]
    }

    private func onlyEvent(_ eventName: String, file: StaticString = #filePath, line: UInt = #line)
        -> InternalProperties
    {
        guard let sent = onlySent(track, file: file, line: line) else { return [:] }
        XCTAssertEqual(sent.eventName, eventName, file: file, line: line)
        return sent.properties
    }

    private func deviceDistinctId() -> String {
        return "$device:" + (mixpanel.anonymousId ?? "")
    }

    private func assertAnonymous(
        _ props: InternalProperties, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(props["distinct_id"] as? String, deviceDistinctId(), file: file, line: line)
        XCTAssertEqual(props["$device_id"] as? String, mixpanel.anonymousId, file: file, line: line)
        XCTAssertNil(props["$user_id"], file: file, line: line)
        XCTAssertNil(props["$company_id"], file: file, line: line)
    }

    private func assertIdentified(
        _ props: InternalProperties, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(props["distinct_id"] as? String, userId, file: file, line: line)
        XCTAssertEqual(props["$user_id"] as? String, userId, file: file, line: line)
        XCTAssertEqual(props["$company_id"] as? String, companyId, file: file, line: line)
        XCTAssertEqual(props["$device_id"] as? String, mixpanel.anonymousId, file: file, line: line)
    }

    // Asserts the single /groups request and returns the value of its operation
    private func onlyGroupsUpdate(
        _ groupKey: String, _ groupId: String, _ operation: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> Any? {
        guard let message = onlySent(groups, file: file, line: line)?.body else { return nil }
        XCTAssertEqual(Set(message.keys), groupMessageKeys.union([operation]), file: file, line: line)
        XCTAssertEqual(message["$group_key"] as? String, groupKey, file: file, line: line)
        XCTAssertEqual(message["$group_id"] as? String, groupId, file: file, line: line)
        XCTAssertEqual(message["$company_id"] as? String, companyId, file: file, line: line)
        return message[operation]
    }

    private func onlyUserUpdate(
        _ operation: String, file: StaticString = #filePath, line: UInt = #line
    ) -> Any? {
        return onlyGroupsUpdate("$user_id", userId, operation, file: file, line: line)
    }

    // $delete is sent as an empty object
    private func assertDeleteValue(
        _ value: Any?, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual((value as? InternalProperties)?.isEmpty, true, file: file, line: line)
    }

    private func superProperties() -> [String: Any] {
        waitForTrackingQueue(mixpanel)
        return mixpanel.currentSuperProperties()
    }

    // MARK: - Track (Anonymous)

    func testTrackAnonymous() {
        mixpanel.track(event: "HG Event!", properties: ["source": "hierarchical_groups_page"])

        let props = onlyEvent("HG Event!")
        assertAnonymous(props)
        XCTAssertEqual(props["source"] as? String, "hierarchical_groups_page")
    }

    // MARK: - Identify

    func testIdentify() {
        let anonymousDistinctId = deviceDistinctId()
        identify()

        let props = onlyEvent("$identify")
        assertIdentified(props)
        XCTAssertEqual(props["$anon_distinct_id"] as? String, anonymousDistinctId)
    }

    // MARK: - Track (Identified)

    func testTrackIdentified() {
        identify()
        clearSent()
        mixpanel.track(event: "HG Event!", properties: ["source": "hierarchical_groups_page"])

        let props = onlyEvent("HG Event!")
        assertIdentified(props)
        XCTAssertEqual(props["source"] as? String, "hierarchical_groups_page")
    }

    // MARK: - Set User Property

    func testSetUserProperty() {
        identify()
        clearSent()
        mixpanel.people.set(property: "plan", to: "enterprise")

        let set = onlyUserUpdate("$set") as? InternalProperties ?? [:]
        XCTAssertEqual(set["plan"] as? String, "enterprise")
        assertDefaultPeopleProperties(set)
    }

    // MARK: - Set User Properties

    func testSetUserProperties() {
        identify()
        clearSent()
        mixpanel.people.set(properties: ["role": "admin", "seats": 5])

        let set = onlyUserUpdate("$set") as? InternalProperties ?? [:]
        XCTAssertEqual(set["role"] as? String, "admin")
        XCTAssertEqual(set["seats"] as? Int, 5)
        assertDefaultPeopleProperties(set)
    }

    // MARK: - Set Once User Property

    func testSetOnceUserProperty() {
        identify()
        clearSent()
        mixpanel.people.setOnce(properties: ["first_seen": "2026-10-27"])

        let setOnce = onlyUserUpdate("$set_once") as? InternalProperties ?? [:]
        XCTAssertEqual(setOnce["first_seen"] as? String, "2026-10-27")
        // Device properties ($ios_*, $swift_lib_version) are added to $set_once as well as $set
        assertDefaultPeopleProperties(setOnce)
        var peopleProperties: InternalProperties = [:]
        AutomaticProperties.automaticPropertiesLock.read {
            peopleProperties = AutomaticProperties.peopleProperties
        }
        XCTAssertEqual(Set(setOnce.keys), Set(peopleProperties.keys).union(["first_seen"]))
    }

    // MARK: - Union User Property

    func testUnionUserProperty() {
        identify()
        clearSent()
        mixpanel.people.union(properties: ["devices": ["android"]])

        let union = onlyUserUpdate("$union") as? InternalProperties ?? [:]
        XCTAssertEqual(union.count, 1)
        XCTAssertEqual(union["devices"] as? [String], ["android"])
    }

    // MARK: - Remove User Property

    func testRemoveUserProperty() {
        identify()
        clearSent()
        mixpanel.people.remove(properties: ["devices": "android"])

        let remove = onlyUserUpdate("$remove") as? InternalProperties ?? [:]
        XCTAssertEqual(remove.count, 1)
        XCTAssertEqual(remove["devices"] as? String, "android")
    }

    // MARK: - Unset User Property

    func testUnsetUserProperty() {
        identify()
        clearSent()
        mixpanel.people.unset(properties: ["plan"])

        XCTAssertEqual(onlyUserUpdate("$unset") as? [String], ["plan"])
    }

    // MARK: - Delete User

    func testDeleteUser() {
        identify()
        clearSent()
        mixpanel.people.deleteUser()

        assertDeleteValue(onlyUserUpdate("$delete"))
    }

    // MARK: - Clear Charges (Unsupported)

    func testClearChargesIsUnsupported() {
        identify()
        clearSent()
        mixpanel.people.clearCharges()

        assertNothingSent()
    }

    // MARK: - Increment User Property (Unsupported)

    func testIncrementUserPropertyIsUnsupported() {
        identify()
        clearSent()
        mixpanel.people.increment(property: "logins", by: 1.0)
        mixpanel.people.increment(properties: ["logins": 1, "sessions": 2])

        assertNothingSent()
    }

    // MARK: - Append User Property (Unsupported)

    func testAppendUserPropertyIsUnsupported() {
        identify()
        clearSent()
        mixpanel.people.append(properties: ["history": "opened_hg_page"])

        assertNothingSent()
    }

    // MARK: - Track Charge (Unsupported)

    func testTrackChargeIsUnsupported() {
        identify()
        clearSent()
        mixpanel.people.trackCharge(amount: 9.99)

        assertNothingSent()
    }

    // MARK: - Set Company Property

    func testSetCompanyProperty() {
        identify()
        clearSent()
        mixpanel.getCompany()?.set(property: "tier", to: "enterprise")

        let set = onlyGroupsUpdate("$company_id", companyId, "$set") as? InternalProperties ?? [:]
        XCTAssertEqual(Set(set.keys), ["tier"])
        XCTAssertEqual(set["tier"] as? String, "enterprise")
    }

    func testGetCompanyIsTheCompanyGroup() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "$company_id", groupID: companyId).set(property: "tier", to: "enterprise")

        let set = onlyGroupsUpdate("$company_id", companyId, "$set") as? InternalProperties ?? [:]
        XCTAssertEqual(set["tier"] as? String, "enterprise")
    }

    // MARK: - Set Company Properties

    func testSetCompanyProperties() {
        identify()
        clearSent()
        mixpanel.getCompany()?.set(properties: ["size": 12, "region": "us"])

        let set = onlyGroupsUpdate("$company_id", companyId, "$set") as? InternalProperties ?? [:]
        XCTAssertEqual(Set(set.keys), ["size", "region"])
        XCTAssertEqual(set["size"] as? Int, 12)
        XCTAssertEqual(set["region"] as? String, "us")
    }

    // MARK: - Set Once Company Property

    func testSetOnceCompanyProperty() {
        identify()
        clearSent()
        mixpanel.getCompany()?.setOnce(properties: ["created": "2026-10-27"])

        let setOnce =
            onlyGroupsUpdate("$company_id", companyId, "$set_once") as? InternalProperties ?? [:]
        XCTAssertEqual(setOnce["created"] as? String, "2026-10-27")
    }

    // MARK: - Union Company Property

    func testUnionCompanyProperty() {
        identify()
        clearSent()
        mixpanel.getCompany()?.union(key: "tags", values: ["android"])

        let union = onlyGroupsUpdate("$company_id", companyId, "$union") as? InternalProperties ?? [:]
        XCTAssertEqual(union["tags"] as? [String], ["android"])
    }

    // MARK: - Remove Company Property

    func testRemoveCompanyProperty() {
        identify()
        clearSent()
        mixpanel.getCompany()?.remove(key: "tags", value: "android")

        let remove = onlyGroupsUpdate("$company_id", companyId, "$remove") as? InternalProperties ?? [:]
        XCTAssertEqual(remove["tags"] as? String, "android")
    }

    // MARK: - Unset Company Property

    func testUnsetCompanyProperty() {
        identify()
        clearSent()
        mixpanel.getCompany()?.unset(property: "tier")

        XCTAssertEqual(onlyGroupsUpdate("$company_id", companyId, "$unset") as? [String], ["tier"])
    }

    // MARK: - Set User's Custom Group (setGroup)

    func testSetUsersCustomGroup() {
        identify()
        clearSent()
        mixpanel.setGroup(groupKey: "team_id", groupID: teamId)

        let set = onlyUserUpdate("$set") as? InternalProperties ?? [:]
        XCTAssertEqual(set["team_id"] as? String, teamId)
        assertDefaultPeopleProperties(set)
    }

    // MARK: - Track with Custom Group (trackWithGroups)

    func testTrackWithCustomGroup() {
        identify()
        clearSent()
        mixpanel.trackWithGroups(event: "HG Team Event!", properties: nil, groups: ["team_id": teamId])

        let props = onlyEvent("HG Team Event!")
        assertIdentified(props)
        XCTAssertEqual(props["team_id"] as? String, teamId)
    }

    // MARK: - Track (After setGroup)

    func testTrackAfterSetGroup() {
        identify()
        mixpanel.setGroup(groupKey: "team_id", groupID: teamId)
        clearSent()
        mixpanel.track(event: "HG Event!", properties: ["source": "hierarchical_groups_page"])

        let props = onlyEvent("HG Event!")
        assertIdentified(props)
        // A single value, not a list: hierarchical groups would read ["my_team_id"] as one group
        XCTAssertEqual(props["team_id"] as? String, teamId)
        XCTAssertEqual(props["source"] as? String, "hierarchical_groups_page")
    }

    // MARK: - Remove User's Custom Group (removeGroup)

    func testRemoveUsersCustomGroup() {
        identify()
        mixpanel.setGroup(groupKey: "team_id", groupID: teamId)
        clearSent()
        mixpanel.removeGroup(groupKey: "team_id", groupID: teamId)

        XCTAssertEqual(onlyUserUpdate("$unset") as? [String], ["team_id"])
        XCTAssertNil(superProperties()["team_id"])
    }

    // MARK: - Set Custom Group Property

    func testSetCustomGroupProperty() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).set(property: "tier", to: "enterprise")

        let set = onlyGroupsUpdate("team_id", teamId, "$set") as? InternalProperties ?? [:]
        XCTAssertEqual(Set(set.keys), ["tier"])
        XCTAssertEqual(set["tier"] as? String, "enterprise")
    }

    // MARK: - Set Custom Group Properties

    func testSetCustomGroupProperties() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).set(properties: ["size": 12, "region": "us"])

        let set = onlyGroupsUpdate("team_id", teamId, "$set") as? InternalProperties ?? [:]
        XCTAssertEqual(set["size"] as? Int, 12)
        XCTAssertEqual(set["region"] as? String, "us")
    }

    // MARK: - Set Once Custom Group Property

    func testSetOnceCustomGroupProperty() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).setOnce(properties: ["created": "2026-10-27"])

        let setOnce = onlyGroupsUpdate("team_id", teamId, "$set_once") as? InternalProperties ?? [:]
        XCTAssertEqual(setOnce["created"] as? String, "2026-10-27")
    }

    // MARK: - Union Custom Group Property

    func testUnionCustomGroupProperty() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).union(key: "tags", values: ["android"])

        let union = onlyGroupsUpdate("team_id", teamId, "$union") as? InternalProperties ?? [:]
        XCTAssertEqual(union["tags"] as? [String], ["android"])
    }

    // MARK: - Remove Custom Group Property

    func testRemoveCustomGroupProperty() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).remove(key: "tags", value: "android")

        let remove = onlyGroupsUpdate("team_id", teamId, "$remove") as? InternalProperties ?? [:]
        XCTAssertEqual(remove["tags"] as? String, "android")
    }

    // MARK: - Unset Custom Group Property

    func testUnsetCustomGroupProperty() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).unset(property: "tier")

        XCTAssertEqual(onlyGroupsUpdate("team_id", teamId, "$unset") as? [String], ["tier"])
    }

    // MARK: - Delete Company

    func testDeleteCompany() {
        identify()
        clearSent()
        mixpanel.getCompany()?.deleteGroup()

        assertDeleteValue(onlyGroupsUpdate("$company_id", companyId, "$delete"))
    }

    // MARK: - Delete Custom Group

    func testDeleteCustomGroup() {
        identify()
        clearSent()
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).deleteGroup()

        assertDeleteValue(onlyGroupsUpdate("team_id", teamId, "$delete"))
    }

    // MARK: - Reset

    func testReset() {
        identify()
        mixpanel.setGroup(groupKey: "team_id", groupID: teamId)
        let deviceId = mixpanel.anonymousId
        clearSent()
        mixpanel.reset()

        assertNothingSent()
        let identity = mixpanel.identity
        XCTAssertNil(identity.userId)
        XCTAssertNil(identity.companyId)
        XCTAssertNotEqual(identity.deviceId, deviceId)
        XCTAssertEqual(superProperties().count, 0)
        XCTAssertFalse(mixpanel.hasOptedOutTracking())
    }

    // MARK: - Track (After Reset)

    func testTrackAfterReset() {
        identify()
        mixpanel.setGroup(groupKey: "team_id", groupID: teamId)
        mixpanel.reset()
        clearSent()
        mixpanel.track(event: "HG Event!", properties: ["source": "hierarchical_groups_page"])

        let props = onlyEvent("HG Event!")
        assertAnonymous(props)
        XCTAssertNil(props["team_id"])
    }

    // MARK: - Opt Out (Identified)

    func testOptOutIdentified() {
        identify()
        let deviceId = mixpanel.anonymousId
        clearSent()
        mixpanel.optOutTracking()

        // The user's profile is deleted; there is no clearCharges $unset of $transactions
        assertDeleteValue(onlyUserUpdate("$delete"))
        XCTAssertTrue(mixpanel.hasOptedOutTracking())
        let identity = mixpanel.identity
        XCTAssertNil(identity.userId)
        XCTAssertNil(identity.companyId)
        XCTAssertNotEqual(identity.deviceId, deviceId)
    }

    // MARK: - Opt Out (Anonymous)

    func testOptOutAnonymous() {
        let deviceId = mixpanel.anonymousId
        mixpanel.optOutTracking()

        assertNothingSent()
        XCTAssertTrue(mixpanel.hasOptedOutTracking())
        XCTAssertNotEqual(mixpanel.anonymousId, deviceId)
    }

    // MARK: - Track (Opted Out)

    func testTrackOptedOut() {
        mixpanel.optOutTracking()
        clearSent()
        mixpanel.track(event: "HG Event!", properties: ["source": "hierarchical_groups_page"])

        assertNothingSent()
    }

    // MARK: - Opt In (Anonymous)

    func testOptInAnonymous() {
        mixpanel.optOutTracking()
        clearSent()
        mixpanel.optInTracking()

        assertAnonymous(onlyEvent("$opt_in"))
        XCTAssertFalse(mixpanel.hasOptedOutTracking())
    }

    // MARK: - Opt In With Identity

    func testOptInWithIdentity() {
        mixpanel.optOutTracking()
        clearSent()
        mixpanel.optInTracking(identity: MixpanelIdentity(userId: userId, companyId: companyId))

        // $opt_in and $identify, both carrying the user and company
        let sent = self.sent()
        XCTAssertEqual(sent.map { $0.endpoint }, [track, track])
        XCTAssertEqual(sent.map { $0.eventName }, ["$opt_in", "$identify"])
        sent.forEach { assertIdentified($0.properties) }
        XCTAssertFalse(mixpanel.hasOptedOutTracking())
    }

    // MARK: - Identify Without Company (Unsupported)

    func testIdentifyWithoutCompanyIsUnsupported() {
        let before = mixpanel.identity
        mixpanel.identify(identity: MixpanelIdentity(userId: userId))

        assertNothingSent()
        XCTAssertEqual(mixpanel.identity, before)
    }

    // MARK: - Identify With Distinct ID (Unsupported)

    func testIdentifyWithDistinctIdIsUnsupported() {
        let before = mixpanel.identity
        mixpanel.identify(distinctId: userId)

        assertNothingSent()
        XCTAssertEqual(mixpanel.identity, before)
    }

    // MARK: - Alias (Unsupported)

    func testAliasIsUnsupported() {
        identify()
        clearSent()
        mixpanel.createAlias("new_alias", distinctId: userId)

        assertNothingSent()
        XCTAssertEqual(mixpanel.identity.userId, userId)
    }

    // MARK: - Opt In With Distinct ID (Unsupported)

    func testOptInWithDistinctIdIsUnsupported() {
        mixpanel.optOutTracking()
        clearSent()
        mixpanel.optInTracking(distinctId: userId)

        assertNothingSent()
        XCTAssertTrue(mixpanel.hasOptedOutTracking())
    }

    // MARK: - Set User's Custom Groups With a List (Unsupported)

    func testSetUsersCustomGroupsWithAListIsUnsupported() {
        identify()
        clearSent()
        mixpanel.setGroup(groupKey: "team_id", groupIDs: [teamId])

        assertNothingSent()
        XCTAssertNil(superProperties()["team_id"])
    }

    // MARK: - Add User's Custom Group (Unsupported)

    func testAddUsersCustomGroupIsUnsupported() {
        identify()
        clearSent()
        mixpanel.addGroup(groupKey: "team_id", groupID: teamId)

        assertNothingSent()
        XCTAssertNil(superProperties()["team_id"])
    }

    // MARK: - Set User Property Before Identify (Unsupported)

    func testSetUserPropertyBeforeIdentifyIsUnsupported() {
        mixpanel.people.set(property: "plan", to: "enterprise")

        assertNothingSent()
    }

    // MARK: - Set Company Property Before Identify (Unsupported)

    func testSetCompanyPropertyBeforeIdentifyIsUnsupported() {
        XCTAssertNil(mixpanel.getCompany())

        assertNothingSent()
    }

    // MARK: - Set Custom Group Property Before Identify (Unsupported)

    func testSetCustomGroupPropertyBeforeIdentifyIsUnsupported() {
        mixpanel.getGroup(groupKey: "team_id", groupID: teamId).set(property: "tier", to: "enterprise")

        assertNothingSent()
    }
}
