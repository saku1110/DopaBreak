import Foundation
import XCTest
@testable import DopaBreakCore

final class DailyOpenLimitPolicyTests: XCTestCase {
    private let wake = 420 // 7:00

    // MARK: - 1日の区切り

    func testDayStartIsTodaysWakeTimeAfterWaking() {
        let now = tokyo(2026, 10, 5, 8, 0)
        XCTAssertEqual(DailyOpenLimitPolicy.dayStart(now: now, boundaryMinutes: wake, calendar: calendar), tokyo(2026, 10, 5, 7, 0))
        XCTAssertEqual(DailyOpenLimitPolicy.nextDayStart(now: now, boundaryMinutes: wake, calendar: calendar), tokyo(2026, 10, 6, 7, 0))
    }

    /// 起床前の深夜は前日のぶんとして数える。0時で回数が戻ると夜更かしの抜け道になる。
    func testBeforeWakeTimeBelongsToThePreviousDay() {
        let now = tokyo(2026, 10, 5, 1, 30)
        XCTAssertEqual(DailyOpenLimitPolicy.dayStart(now: now, boundaryMinutes: wake, calendar: calendar), tokyo(2026, 10, 4, 7, 0))
        XCTAssertEqual(DailyOpenLimitPolicy.nextDayStart(now: now, boundaryMinutes: wake, calendar: calendar), tokyo(2026, 10, 5, 7, 0))
    }

    /// 起床時刻ちょうどは新しい日。
    func testWakeTimeItselfStartsTheNewDay() {
        let now = tokyo(2026, 10, 5, 7, 0)
        XCTAssertEqual(DailyOpenLimitPolicy.dayStart(now: now, boundaryMinutes: wake, calendar: calendar), now)
        XCTAssertEqual(DailyOpenLimitPolicy.nextDayStart(now: now, boundaryMinutes: wake, calendar: calendar), tokyo(2026, 10, 6, 7, 0))
    }

    func testOutOfRangeBoundaryIsNormalized() {
        let now = tokyo(2026, 10, 5, 8, 0)
        XCTAssertEqual(
            DailyOpenLimitPolicy.dayStart(now: now, boundaryMinutes: wake + 1_440, calendar: calendar),
            tokyo(2026, 10, 5, 7, 0)
        )
    }

