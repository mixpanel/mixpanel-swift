//
//  MixpanelHierarchicalGroupsTests.swift
//  MixpanelDemoTests
//

import XCTest

@testable import Mixpanel

/// Hierarchical groups is fixed by `MixpanelOptions.hierarchicalGroups`. These tests cover what
/// changes when it is on, and that nothing changes when it is off. They mirror the Android SDK's
/// HierarchicalGroupsTest.
class MixpanelHierarchicalGroupsTests: MixpanelBaseTests {

    private var instances: [MixpanelInstance] = []

    override func tearDown() {
        for mixpanel in instances {
            waitForTrackingQueue(mixpanel)
            MixpanelPersistence.deleteMPUserDefaultsData(instanceName: mixpanel.apiToken)
            Mixpanel.removeInstance(name: mixpanel.apiToken)
            removeDBfile(mixpanel.apiToken)
        }
        instances = []
        URLProtocol.unregisterClass(FlagsRecordingURLProtocol.self)
        FlagsRecordingURLProtocol.reset()
        super.tearDown()
    }

    private func newApi(_ hierarchicalGroups: Bool) -> MixpanelInstance {
        let options = MixpanelOptions(
            token: randomId(), flushInterval: 60, hierarchicalGroups: hierarchicalGroups)
        let mixpanel = Mixpanel.initialize(options: options)
        // Keep everything queued so the tests can read it
        mixpanel.delegate = self
        instances.append(mixpanel)
        waitForTrackingQueue(mixpanel)
        return mixpanel
    }

    private func events(_ mixpanel: MixpanelInstance) -> Queue {
        waitForTrackingQueue(mixpanel)
        return eventQueue(token: mixpanel.apiToken)
    }

    private func lastEventProperties(_ mixpanel: MixpanelInstance, _ eventName: String)
        -> InternalProperties
    {
        guard
            let event = events(mixpanel).last(where: { $0["event"] as? String == eventName }),
            let properties = event["properties"] as? InternalProperties
        else {
            XCTFail("No \(eventName) event was tracked")
            return [:]
        }
        return properties
    }

    private func countEvents(_ mixpanel: MixpanelInstance, _ eventName: String) -> Int {
        return events(mixpanel).filter { $0["event"] as? String == eventName }.count
    }

    private func people(_ mixpanel: MixpanelInstance) -> Queue {
        waitForTrackingQueue(mixpanel)
        return peopleQueue(token: mixpanel.apiToken)
            + unIdentifiedPeopleQueue(token: mixpanel.apiToken)
    }

    private func groups(_ mixpanel: MixpanelInstance) -> Queue {
        waitForTrackingQueue(mixpanel)
        return groupQueue(token: mixpanel.apiToken)
    }

    private func identify(_ mixpanel: MixpanelInstance, _ userId: String?, _ companyId: String? = nil) {
        mixpanel.identify(identity: MixpanelIdentity(userId: userId, companyId: companyId))
        waitForTrackingQueue(mixpanel)
    }

    // Reads the deprecated distinct id without a warning at every call site
    @available(*, deprecated)
    private func distinctId(_ mixpanel: MixpanelInstance) -> String {
        waitForTrackingQueue(mixpanel)
        return mixpanel.distinctId
    }

    // MARK: - Events

    func testEventsCarryUserCompanyAndDevice() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.track(event: "Viewed Report")

