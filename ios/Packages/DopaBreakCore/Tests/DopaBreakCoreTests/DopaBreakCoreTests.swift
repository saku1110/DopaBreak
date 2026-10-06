import Foundation
import SQLite3
import XCTest
@testable import DopaBreakCore

final class DopaBreakCoreTests: XCTestCase {
    func testAppGroupIdentifier() {
        XCTAssertEqual(AppGroup.identifier, "group.com.dopabreak.shared")
    }

    func testGoalJSONRoundTripWithNilOptionals() throws {
        try assertJSONRoundTrip(
            Goal(
                id: uuid(1),
                title: "Write every morning",
                lockScreenTitle: nil,
                category: .creative,
                displayImagePath: nil,
                createdAt: date(1),
                updatedAt: date(2)
            )
        )
    }

    func testGoalJSONRoundTripWithPopulatedOptionals() throws {
        try assertJSONRoundTrip(
            Goal(
                id: uuid(2),
                title: "Ship the app",
                lockScreenTitle: "Build first",
                category: .work,
                displayImagePath: "images/hero.png",
                createdAt: date(3),
                updatedAt: date(4)
            )
        )
    }

    func testSelfCheckSnapshotJSONRoundTrip() throws {
        try assertJSONRoundTrip(
            SelfCheckSnapshot(
                id: uuid(3),
                usageBucket: "2-4",
                aimlessScrollBucket: "1-2",
                regretBucket: "often",
                estimatedDailyMinutes: 92,
                estimatedYearlyDays: 23,
                createdAt: date(5)
            )
        )
    }

    func testTargetRuleJSONRoundTripWithNilOptionals() throws {
        try assertJSONRoundTrip(
            TargetRule(
                id: uuid(4),
                name: "Social",
                activitySelectionData: Data([0x01, 0x02, 0x03]),
                mode: .standard,
                schedule: nil,
                delaySeconds: 20,
                maxOpensPerDay: nil,
                defaultDurationMinutes: 5,
                isEnabled: true,
                createdAt: date(6),
                updatedAt: date(7)
            )
        )
    }

    func testTargetRuleJSONRoundTripWithPopulatedOptionals() throws {
        try assertJSONRoundTrip(
            TargetRule(
                id: uuid(5),
                name: "Night lock",
                activitySelectionData: Data([0x10, 0x20]),
                mode: .nightOnly,
                schedule: scheduleRule(),
                delaySeconds: 60,
                maxOpensPerDay: 3,
                defaultDurationMinutes: 10,
                isEnabled: false,
                createdAt: date(8),
                updatedAt: date(9)
            )
        )
    }

    func testAttemptLogJSONRoundTripWithNilOptionals() throws {
        try assertJSONRoundTrip(
            AttemptLog(
                id: uuid(6),
                ruleId: uuid(7),
                startedAt: date(10),
                completedAt: nil,
                decision: .cancelled,
                intent: nil,
                selectedDurationSeconds: nil,
                attemptCount24h: 2,
                opened: false
            )
        )
    }

    func testAttemptLogJSONRoundTripWithPopulatedOptionals() throws {
        try assertJSONRoundTrip(
            AttemptLog(
                id: uuid(8),
                ruleId: uuid(9),
                startedAt: date(11),
                completedAt: date(12),
                decision: .opened,
                intent: .research,
                selectedDurationSeconds: 600,
                attemptCount24h: 4,
                opened: true
            )
        )
    }

    func testReflectionLogJSONRoundTripWithNilOptionals() throws {
        try assertJSONRoundTrip(
            ReflectionLog(
                id: uuid(10),
                attemptLogId: nil,
                ruleId: uuid(11),
                promptedAt: date(13),
                answeredAt: nil,
                trigger: .timedSessionEnded,
                satisfaction: nil,
                happinessDelta: nil,
                skipped: false,
                createdAt: date(14)
            )
        )
    }

