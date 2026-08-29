import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class GateUnlockConsumptionTests: XCTestCase {
    func testValidRequestIsConsumedMatchedToRuleAndNotificationIsCancelled() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let tokenData = try GateTokenCoding.encode(context.token)
        let requestID = UUID()
        let model = context.makeModel()
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [context.token]
        let rule = try model.ruleStore.saveFamilyActivitySelection(
            JSONEncoder().encode(selection),
            name: "テスト対象",
            mode: .standard
        )
        try context.requestStore.save(
            GateUnlockRequest(
                id: requestID,
                tokenData: tokenData,
                requestedAt: context.now.addingTimeInterval(-30)
            )
        )

        model.consumePendingGateUnlock()

        XCTAssertEqual(
            model.pendingInterventionTarget,
            .gateToken(tokenData: tokenData, ruleId: rule.id)
        )
        XCTAssertNil(try context.requestStore.request())
        XCTAssertEqual(
            context.notificationCenter.removedPendingIdentifiers,
            [[GateConstants.unlockNotificationIdentifier(for: requestID)]]
        )
        XCTAssertEqual(
            context.notificationCenter.removedDeliveredIdentifiers,
            [[GateConstants.unlockNotificationIdentifier(for: requestID)]]
        )
    }

    func testExpiredRequestIsDiscardedWithoutPresentingIntervention() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let tokenData = try GateTokenCoding.encode(context.token)
        let requestID = UUID()
        let model = context.makeModel()
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [context.token]
        _ = try model.ruleStore.saveFamilyActivitySelection(
            JSONEncoder().encode(selection),
            name: "テスト対象",
            mode: .standard
        )
        try context.requestStore.save(
            GateUnlockRequest(
                id: requestID,
                tokenData: tokenData,
                requestedAt: context.now.addingTimeInterval(-GateConstants.pendingRequestTTL)
            )
        )

        model.consumePendingGateUnlock()

        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertNil(try context.requestStore.request())
        XCTAssertEqual(
            context.notificationCenter.removedDeliveredIdentifiers,
            [[GateConstants.unlockNotificationIdentifier(for: requestID)]]
        )
    }

    func testRulesReadFailurePreservesValidRequestForRetry() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let tokenData = try GateTokenCoding.encode(context.token)
        let request = GateUnlockRequest(
            id: UUID(),
            tokenData: tokenData,
            requestedAt: context.now.addingTimeInterval(-30)
        )
        try context.requestStore.save(request)
        try Data("corrupt-rules".utf8).write(
            to: context.snapshotStore.url(for: .rules),
            options: .atomic
        )
        let model = context.makeModel()

        model.consumePendingGateUnlock()

        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertEqual(try context.requestStore.request(), request)
        XCTAssertTrue(context.notificationCenter.removedPendingIdentifiers.isEmpty)
        XCTAssertTrue(context.notificationCenter.removedDeliveredIdentifiers.isEmpty)
    }

    func testUnconfirmedEntitlementAllowsGateInterventionPresentation() {
        XCTAssertTrue(
            GateEntitlementAccess.isAllowed(
                hasConfirmedEntitlement: false,
                gateAllowed: false
            )
        )
        XCTAssertFalse(
            GateEntitlementAccess.isAllowed(
                hasConfirmedEntitlement: true,
                gateAllowed: false
            )
        )
    }

    func testActiveGrantSuppressesAutomationAfterMarkingItVerified() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        try context.gateLedgerStore.save(
            GateLedger(
                entries: [],
                activeGrants: [context.gateGrant(endsAt: context.now.addingTimeInterval(60))],
                updatedAt: context.now
            )
        )

        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)

        XCTAssertTrue(context.settingsStore.isAutomationVerified(catalogID: "instagram"))
        XCTAssertNil(model.pendingInterventionTarget)
    }

    func testExpiredGrantDoesNotSuppressAutomationIntervention() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        try context.gateLedgerStore.save(
            GateLedger(
                entries: [],
                activeGrants: [context.gateGrant(endsAt: context.now)],
                updatedAt: context.now
            )
        )

        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "instagram").map(InterventionTarget.catalog)
        )
    }

    func testOmittedShortcutParameterAutoResolvesSingleSelectedTargetOnce() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        context.settingsStore.pendingStartInterventionAutoResolve = true

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "instagram").map(InterventionTarget.catalog)
        )
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testOmittedShortcutParameterWithMultipleTargetsUsesFirstSelectedTarget() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["youtube", "instagram", "x"])
        context.settingsStore.pendingStartInterventionAutoResolve = true

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "youtube").map(InterventionTarget.catalog)
        )
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testExplicitShortcutParameterWinsWhenBothPendingKeysExist() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["instagram", "youtube"])
        context.settingsStore.pendingStartInterventionCatalogID = "youtube"
        context.settingsStore.pendingStartInterventionAutoResolve = true

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "youtube").map(InterventionTarget.catalog)
        )
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testOmittedShortcutParameterWithNoSelectionClearsOneShotWithoutPresentation() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        context.settingsStore.pendingStartInterventionAutoResolve = true

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    private func makeContext() throws -> GateUnlockTestContext {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GateUnlockConsumptionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let suiteName = "GateUnlockConsumptionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let token = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLWdhdGUtdW5sb2NrLXRva2Vu"}"#.utf8)
        )
        return GateUnlockTestContext(
            containerURL: containerURL,
            suiteName: suiteName,
            settingsStore: SettingsStore(userDefaults: defaults),
            token: token,
            now: Date(timeIntervalSince1970: 1_777_777_700),
            notificationCenter: RecordingGateUnlockNotifications()
        )
    }
}

@MainActor
private struct GateUnlockTestContext {
    let containerURL: URL
    let suiteName: String
    let settingsStore: SettingsStore
    let token: ApplicationToken
    let now: Date
    let notificationCenter: RecordingGateUnlockNotifications

    var snapshotStore: JSONSnapshotStore {
        JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
    }

    var requestStore: GateUnlockRequestStore {
        GateUnlockRequestStore(snapshotStore: snapshotStore)
    }

    var gateLedgerStore: GateLedgerStore {
        GateLedgerStore(snapshotStore: snapshotStore)
    }

    func gateGrant(endsAt: Date) -> GateGrant {
        GateGrant(
            id: UUID(),
            tokenData: Data("unrelated-active-gate-token".utf8),
            ruleId: UUID(),
            startedAt: now.addingTimeInterval(-60),
            endsAt: endsAt,
            activityName: "automation-suppression-test"
        )
    }

    func makeModel() -> AppModel {
        AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore,
            gateUnlockNotificationCenter: notificationCenter,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false,
            now: { now }
        )
    }

    func cleanup() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
    }
}

private final class RecordingGateUnlockNotifications: GateUnlockNotificationRemoving {
    private(set) var removedPendingIdentifiers: [[String]] = []
    private(set) var removedDeliveredIdentifiers: [[String]] = []

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
    }
}
