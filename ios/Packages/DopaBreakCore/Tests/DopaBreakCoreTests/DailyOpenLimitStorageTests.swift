import Foundation
import XCTest
@testable import DopaBreakCore

final class DailyOpenLimitStorageTests: XCTestCase {
    // MARK: - 開いた回の集計

    func testOpenedAttemptCountCountsOnlyOpensInsideTheRange() throws {
        let log = try SQLiteLogStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        try log.insert(attempt(id: 1, at: date(-10), opened: true))
        try log.insert(attempt(id: 2, at: date(0), opened: true))
        try log.insert(attempt(id: 3, at: date(50), opened: false))
        try log.insert(attempt(id: 4, at: date(99), opened: true))
        try log.insert(attempt(id: 5, at: date(100), opened: true))

        XCTAssertEqual(try log.openedAttemptCount(from: date(0), to: date(100)), 2)
    }

    /// 6:59に呼吸を始めて7:01に開いた回は、開くと決めた時刻の日に入れる。
    func testOpenedAttemptCountUsesTheTimeTheOpenWasChosen() throws {
        let log = try SQLiteLogStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        try log.insert(AttemptLog(
            id: uuid(1), ruleId: uuid(900), startedAt: date(-30), completedAt: date(30),
            decision: .opened, intent: .boredom, selectedDurationSeconds: 300, attemptCount24h: 1, opened: true
        ))
        XCTAssertEqual(try log.openedAttemptCount(from: date(0), to: date(100)), 1)
        XCTAssertEqual(try log.openedAttemptCount(from: date(-100), to: date(0)), 0)
    }

    // MARK: - 緊急で開いた回の記録

    func testLimitOverrideOpenIsRecordedWithoutTouchingTheFlowState() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)
        let engine = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(0) })

        try engine.recordLimitOverrideOpen(ruleId: uuid(900), durationSeconds: 600)

        XCTAssertEqual(try engine.currentStep(), .idle)
        let attempts = try log.fetchAttempts()
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts.first?.decision, .opened)
        XCTAssertEqual(attempts.first?.opened, true)
        XCTAssertEqual(attempts.first?.selectedDurationSeconds, 600)
        XCTAssertNil(attempts.first?.intent)
        XCTAssertEqual(try log.fetchReflections(), [])
        XCTAssertThrowsError(try engine.recordLimitOverrideOpen(ruleId: uuid(900), durationSeconds: 0))
    }

    // MARK: - 控えの保存

    func testStoreWritesReadsAndRemovesTheSnapshot() throws {
        let snapshots = JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        let store = DailyOpenLimitStore(snapshotStore: snapshots)
        XCTAssertNil(try store.read())

        let value = sampleSnapshot()
        var committed: DailyOpenLimitShieldSnapshot?
        try store.transaction({ $0 = value }, afterCommit: { committed = $0 })
        XCTAssertEqual(committed, value)
        XCTAssertEqual(try store.read(), value)

        try store.transaction { $0 = nil }
        XCTAssertNil(try store.read())
        XCTAssertFalse(snapshots.exists(.dailyOpenLimitShieldSnapshot))
    }

    /// 壊れた控えは掛け続ける根拠がない。読めないものは無いものとして扱い、消す。
    func testCorruptSnapshotIsTreatedAsAbsentAndRemoved() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshots = JSONSnapshotStore(containerProvider: container)
        let url = try snapshots.url(for: .dailyOpenLimitShieldSnapshot)
        try Data("broken".utf8).write(to: url)

        let store = DailyOpenLimitStore(snapshotStore: snapshots)
        var committed: DailyOpenLimitShieldSnapshot? = sampleSnapshot()
        try store.transaction({ _ in }, afterCommit: { committed = $0 })
        XCTAssertNil(committed)
        XCTAssertFalse(snapshots.exists(.dailyOpenLimitShieldSnapshot))
    }

    func testLocalDataResetRemovesTheSnapshot() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshots = JSONSnapshotStore(containerProvider: container)
        try DailyOpenLimitStore(snapshotStore: snapshots).transaction { $0 = self.sampleSnapshot() }
        let suiteName = "DailyOpenLimitStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults)
        settings.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: 5)

        let resetter = LocalDataResetter(
            goalStore: GoalStore(snapshotStore: snapshots),
            ruleStore: RuleStore(snapshotStore: snapshots),
            targetStore: InterventionTargetStore(snapshotStore: snapshots),
            logStore: nil,
            funnelEventStore: FunnelEventStore(snapshotStore: snapshots),
            settingsStore: settings,
            snapshotStore: snapshots,
            interventionEngine: nil,
            containerProvider: container
        )
        try resetter.deleteAllLocalData()

        XCTAssertFalse(snapshots.exists(.dailyOpenLimitShieldSnapshot))
        XCTAssertEqual(settings.dailyOpenLimitSettings, DailyOpenLimitSettings())
    }

    // MARK: - 設定の保存と権利

    func testSettingsRoundTripAndUnreadableValueMeansOff() throws {
        let suiteName = "DailyOpenLimitStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.dailyOpenLimitSettings, DailyOpenLimitSettings())
        let value = DailyOpenLimitSettings(
            limit: 8,
            pendingChange: .init(limit: nil, effectiveAt: date(86_400)),
            countingStartsAt: date(0),
            emergencyRequestedAt: date(10)
        )
        store.dailyOpenLimitSettings = value
        XCTAssertEqual(SettingsStore(userDefaults: defaults).dailyOpenLimitSettings, value)

        defaults.set(Data("broken".utf8), forKey: "dailyOpenLimit.v1")
        XCTAssertNil(store.dailyOpenLimitSettings.limit)
    }

    func testOnlyProCanUseTheDailyOpenLimit() {
        XCTAssertFalse(EntitlementGate(tier: .free, now: date(0)).dailyOpenLimitAllowed)
        XCTAssertTrue(EntitlementGate(tier: .pro, now: date(0)).dailyOpenLimitAllowed)
    }

    // MARK: - 補助

    private func sampleSnapshot() -> DailyOpenLimitShieldSnapshot {
        DailyOpenLimitShieldSnapshot(
            selectionDataList: [Data([1, 2])],
            openedCount: 12,
            blockStartsAt: date(600),
            blockEndsAt: date(40_000),
            updatedAt: date(0)
        )
    }

    private func attempt(id: Int, at time: Date, opened: Bool) -> AttemptLog {
        AttemptLog(
            id: uuid(id),
            ruleId: uuid(900),
            startedAt: time,
            completedAt: time,
            decision: opened ? .opened : .cancelled,
            intent: .boredom,
            selectedDurationSeconds: opened ? 300 : nil,
            attemptCount24h: 1,
            opened: opened
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyOpenLimitStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + offset))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
