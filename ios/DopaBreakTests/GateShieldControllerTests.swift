import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class GateShieldControllerTests: XCTestCase {
    func testGateGrantRecoveryRunsForSnapshotOrCachedTierWithoutConfirmation() {
        XCTAssertTrue(
            GateGrantRecoveryPolicy.shouldReconcile(
                hasShieldSnapshot: true,
                gateAllowed: false
            )
        )
        XCTAssertTrue(
            GateGrantRecoveryPolicy.shouldReconcile(
                hasShieldSnapshot: false,
                gateAllowed: true
            )
        )
        XCTAssertFalse(
            GateGrantRecoveryPolicy.shouldReconcile(
                hasShieldSnapshot: false,
                gateAllowed: false
            )
        )
    }

    func testConfirmedFreeClearsGateStoreButPreservesSettingsAndLedgerFiles() throws {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GateShieldControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let storeName = "dopabreak.gate.test.\(UUID().uuidString.prefix(8))"
        let managedStore = ManagedSettingsStore(named: .init(storeName))
        defer {
            managedStore.clearAllSettings()
            try? FileManager.default.removeItem(at: containerURL)
        }

        let now = Date(timeIntervalSince1970: 1_777_777_700)
        let snapshotStore = JSONSnapshotStore(
            containerProvider: FixedContainer(url: containerURL)
        )
        let settingsStore = GateAppSettingsStore(snapshotStore: snapshotStore)
        let ledgerStore = GateLedgerStore(snapshotStore: snapshotStore)
        let shieldSnapshotStore = GateShieldSnapshotStore(snapshotStore: snapshotStore)
        let token = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLWZyZWUtZG93bmdyYWRl"}"#.utf8)
        )
        let tokenData = try GateTokenCoding.encode(token)
        let settings = GateAppSettingsSnapshot(
            settings: [
                GateAppSetting(
                    tokenData: tokenData,
                    dailyOpenLimit: 3,
                    sessionMinutes: 10,
                    cooldownMinutes: 5,
                    updatedAt: now
                )
            ],
            updatedAt: now
        )
        let ledger = GateLedger(
            entries: [
                GateLedgerEntry(
                    tokenData: tokenData,
                    dayKey: "2026-08-22",
                    opensToday: 2,
                    lastGrantEndedAt: now.addingTimeInterval(-300)
                )
            ],
            activeGrants: [],
            updatedAt: now
        )
        try settingsStore.save(settings)
        try ledgerStore.save(ledger)
        try shieldSnapshotStore.save(
            GateShieldSnapshot(selectionDataList: [Data([0x01])], updatedAt: now)
        )
        managedStore.shield.applications = [token]

        let controller = GateShieldController(
            ruleStore: RuleStore(snapshotStore: snapshotStore),
            ledgerStore: ledgerStore,
            snapshotStore: shieldSnapshotStore,
            managedSettingsStore: managedStore,
            now: { now }
        )
        controller.sync(
            entitlementGate: EntitlementGate(tier: .free, now: now),
            hasConfirmedEntitlement: true
        )

        XCTAssertNil(managedStore.shield.applications)
        XCTAssertNil(try shieldSnapshotStore.snapshot())
        XCTAssertTrue(snapshotStore.exists(.gateAppSettings))
        XCTAssertTrue(snapshotStore.exists(.gateLedger))
        XCTAssertEqual(try settingsStore.snapshot(), settings)
        XCTAssertEqual(try ledgerStore.ledger(), ledger)
    }

    func testGateShieldSyncIgnoresDisabledRules() throws {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GateShieldEnabledRulesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let managedStore = ManagedSettingsStore(
            named: .init("dopabreak.gate.enabled-rules.\(UUID().uuidString.prefix(8))")
        )
        defer {
            managedStore.clearAllSettings()
            try? FileManager.default.removeItem(at: containerURL)
        }

        let now = Date(timeIntervalSince1970: 1_777_777_700)
        let snapshotStore = JSONSnapshotStore(
            containerProvider: FixedContainer(url: containerURL)
        )
        let enabledToken = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZW5hYmxlZC1nYXRlLXNoaWVsZC10b2tlbg=="}"#.utf8)
        )
        let disabledToken = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZGlzYWJsZWQtZ2F0ZS1zaGllbGQtdG9rZW4="}"#.utf8)
        )
        var enabledSelection = FamilyActivitySelection()
        enabledSelection.applicationTokens = [enabledToken]
        var disabledSelection = FamilyActivitySelection()
        disabledSelection.applicationTokens = [disabledToken]
        let enabledRule = makeRule(selection: enabledSelection, now: now)
        let disabledRule = makeRule(
            selection: disabledSelection,
            now: now,
            isEnabled: false
        )
        try snapshotStore.write([enabledRule, disabledRule], to: .rules)

        let shieldSnapshotStore = GateShieldSnapshotStore(snapshotStore: snapshotStore)
        let controller = GateShieldController(
            ruleStore: RuleStore(snapshotStore: snapshotStore),
            ledgerStore: GateLedgerStore(snapshotStore: snapshotStore),
            snapshotStore: shieldSnapshotStore,
            managedSettingsStore: managedStore,
            now: { now }
        )

        controller.sync(
            entitlementGate: EntitlementGate(tier: .pro, now: now),
            hasConfirmedEntitlement: true
        )

        let snapshot = try XCTUnwrap(try shieldSnapshotStore.snapshot())
        XCTAssertEqual(snapshot.selectionDataList, [enabledRule.activitySelectionData])
    }

    func testSettingsGateTargetsUnionEnabledRulesAndDedupeTokens() throws {
        let firstToken = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"Zmlyc3Qtc2V0dGluZ3MtZ2F0ZS10b2tlbg=="}"#.utf8)
        )
        let secondToken = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"c2Vjb25kLXNldHRpbmdzLWdhdGUtdG9rZW4="}"#.utf8)
        )
        let disabledToken = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZGlzYWJsZWQtc2V0dGluZ3MtZ2F0ZS10b2tlbg=="}"#.utf8)
        )
        var firstSelection = FamilyActivitySelection()
        firstSelection.applicationTokens = [firstToken]
        var secondSelection = FamilyActivitySelection()
        secondSelection.applicationTokens = [firstToken, secondToken]
        var disabledSelection = FamilyActivitySelection()
        disabledSelection.applicationTokens = [disabledToken]
        let now = Date(timeIntervalSince1970: 1_777_777_700)
        let rules = [
            makeRule(selection: firstSelection, now: now),
            makeRule(selection: secondSelection, now: now),
            makeRule(selection: disabledSelection, now: now, isEnabled: false),
            makeRule(selection: FamilyActivitySelection(), now: now, selectionData: Data())
        ]

        let targets = SettingsView.gateAppSettingTargets(from: rules)

        XCTAssertEqual(Set(targets.map(\.tokenData)), [
            try GateTokenCoding.encode(firstToken),
            try GateTokenCoding.encode(secondToken)
        ])
        XCTAssertEqual(targets.count, 2)
    }

    private func makeRule(
        selection: FamilyActivitySelection,
        now: Date,
        selectionData: Data? = nil,
        isEnabled: Bool = true
    ) -> TargetRule {
        TargetRule(
            id: UUID(),
            name: "gate rule",
            activitySelectionData: selectionData ?? (try! JSONEncoder().encode(selection)),
            mode: .standard,
            schedule: nil,
            delaySeconds: 0,
            maxOpensPerDay: nil,
            defaultDurationMinutes: 10,
            isEnabled: isEnabled,
            createdAt: now,
            updatedAt: now
        )
    }
}