    func testReflectionLogJSONRoundTripWithPopulatedOptionals() throws {
        try assertJSONRoundTrip(
            ReflectionLog(
                id: uuid(12),
                attemptLogId: uuid(13),
                ruleId: uuid(14),
                promptedAt: date(15),
                answeredAt: date(16),
                trigger: .notification,
                satisfaction: .lostTime,
                happinessDelta: .decreased,
                skipped: true,
                createdAt: date(17)
            )
        )
    }

    func testWidgetSnapshotJSONRoundTrip() throws {
        try assertJSONRoundTrip(
            WidgetSnapshot(
                primaryGoalTitle: "Study Japanese daily",
                displayTitle: "Daily Study",
                todayCancelledCount: 7,
                todayAttemptCount: 9,
                theme: .monochrome,
                updatedAt: date(18)
            )
        )
    }

    func testWidgetSnapshotDecodesLegacyThemeThroughMigration() throws {
        let json = """
        {
          "primaryGoalTitle": "Read",
          "displayTitle": "Read",
          "todayCancelledCount": 4,
          "todayAttemptCount": 6,
          "theme": "sumi",
          "updatedAt": "2026-08-25T00:00:00Z",
          "goalTitles": ["Read"],
          "displayTitles": ["Read"]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.theme, .gaming)
    }

    func testLockSurfaceStateJSONRoundTripWithNilOptionals() throws {
        try assertJSONRoundTrip(
            LockSurfaceState(
                weeklyReportNotificationTime: time(hour: 7, minute: 0),
                weeklyReportEnabled: false,
                liveActivityEnabled: true,
                liveActivityStartedAt: nil,
                theme: .e1
            )
        )
    }

    func testLockSurfaceStateJSONRoundTripWithPopulatedOptionals() throws {
        try assertJSONRoundTrip(
            LockSurfaceState(
                weeklyReportNotificationTime: time(hour: 8, minute: 30),
                weeklyReportEnabled: true,
                liveActivityEnabled: true,
                liveActivityStartedAt: date(19),
                theme: .kawaiiPink
            )
        )
    }

    func testInterventionStateJSONRoundTripWithNilOptionals() throws {
        try assertJSONRoundTrip(
            InterventionState(
                currentStep: .idle,
                ruleId: nil,
                startedAt: nil,
                updatedAt: date(20),
                allowedUntil: nil
            )
        )
    }

    func testInterventionStateJSONRoundTripWithPopulatedOptionals() throws {
        try assertJSONRoundTrip(
            InterventionState(
                currentStep: .temporarilyAllowed,
                ruleId: uuid(15),
                startedAt: date(21),
                updatedAt: date(22),
                allowedUntil: date(23)
            )
        )
    }

    func testInterventionModeRawValuesMatchDesign() {
        XCTAssertEqual(InterventionMode.allCases.map(\.rawValue), ["deepFocus", "standard", "nightOnly"])
    }

    func testSnapshotStoreWritesAndReads() throws {
        let store = try makeSnapshotStore()
        let goals = [sampleGoal(id: 16, updatedAt: date(24))]

        try store.write(goals, to: .goals)
        let readGoals = try store.read([Goal].self, from: .goals)

        XCTAssertEqual(readGoals, goals)
    }

    func testSnapshotStoreOverwritesExistingFile() throws {
        let store = try makeSnapshotStore()
        let first = [sampleGoal(id: 17, title: "First", updatedAt: date(25))]
        let second = [sampleGoal(id: 18, title: "Second", updatedAt: date(26))]

        try store.write(first, to: .goals)
        try store.write(second, to: .goals)

        XCTAssertEqual(try store.read([Goal].self, from: .goals), second)
    }

    func testSnapshotStoreAbsentFileReturnsNil() throws {
        let store = try makeSnapshotStore()
        let rules = try store.read([TargetRule].self, from: .rules)

        XCTAssertNil(rules)
    }

    func testSnapshotStoreCorruptedFileThrowsTypedError() throws {
        let store = try makeSnapshotStore()
        let url = try store.url(for: .widgetSnapshot)

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not valid json".utf8).write(to: url)

        XCTAssertThrowsError(try store.read(WidgetSnapshot.self, from: .widgetSnapshot)) { error in
            guard case let CoreError.corruptedSnapshot(file, _) = error else {
                return XCTFail("Expected corruptedSnapshot, got \(error)")
            }
            XCTAssertEqual(file, SnapshotFile.widgetSnapshot.rawValue)
        }
    }

    func testSQLiteStoreInsertsAndFetchesAttemptsAndReflections() throws {
        let store = try makeLogStore()
        let attempt = sampleAttempt(id: 19, startedAt: date(27), completedAt: date(28))
        let reflection = sampleReflection(
            id: 20,
            attemptLogId: attempt.id,
            promptedAt: date(29),
            answeredAt: date(30),
            satisfaction: .satisfied,
            happinessDelta: .increased
        )

        try store.insert(attempt)
        try store.insert(reflection)

        XCTAssertEqual(try store.fetchAttempts(), [attempt])
        XCTAssertEqual(try store.fetchReflections(), [reflection])
    }

    func testSQLiteStoreUpdatesUnansweredReflectionAnswers() throws {
        let store = try makeLogStore()
        let unanswered = sampleReflection(
            id: 21,
            promptedAt: date(31),
            answeredAt: nil,
            satisfaction: nil,
            happinessDelta: nil
        )

        try store.insert(unanswered)
        XCTAssertEqual(try store.fetchUnansweredReflections(limit: 10), [unanswered])

        try store.updateAnswers(
            reflectionID: unanswered.id,
            satisfaction: .nothingGained,
            happinessDelta: .decreased,
            answeredAt: date(32)
        )

        var expected = unanswered
        expected.answeredAt = date(32)
        expected.satisfaction = .nothingGained
        expected.happinessDelta = .decreased
        expected.skipped = false
        XCTAssertEqual(try store.fetchUnansweredReflections(limit: 10), [])
        XCTAssertEqual(try store.fetchReflections(), [expected])
    }

    func testSQLiteStoreDateRangeFiltersAttemptsAndReflections() throws {
        let store = try makeLogStore()
        let start = date(40)
        let middle = date(50)
        let end = date(60)
        let attempts = [
            sampleAttempt(id: 22, startedAt: date(39)),
            sampleAttempt(id: 23, startedAt: start),
            sampleAttempt(id: 24, startedAt: middle),
            sampleAttempt(id: 25, startedAt: end)
        ]
        let reflections = [
            sampleReflection(id: 26, promptedAt: date(39)),
            sampleReflection(id: 27, promptedAt: start),
            sampleReflection(id: 28, promptedAt: middle),
            sampleReflection(id: 29, promptedAt: end)
        ]

        try attempts.forEach(store.insert)
        try reflections.forEach(store.insert)

        XCTAssertEqual(try store.fetchAttempts(from: start, to: end), Array(attempts[1...2]))
        XCTAssertEqual(try store.fetchReflections(from: start, to: end), Array(reflections[1...2]))
    }

    func testSQLiteStoreAttemptCountOnDayUsesCalendarBoundary() throws {
        let store = try makeLogStore()
        let calendar = utcCalendar()
        let targetDay = calendarDate(year: 2026, month: 7, day: 2, hour: 12)
        let attempts = [
            sampleAttempt(id: 30, startedAt: calendarDate(year: 2026, month: 7, day: 1, hour: 23, minute: 59, second: 59)),
            sampleAttempt(id: 31, startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 0)),
            sampleAttempt(id: 32, startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 23, minute: 59, second: 59)),
            sampleAttempt(id: 33, startedAt: calendarDate(year: 2026, month: 7, day: 3, hour: 0))
        ]

        try attempts.forEach(store.insert)

        XCTAssertEqual(try store.attemptCount(onDay: targetDay, calendar: calendar), 2)
    }

    func testSQLiteStoreDeleteAllLogsRemovesAttemptsAndReflections() throws {
        let store = try makeLogStore()

        try store.insertCancelledAttempt(
            sampleAttempt(id: 34, startedAt: date(61)),
            reclaimedSeconds: 300
        )
        try store.insert(sampleReflection(id: 35, promptedAt: date(62)))
        try store.deleteAllLogs()

        XCTAssertEqual(try store.fetchAttempts(), [])
        XCTAssertEqual(try store.fetchReflections(), [])
        XCTAssertEqual(try store.reclaimedLedgerEntryCount(), 0)
    }

    func testSQLiteStoreReopensWithIdempotentMigration() throws {
        let containerURL = try makeTemporaryDirectory()
        let provider = FixedContainer(url: containerURL)
        let attempt = sampleAttempt(id: 36, startedAt: date(63))

        var firstStore: SQLiteLogStore? = try SQLiteLogStore(containerProvider: provider)
        try firstStore?.insert(attempt)
        firstStore = nil

        let secondStore = try SQLiteLogStore(containerProvider: provider)
        XCTAssertEqual(try secondStore.fetchAttempts(), [attempt])

        let thirdStore = try SQLiteLogStore(containerProvider: provider)
        XCTAssertEqual(try thirdStore.fetchAttempts(), [attempt])
    }

    func testReclaimedLedgerBackfillRunsOnceAcrossRepeatedMigration() throws {
        let containerURL = try makeTemporaryDirectory()
        let databaseURL = containerURL.appendingPathComponent("attempt_logs.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        let now = Date().timeIntervalSince1970
        let cancelledID = uuid(3_600).uuidString
        let ruleID = uuid(3_601).uuidString
        let setupSQL = """
        CREATE TABLE attempt_logs (
            id TEXT PRIMARY KEY NOT NULL,
            rule_id TEXT NOT NULL,
            started_at REAL NOT NULL,
            completed_at REAL,
            decision TEXT NOT NULL,
            intent TEXT,
            selected_duration_seconds INTEGER,
            attempt_count24h INTEGER NOT NULL,
            opened INTEGER NOT NULL
        );
        INSERT INTO attempt_logs VALUES
            ('\(uuid(3_602).uuidString)', '\(ruleID)', \(now - 3_600), \(now - 3_600), 'opened', NULL, 600, 1, 1),
            ('\(uuid(3_603).uuidString)', '\(ruleID)', \(now - 1_800), \(now - 1_800), 'opened', NULL, 1200, 1, 1),
            ('\(cancelledID)', '\(ruleID)', \(now - 600), \(now - 600), 'cancelled', NULL, NULL, 1, 0);
        PRAGMA user_version = 1;
        """
        XCTAssertEqual(sqlite3_exec(db, setupSQL, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        var firstStore: SQLiteLogStore? = try SQLiteLogStore(
            containerProvider: FixedContainer(url: containerURL)
        )
        XCTAssertEqual(try firstStore?.reclaimedLedgerEntryCount(), 1)
        XCTAssertEqual(try firstStore?.reclaimedSeconds(), 900)
        firstStore = nil

        let secondStore = try SQLiteLogStore(containerProvider: FixedContainer(url: containerURL))
        XCTAssertEqual(try secondStore.reclaimedLedgerEntryCount(), 1)
        XCTAssertEqual(try secondStore.reclaimedSeconds(), 900)
    }

    func testReclaimedLedgerBackfillRepairsMissingEntryOnReopen() throws {
        let containerURL = try makeTemporaryDirectory()
        let provider = FixedContainer(url: containerURL)
        var store: SQLiteLogStore? = try SQLiteLogStore(containerProvider: provider)
        XCTAssertEqual(try store?.reclaimedLedgerEntryCount(), 0)
        store = nil

        let databaseURL = containerURL.appendingPathComponent("attempt_logs.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        let now = Date().timeIntervalSince1970
        let insertSQL = """
        INSERT INTO attempt_logs
        (id, rule_id, started_at, completed_at, decision, intent,
         selected_duration_seconds, attempt_count24h, opened)
        VALUES
        ('\(uuid(3_610).uuidString)', '\(uuid(3_611).uuidString)', \(now), \(now),
         'cancelled', NULL, NULL, 1, 0);
        """
        XCTAssertEqual(sqlite3_exec(db, insertSQL, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        let reopenedStore = try SQLiteLogStore(containerProvider: provider)
        XCTAssertEqual(try reopenedStore.reclaimedLedgerEntryCount(), 1)
        XCTAssertEqual(try reopenedStore.reclaimedSeconds(), ReclaimedTimeEstimator.defaultSeconds)
    }

    func testSQLiteStoreConcurrentInsertsFromTwoQueues() throws {
        let containerURL = try makeTemporaryDirectory()
        let provider = FixedContainer(url: containerURL)
        let firstStore = try SQLiteLogStore(containerProvider: provider)
        let secondStore = try SQLiteLogStore(containerProvider: provider)
        let group = DispatchGroup()
        let errorLock = NSLock()
        var errors: [Error] = []

        for queueIndex in 0..<2 {
            group.enter()
            DispatchQueue(label: "DopaBreakCoreTests.concurrent.\(queueIndex)").async {
                defer { group.leave() }
                do {
                    let store = queueIndex == 0 ? firstStore : secondStore
                    for index in 0..<100 {
                        let id = 1000 + queueIndex * 100 + index
                        try store.insert(self.sampleAttempt(id: id, startedAt: self.date(id)))
                    }
                } catch {
                    errorLock.lock()
                    errors.append(error)
                    errorLock.unlock()
                }
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertTrue(errors.isEmpty, "\(errors)")
        XCTAssertEqual(try firstStore.fetchAttempts().count, 200)
    }

    func testSettingsStoreReadsAndWritesTypedValues() {
        let suiteName = "DopaBreakCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertFalse(store.onboardingCompleted)
        XCTAssertNil(store.lastAppVersion)
        XCTAssertEqual(store.breathDurationSeconds, 3)
        XCTAssertNil(store.pendingStartInterventionCatalogID)
        XCTAssertFalse(store.pendingStartInterventionAutoResolve)
        XCTAssertNil(store.pendingStartInterventionRequestedAt)
        XCTAssertNil(store.lastSelfOpenedCatalogID)
        XCTAssertNil(store.lastSelfOpenedAt)
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, [])
        XCTAssertNil(store.firstLaunchDate)
        XCTAssertNil(store.wakeTimeMinutes)
        XCTAssertNil(store.bedTimeMinutes)

        store.onboardingCompleted = true
        store.lastAppVersion = "1.2.3"
        store.breathDurationSeconds = 5
        store.pendingStartInterventionCatalogID = "instagram"
        store.pendingStartInterventionAutoResolve = true
        let requestedAt = Date(timeIntervalSince1970: 1_750_000_001)
        let selfOpenedAt = Date(timeIntervalSince1970: 1_750_000_002)
        store.pendingStartInterventionRequestedAt = requestedAt
        store.lastSelfOpenedCatalogID = "instagram"
        store.lastSelfOpenedAt = selfOpenedAt
        store.verifiedAutomationCatalogIDs = ["instagram"]
        let firstLaunchDate = Date(timeIntervalSince1970: 1_750_000_000)
        store.firstLaunchDate = firstLaunchDate
        store.wakeTimeMinutes = 0
        store.bedTimeMinutes = 1_380

        XCTAssertTrue(store.onboardingCompleted)
        XCTAssertEqual(store.lastAppVersion, "1.2.3")
        XCTAssertEqual(store.breathDurationSeconds, 5)
        XCTAssertEqual(store.pendingStartInterventionCatalogID, "instagram")
        XCTAssertTrue(store.pendingStartInterventionAutoResolve)
        XCTAssertEqual(store.pendingStartInterventionRequestedAt, requestedAt)
        XCTAssertEqual(store.lastSelfOpenedCatalogID, "instagram")
        XCTAssertEqual(store.lastSelfOpenedAt, selfOpenedAt)
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, ["instagram"])
        XCTAssertEqual(store.firstLaunchDate, firstLaunchDate)
        XCTAssertEqual(store.wakeTimeMinutes, 0)
        XCTAssertEqual(store.bedTimeMinutes, 1_380)

        store.breathDurationSeconds = 4
        XCTAssertEqual(store.breathDurationSeconds, 3)

        store.lastAppVersion = nil
        store.pendingStartInterventionCatalogID = nil
        store.pendingStartInterventionAutoResolve = false
        store.pendingStartInterventionRequestedAt = nil
        store.lastSelfOpenedCatalogID = nil
        store.lastSelfOpenedAt = nil
        store.verifiedAutomationCatalogIDs = []
        store.firstLaunchDate = nil
        store.wakeTimeMinutes = nil
        store.bedTimeMinutes = nil
        XCTAssertNil(store.lastAppVersion)
        XCTAssertNil(store.pendingStartInterventionCatalogID)
        XCTAssertFalse(store.pendingStartInterventionAutoResolve)
        XCTAssertNil(store.pendingStartInterventionRequestedAt)
        XCTAssertNil(store.lastSelfOpenedCatalogID)
        XCTAssertNil(store.lastSelfOpenedAt)
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, [])
        XCTAssertNil(store.firstLaunchDate)
        XCTAssertNil(store.wakeTimeMinutes)
        XCTAssertNil(store.bedTimeMinutes)
    }

    func testManualAutomationChecklistDoesNotInheritExecutionHistory() {
        let suite = "ManualChecklistTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(userDefaults: defaults)
        store.markAutomationVerified(catalogID: "tiktok")
        XCTAssertEqual(store.confirmedAutomationCatalogIDs, [])
        store.setAutomationConfirmed(catalogID: "x", confirmed: true)
        store.setAutomationConfirmed(catalogID: "x", confirmed: true)
        let reopened = SettingsStore(userDefaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(reopened.confirmedAutomationCatalogIDs, ["x"])
        reopened.setAutomationConfirmed(catalogID: "x", confirmed: false)
        store.markAutomationVerified(catalogID: "x")
        XCTAssertEqual(store.confirmedAutomationCatalogIDs, [])
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, ["tiktok", "x"])
    }

    func testSettingsStoreMarksAutomationVerificationIdempotently() {
        let suiteName = "DopaBreakCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.verifiedAutomationCatalogIDs, [])
        XCTAssertFalse(store.isAutomationVerified(catalogID: "instagram"))

        store.markAutomationVerified(catalogID: "instagram")
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, ["instagram"])
        XCTAssertTrue(store.isAutomationVerified(catalogID: "instagram"))

        store.markAutomationVerified(catalogID: "instagram")
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, ["instagram"])

        store.markAutomationVerified(catalogID: "youtube")
        XCTAssertEqual(store.verifiedAutomationCatalogIDs, ["instagram", "youtube"])
        XCTAssertTrue(store.isAutomationVerified(catalogID: "youtube"))
        XCTAssertFalse(store.isAutomationVerified(catalogID: "safari"))
    }

    private func assertJSONRoundTrip<Value: Codable & Equatable>(
        _ value: Value,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(Value.self, from: data), value, file: file, line: line)
    }

    private func makeSnapshotStore() throws -> JSONSnapshotStore {
        JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
    }

    private func makeLogStore() throws -> SQLiteLogStore {
        try SQLiteLogStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DopaBreakCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func sampleGoal(id: Int, title: String = "Focus", updatedAt: Date) -> Goal {
        Goal(
            id: uuid(id),
            title: title,
            lockScreenTitle: "Focus now",
            category: .study,
            displayImagePath: "images/\(id).png",
            createdAt: date(0),
            updatedAt: updatedAt
        )
    }

    private func sampleAttempt(
        id: Int,
        startedAt: Date,
        completedAt: Date? = nil
    ) -> AttemptLog {
        AttemptLog(
            id: uuid(id),
            ruleId: uuid(900),
            startedAt: startedAt,
            completedAt: completedAt,
            decision: completedAt == nil ? .cancelled : .opened,
            intent: completedAt == nil ? nil : .workRequired,
            selectedDurationSeconds: completedAt == nil ? nil : 300,
            attemptCount24h: id,
            opened: completedAt != nil
        )
    }

    private func sampleReflection(
        id: Int,
        attemptLogId: UUID? = nil,
        promptedAt: Date,
        answeredAt: Date? = nil,
        satisfaction: PostUseSatisfaction? = nil,
        happinessDelta: HappinessDelta? = nil
    ) -> ReflectionLog {
        ReflectionLog(
            id: uuid(id),
            attemptLogId: attemptLogId,
            ruleId: uuid(901),
            promptedAt: promptedAt,
            answeredAt: answeredAt,
            trigger: .reshielded,
            satisfaction: satisfaction,
            happinessDelta: happinessDelta,
            skipped: false,
            createdAt: promptedAt
        )
    }

    private func scheduleRule() -> ScheduleRule {
        ScheduleRule(
            weekdays: [2, 3, 4, 5, 6],
            startTime: time(hour: 9, minute: 0),
            endTime: time(hour: 18, minute: 30)
        )
    }

    private func time(hour: Int, minute: Int) -> DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + offset))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func calendarDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar()
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }

    // MARK: - Review fixes (2026-07-02): SelfCheckSnapshot persistence + fractional-second dates

    func testSelfCheckSnapshotStoreRoundTrip() throws {
        let store = JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        let snapshot = SelfCheckSnapshot(
            id: uuid(701),
            usageBucket: "2-4",
            aimlessScrollBucket: "daily",
            regretBucket: "often",
            estimatedDailyMinutes: 150,
            estimatedYearlyDays: 38,
            createdAt: date(0)
        )

        try store.write(snapshot, to: .selfCheckSnapshot)
        let decoded = try XCTUnwrap(store.read(SelfCheckSnapshot.self, from: .selfCheckSnapshot))

        XCTAssertEqual(decoded, snapshot)
    }

    func testDateFractionalSecondsRoundTripThroughSnapshotStore() throws {
        let store = JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        let fractionalDate = Date(timeIntervalSince1970: 1_800_000_000.123)
        let snapshot = SelfCheckSnapshot(
            id: uuid(702),
            usageBucket: "4+",
            aimlessScrollBucket: "daily",
            regretBucket: "always",
            estimatedDailyMinutes: 240,
            estimatedYearlyDays: 60,
            createdAt: fractionalDate
        )

        try store.write(snapshot, to: .selfCheckSnapshot)
        let decoded = try XCTUnwrap(store.read(SelfCheckSnapshot.self, from: .selfCheckSnapshot))

        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            fractionalDate.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testDecodingPlainISO8601DateStillSucceeds() throws {
        let store = JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        let fixture = """
        {"aimlessScrollBucket":"daily","createdAt":"2027-01-15T08:00:00Z","estimatedDailyMinutes":90,"estimatedYearlyDays":22,"id":"00000000-0000-0000-0000-000000000703","regretBucket":"sometimes","usageBucket":"1-2"}
        """
        try Data(fixture.utf8).write(to: store.url(for: .selfCheckSnapshot))

        let decoded = try XCTUnwrap(store.read(SelfCheckSnapshot.self, from: .selfCheckSnapshot))

        XCTAssertEqual(decoded.createdAt, calendarDate(year: 2027, month: 1, day: 15, hour: 8))
        XCTAssertEqual(decoded.estimatedDailyMinutes, 90)
    }

}
