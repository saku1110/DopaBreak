import DeviceActivity
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class DailyOpenLimitControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var containerURL: URL!
    private var settingsStore: SettingsStore!
    private var snapshotStore: JSONSnapshotStore!
    private var ruleStore: RuleStore!
    private var logStore: SQLiteLogStore!
    private var store: DailyOpenLimitStore!
    private var monitoring: RecordingOpenLimitMonitoring!
    private var writer: RecordingOpenLimitShieldWriter!
    private var current = Date()
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "DailyOpenLimitControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyOpenLimitControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.wakeTimeMinutes = 420
        let container = FixedContainer(url: containerURL)
        snapshotStore = JSONSnapshotStore(containerProvider: container)
        ruleStore = RuleStore(snapshotStore: snapshotStore)
        logStore = try SQLiteLogStore(containerProvider: container)
        store = DailyOpenLimitStore(snapshotStore: snapshotStore)
        monitoring = RecordingOpenLimitMonitoring()
        writer = RecordingOpenLimitShieldWriter()
        current = tokyo(2026, 10, 5, 15, 0)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        // 開いたままのデータベースを消すとSQLiteが警告を出すため、先に手放す。
        logStore = nil
        store = nil
        ruleStore = nil
        snapshotStore = nil
        try? FileManager.default.removeItem(at: containerURL)
        try super.tearDownWithError()
    }

    // MARK: - 使い切ったら止まり始める

    func testOffNeverEngages() throws {
        try makeBlockRule()
        try recordOpens(5)
        let controller = makeController()
        XCTAssertNil(controller.status().remaining)
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNil(try store.read())
        XCTAssertTrue(monitoring.started.isEmpty)
    }

    func testOpensBeforeTheLimitDoNotEngage() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 3)
        try recordOpens(2)
        let controller = makeController()
        XCTAssertEqual(controller.status().remaining, 1)
        XCTAssertTrue(controller.status().isLastOpen)
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNil(try store.read())
    }

    /// 最後の1回の決めた時間が終わったところから、次の起床時刻まで止める。
    func testLastOpenBlocksFromTheEndOfItsChosenTimeUntilWakeTime() throws {
        let rule = try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 2)
        try recordOpens(2)
        let controller = makeController()

        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)

        let snapshot = try XCTUnwrap(try store.read())
        XCTAssertEqual(snapshot.blockStartsAt, tokyo(2026, 10, 5, 15, 10))
        XCTAssertEqual(snapshot.blockEndsAt, tokyo(2026, 10, 6, 7, 0))
        XCTAssertEqual(snapshot.selectionDataList, [rule.activitySelectionData])
        XCTAssertEqual(snapshot.openedCount, 2)
        let started = try XCTUnwrap(monitoring.started.last)
        XCTAssertEqual(started.activity, DailyOpenLimitController.activityName)
        XCTAssertEqual(started.schedule.intervalStart.hour, 15)
        XCTAssertEqual(started.schedule.intervalStart.minute, 10)
        XCTAssertEqual(started.schedule.intervalEnd.day, 6)
        XCTAssertEqual(started.schedule.intervalEnd.hour, 7)
        XCTAssertFalse(started.schedule.repeats)
        XCTAssertNil(controller.activeSnapshot(), "まだ決めた時間の内なので掛けない")

        current = tokyo(2026, 10, 5, 15, 10)
        XCTAssertNotNil(controller.activeSnapshot())
    }

    /// 起床まで15分を切る窓は監視を張れない。掛けると解除の担い手がいなくなる。
    func testWindowsShorterThanFifteenMinutesAreNotScheduled() throws {
        try makeBlockRule()
        current = tokyo(2026, 10, 6, 6, 40)
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()

        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)

        XCTAssertNil(try store.read())
        XCTAssertTrue(monitoring.started.isEmpty)
        XCTAssertTrue(controller.status().isExhausted, "入口の上限画面では止める")
    }

    func testNoBlockAppsMeansOnlyTheEntryScreenStops() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNil(try store.read())
        XCTAssertTrue(controller.status().isExhausted)
    }

    func testMonitoringFailureLeavesNoSnapshotBehind() throws {
        try makeBlockRule()
        monitoring.failsAlways = true
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNil(try store.read(), "解除を出す監視が無いままシールドの控えを残さない")
    }

    func testUnconfirmedEntitlementDoesNotEngage() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: false)
        XCTAssertNil(try store.read())
    }

    // MARK: - 同期

    func testFreeDowngradeClearsTheBlockButKeepsTheSetting() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNotNil(try store.read())
        let stopsBefore = monitoring.stopCount

        controller.sync(isPro: false, hasConfirmedEntitlement: true)

        XCTAssertNil(try store.read())
        XCTAssertGreaterThan(monitoring.stopCount, stopsBefore)
        XCTAssertEqual(settingsStore.dailyOpenLimitSettings.limit, 1)
    }

    /// 使い切ったのに控えが無いとき（記録の直後に終了した等）は、最後の1回で決めた時間を切らずに張り直す。
    func testSyncRepairsAMissingBlockAfterTheRememberedOpenTime() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1, openUntil: tokyo(2026, 10, 5, 15, 20))
        try recordOpens(1)
        let controller = makeController()

        controller.sync(isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(try store.read()?.blockStartsAt, tokyo(2026, 10, 5, 15, 20))
    }

    /// 監視を張れずに控えが消えたあとも、張り直しは最後の1回で決めた時間の終わりから。
    func testRepairAfterARegistrationFailureUsesTheLastOpensChosenTime() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        monitoring.failuresRemaining = 1
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNil(try store.read())

        controller.sync(isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(try store.read()?.blockStartsAt, tokyo(2026, 10, 5, 15, 10))
    }

    func testExpiredBlockIsRemovedEvenBeforeEntitlementIsConfirmed() throws {
        try store.transaction {
            $0 = DailyOpenLimitShieldSnapshot(
                selectionDataList: [Data([1])],
                openedCount: 3,
                blockStartsAt: tokyo(2026, 10, 4, 22, 0),
                blockEndsAt: tokyo(2026, 10, 5, 7, 0),
                updatedAt: tokyo(2026, 10, 4, 22, 0)
            )
        }
        let controller = makeController()
        let writesBefore = writer.writeCount

        controller.sync(isPro: true, hasConfirmedEntitlement: false)

        XCTAssertNil(try store.read())
        XCTAssertGreaterThan(writer.writeCount, writesBefore)
    }

    /// 控えはあるのに解除の監視が消えていたら、次の同期で張り直す。張らないまま掛けると起床後も外れない。
    func testSyncReRegistersAMissingMonitor() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        let startsBefore = monitoring.started.count
        monitoring.forgetAll()

        controller.sync(isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(monitoring.started.count, startsBefore + 1)
        XCTAssertTrue(monitoring.monitoredActivityNames.contains(DailyOpenLimitController.activityName))
        XCTAssertNotNil(controller.activeSnapshot())
    }

    /// 止まっているあいだに起床時刻を変えたら、止まり終わりも今の起床時刻へ合わせる。
    func testChangingWakeTimeMovesTheEndOfTheBlock() throws {
        try makeBlockRule()
        current = tokyo(2026, 10, 5, 23, 0)
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(try store.read()?.blockEndsAt, tokyo(2026, 10, 6, 7, 0))

        settingsStore.wakeTimeMinutes = 360
        controller.sync(isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(try store.read()?.blockEndsAt, tokyo(2026, 10, 6, 6, 0))
        XCTAssertEqual(monitoring.started.last?.schedule.intervalEnd.hour, 6)
    }

    /// 足したアプリはすぐ止める。外したアプリは翌朝まで止めたまま（緩める変更は翌朝から）。
    func testAddedBlockAppsAreBlockedNowAndRemovedOnesStayBlockedUntilMorning() throws {
        let first = try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.sync(isPro: true, hasConfirmedEntitlement: true)

        let second = try ruleStore.saveFamilyActivitySelection(Data([0x03, 0x04]), name: "追加", mode: .deepFocus)
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(try store.read()?.selectionDataList, [first.activitySelectionData, second.activitySelectionData])

        try ruleStore.deleteRule(id: first.id)
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(try store.read()?.selectionDataList, [first.activitySelectionData, second.activitySelectionData])
    }

    /// 最後の1回の決めた時間のあいだは、まだ開ける。表示はその終わりを使う。
    func testOpenUntilCoversTheLastOpensChosenTime() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(controller.openUntil(), tokyo(2026, 10, 5, 15, 10))
        current = tokyo(2026, 10, 5, 15, 10)
        XCTAssertNil(controller.openUntil())
    }

    /// 起床時刻を変えて控えだけ書き換わり、監視は古い終わりのまま（書き換えの直後に終了した）でも、
    /// 次の同期で予定の時刻まで照合して張り直す。名前の有無だけを見ると気づけない。
    func testSyncReRegistersWhenTheRegisteredScheduleIsStale() throws {
        try makeBlockRule()
        current = tokyo(2026, 10, 5, 23, 0)
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(monitoring.started.last?.schedule.intervalEnd.hour, 7)

        settingsStore.wakeTimeMinutes = 480
        var moved = try XCTUnwrap(try store.read())
        moved.blockEndsAt = tokyo(2026, 10, 6, 8, 0)
        try store.transaction { $0 = moved }

        controller.sync(isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(monitoring.started.last?.schedule.intervalEnd.hour, 8)
    }

    /// 止まっている最中は「開けます」と出さない。
    func testOpenUntilIsNilWhileBlocked() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)
        current = tokyo(2026, 10, 5, 15, 30)

        XCTAssertNotNil(controller.activeSnapshot())
        XCTAssertNil(controller.openUntil())
    }

    /// 止める対象が無いときも、最後の1回の決めた時間のあいだは「開けます」と出せる。
    func testOpenUntilWithoutBlockAppsUsesTheLastOpensChosenTime() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.didRecordOpen(durationSeconds: 600, isPro: true, hasConfirmedEntitlement: true)

        XCTAssertEqual(controller.openUntil(), tokyo(2026, 10, 5, 15, 10))
        current = tokyo(2026, 10, 5, 15, 11)
        XCTAssertNil(controller.openUntil())
    }

    // MARK: - 設定の変更

    /// 減らして使い切ったらその場で止める。増やす変更は翌朝まで効かない。
    func testLoweringBlocksNowAndRaisingWaitsUntilTomorrow() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 5)
        try recordOpens(3)
        let controller = makeController()

        controller.setLimit(2, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertTrue(controller.status().isExhausted)
        XCTAssertEqual(try store.read()?.blockStartsAt, current)
        XCTAssertNotNil(controller.activeSnapshot())

        controller.setLimit(10, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(controller.status().limit, 2)
        XCTAssertEqual(controller.status().pendingChange?.limit, 10)
        XCTAssertNotNil(controller.activeSnapshot(), "増やしても今日は止まったまま")

        current = tokyo(2026, 10, 6, 7, 0)
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(controller.status().limit, 10)
        XCTAssertNil(try store.read())
    }

    /// オンにした日は、オンにした時刻より前の回を数えない。
    func testTurningOnCountsFromThatMoment() throws {
        try recordOpens(4)
        let controller = makeController()
        controller.setLimit(3, isPro: true, hasConfirmedEntitlement: true)
        XCTAssertEqual(controller.status().remaining, 3)
    }

    // MARK: - 緊急で開く

    func testEmergencyOpenNeedsTheThirtySecondWaitAndBlocksAgainAfterward() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.setLimit(1, isPro: true, hasConfirmedEntitlement: true)
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNotNil(controller.activeSnapshot())

        XCTAssertFalse(controller.openForEmergency(durationSeconds: 600), "待ちを始める前は開けない")
        controller.requestEmergency()
        current = current.addingTimeInterval(29)
        XCTAssertFalse(controller.openForEmergency(durationSeconds: 600))
        controller.requestEmergency()
        current = current.addingTimeInterval(1)
        XCTAssertEqual(controller.emergencyState(), .ready, "押し直しても待ちは延びない")

        XCTAssertTrue(controller.openForEmergency(durationSeconds: 600))

        XCTAssertNil(controller.activeSnapshot())
        XCTAssertEqual(try store.read()?.blockStartsAt, current.addingTimeInterval(600))
        XCTAssertEqual(monitoring.started.last?.schedule.intervalStart.minute,
                       calendar.component(.minute, from: current.addingTimeInterval(600)))
        XCTAssertEqual(controller.emergencyState(), .notRequested, "一度使った待ちは使い回せない")
        current = current.addingTimeInterval(600)
        XCTAssertNotNil(controller.activeSnapshot())
    }

    /// 止め直しを登録できないときは外さない。外してから失敗すると、選んだ時間が過ぎても止まらない。
    func testEmergencyKeepsTheBlockWhenTheNewWindowCannotBeRegistered() throws {
        try makeBlockRule()
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        let before = try XCTUnwrap(try store.read())
        controller.requestEmergency()
        current = current.addingTimeInterval(30)
        monitoring.failuresRemaining = 1

        XCTAssertFalse(controller.openForEmergency(durationSeconds: 600))

        XCTAssertEqual(try store.read()?.blockStartsAt, before.blockStartsAt)
        XCTAssertNotNil(controller.activeSnapshot())
    }

    func testEmergencyNearWakeTimeEndsTheBlockForTheNight() throws {
        try makeBlockRule()
        current = tokyo(2026, 10, 6, 5, 0)
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try recordOpens(1)
        let controller = makeController()
        controller.sync(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertNotNil(controller.activeSnapshot())
        current = tokyo(2026, 10, 6, 6, 50)
        controller.requestEmergency()
        current = current.addingTimeInterval(30)

        XCTAssertTrue(controller.openForEmergency(durationSeconds: 600))

        XCTAssertNil(try store.read())
    }

    // MARK: - 目安

    func testAverageDailyOpensUsesFullDaysOnly() throws {
        settingsStore.firstLaunchDate = tokyo(2026, 9, 1, 12, 0)
        for day in 28...30 {
            for _ in 0..<7 {
                try insertOpen(at: tokyo(2026, 9, day, 12, 0))
            }
        }
        for day in 1...4 {
            for _ in 0..<7 {
                try insertOpen(at: tokyo(2026, 10, day, 12, 0))
            }
        }
        try recordOpens(20)
        XCTAssertEqual(makeController().averageDailyOpens(), 7, "今日の途中の回は平均に入れない")
    }

    // MARK: - 補助

    private func makeController() -> DailyOpenLimitController {
        DailyOpenLimitController(
            settingsStore: settingsStore,
            ruleStore: ruleStore,
            logStore: logStore,
            store: store,
            monitoring: monitoring,
            shieldWriter: writer,
            now: { [weak self] in self?.current ?? Date(timeIntervalSince1970: 0) },
            calendar: calendar
        )
    }

    @discardableResult
    private func makeBlockRule() throws -> TargetRule {
        try ruleStore.saveFamilyActivitySelection(Data([0x01, 0x02]), name: "テスト対象", mode: .deepFocus)
    }

    /// いまの時刻の少し前に、開いた回を記録する。
    private func recordOpens(_ count: Int) throws {
        for index in 0..<count {
            try insertOpen(at: current.addingTimeInterval(TimeInterval(-60 * (index + 1))))
        }
    }

    private func insertOpen(at time: Date) throws {
        try logStore.insert(AttemptLog(
            id: UUID(), ruleId: UUID(), startedAt: time, completedAt: time,
            decision: .opened, intent: .boredom, selectedDurationSeconds: 300, attemptCount24h: 1, opened: true
        ))
    }

    private func tokyo(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

// MARK: - Test doubles

private final class RecordingOpenLimitMonitoring: DailyOpenLimitMonitoring {
    struct Start {
        let activity: DeviceActivityName
        let schedule: DeviceActivitySchedule
    }

    enum MonitoringError: Error { case rejected }

    private(set) var started: [Start] = []
    private(set) var stopCount = 0
    private var registered: [DeviceActivityName: DeviceActivitySchedule] = [:]
    var failsAlways = false
    var failuresRemaining = 0

    var monitoredActivityNames: [DeviceActivityName] { Array(registered.keys) }

    func schedule(for activity: DeviceActivityName) -> DeviceActivitySchedule? {
        registered[activity]
    }

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if failsAlways { throw MonitoringError.rejected }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw MonitoringError.rejected
        }
        started.append(Start(activity: activity, schedule: schedule))
        registered[activity] = schedule
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stopCount += 1
        for activity in activities {
            registered.removeValue(forKey: activity)
        }
    }

    /// 端末側で監視が消えた状態（登録の途中で終了した等）を作る。
    func forgetAll() {
        registered.removeAll()
    }
}

private final class RecordingOpenLimitShieldWriter: ShieldSettingsWriting {
    private(set) var writeCount = 0

    func setShield(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>) {
        writeCount += 1
    }
}
