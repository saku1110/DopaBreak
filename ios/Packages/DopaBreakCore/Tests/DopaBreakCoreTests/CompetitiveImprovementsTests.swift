import XCTest
@testable import DopaBreakCore

final class CompetitiveImprovementsTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func schedule(_ start: Int, _ end: Int, days: [Int] = [2]) -> DeepFocusSchedule {
        .init(isEnabled: true, weekdays: days, startMinutes: start, endMinutes: end)
    }

    func testOverlappingScheduleKeepsShieldAfterFirstWindowEnds() {
        let schedules = [schedule(600, 720), schedule(660, 780)]
        let now = date("2026-09-07T12:10:00Z")
        let snapshot = DeepFocusShieldSnapshot(selectionDataList: [Data([1])], schedule: schedules[0], additionalSchedules: [schedules[1]], session: nil, updatedAt: now)
        XCTAssertTrue(DeepFocusWindowPolicy.isWindowActive(now: now, snapshot: snapshot, calendar: calendar))
        XCTAssertEqual(DeepFocusWindowPolicy.selectionDataListToShield(now: now, snapshot: snapshot, calendar: calendar), [Data([1])])
        XCTAssertEqual(DeepFocusWindowPolicy.scheduleWindowEnd(now: date("2026-09-07T10:30:00Z"), schedules: schedules, calendar: calendar), date("2026-09-07T13:00:00Z"))
        XCTAssertFalse(DeepFocusWindowPolicy.isWindowActive(now: date("2026-09-07T13:00:00Z"), snapshot: snapshot, calendar: calendar))
    }

    func testManualSessionExtendsIntoFollowingScheduledBlock() {
        let now = date("2026-09-07T09:30:00Z")
        let session = DeepFocusSession(startedAt: now, endsAt: date("2026-09-07T10:30:00Z"))
        XCTAssertEqual(DeepFocusWindowPolicy.scheduleWindowEnd(now: now, schedules: [schedule(600, 720)], calendar: calendar, session: session), date("2026-09-07T12:00:00Z"))
    }

    func testNightRuleOnlyUsesWeeklyScheduleAfterOptIn() {
        let rule = TargetRule(id: UUID(), name: "night", activitySelectionData: Data([1]), mode: .nightOnly, schedule: nil, delaySeconds: 0, maxOpensPerDay: nil, defaultDurationMinutes: 10, isEnabled: true, createdAt: Date(), updatedAt: Date())
        XCTAssertEqual(ShieldSyncPolicy.rulesToShield(rules: [rule], isPro: true, strictModeAllowed: true, hasConfirmedEntitlement: true, isNightWindow: false, isDeepFocusWindowActive: true), [])
        XCTAssertEqual(ShieldSyncPolicy.rulesToShield(rules: [rule], isPro: true, strictModeAllowed: true, hasConfirmedEntitlement: true, isNightWindow: false, isDeepFocusWindowActive: true, allowsNightSchedule: true), [rule])
    }

    func testAdjacentOvernightSchedulesMergeButGapDoesNot() {
        let now = date("2026-09-07T23:00:00Z")
        XCTAssertEqual(DeepFocusWindowPolicy.scheduleWindowEnd(now: now, schedules: [schedule(1320, 120), schedule(120, 240, days: [3])], calendar: calendar), date("2026-09-08T04:00:00Z"))
        XCTAssertEqual(DeepFocusWindowPolicy.scheduleWindowEnd(now: now, schedules: [schedule(1320, 120), schedule(135, 240, days: [3])], calendar: calendar), date("2026-09-08T02:00:00Z"))
    }

    func testScheduleEndRespectsDSTWallClock() {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(DeepFocusWindowPolicy.scheduleWindowEnd(now: date("2026-03-08T09:30:00Z"), schedules: [schedule(60, 240, days: [1])], calendar: cal), date("2026-03-08T11:00:00Z"))
    }

    func testLegacySettingsMigrateAndExtraScheduleCanBeRemoved() throws {
        let name = "CompetitiveImprovements.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(userDefaults: defaults)
        store.deepFocusSchedule = schedule(600, 720)
        XCTAssertEqual(store.deepFocusSchedules, [schedule(600, 720)])
        XCTAssertFalse(store.blockTriggers.contains(.weeklySchedule))
        store.deepFocusSchedules = [schedule(600, 720), schedule(800, 900)]
        XCTAssertEqual(SettingsStore(userDefaults: defaults).deepFocusSchedules.count, 2)
        store.deepFocusSchedules = [schedule(600, 720)]
        XCTAssertEqual(store.deepFocusSchedules, [schedule(600, 720)])
    }

    func testOldSnapshotAndSessionDecodeWithoutNewFields() throws {
        let json = #"{"selectionDataList":[],"schedule":{"isEnabled":false,"weekdays":[],"startMinutes":1200,"endMinutes":1320},"session":{"startedAt":100,"endsAt":1000},"updatedAt":100}"#.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(DeepFocusShieldSnapshot.self, from: json)
        XCTAssertEqual(snapshot.schedules.count, 1)
        XCTAssertEqual(snapshot.session?.isStrict, false)
    }

    func testStrictEmergencyExitSurvivesReloadAndRequiresFullWait() throws {
        let now = date("2026-09-07T10:00:00Z")
        let session = DeepFocusSession(startedAt: now, endsAt: now.addingTimeInterval(3600), isStrict: true, emergencyExitRequestedAt: now)
        let restored = try JSONDecoder().decode(DeepFocusSession.self, from: JSONEncoder().encode(session))
        XCTAssertFalse(restored.canEnd(now: now.addingTimeInterval(60)))
        XCTAssertFalse(restored.canEnd(now: now.addingTimeInterval(29.9), emergency: true))
        XCTAssertTrue(restored.canEnd(now: now.addingTimeInterval(30), emergency: true))
        XCTAssertFalse(restored.canEnd(now: now.addingTimeInterval(-60), emergency: true))
        XCTAssertTrue(restored.canEnd(now: now.addingTimeInterval(3600)))
    }

    func testStrictWithoutExitRequestDoesNotUnlockAndIndefiniteIsNeverStrict() {
        let now = Date()
        XCTAssertFalse(DeepFocusSession(startedAt: now, endsAt: now.addingTimeInterval(3600), isStrict: true).canEnd(now: now.addingTimeInterval(30), emergency: true))
        XCTAssertFalse(DeepFocusSession(startedAt: now, endsAt: nil, isStrict: true).isStrict)
    }

    func testInsightsNeedEnoughAnswersAndRegretMajority() {
        XCTAssertNil(ReflectionInsightPolicy.insight(counts: [.lostTime: 4]))
        XCTAssertNil(ReflectionInsightPolicy.insight(counts: [.nothingGained: 5]))
        XCTAssertNil(ReflectionInsightPolicy.insight(counts: [.lostTime: 2, .fun: 3]))
        XCTAssertEqual(ReflectionInsightPolicy.insight(counts: [.lostTime: 2, .feltWorse: 1, .fun: 2]), ReflectionInsight(answerCount: 5, regretCount: 3))
    }
}