        let props = lastEventProperties(mixpanel, "Viewed Report")
        XCTAssertEqual(props["$user_id"] as? String, "user_123")
        XCTAssertEqual(props["$company_id"] as? String, "acme")
        XCTAssertEqual(props["$device_id"] as? String, mixpanel.anonymousId)
        XCTAssertEqual(mixpanel.identity.companyId, "acme")
        XCTAssertEqual(distinctId(mixpanel), "$company:acme|$user:user_123")
    }

    @available(*, deprecated)
    func testSettingDistinctIdIsIgnored() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.distinctId = "user_456"
        mixpanel.track(event: "Viewed Report")

        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["distinct_id"] as? String, "user_123")
        XCTAssertEqual(distinctId(mixpanel), "$company:acme|$user:user_123")
    }

    @available(*, deprecated)
    func testDisabledSettingDistinctIdStillApplies() {
        let mixpanel = newApi(false)
        mixpanel.distinctId = "user_456"
        mixpanel.track(event: "Viewed Report")

        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["distinct_id"] as? String, "user_456")
    }

    func testIdentifyEventCarriesTheNewCompany() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")

        let props = lastEventProperties(mixpanel, "$identify")
        XCTAssertEqual(props["$company_id"] as? String, "acme")
        XCTAssertEqual(props["$user_id"] as? String, "user_123")
    }

    func testAnonymousEventsCarryNoCompany() {
        let mixpanel = newApi(true)
        mixpanel.track(event: "Opened")

        let props = lastEventProperties(mixpanel, "Opened")
        XCTAssertNil(props["$company_id"])
        XCTAssertNil(props["$user_id"])
        XCTAssertNotNil(props["$device_id"])
    }

    func testCompanyIdOverridesSuperProperty() {
        let mixpanel = newApi(true)
        mixpanel.registerSuperProperties(["$company_id": "stale"])
        identify(mixpanel, "user_123", "acme")
        mixpanel.track(event: "Viewed Report")

        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["$company_id"] as? String, "acme")
    }

    func testEventPropertyOverridesCompanyId() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.track(event: "Viewed Report", properties: ["$company_id": "override"])

        XCTAssertEqual(
            lastEventProperties(mixpanel, "Viewed Report")["$company_id"] as? String, "override")
    }

    func testCompanyChangeIsAnIdentityChange() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        identify(mixpanel, "user_123", "acme")
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 1)

        identify(mixpanel, "user_123", "globex")
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 2)

        mixpanel.track(event: "Viewed Report")
        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["$company_id"] as? String, "globex")
    }

    func testIdentifyWithDistinctIdDoesNothing() {
        let mixpanel = newApi(true)
        let anonymous = mixpanel.identity
        mixpanel.identify(distinctId: "user_123")
        waitForTrackingQueue(mixpanel)

        XCTAssertEqual(mixpanel.identity, anonymous)
        XCTAssertNil(mixpanel.identity.userId)
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 0)
    }

    func testIdentifyWithDistinctIdKeepsCurrentIdentity() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.identify(distinctId: "user_456")
        waitForTrackingQueue(mixpanel)

        XCTAssertEqual(mixpanel.identity.userId, "user_123")
        XCTAssertEqual(mixpanel.identity.companyId, "acme")
        mixpanel.track(event: "Viewed Report")
        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["$company_id"] as? String, "acme")
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 1)
    }

    func testIdentifyWithEmptyCompanyDoesNothing() {
        let mixpanel = newApi(true)
        let anonymous = mixpanel.identity
        identify(mixpanel, "user_123", "")

        XCTAssertEqual(mixpanel.identity, anonymous)
        XCTAssertNil(mixpanel.identity.companyId)
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 0)
    }

    func testIdentityWithoutCompanyDoesNothing() {
        let mixpanel = newApi(true)
        let anonymous = mixpanel.identity
        identify(mixpanel, "user_123")

        XCTAssertEqual(mixpanel.identity, anonymous)
        XCTAssertNil(mixpanel.identity.userId)
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 0)
    }

    func testIdentityWithoutCompanyKeepsCurrentIdentity() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        identify(mixpanel, "user_456")

        XCTAssertEqual(mixpanel.identity.userId, "user_123")
        XCTAssertEqual(mixpanel.identity.companyId, "acme")
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 1)
    }

    func testInvalidIdentitiesDoNothing() {
        let mixpanel = newApi(true)
        let anonymous = mixpanel.identity
        identify(mixpanel, nil, "acme")
        identify(mixpanel, "", "acme")

        XCTAssertEqual(mixpanel.identity, anonymous)
        XCTAssertNil(mixpanel.identity.companyId)
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 0)
    }

    func testIdentityDeviceIdIsIgnored() {
        let mixpanel = newApi(true)
        let deviceId = mixpanel.anonymousId
        mixpanel.identify(
            identity: MixpanelIdentity(userId: "user_123", companyId: "acme", deviceId: "some_other_device"))
        waitForTrackingQueue(mixpanel)

        XCTAssertEqual(mixpanel.anonymousId, deviceId)
        XCTAssertEqual(mixpanel.identity.userId, "user_123")
        mixpanel.track(event: "Viewed Report")
        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["$device_id"] as? String, deviceId)
    }

    func testGetIdentityReportsUserCompanyAndDevice() {
        let mixpanel = newApi(true)
        XCTAssertEqual(mixpanel.identity, MixpanelIdentity(userId: nil, deviceId: mixpanel.anonymousId))

        identify(mixpanel, "user_123", "acme")
        XCTAssertEqual(
            mixpanel.identity,
            MixpanelIdentity(userId: "user_123", companyId: "acme", deviceId: mixpanel.anonymousId))

        // What analytics reports, it accepts back unchanged
        mixpanel.identify(identity: mixpanel.identity)
        waitForTrackingQueue(mixpanel)
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 1)
    }

    func testGetIdentityWhenDisabledHasNoCompany() {
        let mixpanel = newApi(false)
        mixpanel.identify(distinctId: "user_123")
        waitForTrackingQueue(mixpanel)
        XCTAssertEqual(
            mixpanel.identity, MixpanelIdentity(userId: "user_123", deviceId: mixpanel.anonymousId))
    }

    func testCompanyPersistsAcrossRestarts() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        XCTAssertEqual(
            MixpanelPersistence.loadIdentity(instanceName: mixpanel.apiToken).companyId, "acme")

        mixpanel.unarchive()
        XCTAssertEqual(mixpanel.identity.userId, "user_123")
        XCTAssertEqual(mixpanel.identity.companyId, "acme")
    }

    // MARK: - distinctId reports the id Mixpanel resolves the user to

    @available(*, deprecated)
    func testDistinctIdIsDeviceBeforeIdentify() {
        let mixpanel = newApi(true)
        XCTAssertEqual(distinctId(mixpanel), "$device:" + mixpanel.anonymousId!)
        XCTAssertEqual(mixpanel.getDistinctId(), distinctId(mixpanel))
    }

    @available(*, deprecated)
    func testDistinctIdCombinesCompanyAndUser() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        XCTAssertEqual(distinctId(mixpanel), "$company:acme|$user:user_123")
        XCTAssertEqual(mixpanel.getDistinctId(), "$company:acme|$user:user_123")

        // Events still send the stored id; ingestion resolves the user from the identity keys
        mixpanel.track(event: "Viewed Report")
        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["distinct_id"] as? String, "user_123")

        identify(mixpanel, "user_123", "globex")
        XCTAssertEqual(distinctId(mixpanel), "$company:globex|$user:user_123")
    }

    @available(*, deprecated)
    func testDistinctIdStaysOnDeviceUntilCompanyIsKnown() {
        let mixpanel = newApi(true)
        mixpanel.identify(distinctId: "user_123")
        XCTAssertEqual(distinctId(mixpanel), "$device:" + mixpanel.anonymousId!)
    }

    @available(*, deprecated)
    func testDistinctIdUnchangedWhenDisabled() {
        let mixpanel = newApi(false)
        mixpanel.identify(distinctId: "user_123")
        XCTAssertEqual(distinctId(mixpanel), "user_123")
        XCTAssertEqual(mixpanel.getDistinctId(), "user_123")
    }

    @available(*, deprecated)
    func testResetReturnsToDeviceDistinctId() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.reset()
        XCTAssertEqual(distinctId(mixpanel), "$device:" + mixpanel.anonymousId!)
    }

    func testResetClearsCompany() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.reset()
        waitForTrackingQueue(mixpanel)

        XCTAssertNil(mixpanel.identity.companyId)
        XCTAssertNil(MixpanelPersistence.loadIdentity(instanceName: mixpanel.apiToken).companyId)
        mixpanel.track(event: "Opened")
        XCTAssertNil(lastEventProperties(mixpanel, "Opened")["$company_id"])
    }

    func testAliasIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.createAlias("new_id", distinctId: "user_123")

        XCTAssertEqual(countEvents(mixpanel, "$create_alias"), 0)
    }

    // MARK: - Opt in / opt out

    func testOptInWithIdentityCarriesCompany() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.optOutTracking()
        mixpanel.optInTracking(identity: MixpanelIdentity(userId: "user_123", companyId: "acme"))
        waitForTrackingQueue(mixpanel)

        let props = lastEventProperties(mixpanel, "$opt_in")
        XCTAssertEqual(props["$user_id"] as? String, "user_123")
        XCTAssertEqual(props["$company_id"] as? String, "acme")
        XCTAssertEqual(mixpanel.identity.companyId, "acme")
    }

    func testOptInWithDistinctIdIsDropped() {
        let mixpanel = newApi(true)
        mixpanel.optOutTracking()
        waitForTrackingQueue(mixpanel)
        mixpanel.optInTracking(distinctId: "user_123")
        mixpanel.optInTracking(distinctId: "user_123", properties: nil)
        waitForTrackingQueue(mixpanel)

        XCTAssertTrue(mixpanel.hasOptedOutTracking())
        XCTAssertEqual(countEvents(mixpanel, "$opt_in"), 0)
    }

    func testOptInWithoutArgumentsStillWorks() {
        let mixpanel = newApi(true)
        mixpanel.optOutTracking()
        mixpanel.optInTracking()
        waitForTrackingQueue(mixpanel)

        XCTAssertFalse(mixpanel.hasOptedOutTracking())
        XCTAssertEqual(countEvents(mixpanel, "$opt_in"), 1)
    }

    func testOptInWithoutIdentityStaysAnonymous() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.optOutTracking()
        mixpanel.optInTracking(properties: ["source": "settings"])
        waitForTrackingQueue(mixpanel)

        let props = lastEventProperties(mixpanel, "$opt_in")
        XCTAssertEqual(props["source"] as? String, "settings")
        XCTAssertNil(props["$company_id"])
        XCTAssertNil(props["$user_id"])
    }

    func testOptOutDeletesUserWithoutClearingCharges() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.optOutTracking()
        waitForTrackingQueue(mixpanel)

        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(people(mixpanel).count, 0)
        let message = groups[0]
        XCTAssertNotNil(message["$delete"])
        XCTAssertEqual(message["$group_key"] as? String, "$user_id")
        XCTAssertEqual(message["$group_id"] as? String, "user_123")
        XCTAssertEqual(message["$company_id"] as? String, "acme")
        XCTAssertNil(mixpanel.identity.companyId)
    }

    // MARK: - Disabled: behaves exactly as before

    func testIdentifyWithCompanyIsIgnoredWhenDisabled() {
        let mixpanel = newApi(false)
        let anonymous = mixpanel.identity
        identify(mixpanel, "user_123", "acme")

        XCTAssertEqual(mixpanel.identity, anonymous)
        XCTAssertNil(mixpanel.identity.companyId)
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 0)
    }

    func testDisabledSendsPeopleToEngage() {
        let mixpanel = newApi(false)
        mixpanel.identify(distinctId: "user_123")
        mixpanel.people.set(property: "plan", to: "pro")
        mixpanel.people.increment(property: "logins", by: 1)
        mixpanel.track(event: "Viewed Report")

        let people = self.people(mixpanel)
        XCTAssertEqual(people.count, 2)
        XCTAssertEqual(groups(mixpanel).count, 0)
        XCTAssertEqual(people[0]["$distinct_id"] as? String, "user_123")
        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["$company_id"])
    }

    func testIdentityWithoutCompanyWorksWhenDisabled() {
        let mixpanel = newApi(false)
        identify(mixpanel, "user_123")

        XCTAssertEqual(mixpanel.identity.userId, "user_123")
        XCTAssertEqual(lastEventProperties(mixpanel, "$identify")["distinct_id"] as? String, "user_123")
        XCTAssertEqual(countEvents(mixpanel, "$identify"), 1)
    }

    // MARK: - User profiles

    func testPeopleUpdatesBecomeUserIdGroupProfiles() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        let people = mixpanel.people!
        people.set(property: "plan", to: "pro")
        people.setOnce(properties: ["first_seen": "today"])
        people.union(properties: ["roles": ["admin"]])
        people.remove(properties: ["roles": "viewer"])
        people.unset(properties: ["legacy"])
        people.deleteUser()

        XCTAssertEqual(self.people(mixpanel).count, 0)
        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 6)
        let operations = ["$set", "$set_once", "$union", "$remove", "$unset", "$delete"]
        for (i, operation) in operations.enumerated() where i < groups.count {
            let message = groups[i]
            XCTAssertNotNil(message[operation], operation)
            XCTAssertEqual(message["$group_key"] as? String, "$user_id")
            XCTAssertEqual(message["$group_id"] as? String, "user_123")
            XCTAssertEqual(message["$company_id"] as? String, "acme")
            XCTAssertNil(message["$distinct_id"])
            XCTAssertNil(message["$device_id"])
            XCTAssertNil(message["$user_id"])
            XCTAssertNotNil(message["$mp_metadata"])
        }
        let set = groups.first?["$set"] as? InternalProperties
        XCTAssertEqual(set?["plan"] as? String, "pro")
        // Platform extras that /engage $set had are kept
        if let set = set {
            assertDefaultPeopleProperties(set)
        }
        XCTAssertEqual(groups.dropFirst(4).first?["$unset"] as? [String], ["legacy"])
    }

    func testUnsupportedPeopleOperationsAreDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        let people = mixpanel.people!
        people.increment(property: "logins", by: 1)
        people.append(properties: ["history": "a"])
        people.merge(properties: ["settings": ["theme": "dark"]])
        people.trackCharge(amount: 9.99)
        people.clearCharges()

        XCTAssertEqual(self.people(mixpanel).count, 0)
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testPeopleUpdatesBeforeIdentifyAreDropped() {
        let mixpanel = newApi(true)
        mixpanel.people.set(property: "plan", to: "pro")

        XCTAssertEqual(people(mixpanel).count, 0)
        XCTAssertEqual(groups(mixpanel).count, 0)

        // Nothing queued anonymously is attributed to a later identify
        identify(mixpanel, "user_123", "acme")
        XCTAssertEqual(people(mixpanel).count, 0)
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testPeopleUpdatesWithoutCompanyAreDropped() {
        let mixpanel = newApi(true)
        mixpanel.identify(distinctId: "user_123")
        mixpanel.people.set(property: "plan", to: "pro")

        XCTAssertEqual(people(mixpanel).count, 0)
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testPeopleUpdateRightAfterIdentifyUsesTheNewIdentity() {
        let mixpanel = newApi(true)
        mixpanel.identify(identity: MixpanelIdentity(userId: "user_123", companyId: "acme"))
        mixpanel.people.set(property: "plan", to: "pro")

        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?["$group_id"] as? String, "user_123")
        XCTAssertEqual(groups.first?["$company_id"] as? String, "acme")
    }

    func testSetGroupWritesUserProfileThroughGroups() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: "finance")

        XCTAssertEqual(people(mixpanel).count, 0)
        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?["$group_key"] as? String, "$user_id")
        XCTAssertEqual((groups.first?["$set"] as? InternalProperties)?["team"] as? String, "finance")
    }

    // MARK: - Custom group membership: one group per key, stored as a single value

    func testSetGroupSendsSingleValueOnEvents() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: "finance")
        mixpanel.track(event: "Viewed Report")

        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["team"] as? String, "finance")
    }

    func testSetGroupWithListIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupIDs: ["finance"])
        mixpanel.track(event: "Viewed Report")

        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["team"])
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testSetGroupWithArrayValueIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: ["finance"])
        mixpanel.track(event: "Viewed Report")

        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["team"])
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testSetGroupWithSeveralGroupsIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupIDs: ["finance", "sales"])
        mixpanel.track(event: "Viewed Report")

        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["team"])
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testAddGroupIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.addGroup(groupKey: "team", groupID: "finance")
        mixpanel.track(event: "Viewed Report")

        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["team"])
        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testAddGroupToSecondGroupIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: "finance")
        mixpanel.addGroup(groupKey: "team", groupID: "sales")
        mixpanel.track(event: "Viewed Report")

        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["team"] as? String, "finance")
        XCTAssertEqual(groups(mixpanel).count, 1)
    }

    func testRemoveGroupClearsTheGroup() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: "finance")
        mixpanel.removeGroup(groupKey: "team", groupID: "finance")
        mixpanel.track(event: "Viewed Report")

        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["team"])
        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.last?["$unset"] as? [String], ["team"])
        XCTAssertEqual(groups.last?["$group_key"] as? String, "$user_id")
    }

    func testRemoveOtherGroupDoesNothing() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: "finance")
        mixpanel.removeGroup(groupKey: "team", groupID: "sales")
        mixpanel.track(event: "Viewed Report")

        XCTAssertEqual(lastEventProperties(mixpanel, "Viewed Report")["team"] as? String, "finance")
        XCTAssertEqual(groups(mixpanel).count, 1)
    }

    func testRemoveGroupClearsListStoredBeforeHierarchicalGroups() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.registerSuperProperties(["team": ["finance"]])
        mixpanel.removeGroup(groupKey: "team", groupID: "finance")
        mixpanel.track(event: "Viewed Report")

        XCTAssertNil(lastEventProperties(mixpanel, "Viewed Report")["team"])
    }

    func testRemoveGroupThenIdentifyClearsThePreviousUser() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.setGroup(groupKey: "team", groupID: "finance")
        mixpanel.removeGroup(groupKey: "team", groupID: "finance")
        mixpanel.identify(identity: MixpanelIdentity(userId: "user_456", companyId: "globex"))

        let unset = groups(mixpanel).last
        XCTAssertEqual(unset?["$unset"] as? [String], ["team"])
        XCTAssertEqual(unset?["$group_id"] as? String, "user_123")
        XCTAssertEqual(unset?["$company_id"] as? String, "acme")
    }

    func testDisabledGroupMembershipStaysAList() {
        let mixpanel = newApi(false)
        mixpanel.setGroup(groupKey: "team", groupID: "finance")
        mixpanel.addGroup(groupKey: "team", groupID: "sales")
        mixpanel.track(event: "Viewed Report")

        let teams = lastEventProperties(mixpanel, "Viewed Report")["team"] as? [String]
        XCTAssertEqual(teams, ["finance", "sales"])
    }

    func testTrackWithGroupsSendsSingleValue() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.trackWithGroups(
            event: "Viewed Report", properties: ["page": "home"], groups: ["team": "finance"])

        let properties = lastEventProperties(mixpanel, "Viewed Report")
        XCTAssertEqual(properties["team"] as? String, "finance")
        XCTAssertEqual(properties["page"] as? String, "home")
    }

    func testTrackWithGroupsWithListIsDropped() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.trackWithGroups(
            event: "Viewed Report", properties: ["page": "home"],
            groups: ["region": "emea", "team": ["finance", "sales"]])
        mixpanel.trackWithGroups(event: "Viewed Report", properties: nil, groups: ["team": ["finance"]])

        XCTAssertEqual(countEvents(mixpanel, "Viewed Report"), 0)
    }

    func testDisabledTrackWithGroupsSendsList() {
        let mixpanel = newApi(false)
        mixpanel.trackWithGroups(
            event: "Viewed Report", properties: ["page": "home"], groups: ["team": ["finance", "sales"]])

        let teams = lastEventProperties(mixpanel, "Viewed Report")["team"] as? [String]
        XCTAssertEqual(teams, ["finance", "sales"])
    }

    // MARK: - Group profiles

    func testGroupUpdatesCarryCompany() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.getGroup(groupKey: "$company_id", groupID: "acme").set(property: "tier", to: "enterprise")
        mixpanel.getGroup(groupKey: "team", groupID: "finance").set(property: "size", to: 12)

        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 2)
        let company = groups[0]
        XCTAssertEqual(company["$group_key"] as? String, "$company_id")
        XCTAssertEqual(company["$group_id"] as? String, "acme")
        XCTAssertEqual(company["$company_id"] as? String, "acme")
        XCTAssertNil((company["$set"] as? InternalProperties)?["$company_id"])

        let team = groups[1]
        XCTAssertEqual(team["$group_key"] as? String, "team")
        XCTAssertEqual(team["$company_id"] as? String, "acme")
    }

    func testGetCompanyUpdatesIdentifiedCompany() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        mixpanel.getCompany()?.set(property: "tier", to: "enterprise")

        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 1)
        let message = groups.first
        XCTAssertEqual(message?["$group_key"] as? String, "$company_id")
        XCTAssertEqual(message?["$group_id"] as? String, "acme")
        XCTAssertEqual(message?["$company_id"] as? String, "acme")
        XCTAssertEqual((message?["$set"] as? InternalProperties)?["tier"] as? String, "enterprise")
        XCTAssertTrue(mixpanel.getGroup(groupKey: "$company_id", groupID: "acme") === mixpanel.getCompany())
    }

    func testGetCompanyBeforeIdentifyIsNil() {
        let mixpanel = newApi(true)
        XCTAssertNil(mixpanel.getCompany())
    }

    func testGetCompanyIsFixedWhenCalled() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        let company = mixpanel.getCompany()
        identify(mixpanel, "user_123", "globex")
        company?.set(property: "tier", to: "enterprise")

        XCTAssertEqual(groups(mixpanel).first?["$group_id"] as? String, "acme")
    }

    func testGetCompanyKeepsItsCompanyAfterIdentify() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        let company = mixpanel.getCompany()
        identify(mixpanel, "user_456", "globex")
        company?.set(property: "tier", to: "enterprise")

        let message = groups(mixpanel).first
        XCTAssertEqual(message?["$group_id"] as? String, "acme")
        XCTAssertEqual(message?["$company_id"] as? String, "acme")
    }

    func testGetCompanyKeepsItsCompanyAfterReset() {
        let mixpanel = newApi(true)
        identify(mixpanel, "user_123", "acme")
        let company = mixpanel.getCompany()
        mixpanel.reset()
        company?.set(property: "tier", to: "enterprise")

        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?["$group_id"] as? String, "acme")
        XCTAssertEqual(groups.first?["$company_id"] as? String, "acme")
    }

    func testGetCompanyWhenDisabledIsNil() {
        let mixpanel = newApi(false)
        XCTAssertNil(mixpanel.getCompany())
    }

    func testGroupUpdatesWithoutCompanyAreDropped() {
        let mixpanel = newApi(true)
        mixpanel.getGroup(groupKey: "team", groupID: "finance").set(property: "size", to: 12)

        XCTAssertEqual(groups(mixpanel).count, 0)
    }

    func testDisabledGroupUpdatesCarryNoCompany() {
        let mixpanel = newApi(false)
        mixpanel.getGroup(groupKey: "team", groupID: "finance").set(property: "size", to: 12)

        let groups = self.groups(mixpanel)
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups.first?["$company_id"])
    }

    // MARK: - Feature flags

    private func newFlagsApi(_ hierarchicalGroups: Bool) -> MixpanelInstance {
        URLProtocol.registerClass(FlagsRecordingURLProtocol.self)
        let options = MixpanelOptions(
            token: randomId(), flushInterval: 60,
            serverURL: "https://\(FlagsRecordingURLProtocol.host)",
            featureFlagOptions: FeatureFlagOptions(enabled: true, prefetchFlags: false),
            hierarchicalGroups: hierarchicalGroups)
        let mixpanel = Mixpanel.initialize(options: options)
        mixpanel.delegate = self
        instances.append(mixpanel)
        waitForTrackingQueue(mixpanel)
        return mixpanel
    }

    private func loadFlags(_ mixpanel: MixpanelInstance) {
        let loaded = expectation(description: "flags loaded")
        mixpanel.flags.loadFlags { _ in loaded.fulfill() }
        wait(for: [loaded], timeout: 10)
    }

    private func lastFlagsContext() -> NSDictionary? {
        guard
            let request = FlagsRecordingURLProtocol.requests().last(where: { $0.url.path == "/flags" }),
            let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems,
            let context = items.first(where: { $0.name == "context" })?.value?.data(using: .utf8)
        else {
            XCTFail("No /flags request was sent")
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: context)) as? NSDictionary
    }

    func testFlagsContextCarriesUserAndCompany() {
        let mixpanel = newFlagsApi(true)
        identify(mixpanel, "user_123", "acme")
        loadFlags(mixpanel)

        let expected: NSDictionary = [
            "distinct_id": "user_123", "device_id": mixpanel.anonymousId!,
            "$user_id": "user_123", "$company_id": "acme",
        ]
        XCTAssertEqual(lastFlagsContext(), expected)
    }

    func testFlagsContextBeforeIdentifyIsAnonymous() {
        let mixpanel = newFlagsApi(true)
        loadFlags(mixpanel)

        let anonymousId = mixpanel.anonymousId!
        let expected: NSDictionary = ["distinct_id": "$device:\(anonymousId)", "device_id": anonymousId]
        XCTAssertEqual(lastFlagsContext(), expected)
    }

    func testDisabledFlagsContextIsUnchanged() {
        let mixpanel = newFlagsApi(false)
        mixpanel.identify(distinctId: "user_123")
        waitForTrackingQueue(mixpanel)
        loadFlags(mixpanel)

        let expected: NSDictionary = ["distinct_id": "user_123", "device_id": mixpanel.anonymousId!]
        XCTAssertEqual(lastFlagsContext(), expected)
    }

    func testFirstTimeEventCarriesUserAndCompany() {
        FlagsRecordingURLProtocol.flagsResponse = """
            {"flags": {}, "pending_first_time_events": [{
              "flag_key": "hg-flag", "flag_id": "flag-123", "project_id": 3,
              "first_time_event_hash": "abc123", "event_name": "Purchase",
              "pending_variant": {"variant_key": "treatment", "variant_value": true}
            }]}
            """
        let mixpanel = newFlagsApi(true)
        identify(mixpanel, "user_123", "acme")
        loadFlags(mixpanel)
        mixpanel.track(event: "Purchase")

        let path = "/flags/flag-123/first-time-events"
        let recorded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                FlagsRecordingURLProtocol.requests().contains { $0.url.path == path }
            }, object: nil)
        wait(for: [recorded], timeout: 10)

        let body = FlagsRecordingURLProtocol.requests().first { $0.url.path == path }?.body ?? Data()
        let expected: NSDictionary = [
            "distinct_id": "user_123", "project_id": 3, "first_time_event_hash": "abc123",
            "$user_id": "user_123", "$company_id": "acme",
        ]
        XCTAssertEqual((try? JSONSerialization.jsonObject(with: body)) as? NSDictionary, expected)
    }

    func testExperimentStartedCarriesUserAndCompany() {
        FlagsRecordingURLProtocol.flagsResponse = """
            {"flags": {"hg-flag": {"variant_key": "treatment", "variant_value": true}}}
            """
        let mixpanel = newFlagsApi(true)
        identify(mixpanel, "user_123", "acme")
        loadFlags(mixpanel)
        _ = mixpanel.flags.getVariantSync("hg-flag", fallback: MixpanelFlagVariant(value: false))
        waitForAsyncTasks()

        let props = lastEventProperties(mixpanel, "$experiment_started")
        XCTAssertEqual(props["distinct_id"] as? String, "user_123")
        XCTAssertEqual(props["$user_id"] as? String, "user_123")
        XCTAssertEqual(props["$company_id"] as? String, "acme")
    }

    // MARK: - Types and options

    func testIdentityInitializerDefaults() {
        XCTAssertNil(MixpanelIdentity(userId: "user_123").companyId)
        XCTAssertNil(MixpanelIdentity(userId: "user_123", companyId: "acme").deviceId)
        XCTAssertEqual(
            MixpanelIdentity(userId: "user_123", companyId: "acme", deviceId: "device_abc").deviceId,
            "device_abc")
        XCTAssertEqual(
            MixpanelIdentity(userId: "u", companyId: "c").description,
            "MixpanelIdentity(userId=u, companyId=c)")
    }

    func testCompanyIdIsReserved() {
        XCTAssertTrue(MixpanelOptions.reservedPropertyKeys.contains("$company_id"))
    }

    func testOptionDefaultsToDisabled() {
        XCTAssertFalse(MixpanelOptions(token: "t").hierarchicalGroups)
        XCTAssertTrue(MixpanelOptions(token: "t", hierarchicalGroups: true).hierarchicalGroups)
    }
}

/// Records the requests sent to `host` and answers /flags with `flagsResponse`, so flag tests can
/// read what was sent without touching the network.
private class FlagsRecordingURLProtocol: URLProtocol {
    static let host = "hg-flags-test.mixpanel.com"
    static var flagsResponse = "{\"flags\": {}}"
    private static let lock = NSLock()
    private static var recorded: [(url: URL, body: Data)] = []

    static func reset() {
        lock.lock()
        flagsResponse = "{\"flags\": {}}"
        recorded = []
        lock.unlock()
    }

    static func requests() -> [(url: URL, body: Data)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        FlagsRecordingURLProtocol.lock.lock()
        FlagsRecordingURLProtocol.recorded.append((url: url, body: readBody()))
        let body = url.path == "/flags" ? FlagsRecordingURLProtocol.flagsResponse : "1"
        FlagsRecordingURLProtocol.lock.unlock()

        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: .utf8)!)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func readBody() -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}
