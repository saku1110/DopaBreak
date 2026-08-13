import Foundation
import XCTest
@testable import DopaBreakCore

final class LocalDataResetterTests: XCTestCase {
    private var containerURL: URL!
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalDataResetterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        defaultsSuiteName = "LocalDataResetterTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: containerURL)
        defaults = nil
        defaultsSuiteName = nil
        containerURL = nil
        try super.tearDownWithError()
    }

    func testDeleteAllLocalDataClearsEveryStoreAndAggregates() throws {
        let context = try makeContext()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = Goal(
            id: UUID(),
            title: "Focus",
            lockScreenTitle: "Focus",
            category: .study,
            displayImagePath: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try context.goalStore.save(goal)
        let rule = try context.ruleStore.saveFamilyActivitySelection(
            Data([0x01]),
            name: "Instagram",
            mode: .standard
        )
        try context.targetStore.setTargets(["instagram", "youtube"])
        try context.logStore.insert(
            AttemptLog(
                id: UUID(),
                ruleId: rule.id,
                startedAt: timestamp,
                completedAt: timestamp,
                decision: .opened,
                intent: .boredom,
                selectedDurationSeconds: 300,
                attemptCount24h: 1,
                opened: true
            )
        )
        try context.logStore.insert(
            ReflectionLog(
                id: UUID(),
                attemptLogId: nil,
                ruleId: rule.id,
                promptedAt: timestamp,
                answeredAt: timestamp,
                trigger: .timedSessionEnded,
                satisfaction: .lostTime,
                happinessDelta: .decreased,
                skipped: false,
                createdAt: timestamp
            )
        )
        try context.funnelEventStore.record(name: .paywallShown, at: timestamp)

        try context.resetter.deleteAllLocalData()

        XCTAssertEqual(try context.goalStore.goals(), [])
        XCTAssertEqual(try context.ruleStore.allRules(), [])
        XCTAssertEqual(try context.targetStore.selectedCatalogIDs(), [])
        XCTAssertEqual(try context.logStore.fetchAttempts(), [])
        XCTAssertEqual(try context.logStore.fetchReflections(), [])
        XCTAssertEqual(try context.funnelEventStore.allEvents(), [])

        let summary = try StatsService(logStore: context.logStore, now: { timestamp }).weeklySummary()
        XCTAssertEqual(summary.attempts, 0)
        XCTAssertEqual(summary.cancelled, 0)
        XCTAssertEqual(summary.answeredReflections, 0)
        XCTAssertEqual(summary.wastedTimeRealizationRate, 0)

        XCTAssertNoThrow(try context.resetter.deleteAllLocalData())
    }

    func testDeleteAllLocalDataResetsSettingsAndTransientSnapshots() throws {
        let context = try makeContext()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        context.settingsStore.onboardingCompleted = true
        context.settingsStore.lastAppVersion = "1.2.3"
        context.settingsStore.pendingInterventionMode = InterventionMode.deepFocus.rawValue
        context.settingsStore.selectedAppBrands = ["Instagram"]
        context.settingsStore.breathDurationSeconds = 8
        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingMidSessionCheckIn = PendingMidSessionCheckIn(
            catalogID: "youtube",
            writtenAt: timestamp
        )
        context.settingsStore.verifiedAutomationCatalogIDs = ["instagram"]
        context.settingsStore.firstLaunchDate = timestamp
        context.settingsStore.lastAppOpenedDateKey = "2027-01-15"
        context.settingsStore.wakeTimeMinutes = 480
        context.settingsStore.bedTimeMinutes = 1_320
        context.settingsStore.morningNotificationEnabled = false
        context.settingsStore.morningNotificationMinutes = 510
        context.settingsStore.weeklyReportNotificationEnabled = false
        context.settingsStore.retentionSupportNotificationsEnabled = false
        context.settingsStore.planNotificationsEnabled = false
        context.settingsStore.reviewPromptEventDates = [timestamp]
        context.settingsStore.liveActivityEnabled = false
        context.settingsStore.lockScreenCheckCompleted = true
        context.settingsStore.lockTheme = .kpop

        try context.snapshotStore.write(
            SelfCheckSnapshot(
                id: UUID(),
                usageBucket: "4+",
                aimlessScrollBucket: "daily",
                regretBucket: "often",
                estimatedDailyMinutes: 240,
                estimatedYearlyDays: 60,
                createdAt: timestamp
            ),
            to: .selfCheckSnapshot
        )
        try context.interventionEngine.beginIntervention(ruleId: UUID())

        try context.resetter.deleteAllLocalData()

        XCTAssertFalse(context.settingsStore.onboardingCompleted)
        XCTAssertNil(context.settingsStore.lastAppVersion)
        XCTAssertNil(context.settingsStore.pendingInterventionMode)
        XCTAssertNil(context.settingsStore.selectedAppBrands)
        XCTAssertEqual(context.settingsStore.breathDurationSeconds, 3)
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertNil(context.settingsStore.pendingMidSessionCheckIn)
        XCTAssertEqual(context.settingsStore.verifiedAutomationCatalogIDs, [])
        XCTAssertEqual(context.settingsStore.firstLaunchDate, timestamp)
        XCTAssertNil(context.settingsStore.lastAppOpenedDateKey)
        XCTAssertNil(context.settingsStore.wakeTimeMinutes)
        XCTAssertNil(context.settingsStore.bedTimeMinutes)
        XCTAssertTrue(context.settingsStore.morningNotificationEnabled)
        XCTAssertEqual(context.settingsStore.morningNotificationMinutes, 420)
        XCTAssertTrue(context.settingsStore.weeklyReportNotificationEnabled)
        XCTAssertTrue(context.settingsStore.retentionSupportNotificationsEnabled)
        XCTAssertTrue(context.settingsStore.planNotificationsEnabled)
        XCTAssertEqual(context.settingsStore.reviewPromptEventDates, [timestamp])
        XCTAssertTrue(context.settingsStore.liveActivityEnabled)
        XCTAssertFalse(context.settingsStore.lockScreenCheckCompleted)
        XCTAssertEqual(context.settingsStore.lockTheme, .e1)
        XCTAssertNil(
            try context.snapshotStore.read(SelfCheckSnapshot.self, from: .selfCheckSnapshot)
        )
        XCTAssertEqual(try context.interventionEngine.currentStep(), .idle)
    }

    func testDeleteAllLocalDataWithoutLogStoreClearsOtherStoresAndRemovesSQLiteFiles() throws {
        let provider = FixedContainer(url: containerURL)
        let snapshotStore = JSONSnapshotStore(containerProvider: provider)
        let goalStore = GoalStore(snapshotStore: snapshotStore)
        let ruleStore = RuleStore(snapshotStore: snapshotStore)
        let targetStore = InterventionTargetStore(snapshotStore: snapshotStore)
        let funnelEventStore = FunnelEventStore(snapshotStore: snapshotStore)
        let settingsStore = SettingsStore(userDefaults: defaults)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

        try goalStore.save(
            Goal(
                id: UUID(),
                title: "Focus",
                lockScreenTitle: nil,
                category: .study,
                displayImagePath: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        _ = try ruleStore.saveFamilyActivitySelection(
            Data([0x01]),
            name: "Instagram",
            mode: .standard
        )
        try targetStore.setTargets(["instagram"])
        try funnelEventStore.record(name: .paywallShown, at: timestamp)
        settingsStore.onboardingCompleted = true
        settingsStore.firstLaunchDate = timestamp
        try snapshotStore.write(
            SelfCheckSnapshot(
                id: UUID(),
                usageBucket: "4+",
                aimlessScrollBucket: "daily",
                regretBucket: "often",
                estimatedDailyMinutes: 240,
                estimatedYearlyDays: 60,
                createdAt: timestamp
            ),
            to: .selfCheckSnapshot
        )

        let sqliteFileNames = ["attempt_logs.sqlite", "reflection_logs.sqlite"]
        let sqliteSuffixes = ["", "-wal", "-shm", "-journal"]
        let sqliteURLs = sqliteFileNames.flatMap { fileName in
            sqliteSuffixes.map { suffix in
                containerURL.appendingPathComponent(fileName + suffix)
            }
        }
        for url in sqliteURLs {
            try Data("corrupt sqlite data".utf8).write(to: url)
        }

        let resetter = LocalDataResetter(
            goalStore: goalStore,
            ruleStore: ruleStore,
            targetStore: targetStore,
            logStore: nil,
            funnelEventStore: funnelEventStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            interventionEngine: nil,
            containerProvider: provider
        )

        try resetter.deleteAllLocalData()

        XCTAssertEqual(try goalStore.goals(), [])
        XCTAssertEqual(try ruleStore.allRules(), [])
        XCTAssertEqual(try targetStore.selectedCatalogIDs(), [])
        XCTAssertEqual(try funnelEventStore.allEvents(), [])
        XCTAssertFalse(settingsStore.onboardingCompleted)
        XCTAssertEqual(settingsStore.firstLaunchDate, timestamp)
        XCTAssertNil(
            try snapshotStore.read(SelfCheckSnapshot.self, from: .selfCheckSnapshot)
        )
        for url in sqliteURLs {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), url.lastPathComponent)
        }
    }

    private func makeContext() throws -> TestContext {
        let provider = FixedContainer(url: containerURL)
        let snapshotStore = JSONSnapshotStore(containerProvider: provider)
        let logStore = try SQLiteLogStore(containerProvider: provider)
        let goalStore = GoalStore(snapshotStore: snapshotStore)
        let ruleStore = RuleStore(snapshotStore: snapshotStore)
        let targetStore = InterventionTargetStore(snapshotStore: snapshotStore)
        let funnelEventStore = FunnelEventStore(snapshotStore: snapshotStore)
        let settingsStore = SettingsStore(userDefaults: defaults)
        let interventionEngine = InterventionEngine(snapshotStore: snapshotStore, logStore: logStore)
        let resetter = LocalDataResetter(
            goalStore: goalStore,
            ruleStore: ruleStore,
            targetStore: targetStore,
            logStore: logStore,
            funnelEventStore: funnelEventStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            interventionEngine: interventionEngine
        )
        return TestContext(
            snapshotStore: snapshotStore,
            goalStore: goalStore,
            ruleStore: ruleStore,
            targetStore: targetStore,
            logStore: logStore,
            funnelEventStore: funnelEventStore,
            settingsStore: settingsStore,
            interventionEngine: interventionEngine,
            resetter: resetter
        )
    }
}

private struct TestContext {
    let snapshotStore: JSONSnapshotStore
    let goalStore: GoalStore
    let ruleStore: RuleStore
    let targetStore: InterventionTargetStore
    let logStore: SQLiteLogStore
    let funnelEventStore: FunnelEventStore
    let settingsStore: SettingsStore
    let interventionEngine: InterventionEngine
    let resetter: LocalDataResetter
}
