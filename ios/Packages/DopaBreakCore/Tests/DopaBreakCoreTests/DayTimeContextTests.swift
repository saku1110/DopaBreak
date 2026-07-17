import Foundation
import XCTest
@testable import DopaBreakCore

final class DayTimeContextTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNoWakeOrBedTimeReturnsNormal() {
        XCTAssertEqual(resolve(nowMinutes: 0, wakeMinutes: nil, bedMinutes: nil), .normal)
        XCTAssertEqual(resolve(nowMinutes: 720, wakeMinutes: nil, bedMinutes: nil), .normal)
        XCTAssertEqual(resolve(nowMinutes: 1_439, wakeMinutes: nil, bedMinutes: nil), .normal)
    }

    func testWakeWindowIncludesStart() {
        XCTAssertEqual(resolve(nowMinutes: 420, wakeMinutes: 420, bedMinutes: nil), .wake)
    }

    func testWakeWindowExcludesOneMinuteBeforeStart() {
        XCTAssertEqual(resolve(nowMinutes: 419, wakeMinutes: 420, bedMinutes: nil), .normal)
    }

    func testWakeWindowExcludesEnd() {
        XCTAssertEqual(resolve(nowMinutes: 450, wakeMinutes: 420, bedMinutes: nil), .normal)
    }

    func testSleepWindowIncludesStart() {
        XCTAssertEqual(resolve(nowMinutes: 1_320, wakeMinutes: nil, bedMinutes: 1_380), .sleep)
    }

    func testSleepWindowExcludesEnd() {
        XCTAssertEqual(resolve(nowMinutes: 1_380, wakeMinutes: nil, bedMinutes: 1_380), .normal)
    }

    func testWakeWindowWrapsAcrossMidnight() {
        XCTAssertEqual(resolve(nowMinutes: 10, wakeMinutes: 1_430, bedMinutes: nil), .wake)
    }

    func testWakeWindowAtMidnightDoesNotIncludePreviousDay() {
        XCTAssertEqual(resolve(nowMinutes: 1_430, wakeMinutes: 0, bedMinutes: nil), .normal)
    }

    func testWakeWindowAtMidnightUsesThirtyMinuteHalfOpenRange() {
        XCTAssertEqual(resolve(nowMinutes: 29, wakeMinutes: 0, bedMinutes: nil), .wake)
        XCTAssertEqual(resolve(nowMinutes: 30, wakeMinutes: 0, bedMinutes: nil), .normal)
    }

    func testSleepWindowWrapsAcrossMidnight() {
        XCTAssertEqual(resolve(nowMinutes: 1_400, wakeMinutes: nil, bedMinutes: 20), .sleep)
        XCTAssertEqual(resolve(nowMinutes: 10, wakeMinutes: nil, bedMinutes: 20), .sleep)
    }

    func testWakeTakesPriorityWhenWakeAndSleepWindowsOverlap() {
        XCTAssertEqual(resolve(nowMinutes: 420, wakeMinutes: 420, bedMinutes: 450), .wake)
    }

    private func resolve(nowMinutes: Int, wakeMinutes: Int?, bedMinutes: Int?) -> DayTimeContext {
        DayTimeContext.resolve(
            now: date(minutes: nowMinutes),
            wakeMinutes: wakeMinutes,
            bedMinutes: bedMinutes,
            calendar: calendar
        )
    }

    private func date(minutes: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 9,
            hour: minutes / 60,
            minute: minutes % 60
        ).date!
    }
}
