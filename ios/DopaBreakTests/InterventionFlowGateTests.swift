import DeviceActivity
import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class InterventionFlowGateTests: XCTestCase {
    func testGateTargetUsesPerAppSessionMinutesAsDefaultDuration() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let tokenData = try GateTokenCoding.encode(context.token)
        try context.gateSettingsStore.save(
            GateAppSettingsSnapshot(
                settings: [
                    GateAppSetting(
                        tokenData: tokenData,
                        dailyOpenLimit: nil,
                        sessionMinutes: 15,
                        cooldownMinutes: 0,
                        updatedAt: context.now
                    )
                ],
                updatedAt: context.now
            )
        )
        let model = context.makeModel()

        let flow = InterventionFlowModel(
            target: .gateToken(tokenData: tokenData, ruleId: UUID()),
            model: model,
            settingsStore: context.settingsStore
        )

        XCTAssertEqual(flow.selectedDuration, .fifteenMinutes)
    }

    func testGateDenialHappensBeforeRecordOpenAndRecordsCancelledAttempt() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let tokenData = try GateTokenCoding.encode(context.token)
        let ruleID = UUID()
        try context.gateSettingsStore.save(
            GateAppSettingsSnapshot(
                settings: [
                    GateAppSetting(
                        tokenData: tokenData,
                        dailyOpenLimit: 1,
                        sessionMinutes: 10,
                        cooldownMinutes: 0,
                        updatedAt: context.now
                    )
                ],
                updatedAt: context.now
            )
        )
        try context.gateLedgerStore.save(
            GateLedger(
                entries: [
                    GateLedgerEntry(
                        tokenData: tokenData,
                        dayKey: GatePolicy.dayKey(for: context.now, calendar: .current),
                        opensToday: 1,
                        lastGrantEndedAt: nil
                    )
                ],
                activeGrants: [],
                updatedAt: context.now
            )
        )
        let model = context.makeModel()
        let flow = InterventionFlowModel(
            target: .gateToken(tokenData: tokenData, ruleId: ruleID),
            model: model,
            settingsStore: context.settingsStore
        )

        flow.start()
        XCTAssertEqual(flow.stage, .breathing)
        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .reasonSelection)
        flow.selectReason(.work)
        XCTAssertEqual(flow.stage, .durationSelection)
        flow.confirmSelectedDuration()

        XCTAssertEqual(flow.stage, .limit(.limitReached(limit: 1)))
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .idle)
        let attempts = try context.logStore.fetchAttempts(
            from: .distantPast,
            to: .distantFuture
        )
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts.first?.ruleId, ruleID)
        XCTAssertEqual(attempts.first?.decision, .cancelled)
        XCTAssertFalse(attempts.first?.opened ?? true)
        XCTAssertTrue(try context.logStore.fetchReflections().isEmpty)
        XCTAssertTrue(try context.gateLedgerStore.ledger().activeGrants.isEmpty)
    }

    func testSuccessfulGateFlowRecordsOpenGrantsAndTransitionsToOpening() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let tokenData = try GateTokenCoding.encode(context.token)
        let ruleID = UUID()
        let monitoringCenter = SuccessfulGateGrantMonitoring()
        let model = context.makeModel(gateGrantMonitoringCenter: monitoringCenter)
        let flow = InterventionFlowModel(
            target: .gateToken(tokenData: tokenData, ruleId: ruleID),
            model: model,
            settingsStore: context.settingsStore
        )

        flow.start()
        XCTAssertEqual(flow.stage, .breathing)
        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .reasonSelection)
        flow.selectReason(.work)
        XCTAssertEqual(flow.stage, .durationSelection)

        flow.confirmSelectedDuration()

        guard case .opening = flow.stage else {
            return XCTFail("Expected the successful gate grant to reach the opening stage")
        }
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .temporarilyAllowed)
        let attempts = try context.logStore.fetchAttempts()
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts.first?.ruleId, ruleID)
        XCTAssertEqual(attempts.first?.decision, .opened)
        XCTAssertTrue(attempts.first?.opened ?? false)
        XCTAssertEqual(try context.logStore.fetchReflections().count, 1)
        let grants = try context.gateLedgerStore.ledger().activeGrants
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.tokenData, tokenData)
        XCTAssertEqual(monitoringCenter.startedActivities.count, 1)
    }

    private func makeContext() throws -> GateFlowTestContext {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InterventionFlowGateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let suiteName = "InterventionFlowGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let token = try GateTokenCoding.decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLWdhdGUtZmxvdy10b2tlbg=="}"#.utf8)
        )
        return GateFlowTestContext(
            containerURL: containerURL,
            suiteName: suiteName,
            settingsStore: SettingsStore(userDefaults: defaults),
            token: token,
            now: Date(timeIntervalSince1970: 1_777_777_700)
        )
    }
}

@MainActor
private struct GateFlowTestContext {
    let containerURL: URL
    let suiteName: String
    let settingsStore: SettingsStore
    let token: ApplicationToken
    let now: Date

    private var snapshotStore: JSONSnapshotStore {
        JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
    }

    var gateSettingsStore: GateAppSettingsStore {
        GateAppSettingsStore(snapshotStore: snapshotStore)
    }

    var gateLedgerStore: GateLedgerStore {
        GateLedgerStore(snapshotStore: snapshotStore)
    }

    var logStore: SQLiteLogStore {
        get throws {
            try SQLiteLogStore(containerProvider: FixedContainer(url: containerURL))
        }
    }

    func makeModel(
        gateGrantMonitoringCenter: (any GateGrantMonitoring)? = nil
    ) -> AppModel {
        AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore,
            gateGrantMonitoringCenter: gateGrantMonitoringCenter,
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

private final class SuccessfulGateGrantMonitoring: GateGrantMonitoring {
    private(set) var startedActivities: [DeviceActivityName] = []

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        startedActivities.append(activity)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        startedActivities.removeAll { activities.contains($0) }
    }
}
