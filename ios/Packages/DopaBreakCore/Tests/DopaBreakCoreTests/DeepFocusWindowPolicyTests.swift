import Foundation
import XCTest
@testable import DopaBreakCore

final class DeepFocusWindowPolicyTests: XCTestCase {
    // MARK: - セッション

    func testTimedSessionIsActiveBeforeItsEnd() {
        let session = DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))

        XCTAssertTrue(DeepFocusWindowPolicy.isSessionActive(now: at(10, 0), session: session))
        XCTAssertTrue(DeepFocusWindowPolicy.isSessionActive(now: at(10, 59), session: session))
    }

    /// 終わる時刻ちょうどで終わる。1分でも過ぎて残ると「終わったのに開けない」になる。
    func testTimedSessionEndsExactlyAtItsEndDate() {
        let session = DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))

        XCTAssertFalse(DeepFocusWindowPolicy.isSessionActive(now: at(11, 0), session: session))
        XCTAssertFalse(DeepFocusWindowPolicy.isSessionActive(now: at(11, 1), session: session))
    }

    /// 端末を触らないまま何日も経っても、終わった回は終わったまま。
    func testLongExpiredSessionStaysInactive() {
        let session = DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))
        let muchLater = at(11, 0).addingTimeInterval(60 * 60 * 24 * 30)

        XCTAssertFalse(DeepFocusWindowPolicy.isSessionActive(now: muchLater, session: session))
        XCTAssertNil(DeepFocusWindowPolicy.activeSession(session, now: muchLater))
    }

    /// 「自分で戻すまで」は時間では終わらない。常時ブロックの後継はここに入る。
    func testOpenEndedSessionNeverExpires() {
        let session = DeepFocusSession(startedAt: at(10, 0), endsAt: nil)

        XCTAssertTrue(DeepFocusWindowPolicy.isSessionActive(now: at(10, 0), session: session))
        XCTAssertTrue(
            DeepFocusWindowPolicy.isSessionActive(
                now: at(10, 0).addingTimeInterval(60 * 60 * 24 * 365),
                session: session
            )
        )
        XCTAssertFalse(DeepFocusWindowPolicy.isExpired(session: session, now: at(23, 59)))
    }

    func testNoSessionIsNotActive() {
        XCTAssertFalse(DeepFocusWindowPolicy.isSessionActive(now: at(10, 0), session: nil))
        XCTAssertNil(DeepFocusWindowPolicy.activeSession(nil, now: at(10, 0)))
    }

    func testActiveSessionDropsTheExpiredOne() {
        let expired = DeepFocusSession(startedAt: at(9, 0), endsAt: at(10, 0))
        let running = DeepFocusSession(startedAt: at(9, 0), endsAt: at(11, 0))

        XCTAssertNil(DeepFocusWindowPolicy.activeSession(expired, now: at(10, 0)))
        XCTAssertEqual(DeepFocusWindowPolicy.activeSession(running, now: at(10, 0)), running)
    }

    func testRemainingSecondsCountsDownToTheEnd() {
        let session = DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))

        XCTAssertEqual(
            DeepFocusWindowPolicy.remainingSeconds(now: at(10, 0), session: session),
            3_600
        )
        XCTAssertEqual(
            DeepFocusWindowPolicy.remainingSeconds(now: at(10, 30), session: session),
            1_800
        )
    }

    /// 終わった回と「自分で戻すまで」には残り時間がない。画面はここで表示を分ける。
    func testRemainingSecondsIsNilWithoutAnEndDate() {
        XCTAssertNil(
            DeepFocusWindowPolicy.remainingSeconds(
                now: at(10, 0),
                session: DeepFocusSession(startedAt: at(10, 0), endsAt: nil)
            )
        )
        XCTAssertNil(
            DeepFocusWindowPolicy.remainingSeconds(
                now: at(11, 0),
                session: DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))
            )
        )
        XCTAssertNil(DeepFocusWindowPolicy.remainingSeconds(now: at(10, 0), session: nil))
    }

    // MARK: - 予定（同日内の時間帯）

    func testSameDayScheduleAppliesOnlyOnItsWeekdaysAndHours() {
        // 月曜（weekday=2）の20:00→22:00。
        let schedule = makeSchedule(weekdays: [2], start: 1_200, end: 1_320)

        XCTAssertTrue(isScheduleActive(schedule, monday: true, hour: 20, minute: 0))
        XCTAssertTrue(isScheduleActive(schedule, monday: true, hour: 21, minute: 59))
        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 22, minute: 0))
        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 19, minute: 59))
        // 曜日が違えば同じ時刻でも入らない。
        XCTAssertFalse(isScheduleActive(schedule, monday: false, hour: 21, minute: 0))
    }

    func testEveryWeekdayScheduleAppliesAllWeek() {
        let schedule = makeSchedule(
            weekdays: DeepFocusConstants.allWeekdays,
            start: 1_200,
            end: 1_320
        )

        for day in 16...22 {
            XCTAssertTrue(
                DeepFocusWindowPolicy.isScheduleActive(
                    now: date(day: day, hour: 21, minute: 0),
                    schedule: schedule,
                    calendar: calendar
                ),
                "day=\(day)"
            )
        }
    }

    // MARK: - 予定（跨日）

    /// 22:00→翌6:00。月曜を選んだら、火曜の朝5時までが月曜のぶん。
    func testCrossMidnightScheduleBelongsToItsStartWeekday() {
        let schedule = makeSchedule(weekdays: [2], start: 1_320, end: 360)

        // 月曜の夜側。
        XCTAssertTrue(isScheduleActive(schedule, monday: true, hour: 22, minute: 0))
        XCTAssertTrue(isScheduleActive(schedule, monday: true, hour: 23, minute: 59))
        // 火曜の朝側は月曜の窓の続き。
        XCTAssertTrue(isScheduleActive(schedule, monday: false, hour: 0, minute: 0))
        XCTAssertTrue(isScheduleActive(schedule, monday: false, hour: 5, minute: 59))
        // 終わりちょうどで開く。
        XCTAssertFalse(isScheduleActive(schedule, monday: false, hour: 6, minute: 0))
        // 月曜の朝は、日曜を選んでいないので入らない。
        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 5, minute: 0))
        // 火曜の夜は火曜を選んでいないので入らない。
        XCTAssertFalse(isScheduleActive(schedule, monday: false, hour: 23, minute: 0))
    }

    /// 日曜（weekday=1）を選んだ跨日の窓は、月曜の朝へ続く。曜日の巻き戻りを固定する。
    func testCrossMidnightScheduleWrapsFromSaturdayToSunday() {
        // 土曜（weekday=7）の23:00→翌5:00。
        let schedule = makeSchedule(weekdays: [7], start: 1_380, end: 300)

        // 2026年8月22日は土曜。
        XCTAssertTrue(
            DeepFocusWindowPolicy.isScheduleActive(
                now: date(day: 22, hour: 23, minute: 30),
                schedule: schedule,
                calendar: calendar
            )
        )
        // 翌23日は日曜。土曜の窓の続きとして入る。
        XCTAssertTrue(
            DeepFocusWindowPolicy.isScheduleActive(
                now: date(day: 23, hour: 4, minute: 59),
                schedule: schedule,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            DeepFocusWindowPolicy.isScheduleActive(
                now: date(day: 23, hour: 5, minute: 0),
                schedule: schedule,
                calendar: calendar
            )
        )
    }

    // MARK: - 予定の縮退

    func testDisabledScheduleIsNeverActive() {
        let schedule = DeepFocusSchedule(
            isEnabled: false,
            weekdays: DeepFocusConstants.allWeekdays,
            startMinutes: 1_200,
            endMinutes: 1_320
        )

        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 21, minute: 0))
        XCTAssertFalse(DeepFocusWindowPolicy.isScheduleUsable(schedule))
    }

    func testScheduleWithoutWeekdaysIsNeverActive() {
        let schedule = makeSchedule(weekdays: [], start: 1_200, end: 1_320)

        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 21, minute: 0))
        XCTAssertFalse(DeepFocusWindowPolicy.isScheduleUsable(schedule))
    }

    /// 幅ゼロを24時間と読むと、設定の初期化に失敗した端末が終日ブロックになる。
    func testZeroLengthScheduleIsNeverActive() {
        let schedule = makeSchedule(weekdays: [2], start: 1_200, end: 1_200)

        for hour in 0..<24 {
            XCTAssertFalse(
                isScheduleActive(schedule, monday: true, hour: hour, minute: 0),
                "hour=\(hour)"
            )
        }
    }

    /// 15分未満はDeviceActivityが受け付けない。張れない予定を成立させない。
    func testScheduleShorterThanFifteenMinutesIsNeverActive() {
        let schedule = makeSchedule(weekdays: [2], start: 1_200, end: 1_214)

        XCTAssertFalse(DeepFocusWindowPolicy.hasWindow(startMinutes: 1_200, endMinutes: 1_214))
        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 20, minute: 5))
    }

    func testFifteenMinuteScheduleIsTheShortestUsableOne() {
        XCTAssertTrue(DeepFocusWindowPolicy.hasWindow(startMinutes: 1_200, endMinutes: 1_215))

        let schedule = makeSchedule(weekdays: [2], start: 1_200, end: 1_215)
        XCTAssertTrue(isScheduleActive(schedule, monday: true, hour: 20, minute: 14))
        XCTAssertFalse(isScheduleActive(schedule, monday: true, hour: 20, minute: 15))
    }

    // MARK: - 窓の長さと正規化

    func testWindowLengthCountsAcrossMidnight() {
        XCTAssertEqual(
            DeepFocusWindowPolicy.windowLengthMinutes(startMinutes: 1_320, endMinutes: 360),
            480
        )
        XCTAssertEqual(
            DeepFocusWindowPolicy.windowLengthMinutes(startMinutes: 1_200, endMinutes: 1_320),
            120
        )
        XCTAssertEqual(
            DeepFocusWindowPolicy.windowLengthMinutes(startMinutes: 600, endMinutes: 600),
            0
        )
    }

    func testCrossesMidnightIncludesTheZeroLengthCase() {
        XCTAssertTrue(DeepFocusWindowPolicy.crossesMidnight(startMinutes: 1_320, endMinutes: 360))
        XCTAssertTrue(DeepFocusWindowPolicy.crossesMidnight(startMinutes: 600, endMinutes: 600))
        XCTAssertFalse(DeepFocusWindowPolicy.crossesMidnight(startMinutes: 1_200, endMinutes: 1_320))
    }

    func testNormalizedMinutesWrapsBothDirections() {
        XCTAssertEqual(DeepFocusWindowPolicy.normalizedMinutes(-60), 1_380)
        XCTAssertEqual(DeepFocusWindowPolicy.normalizedMinutes(1_440), 0)
        XCTAssertEqual(DeepFocusWindowPolicy.normalizedMinutes(1_500), 60)
        XCTAssertEqual(DeepFocusWindowPolicy.normalizedMinutes(600), 600)
    }

    /// 控えは拡張がそのまま読む。並びが揺れると比較も表示も安定しない。
    func testNormalizedWeekdaysSortsAndDropsInvalidValues() {
        XCTAssertEqual(DeepFocusWindowPolicy.normalizedWeekdays([7, 2, 2, 0, 8, -1, 4]), [2, 4, 7])
        XCTAssertEqual(DeepFocusWindowPolicy.normalizedWeekdays([]), [])
    }

    func testWeekdayNeighboursWrapAroundTheWeek() {
        XCTAssertEqual(DeepFocusWindowPolicy.nextWeekday(7), 1)
        XCTAssertEqual(DeepFocusWindowPolicy.nextWeekday(1), 2)
        XCTAssertEqual(DeepFocusWindowPolicy.previousWeekday(1), 7)
        XCTAssertEqual(DeepFocusWindowPolicy.previousWeekday(2), 1)
    }

    // MARK: - 2つの窓のまとめ

    func testWindowIsActiveWhenEitherSideIsOpen() {
        let schedule = makeSchedule(weekdays: [2], start: 1_200, end: 1_320)
        let session = DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))

        // セッションだけ。
        XCTAssertTrue(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 10, minute: 30),
                session: session,
                schedule: schedule,
                calendar: calendar
            )
        )
        // 予定だけ。
        XCTAssertTrue(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 21, minute: 0),
                session: nil,
                schedule: schedule,
                calendar: calendar
            )
        )
        // どちらも閉じている。
        XCTAssertFalse(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 15, minute: 0),
                session: nil,
                schedule: schedule,
                calendar: calendar
            )
        )
    }

    /// セッションが終わっても、予定の時間帯なら閉じない。片方の終了で両方を落とさない。
    func testScheduleKeepsTheWindowOpenAfterTheSessionEnds() {
        let schedule = makeSchedule(weekdays: [2], start: 1_200, end: 1_320)
        let session = DeepFocusSession(
            startedAt: monday(hour: 20, minute: 0),
            endsAt: monday(hour: 20, minute: 30)
        )

        XCTAssertTrue(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 20, minute: 45),
                session: session,
                schedule: schedule,
                calendar: calendar
            )
        )
        // 予定も終われば閉じる。
        XCTAssertFalse(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 22, minute: 0),
                session: session,
                schedule: schedule,
                calendar: calendar
            )
        )
    }

    /// 拡張は控えだけを見て検算する。控え経由でも同じ答えになることを固定する。
    func testSnapshotOverloadMatchesTheDirectCall() {
        let snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [Data([0x01])],
            schedule: makeSchedule(weekdays: [2], start: 1_200, end: 1_320),
            session: nil,
            updatedAt: at(0, 0)
        )

        XCTAssertTrue(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 21, minute: 0),
                snapshot: snapshot,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            DeepFocusWindowPolicy.isWindowActive(
                now: monday(hour: 23, minute: 0),
                snapshot: snapshot,
                calendar: calendar
            )
        )
    }

    func testActiveSelectionDataSeparatesManualSessionFromWeeklySchedule() {
        let scheduledSelection = Data([0x01])
        let standardSelection = Data([0x02])
        let snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [scheduledSelection],
            sessionSelectionDataList: [standardSelection, scheduledSelection],
            schedule: makeSchedule(weekdays: [2], start: 1_200, end: 1_320),
            session: DeepFocusSession(
                startedAt: monday(hour: 20, minute: 0),
                endsAt: monday(hour: 20, minute: 30)
            ),
            updatedAt: monday(hour: 20, minute: 0)
        )

        XCTAssertEqual(
            DeepFocusWindowPolicy.selectionDataListToShield(
                now: monday(hour: 20, minute: 15),
                snapshot: snapshot,
                calendar: calendar
            ),
            [standardSelection, scheduledSelection]
        )
        XCTAssertEqual(
            DeepFocusWindowPolicy.selectionDataListToShield(
                now: monday(hour: 20, minute: 45),
                snapshot: snapshot,
                calendar: calendar
            ),
            [scheduledSelection]
        )
        XCTAssertTrue(
            DeepFocusWindowPolicy.selectionDataListToShield(
                now: monday(hour: 23, minute: 0),
                snapshot: snapshot,
                calendar: calendar
            ).isEmpty
        )
    }

    // MARK: - 控えを持つ価値があるか

    func testHasConfiguredWindowFollowsSessionAndSchedule() {
        let usable = makeSchedule(weekdays: [2], start: 1_200, end: 1_320)
        let unusable = makeSchedule(weekdays: [], start: 1_200, end: 1_320)
        let running = DeepFocusSession(startedAt: at(10, 0), endsAt: at(11, 0))
        let expired = DeepFocusSession(startedAt: at(8, 0), endsAt: at(9, 0))

        XCTAssertTrue(
            DeepFocusWindowPolicy.hasConfiguredWindow(
                now: at(10, 30),
                session: running,
                schedule: unusable
            )
        )
        // いま窓の外でも、これから開く予定があるなら控えは要る。
        XCTAssertTrue(
            DeepFocusWindowPolicy.hasConfiguredWindow(
                now: at(10, 30),
                session: nil,
                schedule: usable
            )
        )
        XCTAssertFalse(
            DeepFocusWindowPolicy.hasConfiguredWindow(
                now: at(10, 30),
                session: expired,
                schedule: unusable
            )
        )
        XCTAssertFalse(
            DeepFocusWindowPolicy.hasConfiguredWindow(
                now: at(10, 30),
                session: nil,
                schedule: unusable
            )
        )
    }

    // MARK: - 活動名

    /// 名前は拡張と共有する。往復が崩れると、境界が届いても分岐に入らない。
    func testScheduleActivityNameRoundTrips() {
        for weekday in DeepFocusConstants.allWeekdays {
            let name = DeepFocusConstants.scheduleActivityName(weekday: weekday)
            XCTAssertEqual(DeepFocusConstants.scheduleWeekday(activityName: name), weekday)
            XCTAssertTrue(DeepFocusConstants.isWindowActivity(name))
        }
    }

    func testScheduleWeekdayRejectsOutOfRangeAndForeignNames() {
        XCTAssertNil(DeepFocusConstants.scheduleWeekday(activityName: "dopabreak.deepfocus.weekday0"))
        XCTAssertNil(DeepFocusConstants.scheduleWeekday(activityName: "dopabreak.deepfocus.weekday8"))
        XCTAssertNil(DeepFocusConstants.scheduleWeekday(activityName: "dopabreak.deepfocus.weekdayX"))
        XCTAssertNil(DeepFocusConstants.scheduleWeekday(activityName: NightShieldConstants.activityName))
    }

    /// 夜だけ強化と使いすぎ見守りの活動を拾ってしまうと、別機能のブロックを触ってしまう。
    func testIsWindowActivityIgnoresOtherFeatures() {
        XCTAssertTrue(DeepFocusConstants.isWindowActivity(DeepFocusConstants.sessionActivityName))
        XCTAssertFalse(DeepFocusConstants.isWindowActivity(NightShieldConstants.activityName))
        XCTAssertFalse(DeepFocusConstants.isWindowActivity(UsageWatchConstants.activityName))
    }

    func testAllWindowActivityNamesCoverSessionAndEveryWeekday() {
        XCTAssertEqual(DeepFocusConstants.allWindowActivityNames.count, 8)
        XCTAssertTrue(
            DeepFocusConstants.allWindowActivityNames
                .contains(DeepFocusConstants.sessionActivityName)
        )
        XCTAssertTrue(DeepFocusConstants.allWindowActivityNames.allSatisfy(DeepFocusConstants.isWindowActivity))
    }

    /// ストア名を変えると、旧版で掛かったブロックを剥がす先がなくなる。
    func testShieldStoreNamesStayDistinct() {
        XCTAssertEqual(DeepFocusConstants.shieldStoreName, "dopabreak.deepfocus")
        XCTAssertEqual(DeepFocusConstants.legacyShieldStoreName, "dopabreak.rules")
        XCTAssertNotEqual(DeepFocusConstants.shieldStoreName, NightShieldConstants.shieldStoreName)
        XCTAssertNotEqual(
            DeepFocusConstants.legacyShieldStoreName,
            NightShieldConstants.shieldStoreName
        )
    }

    // MARK: - Helpers

    /// 曜日の判定を固定するため、テストは日本時間のグレゴリオ暦で回す。
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    private func makeSchedule(weekdays: [Int], start: Int, end: Int) -> DeepFocusSchedule {
        DeepFocusSchedule(
            isEnabled: true,
            weekdays: weekdays,
            startMinutes: start,
            endMinutes: end
        )
    }

    /// 2026年8月の日付。17日が月曜、18日が火曜、22日が土曜、23日が日曜。
    private func date(day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func monday(hour: Int, minute: Int) -> Date {
        date(day: 17, hour: hour, minute: minute)
    }

    private func tuesday(hour: Int, minute: Int) -> Date {
        date(day: 18, hour: hour, minute: minute)
    }

    /// 曜日に依らないセッションの検査で使う時刻。
    private func at(_ hour: Int, _ minute: Int) -> Date {
        monday(hour: hour, minute: minute)
    }

    private func isScheduleActive(
        _ schedule: DeepFocusSchedule,
        monday isMonday: Bool,
        hour: Int,
        minute: Int
    ) -> Bool {
        DeepFocusWindowPolicy.isScheduleActive(
            now: isMonday ? monday(hour: hour, minute: minute) : tuesday(hour: hour, minute: minute),
            schedule: schedule,
            calendar: calendar
        )
    }
}
