import Foundation
import XCTest
@testable import DopaBreakCore

final class NotificationQuietHoursTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    func testTwentyOneHundredEdgeIsUnchanged() {
        let candidate = date(year: 2026, month: 8, day: 11, hour: 21)

        XCTAssertEqual(
            NotificationQuietHours.adjustedFireDate(candidate, calendar: calendar),
            candidate
        )
    }

    func testEightFiftyNineDefersToSameDayAtNine() {
        XCTAssertEqual(
            NotificationQuietHours.adjustedFireDate(
                date(year: 2026, month: 8, day: 11, hour: 8, minute: 59),
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 11, hour: 9)
        )
    }

    func testThreeInTheMorningDefersToSameDayAtNine() {
        XCTAssertEqual(
            NotificationQuietHours.adjustedFireDate(
                date(year: 2026, month: 8, day: 11, hour: 3),
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 11, hour: 9)
        )
    }

    func testTwentyThreeThirtyDefersToNextDayAtNine() {
        XCTAssertEqual(
            NotificationQuietHours.adjustedFireDate(
                date(year: 2026, month: 8, day: 11, hour: 23, minute: 30),
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 12, hour: 9)
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