    /// 夏時間の切り替え日でも、区切りは「いまより前」と「いまより後」に1つずつある。
    func testDaylightSavingTransitionKeepsBoundariesAroundNow() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        for hour in [1, 3, 9, 23] {
            let now = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: hour)))
            for boundary in [150, 420] {
                let start = DailyOpenLimitPolicy.dayStart(now: now, boundaryMinutes: boundary, calendar: newYork)
                let end = DailyOpenLimitPolicy.nextDayStart(now: now, boundaryMinutes: boundary, calendar: newYork)
                XCTAssertLessThanOrEqual(start, now)
                XCTAssertGreaterThan(end, now)
                XCTAssertLessThanOrEqual(end.timeIntervalSince(start), 25 * 3_600)
            }
        }
    }

    // MARK: - 設定の変更

    func testTurningOnTakesEffectNowAndCountsFromThatMoment() {
        let now = tokyo(2026, 10, 5, 15, 0)
        let value = apply(10, to: DailyOpenLimitSettings(), now: now)
        XCTAssertEqual(value.limit, 10)
        XCTAssertNil(value.pendingChange)
        XCTAssertEqual(value.countingStartsAt, now)
        XCTAssertEqual(
            DailyOpenLimitPolicy.countingStart(settings: value, now: now.addingTimeInterval(60), boundaryMinutes: wake, calendar: calendar),
            now
        )
    }

    /// オンにした翌日は、区切りから数える。
    func testCountingStartFallsBackToDayStartOnLaterDays() {
        let enabledAt = tokyo(2026, 10, 5, 15, 0)
        let value = apply(10, to: DailyOpenLimitSettings(), now: enabledAt)
        let nextDay = tokyo(2026, 10, 6, 9, 0)
        XCTAssertEqual(
            DailyOpenLimitPolicy.countingStart(settings: value, now: nextDay, boundaryMinutes: wake, calendar: calendar),
            tokyo(2026, 10, 6, 7, 0)
        )
    }

    func testLoweringTakesEffectNow() {
        let now = tokyo(2026, 10, 5, 15, 0)
        let value = apply(5, to: DailyOpenLimitSettings(limit: 10), now: now)
        XCTAssertEqual(value.limit, 5)
        XCTAssertNil(value.pendingChange)
    }

    /// 増やす・オフは翌朝から。使い切った直後に設定から緩めて開く抜け道をふさぐ。
    func testRaisingAndTurningOffWaitUntilTheNextWakeTime() {
        let now = tokyo(2026, 10, 5, 15, 0)
        let raised = apply(15, to: DailyOpenLimitSettings(limit: 10), now: now)
        XCTAssertEqual(raised.limit, 10)
        XCTAssertEqual(raised.pendingChange, .init(limit: 15, effectiveAt: tokyo(2026, 10, 6, 7, 0)))

        let off = apply(nil, to: DailyOpenLimitSettings(limit: 10), now: now)
        XCTAssertEqual(off.limit, 10)
        XCTAssertEqual(off.pendingChange, .init(limit: nil, effectiveAt: tokyo(2026, 10, 6, 7, 0)))
    }

    func testPendingChangeIsAppliedAtItsTime() {
        let pending = DailyOpenLimitSettings(limit: 10, pendingChange: .init(limit: 15, effectiveAt: tokyo(2026, 10, 6, 7, 0)))
        XCTAssertEqual(DailyOpenLimitPolicy.resolved(pending, now: tokyo(2026, 10, 6, 6, 59)).limit, 10)
        let resolved = DailyOpenLimitPolicy.resolved(pending, now: tokyo(2026, 10, 6, 7, 0))
        XCTAssertEqual(resolved.limit, 15)
        XCTAssertNil(resolved.pendingChange)
    }

    /// 予約中に今の値を選び直すと、予約を取り消す。
    func testChoosingTheCurrentValueCancelsTheReservation() {
        let now = tokyo(2026, 10, 5, 15, 0)
        let pending = apply(15, to: DailyOpenLimitSettings(limit: 10), now: now)
        let cancelled = apply(10, to: pending, now: now)
        XCTAssertEqual(cancelled.limit, 10)
        XCTAssertNil(cancelled.pendingChange)
    }

    /// 予約中でも、締める変更は予約を置き換えてすぐ効く。
    func testTighteningReplacesAReservation() {
        let now = tokyo(2026, 10, 5, 15, 0)
        let pending = apply(nil, to: DailyOpenLimitSettings(limit: 10), now: now)
        let tightened = apply(3, to: pending, now: now)
        XCTAssertEqual(tightened.limit, 3)
        XCTAssertNil(tightened.pendingChange)
    }

    func testLimitIsNeverBelowOne() {
        let value = apply(0, to: DailyOpenLimitSettings(), now: tokyo(2026, 10, 5, 15, 0))
        XCTAssertEqual(value.limit, 1)
    }

    // MARK: - 残り

    func testStatusReportsRemainingAndLastOpen() {
        let now = tokyo(2026, 10, 5, 15, 0)
        let settings = DailyOpenLimitSettings(limit: 3)
        let two = DailyOpenLimitPolicy.status(settings: settings, openedCount: 2, now: now, boundaryMinutes: wake, calendar: calendar)
        XCTAssertEqual(two.remaining, 1)
        XCTAssertTrue(two.isLastOpen)
        XCTAssertFalse(two.isExhausted)
        XCTAssertEqual(two.dayEndsAt, tokyo(2026, 10, 6, 7, 0))

        let over = DailyOpenLimitPolicy.status(settings: settings, openedCount: 5, now: now, boundaryMinutes: wake, calendar: calendar)
        XCTAssertEqual(over.remaining, 0)
        XCTAssertTrue(over.isExhausted)

        let off = DailyOpenLimitPolicy.status(settings: DailyOpenLimitSettings(), openedCount: 5, now: now, boundaryMinutes: wake, calendar: calendar)
        XCTAssertNil(off.remaining)
        XCTAssertFalse(off.isExhausted)
        XCTAssertFalse(off.isLastOpen)
    }

    // MARK: - 使い切ったあとの窓

    func testBlockStartsWhenTheLastOpensChosenTimeEnds() {
        let openedAt = tokyo(2026, 10, 5, 15, 0)
        XCTAssertEqual(DailyOpenLimitPolicy.blockStart(openedAt: openedAt, durationSeconds: 600), tokyo(2026, 10, 5, 15, 10))
        XCTAssertEqual(DailyOpenLimitPolicy.blockStart(openedAt: openedAt, durationSeconds: nil), tokyo(2026, 10, 5, 15, 30))
    }

    /// 15分未満の窓は張れないので窓なし。掛けると解除の担い手がいなくなる。
    func testWindowsShorterThanFifteenMinutesAreDropped() {
        XCTAssertNil(DailyOpenLimitPolicy.blockWindow(startsAt: tokyo(2026, 10, 6, 6, 46), endsAt: tokyo(2026, 10, 6, 7, 0)))
        XCTAssertNotNil(DailyOpenLimitPolicy.blockWindow(startsAt: tokyo(2026, 10, 6, 6, 45), endsAt: tokyo(2026, 10, 6, 7, 0)))
        XCTAssertNil(DailyOpenLimitPolicy.blockWindow(startsAt: tokyo(2026, 10, 6, 7, 5), endsAt: tokyo(2026, 10, 6, 7, 0)))
    }

    func testBlockIsActiveOnlyInsideTheWindow() {
        let snapshot = DailyOpenLimitShieldSnapshot(
            selectionDataList: [Data([1])],
            openedCount: 12,
            blockStartsAt: tokyo(2026, 10, 5, 15, 10),
            blockEndsAt: tokyo(2026, 10, 6, 7, 0),
            updatedAt: tokyo(2026, 10, 5, 15, 0)
        )
        XCTAssertFalse(DailyOpenLimitPolicy.isBlockActive(now: tokyo(2026, 10, 5, 15, 9), snapshot: snapshot))
        XCTAssertTrue(DailyOpenLimitPolicy.isBlockActive(now: tokyo(2026, 10, 5, 15, 10), snapshot: snapshot))
        XCTAssertTrue(DailyOpenLimitPolicy.isBlockActive(now: tokyo(2026, 10, 6, 6, 59), snapshot: snapshot))
        XCTAssertFalse(DailyOpenLimitPolicy.isBlockActive(now: tokyo(2026, 10, 6, 7, 0), snapshot: snapshot))
        XCTAssertFalse(DailyOpenLimitPolicy.isSnapshotCurrent(now: tokyo(2026, 10, 6, 7, 0), snapshot: snapshot))

        var empty = snapshot
        empty.selectionDataList = []
        XCTAssertFalse(DailyOpenLimitPolicy.isBlockActive(now: tokyo(2026, 10, 5, 20, 0), snapshot: empty))
    }

    // MARK: - 緊急で開く

    func testEmergencyWaitIsThirtySecondsAndExpiresAfterFiveMinutes() {
        let requestedAt = tokyo(2026, 10, 5, 20, 0)
        XCTAssertEqual(DailyOpenLimitPolicy.emergencyState(requestedAt: nil, now: requestedAt), .notRequested)
        XCTAssertEqual(DailyOpenLimitPolicy.emergencyState(requestedAt: requestedAt, now: requestedAt), .waiting(remainingSeconds: 30))
        XCTAssertEqual(
            DailyOpenLimitPolicy.emergencyState(requestedAt: requestedAt, now: requestedAt.addingTimeInterval(10.2)),
            .waiting(remainingSeconds: 20)
        )
        XCTAssertEqual(DailyOpenLimitPolicy.emergencyState(requestedAt: requestedAt, now: requestedAt.addingTimeInterval(30)), .ready)
        XCTAssertEqual(DailyOpenLimitPolicy.emergencyState(requestedAt: requestedAt, now: requestedAt.addingTimeInterval(330)), .ready)
        XCTAssertEqual(DailyOpenLimitPolicy.emergencyState(requestedAt: requestedAt, now: requestedAt.addingTimeInterval(331)), .notRequested)
    }

    /// 時計が戻ったときは待ちを信用しない。
    func testEmergencyWaitIsNotTrustedWhenTheClockMovesBack() {
        let requestedAt = tokyo(2026, 10, 5, 20, 0)
        XCTAssertEqual(
            DailyOpenLimitPolicy.emergencyState(requestedAt: requestedAt, now: requestedAt.addingTimeInterval(-60)),
            .notRequested
        )
    }

    // MARK: - 補助

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func tokyo(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func apply(_ limit: Int?, to settings: DailyOpenLimitSettings, now: Date) -> DailyOpenLimitSettings {
        DailyOpenLimitPolicy.applying(limit: limit, to: settings, now: now, boundaryMinutes: wake, calendar: calendar)
    }
}
