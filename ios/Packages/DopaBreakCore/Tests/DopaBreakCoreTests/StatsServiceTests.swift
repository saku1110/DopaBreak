import Foundation
import XCTest
@testable import DopaBreakCore

final class StatsServiceTests: XCTestCase {
    func testAttemptsTodayAndCancelledTodayRespectUTCDayBoundary() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 1, hour: 23, minute: 59, second: 59), decision: .opened))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 0), decision: .cancelled))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 12), decision: .opened))
        try log.insert(attempt(id: 4, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 3, hour: 0), decision: .cancelled))

        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        XCTAssertEqual(try stats.attemptsToday(), 2)
        XCTAssertEqual(try stats.cancelledToday(), 1)
    }

    func testCancelledAttemptsAllTimeCountsOnlyCancelledLogs() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: date(-10_000), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: date(10), decision: .opened))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: date(20), decision: .cancelled))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.cancelledAttemptsAllTime(), 2)
    }

    func testCancelledAttemptsCountsOnlyCancelledLogsInRange() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: date(10), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: date(20), decision: .opened))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: date(30), decision: .cancelled))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.cancelledAttempts(from: date(15), to: date(31)), 1)
    }

    func testAttemptSummaryCountsAttemptsAndCancelledLogsInRange() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: date(10), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: date(20), decision: .opened))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: date(30), decision: .cancelled))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(
            try stats.attemptSummary(from: date(15), to: date(31)),
            AttemptSummary(attempts: 2, cancelled: 1)
        )
    }

    func testIntentBreakdownCountsNonNilIntents() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: date(10), decision: .cancelled, intent: .boredom))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: date(20), decision: .opened, intent: .boredom))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: date(30), decision: .opened, intent: .research))
        try log.insert(attempt(id: 4, ruleId: uuid(1), startedAt: date(40), decision: .cancelled, intent: nil))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.intentBreakdown(from: date(0), to: date(1_000)), [.boredom: 2, .research: 1])
    }

    func testAppRuleBreakdownCountsPerRule() throws {
        let log = try makeLogStore()
        let ruleA = uuid(100)
        let ruleB = uuid(200)
        try log.insert(attempt(id: 1, ruleId: ruleA, startedAt: date(10), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: ruleA, startedAt: date(20), decision: .opened))
        try log.insert(attempt(id: 3, ruleId: ruleB, startedAt: date(30), decision: .cancelled))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.appRuleBreakdown(from: date(0), to: date(1_000)), [ruleA: 2, ruleB: 1])
    }

    func testReflectionBreakdownCountsAnsweredOnly() throws {
        let log = try makeLogStore()
        try log.insert(reflection(id: 1, promptedAt: date(10), answeredAt: date(11), satisfaction: .satisfied, happinessDelta: .increased))
        try log.insert(reflection(id: 2, promptedAt: date(20), answeredAt: date(21), satisfaction: .satisfied, happinessDelta: .unchanged))
        try log.insert(reflection(id: 3, promptedAt: date(30), answeredAt: date(31), satisfaction: .lostTime, happinessDelta: .decreased))
        try log.insert(reflection(id: 4, promptedAt: date(40), answeredAt: nil, satisfaction: nil, happinessDelta: nil))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.reflectionBreakdown(from: date(0), to: date(1_000)), [.satisfied: 2, .lostTime: 1])
    }

    func testHappinessDeltaBreakdownCountsAnsweredOnly() throws {
        let log = try makeLogStore()
        try log.insert(reflection(id: 1, promptedAt: date(10), answeredAt: date(11), satisfaction: .satisfied, happinessDelta: .increased))
        try log.insert(reflection(id: 2, promptedAt: date(20), answeredAt: date(21), satisfaction: .lostTime, happinessDelta: .decreased))
        try log.insert(reflection(id: 3, promptedAt: date(30), answeredAt: date(31), satisfaction: .feltWorse, happinessDelta: .decreased))
        try log.insert(reflection(id: 4, promptedAt: date(40), answeredAt: nil, satisfaction: nil, happinessDelta: nil))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.happinessDeltaBreakdown(from: date(0), to: date(1_000)), [.increased: 1, .decreased: 2])
    }

    func testWastedTimeRealizationRate() throws {
        let log = try makeLogStore()
        try log.insert(reflection(id: 1, promptedAt: date(10), answeredAt: date(11), satisfaction: .satisfied, happinessDelta: .increased))
        try log.insert(reflection(id: 2, promptedAt: date(20), answeredAt: date(21), satisfaction: .fun, happinessDelta: .unchanged))
        try log.insert(reflection(id: 3, promptedAt: date(30), answeredAt: date(31), satisfaction: .nothingGained, happinessDelta: .decreased))
        try log.insert(reflection(id: 4, promptedAt: date(40), answeredAt: date(41), satisfaction: .lostTime, happinessDelta: .decreased))
        try log.insert(reflection(id: 5, promptedAt: date(50), answeredAt: date(51), satisfaction: .feltWorse, happinessDelta: .decreased))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.wastedTimeRealizationRate(from: date(0), to: date(1_000)), 0.6, accuracy: 0.0001)
    }

    func testWastedTimeRealizationRateZeroWhenNoAnsweredReflections() throws {
        let log = try makeLogStore()
        try log.insert(reflection(id: 1, promptedAt: date(10), answeredAt: nil, satisfaction: nil, happinessDelta: nil))

        let stats = makeStats(log: log, now: date(500))

        XCTAssertEqual(try stats.wastedTimeRealizationRate(from: date(0), to: date(1_000)), 0)
    }

    func testWeeklySummaryTotalsAndPerDay() throws {
        let log = try makeLogStore()
        // within the trailing 7-day window (06-26 .. 07-02 inclusive)
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 26, hour: 9), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 1, hour: 8), decision: .cancelled))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 1, hour: 20), decision: .opened))
        try log.insert(attempt(id: 4, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 10), decision: .opened))
        // outside the window
        try log.insert(attempt(id: 5, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 25, hour: 23), decision: .cancelled))
        try log.insert(attempt(id: 6, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 3, hour: 0), decision: .cancelled))
        // answered reflections within the window
        try log.insert(reflection(id: 10, promptedAt: calendarDate(year: 2026, month: 7, day: 1, hour: 21), answeredAt: calendarDate(year: 2026, month: 7, day: 1, hour: 21, minute: 5), satisfaction: .lostTime, happinessDelta: .decreased))
        try log.insert(reflection(id: 11, promptedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 10), answeredAt: calendarDate(year: 2026, month: 7, day: 2, hour: 10, minute: 5), satisfaction: .nothingGained, happinessDelta: .decreased))
        try log.insert(reflection(id: 12, promptedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 11), answeredAt: calendarDate(year: 2026, month: 7, day: 2, hour: 11, minute: 5), satisfaction: .satisfied, happinessDelta: .increased))
        try log.insert(reflection(id: 13, promptedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 11, minute: 30), answeredAt: nil, satisfaction: nil, happinessDelta: nil))

        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))
        let summary = try stats.weeklySummary()

        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.days.first?.date, calendarDate(year: 2026, month: 6, day: 26, hour: 0))
        XCTAssertEqual(summary.days.last?.date, calendarDate(year: 2026, month: 7, day: 2, hour: 0))
        XCTAssertEqual(summary.days[0].attempts, 1)
        XCTAssertEqual(summary.days[0].cancelled, 1)
        XCTAssertEqual(summary.days[5].attempts, 2)
        XCTAssertEqual(summary.days[5].cancelled, 1)
        XCTAssertEqual(summary.days[6].attempts, 1)
        XCTAssertEqual(summary.days[6].cancelled, 0)
        XCTAssertEqual(summary.attempts, 4)
        XCTAssertEqual(summary.cancelled, 2)
        XCTAssertEqual(summary.cancelRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.answeredReflections, 3)
        XCTAssertEqual(summary.wastedTimeRealizationRate, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testWeeklySummaryZeroStateHasSevenEmptyDays() throws {
        let log = try makeLogStore()
        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        let summary = try stats.weeklySummary()

        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.attempts, 0)
        XCTAssertEqual(summary.cancelled, 0)
        XCTAssertEqual(summary.cancelRate, 0)
        XCTAssertEqual(summary.answeredReflections, 0)
        XCTAssertEqual(summary.wastedTimeRealizationRate, 0)
        XCTAssertTrue(summary.days.allSatisfy { $0.attempts == 0 && $0.cancelled == 0 })
    }

    // MARK: - 週次詳細レポート（Pro）

    func testWeeklySummaryWeeksBackReturnsPreviousNonOverlappingWindow() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 19, hour: 0), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 25, hour: 23, minute: 59, second: 59), decision: .opened))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 26, hour: 0), decision: .opened))
        try log.insert(attempt(id: 4, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 12), decision: .cancelled))

        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        let previous = try stats.weeklySummary(weeksBack: 1)

        XCTAssertEqual(previous.days.count, 7)
        XCTAssertEqual(previous.days.first?.date, calendarDate(year: 2026, month: 6, day: 19, hour: 0))
        XCTAssertEqual(previous.days.last?.date, calendarDate(year: 2026, month: 6, day: 25, hour: 0))
        XCTAssertEqual(previous.attempts, 2)
        XCTAssertEqual(previous.cancelled, 1)
        XCTAssertEqual(previous.cancelRate, 0.5, accuracy: 0.0001)

        // 直近7日は既定引数のまま変わらない。窓は1日も重ならない。
        let current = try stats.weeklySummary()
        XCTAssertEqual(current.days.first?.date, calendarDate(year: 2026, month: 6, day: 26, hour: 0))
        XCTAssertEqual(current.attempts, 2)
        XCTAssertEqual(current.cancelled, 1)
    }

    func testWeeklySummaryWeeksBackBeyondRecordedHistoryIsEmpty() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 26, hour: 0), decision: .cancelled))

        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        let summary = try stats.weeklySummary(weeksBack: 2)

        XCTAssertEqual(summary.days.first?.date, calendarDate(year: 2026, month: 6, day: 12, hour: 0))
        XCTAssertEqual(summary.days.last?.date, calendarDate(year: 2026, month: 6, day: 18, hour: 0))
        XCTAssertEqual(summary.attempts, 0)
        XCTAssertEqual(summary.cancelRate, 0)
    }

    func testWeeklySummaryRejectsNegativeWeeksBack() throws {
        let log = try makeLogStore()
        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        XCTAssertThrowsError(try stats.weeklySummary(weeksBack: -1))
    }

    func testWeeklySummaryWeeksBackRespectsInjectedTimeZoneDayBoundary() throws {
        let log = try makeLogStore()
        // JSTでは6/26 08:00（今週の初日）。UTC基準だと6/25で前週側に落ちる時刻。
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 25, hour: 23), decision: .cancelled))
        // JSTでは6/25 23:00（前週の最終日）。
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 25, hour: 14), decision: .opened))

        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // JSTでは7/2 12:00。
        let nowDate = calendarDate(year: 2026, month: 7, day: 2, hour: 3)
        let stats = StatsService(logStore: log, calendar: tokyoCalendar, now: { nowDate })

        let current = try stats.weeklySummary(weeksBack: 0)
        let previous = try stats.weeklySummary(weeksBack: 1)

        // 6/26 00:00 JST = 6/25 15:00 UTC。
        XCTAssertEqual(current.days.first?.date, calendarDate(year: 2026, month: 6, day: 25, hour: 15))
        XCTAssertEqual(current.attempts, 1)
        XCTAssertEqual(current.days[0].cancelled, 1)
        // 6/25 00:00 JST = 6/24 15:00 UTC。
        XCTAssertEqual(previous.days.last?.date, calendarDate(year: 2026, month: 6, day: 24, hour: 15))
        XCTAssertEqual(previous.attempts, 1)
        XCTAssertEqual(previous.cancelled, 0)
    }

    func testWeeklyDetailReportComparesCurrentAndPreviousWeek() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 30, hour: 9), decision: .cancelled))
        try log.insert(attempt(id: 2, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 30, hour: 10), decision: .cancelled))
        try log.insert(attempt(id: 3, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 30, hour: 11), decision: .opened))
        try log.insert(attempt(id: 4, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 2, hour: 8), decision: .cancelled))
        try log.insert(attempt(id: 5, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 20, hour: 9), decision: .cancelled))
        try log.insert(attempt(id: 6, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 20, hour: 10), decision: .opened))

        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        let report = try stats.weeklyDetailReport()

        XCTAssertEqual(report.current.attempts, 4)
        XCTAssertEqual(report.current.cancelled, 3)
        XCTAssertEqual(report.previous.attempts, 2)
        XCTAssertEqual(report.previous.cancelled, 1)
        XCTAssertTrue(report.isComparable)
        XCTAssertEqual(report.cancelledDelta, 2)
        XCTAssertEqual(report.peakDailyAttempts, 3)
        XCTAssertFalse(report.isEmpty)
    }

    func testWeeklyDetailReportWithoutPreviousWeekDataIsNotComparable() throws {
        let log = try makeLogStore()
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 7, day: 1, hour: 9), decision: .cancelled))

        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        let report = try stats.weeklyDetailReport()

        XCTAssertFalse(report.isComparable)
        XCTAssertNil(report.cancelledDelta)
        XCTAssertFalse(report.isEmpty)
        XCTAssertEqual(report.peakDailyAttempts, 1)
    }

    func testWeeklyDetailReportIsEmptyWhenNeitherWeekHasAttempts() throws {
        let log = try makeLogStore()
        let stats = makeStats(log: log, now: calendarDate(year: 2026, month: 7, day: 2, hour: 12))

        let report = try stats.weeklyDetailReport()

        XCTAssertTrue(report.isEmpty)
        XCTAssertNil(report.cancelledDelta)
        XCTAssertEqual(report.peakDailyAttempts, 0)
        XCTAssertEqual(report.current.days.count, 7)
        XCTAssertEqual(report.previous.days.count, 7)
    }

    /// 今週と前週で現在時刻を読み直すと、深夜0時をまたいだ瞬間に窓が1日重なる。
    /// 起点の日を1度だけ確定させていれば、`now` が途中で進んでも窓の関係は崩れない。
    func testWeeklyDetailReportAnchorsBothWindowsToOneDayAcrossMidnight() throws {
        let log = try makeLogStore()
        // 両方の窓の境目になる日。重複が起きると今週と前週の両方に数えられる。
        try log.insert(attempt(id: 1, ruleId: uuid(1), startedAt: calendarDate(year: 2026, month: 6, day: 26, hour: 12), decision: .cancelled))

        let clock = AdvancingClock([
            calendarDate(year: 2026, month: 7, day: 2, hour: 23, minute: 59, second: 59),
            calendarDate(year: 2026, month: 7, day: 3, hour: 0)
        ])
        let stats = StatsService(logStore: log, calendar: utcCalendar(), now: { clock.next() })

        let report = try stats.weeklyDetailReport()

        // 起点は7/2のまま。今週=6/26〜7/2、前週=6/19〜6/25。
        XCTAssertEqual(report.current.days.first?.date, calendarDate(year: 2026, month: 6, day: 26, hour: 0))
        XCTAssertEqual(report.current.days.last?.date, calendarDate(year: 2026, month: 7, day: 2, hour: 0))
        XCTAssertEqual(report.previous.days.first?.date, calendarDate(year: 2026, month: 6, day: 19, hour: 0))
        XCTAssertEqual(report.previous.days.last?.date, calendarDate(year: 2026, month: 6, day: 25, hour: 0))
        // 6/26の1件はどちらか一方にしか出ない。
        XCTAssertEqual(report.current.attempts, 1)
        XCTAssertEqual(report.previous.attempts, 0)
    }

    // MARK: - Helpers

    /// 呼ばれるたびに次の時刻を返し、尽きたら最後の値を返し続けるテスト用の時計。
    private final class AdvancingClock: @unchecked Sendable {
        private let values: [Date]
        private var index = 0

        init(_ values: [Date]) {
            precondition(!values.isEmpty)
            self.values = values
        }

        func next() -> Date {
            defer { index = min(index + 1, values.count - 1) }
            return values[index]
        }
    }

    private func makeStats(log: SQLiteLogStore, now: Date) -> StatsService {
        StatsService(logStore: log, calendar: utcCalendar(), now: { now })
    }

    private func makeLogStore() throws -> SQLiteLogStore {
        try SQLiteLogStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatsServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func attempt(
        id: Int,
        ruleId: UUID,
        startedAt: Date,
        decision: Decision,
        intent: IntentCategory? = nil
    ) -> AttemptLog {
        AttemptLog(
            id: uuid(id),
            ruleId: ruleId,
            startedAt: startedAt,
            completedAt: startedAt,
            decision: decision,
            intent: intent,
            selectedDurationSeconds: decision == .opened ? 300 : nil,
            attemptCount24h: 1,
            opened: decision == .opened
        )
    }

    private func reflection(
        id: Int,
        promptedAt: Date,
        answeredAt: Date?,
        satisfaction: PostUseSatisfaction?,
        happinessDelta: HappinessDelta?,
        skipped: Bool = false
    ) -> ReflectionLog {
        ReflectionLog(
            id: uuid(id),
            attemptLogId: nil,
            ruleId: uuid(900),
            promptedAt: promptedAt,
            answeredAt: answeredAt,
            trigger: .timedSessionEnded,
            satisfaction: satisfaction,
            happinessDelta: happinessDelta,
            skipped: skipped,
            createdAt: promptedAt
        )
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
}
