import DeviceActivity
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class GateGrantControllerTests: XCTestCase {
    private var containerURL: URL!
    private var snapshotStore: JSONSnapshotStore!
    private var settingsStore: GateAppSettingsStore!
    private var ledgerStore: GateLedgerStore!
    private var requestStore: GateUnlockRequestStore!
    private var monitoringCenter: RecordingGateGrantMonitoring!
    private var reappliedDates: [Date] = []
    private var currentDate = Date(timeIntervalSince1970: 1_777_777_700)

    override func setUpWithError() throws {
        try super.setUpWithError()
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GateGrantControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        snapshotStore = JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        settingsStore = GateAppSettingsStore(snapshotStore: snapshotStore)
        ledgerStore = GateLedgerStore(snapshotStore: snapshotStore)
        requestStore = GateUnlockRequestStore(snapshotStore: snapshotStore)
        monitoringCenter = RecordingGateGrantMonitoring()
        reappliedDates = []
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: containerURL)
        monitoringCenter = nil
        requestStore = nil
        ledgerStore = nil
        settingsStore = nil
        snapshotStore = nil
        containerURL = nil
        try super.tearDownWithError()
    }

    func testGrantUpdatesLedgerReappliesGateAndStartsReshieldMonitoring() throws {
        let tokenData = Data("gate-token".utf8)
        let ruleID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let grantID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        try settingsStore.save(
            GateAppSettingsSnapshot(
                settings: [
                    GateAppSetting(
                        tokenData: tokenData,
                        dailyOpenLimit: 2,
                        sessionMinutes: 10,
                        cooldownMinutes: 0,
                        updatedAt: currentDate
                    )
                ],
                updatedAt: currentDate
            )
        )
        try requestStore.save(
            GateUnlockRequest(
                id: UUID(),
                tokenData: tokenData,
                requestedAt: currentDate.addingTimeInterval(-30)
            )
        )

        let controller = makeController(grantID: grantID)
        let grant = try controller.grant(tokenData: tokenData, ruleId: ruleID, minutes: 10)

        XCTAssertEqual(grant.id, grantID)
        XCTAssertEqual(grant.startedAt, currentDate)
        XCTAssertEqual(grant.endsAt, currentDate.addingTimeInterval(600))
        XCTAssertEqual(grant.activityName, GateConstants.reshieldActivityName(for: grantID))
        let ledger = try ledgerStore.ledger()
        XCTAssertEqual(ledger.entries.first?.opensToday, 1)
        XCTAssertEqual(ledger.activeGrants, [grant])
        XCTAssertEqual(reappliedDates, [currentDate])
        XCTAssertEqual(monitoringCenter.startedActivities.map(\.rawValue), [grant.activityName])
        XCTAssertNil(try requestStore.request())

        let schedule = try XCTUnwrap(monitoringCenter.startedSchedules.first)
        let monitoringStart = try XCTUnwrap(Calendar.current.date(from: schedule.intervalStart))
        let monitoringEnd = try XCTUnwrap(Calendar.current.date(from: schedule.intervalEnd))
        XCTAssertGreaterThanOrEqual(monitoringStart, grant.endsAt)
        XCTAssertEqual(monitoringEnd, monitoringStart.addingTimeInterval(16 * 60))
        XCTAssertFalse(schedule.repeats)
    }

    func testGrantRoundsReshieldIntervalStartUpWhenEndsAtHasSeconds() throws {
        currentDate = Date(
            timeIntervalSince1970: floor(currentDate.timeIntervalSince1970 / 60) * 60 + 45
        )
        let controller = makeController()

        let grant = try controller.grant(
            tokenData: Data("seconds-component".utf8),
            ruleId: UUID(),
            minutes: 10
        )

        XCTAssertEqual(Calendar.current.component(.second, from: grant.endsAt), 45)
        let schedule = try XCTUnwrap(monitoringCenter.startedSchedules.first)
        let intervalStart = try XCTUnwrap(Calendar.current.date(from: schedule.intervalStart))
        let intervalEnd = try XCTUnwrap(Calendar.current.date(from: schedule.intervalEnd))
        XCTAssertGreaterThanOrEqual(intervalStart, grant.endsAt)
        XCTAssertEqual(intervalStart.timeIntervalSince(grant.endsAt), 15, accuracy: 0.001)
        XCTAssertEqual(intervalEnd, intervalStart.addingTimeInterval(16 * 60))
    }

    func testMonitoringFailureKeepsGrantWithEmptyActivityName() throws {
        let tokenData = Data("monitoring-failure".utf8)
        monitoringCenter.failsToStart = true
        let controller = makeController()

        let grant = try controller.grant(tokenData: tokenData, ruleId: UUID(), minutes: 5)

        XCTAssertEqual(grant.activityName, "")
        let ledger = try ledgerStore.ledger()
        XCTAssertEqual(ledger.entries.first?.opensToday, 1)
        XCTAssertEqual(ledger.activeGrants, [grant])
        XCTAssertEqual(reappliedDates, [currentDate])
    }

    func testReapplyFailureAfterCommitKeepsGrantAndStopsExpiredMonitoring() throws {
        let expiredGrant = GateGrant(
            id: UUID(),
            tokenData: Data("expired-before-reapply".utf8),
            ruleId: UUID(),
            startedAt: currentDate.addingTimeInterval(-1_200),
            endsAt: currentDate.addingTimeInterval(-60),
            activityName: "expired-before-reapply-activity"
        )
        try ledgerStore.save(
            GateLedger(
                entries: [],
                activeGrants: [expiredGrant],
                updatedAt: currentDate.addingTimeInterval(-60)
            )
        )
        let controller = GateGrantController(
            settingsStore: settingsStore,
            ledgerStore: ledgerStore,
            requestStore: requestStore,
            monitoringCenter: monitoringCenter,
            reapplyGate: { _ in throw GateGrantControllerTestError.reapplyFailed },
            now: { [weak self] in self?.currentDate ?? .distantPast },
            calendar: .current
        )

        let grant = try controller.grant(
            tokenData: Data("live-after-reapply-failure".utf8),
            ruleId: UUID(),
            minutes: 10
        )

        XCTAssertFalse(grant.activityName.isEmpty)
        XCTAssertEqual(try ledgerStore.ledger().activeGrants, [grant])
        XCTAssertTrue(
            monitoringCenter.stoppedActivities.contains([
                DeviceActivityName(expiredGrant.activityName)
            ])
        )
        XCTAssertEqual(monitoringCenter.startedActivities, [DeviceActivityName(grant.activityName)])
    }

    func testSecondLedgerUpdateFailureKeepsMonitoringAndReturnsPendingGrant() throws {
        let grantID = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        monitoringCenter.afterStart = { [snapshotStore] in
            guard let ledgerURL = try? snapshotStore?.url(for: .gateLedger) else {
                return
            }
            try? Data("not-json".utf8).write(to: ledgerURL, options: .atomic)
        }

        let grant = try makeController(grantID: grantID).grant(
            tokenData: Data("second-ledger-update-failure".utf8),
            ruleId: UUID(),
            minutes: 10
        )

        let activity = DeviceActivityName(GateConstants.reshieldActivityName(for: grantID))
        XCTAssertEqual(grant.activityName, "")
        XCTAssertEqual(monitoringCenter.startedActivities, [activity])
        XCTAssertFalse(monitoringCenter.stoppedActivities.contains([activity]))
    }

    func testSixthGrantExpiresOldestAndKeepsFiveConcurrentGrants() throws {
        let oldestToken = Data("oldest".utf8)
        let oldestID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        var existing: [GateGrant] = []
        for index in 0..<5 {
            existing.append(GateGrant(
                id: index == 0 ? oldestID : UUID(),
                tokenData: index == 0 ? oldestToken : Data("existing-\(index)".utf8),
                ruleId: UUID(),
                startedAt: currentDate.addingTimeInterval(TimeInterval(-500 + index)),
                endsAt: currentDate.addingTimeInterval(600),
                activityName: index == 0 ? "oldest-activity" : "activity-\(index)"
            ))
        }
        try ledgerStore.save(
            GateLedger(
                entries: existing.map {
                    GateLedgerEntry(
                        tokenData: $0.tokenData,
                        dayKey: GatePolicy.dayKey(for: currentDate, calendar: .current),
                        opensToday: 1,
                        lastGrantEndedAt: nil
                    )
                },
                activeGrants: existing,
                updatedAt: currentDate.addingTimeInterval(-500)
            )
        )

        _ = try makeController().grant(
            tokenData: Data("sixth".utf8),
            ruleId: UUID(),
            minutes: 10
        )

        let ledger = try ledgerStore.ledger()
        XCTAssertEqual(ledger.activeGrants.count, 5)
        XCTAssertFalse(ledger.activeGrants.contains { $0.id == oldestID })
        XCTAssertEqual(
            ledger.entries.first { $0.tokenData == oldestToken }?.lastGrantEndedAt,
            currentDate
        )
        XCTAssertTrue(
            monitoringCenter.stoppedActivities.contains([
                DeviceActivityName("oldest-activity")
            ])
        )
    }

    func testReconcileExpiresFinishedGrantsReappliesGateAndStopsActivities() throws {
        let expiredToken = Data("expired".utf8)
        let activeToken = Data("active".utf8)
        let expired = GateGrant(
            id: UUID(),
            tokenData: expiredToken,
            ruleId: UUID(),
            startedAt: currentDate.addingTimeInterval(-1_200),
            endsAt: currentDate.addingTimeInterval(-60),
            activityName: "expired-activity"
        )
        let active = GateGrant(
            id: UUID(),
            tokenData: activeToken,
            ruleId: UUID(),
            startedAt: currentDate.addingTimeInterval(-60),
            endsAt: currentDate.addingTimeInterval(600),
            activityName: "active-activity"
        )
        try ledgerStore.save(
            GateLedger(
                entries: [
                    GateLedgerEntry(
                        tokenData: expiredToken,
                        dayKey: GatePolicy.dayKey(for: currentDate, calendar: .current),
                        opensToday: 1,
                        lastGrantEndedAt: nil
                    ),
                    GateLedgerEntry(
                        tokenData: activeToken,
                        dayKey: GatePolicy.dayKey(for: currentDate, calendar: .current),
                        opensToday: 1,
                        lastGrantEndedAt: nil
                    )
                ],
                activeGrants: [expired, active],
                updatedAt: currentDate.addingTimeInterval(-60)
            )
        )

        let expiredGrants = try makeController().reconcile(now: currentDate)

        XCTAssertEqual(expiredGrants, [expired])
        let ledger = try ledgerStore.ledger()
        XCTAssertEqual(ledger.activeGrants, [active])
        XCTAssertEqual(
            ledger.entries.first { $0.tokenData == expiredToken }?.lastGrantEndedAt,
            expired.endsAt
        )
        XCTAssertEqual(reappliedDates, [currentDate])
        XCTAssertTrue(
            monitoringCenter.stoppedActivities.contains([
                DeviceActivityName("expired-activity")
            ])
        )
    }

    func testGrantForAlreadyOpenTokenReusesActiveGrantWithoutDoubleCounting() throws {
        let tokenData = Data("already-open".utf8)
        let existing = GateGrant(
            id: UUID(),
            tokenData: tokenData,
            ruleId: UUID(),
            startedAt: currentDate.addingTimeInterval(-60),
            endsAt: currentDate.addingTimeInterval(540),
            activityName: "existing-activity"
        )
        try ledgerStore.save(
            GateLedger(
                entries: [
                    GateLedgerEntry(
                        tokenData: tokenData,
                        dayKey: GatePolicy.dayKey(for: currentDate, calendar: .current),
                        opensToday: 1,
                        lastGrantEndedAt: nil
                    )
                ],
                activeGrants: [existing],
                updatedAt: currentDate.addingTimeInterval(-60)
            )
        )

        let controller = makeController()
        switch try controller.validate(tokenData: tokenData) {
        case .success:
            XCTFail("Expected an already-open validation denial")
        case .failure(let denial):
            XCTAssertEqual(denial, .alreadyOpen(until: existing.endsAt))
        }

        let reusedGrant = try controller.grant(
            tokenData: tokenData,
            ruleId: UUID(),
            minutes: 10
        )

        XCTAssertEqual(reusedGrant, existing)
        let ledger = try ledgerStore.ledger()
        XCTAssertEqual(ledger.entries.first?.opensToday, 1)
        XCTAssertEqual(ledger.activeGrants, [existing])
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
    }

    private func makeController(grantID: UUID = UUID()) -> GateGrantController {
        GateGrantController(
            settingsStore: settingsStore,
            ledgerStore: ledgerStore,
            requestStore: requestStore,
            monitoringCenter: monitoringCenter,
            reapplyGate: { [weak self] date in
                self?.reappliedDates.append(date)
            },
            now: { [weak self] in
                self?.currentDate ?? .distantPast
            },
            calendar: .current,
            makeUUID: { grantID }
        )
    }
}

private final class RecordingGateGrantMonitoring: GateGrantMonitoring {
    enum MonitoringError: Error {
        case rejected
    }

    private(set) var startedActivities: [DeviceActivityName] = []
    private(set) var startedSchedules: [DeviceActivitySchedule] = []
    private(set) var stoppedActivities: [[DeviceActivityName]] = []
    var failsToStart = false
    var afterStart: (() -> Void)?

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if failsToStart {
            throw MonitoringError.rejected
        }
        startedActivities.append(activity)
        startedSchedules.append(schedule)
        afterStart?()
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stoppedActivities.append(activities)
        startedActivities.removeAll { activities.contains($0) }
    }
}

private enum GateGrantControllerTestError: Error {
    case reapplyFailed
}
