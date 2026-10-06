import Foundation
import XCTest
@testable import DopaBreakCore

final class ReflectionNotificationPolicyTests: XCTestCase {
    func testReturnsPromptedAtDuringQuietHours() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 60 * 60))
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23))
        )
        let promptedAt = now.addingTimeInterval(10 * 60)

        XCTAssertEqual(
            ReflectionNotificationPolicy.fireDate(
                promptedAt: promptedAt,
                now: now,
                isEnabled: true
            ),
            promptedAt
        )
    }

    func testDisabledReturnsNil() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(
            ReflectionNotificationPolicy.fireDate(
                promptedAt: now.addingTimeInterval(60),
                now: now,
                isEnabled: false
            )
        )
    }

    func testPromptedAtNowOrPastReturnsNil() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(
            ReflectionNotificationPolicy.fireDate(
                promptedAt: now,
                now: now,
                isEnabled: true
            )
        )
        XCTAssertNil(
            ReflectionNotificationPolicy.fireDate(
                promptedAt: now.addingTimeInterval(-1),
                now: now,
                isEnabled: true
            )
        )
    }
}
