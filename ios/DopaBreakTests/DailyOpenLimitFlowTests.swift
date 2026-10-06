import DeviceActivity
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

/// 一呼吸の入口での1日に開ける回数（残りの表示・最後の1回・上限画面・緊急で開く）。
@MainActor
final class DailyOpenLimitFlowTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var containerURL: URL!
    private var settingsStore: SettingsStore!
    private var monitoring: FlowOpenLimitMonitoring!
    private var writer: FlowOpenLimitShieldWriter!
    private var offset: TimeInterval = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "DailyOpenLimitFlowTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyOpenLimitFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.onboardingCompleted = true
        settingsStore.entitlementCachedIsPro = true
        // 区切り（起床時刻）を今から12時間離し、テストの途中で日が変わらないようにする。
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: Date())
        settingsStore.wakeTimeMinutes = ((components.hour ?? 0) * 60 + (components.minute ?? 0) + 720) % 1_440
        monitoring = FlowOpenLimitMonitoring()
        writer = FlowOpenLimitShieldWriter()
        offset = 0
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
        try super.tearDownWithError()
    }

    func testUsedUpLimitShowsTheLimitScreenWithoutStartingABreath() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try insertOpen()
        let model = makeModel()
        let flow = InterventionFlowModel(target: .catalog(try instagram()), model: model, settingsStore: settingsStore)

        flow.start()

        XCTAssertEqual(flow.stage, .limitReached)
        XCTAssertEqual(flow.dailyOpenLimitOpenedCount, 1)
        XCTAssertNotNil(flow.dailyOpenLimitDayEndsAt)
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .idle, "上限画面では一呼吸の記録を始めない")
    }

    func testBreathShowsTheRemainingCountAndTheLastOpenMustBeTimed() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 2)
        try insertOpen()
        let model = makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        let flow = InterventionFlowModel(target: .catalog(try instagram()), model: model, settingsStore: settingsStore)

        flow.start()
        defer { flow.stop() }
        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertEqual(flow.remainingOpensForDisplay, 1)

        flow.completeBreathingForTesting()
        flow.selectReason(.work)

        XCTAssertEqual(flow.stage, .durationSelection)
        XCTAssertTrue(flow.isLastOpenForDailyLimit)
        XCTAssertFalse(flow.canChooseUntimed, "最後の1回は決めた時間の終わりから止まるため、時間なしを出さない")
        XCTAssertTrue(flow.usesTimeLimit)
    }

    func testFreeUsersAreNotLimitedEvenWithASavedLimit() throws {
        settingsStore.entitlementCachedIsPro = false
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try insertOpen()
        let model = makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        let flow = InterventionFlowModel(target: .catalog(try instagram()), model: model, settingsStore: settingsStore)

        flow.start()
        defer { flow.stop() }

        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertNil(flow.remainingOpensForDisplay)
    }

    func testEmergencyOpenWaitsThirtySecondsThenOpensForTheChosenTime() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try insertOpen()
        let model = makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        var openedURLs: [URL] = []
        let flow = InterventionFlowModel(
            target: .catalog(try instagram()),
            model: model,
            settingsStore: settingsStore,
            openURL: { url, completion in
                openedURLs.append(url)
                completion(true)
            }
        )

        flow.start()
        XCTAssertEqual(flow.stage, .limitReached)
        flow.requestEmergencyOpen()
        XCTAssertEqual(flow.stage, .emergencyWaiting)
        flow.proceedAfterEmergencyWait()
        XCTAssertEqual(flow.stage, .emergencyWaiting, "30秒たつまでは時間を選べない")

        offset = 30
        flow.proceedAfterEmergencyWait()
        XCTAssertEqual(flow.stage, .durationSelection)
        XCTAssertTrue(flow.isEmergencyOpen)
        XCTAssertFalse(flow.isLastOpenForDailyLimit)

        flow.chooseDuration(.fiveMinutes)
        flow.confirmSelectedDuration()

        XCTAssertEqual(openedURLs.count, 1)
        XCTAssertNotNil(model.catalogAllowanceStore.activeAllowance(catalogID: "instagram", at: model.currentDate))
        XCTAssertNil(settingsStore.dailyOpenLimitSettings.emergencyRequestedAt, "一度使った待ちは使い回せない")
        XCTAssertEqual(model.dailyOpenLimitStatus.openedCount, 2, "緊急で開いた回も開いた回として残す")
    }

    /// 上限画面を開いたまま朝を迎えた（上限がもう効いていない）なら、古い画面で待たせず一呼吸からやり直す。
    func testEmergencyButtonRestartsTheFlowWhenTheLimitNoLongerApplies() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try insertOpen()
        let model = makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        let flow = InterventionFlowModel(target: .catalog(try instagram()), model: model, settingsStore: settingsStore)
        flow.start()
        defer { flow.stop() }
        XCTAssertEqual(flow.stage, .limitReached)

        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 5)
        model.dailyOpenLimitRevision += 1
        flow.requestEmergencyOpen()

        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertNil(settingsStore.dailyOpenLimitSettings.emergencyRequestedAt)
    }

    /// 緊急の時間を選んでいるあいだに朝を迎えたら、緊急ではなく一呼吸からやり直す（翌日の一呼吸を飛ばさない）。
    func testEmergencyConfirmRestartsWhenTheLimitNoLongerApplies() throws {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 1)
        try insertOpen()
        let model = makeModel()
        try model.setTargetCatalogIDs(["instagram"])
        var openedURLs: [URL] = []
        let flow = InterventionFlowModel(
            target: .catalog(try instagram()),
            model: model,
            settingsStore: settingsStore,
            openURL: { url, completion in
                openedURLs.append(url)
                completion(true)
            }
        )
        flow.start()
        defer { flow.stop() }
        flow.requestEmergencyOpen()
        offset = 30
        flow.proceedAfterEmergencyWait()
        XCTAssertEqual(flow.stage, .durationSelection)

        settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 5)
        model.dailyOpenLimitRevision += 1
        flow.confirmSelectedDuration()

        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertTrue(openedURLs.isEmpty)
    }

    // MARK: - 補助

    private func makeModel() -> AppModel {
        AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore,
            clampBackupStore: TargetClampBackupStore(userDefaults: defaults),
            catalogAllowanceStore: CatalogAllowanceStore(userDefaults: defaults),
            dailyOpenLimitMonitoringCenter: monitoring,
            dailyOpenLimitShieldWriter: writer,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false,
            now: { [weak self] in Date().addingTimeInterval(self?.offset ?? 0) }
        )
    }

    private func instagram() throws -> SNSAppCatalogItem {
        try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
    }

    private func insertOpen() throws {
        let log = try SQLiteLogStore(containerProvider: FixedContainer(url: containerURL))
        let time = Date().addingTimeInterval(-60)
        try log.insert(AttemptLog(
            id: UUID(), ruleId: UUID(), startedAt: time, completedAt: time,
            decision: .opened, intent: .boredom, selectedDurationSeconds: 300, attemptCount24h: 1, opened: true
        ))
    }
}

private final class FlowOpenLimitMonitoring: DailyOpenLimitMonitoring {
    func schedule(for activity: DeviceActivityName) -> DeviceActivitySchedule? { nil }

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {}

    func stopMonitoring(_ activities: [DeviceActivityName]) {}
}

private final class FlowOpenLimitShieldWriter: ShieldSettingsWriting {
    func setShield(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>) {}
}
