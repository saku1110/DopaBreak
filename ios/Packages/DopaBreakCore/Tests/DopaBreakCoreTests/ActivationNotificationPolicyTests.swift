import Foundation
import XCTest
@testable import DopaBreakCore

final class ActivationNotificationPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    // MARK: - D3（再挑戦・未検収ゲート）

    func testD3FiresSeventyTwoHoursAfterFirstLaunchWhileUnverified() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertEqual(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: [],
                now: firstLaunch,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 4, hour: 10)
        )
    }

    func testD3IsSuppressedOnceAutomationIsVerified() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertNil(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: ["instagram"],
                now: firstLaunch,
                calendar: calendar
            )
        )
    }

    func testD3RequiresRetentionSupportToggleAndFirstLaunchDate() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertNil(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: false,
                verifiedAutomationCatalogIDs: [],
                now: firstLaunch,
                calendar: calendar
            )
        )
        XCTAssertNil(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: nil,
                isEnabled: true,
                verifiedAutomationCatalogIDs: [],
                now: firstLaunch,
                calendar: calendar
            )
        )
    }

    func testD3DefersOutOfQuietHoursFireDateToNextMorning() {
        // 初回起動 23:30 → +72h も 23:30。送信可能窓（9:00-21:00）の外なので翌朝9:00へ繰り延べる。
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 23, minute: 30)

        XCTAssertEqual(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: [],
                now: firstLaunch,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 5, hour: 9)
        )
    }

    func testD3PullsEarlyMorningFireDateForwardToNineAM() {
        // 初回起動 4:00 → +72h は 4:00。同日9:00へ繰り延べる（前倒しはしない）。
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 4)

        XCTAssertEqual(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: [],
                now: firstLaunch,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 4, hour: 9)
        )
    }

    func testD3IsNotScheduledOnceItsFireDateHasPassed() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertNil(
            ActivationNotificationPolicy.d3FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: [],
                now: date(year: 2026, month: 8, day: 4, hour: 10),
                calendar: calendar
            )
        )
    }

    // MARK: - D7（未活性フォールバック・試行0件ゲート）

    func testD7FiresSevenDaysAfterFirstLaunchWhenNoAttemptsExist() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertEqual(
            ActivationNotificationPolicy.d7FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                totalInterventionAttempts: 0,
                now: firstLaunch,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 8, hour: 10)
        )
    }

    func testD7IsSuppressedAsSoonAsOneAttemptExists() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertNil(
            ActivationNotificationPolicy.d7FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                totalInterventionAttempts: 1,
                now: firstLaunch,
                calendar: calendar
            )
        )
    }

    func testD7RequiresRetentionSupportToggleAndFirstLaunchDate() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertNil(
            ActivationNotificationPolicy.d7FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: false,
                totalInterventionAttempts: 0,
                now: firstLaunch,
                calendar: calendar
            )
        )
        XCTAssertNil(
            ActivationNotificationPolicy.d7FireDate(
                firstLaunchDate: nil,
                isEnabled: true,
                totalInterventionAttempts: 0,
                now: firstLaunch,
                calendar: calendar
            )
        )
    }

    func testD7DefersOutOfQuietHoursFireDateToNextMorning() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 22)

        XCTAssertEqual(
            ActivationNotificationPolicy.d7FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                totalInterventionAttempts: 0,
                now: firstLaunch,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 9, hour: 9)
        )
    }

    func testD7IsNotScheduledOnceItsFireDateHasPassed() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertNil(
            ActivationNotificationPolicy.d7FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                totalInterventionAttempts: 0,
                now: date(year: 2026, month: 8, day: 8, hour: 10, minute: 1),
                calendar: calendar
            )
        )
    }

    // MARK: - D1（既存挙動の据え置き確認）

    func testD1KeepsTwentyFourHourOffsetAndUnverifiedGate() {
        let firstLaunch = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertEqual(
            ActivationNotificationPolicy.d1FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: [],
                now: firstLaunch,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 2, hour: 10)
        )
        XCTAssertNil(
            ActivationNotificationPolicy.d1FireDate(
                firstLaunchDate: firstLaunch,
                isEnabled: true,
                verifiedAutomationCatalogIDs: ["x"],
                now: firstLaunch,
                calendar: calendar
            )
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
