import Foundation
import XCTest
@testable import DopaBreakCore

final class FreeMonthlyReportNotificationPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testFreeUserReceivesThreeUpcomingReportsWithCountsOnlyOnTheFirst() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2026, month: 1, day: 15, hour: 10),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 7,
            attemptCount: 11,
            now: date(year: 2026, month: 2, day: 10, hour: 12),
            calendar: calendar
        )

        XCTAssertEqual(
            schedules.map(\.fireDate),
            [
                date(year: 2026, month: 2, day: 15, hour: 10),
                date(year: 2026, month: 3, day: 15, hour: 10),
                date(year: 2026, month: 4, day: 15, hour: 10)
            ]
        )
        XCTAssertEqual(
            schedules.map(\.body),
            [
                .counts(cancelled: 7, attempts: 11),
                .fixed,
                .fixed
            ]
        )
    }

    func testZeroAttemptsUsesFixedBodyForEveryReport() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2026, month: 1, day: 15, hour: 10),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 0,
            attemptCount: 0,
            now: date(year: 2026, month: 2, day: 10, hour: 12),
            calendar: calendar
        )

        XCTAssertEqual(schedules.map(\.body), [.fixed, .fixed, .fixed])
    }

    func testAnniversaryAtNowSkipsTodayAndStartsNextMonth() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2026, month: 1, day: 15, hour: 10),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 2,
            attemptCount: 3,
            now: date(year: 2026, month: 2, day: 15, hour: 10),
            calendar: calendar
        )

        XCTAssertEqual(
            schedules.map(\.fireDate),
            [
                date(year: 2026, month: 3, day: 15, hour: 10),
                date(year: 2026, month: 4, day: 15, hour: 10),
                date(year: 2026, month: 5, day: 15, hour: 10)
            ]
        )
    }

    func testAnniversaryEarlierTodaySkipsToNextMonth() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2026, month: 1, day: 15, hour: 8),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 2,
            attemptCount: 3,
            now: date(year: 2026, month: 2, day: 15, hour: 9, minute: 1),
            calendar: calendar
        )

        XCTAssertEqual(
            schedules.map(\.fireDate),
            [
                date(year: 2026, month: 3, day: 15, hour: 9),
                date(year: 2026, month: 4, day: 15, hour: 9),
                date(year: 2026, month: 5, day: 15, hour: 9)
            ]
        )
    }

    func testQuietHoursDeferralCrossesMonthBoundary() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2026, month: 7, day: 31, hour: 22),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 2,
            attemptCount: 3,
            now: date(year: 2026, month: 7, day: 31, hour: 22),
            calendar: calendar
        )

        XCTAssertEqual(
            schedules.map(\.fireDate),
            [
                date(year: 2026, month: 9, day: 1, hour: 9),
                date(year: 2026, month: 10, day: 1, hour: 9),
                date(year: 2026, month: 11, day: 1, hour: 9)
            ]
        )
    }

    func testCalendarAnniversaryClampsEachMissingDayToMonthEnd() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2027, month: 1, day: 31, hour: 10),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 0,
            attemptCount: 0,
            now: date(year: 2027, month: 1, day: 31, hour: 12),
            calendar: calendar
        )

        XCTAssertEqual(
            schedules.map(\.fireDate),
            [
                date(year: 2027, month: 2, day: 28, hour: 10),
                date(year: 2027, month: 3, day: 31, hour: 10),
                date(year: 2027, month: 4, day: 30, hour: 10)
            ]
        )
    }

    func testQuietHoursDefersEveryLateNightAnniversaryToNextMorning() {
        let schedules = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: date(year: 2026, month: 1, day: 15, hour: 23, minute: 30),
            hasResolvedEntitlement: true,
            isPro: false,
            isEnabled: true,
            cancelledCount: 2,
            attemptCount: 3,
            now: date(year: 2026, month: 2, day: 16, hour: 8),
            calendar: calendar
        )

        XCTAssertEqual(
            schedules.map(\.fireDate),
            [
                date(year: 2026, month: 2, day: 16, hour: 9),
                date(year: 2026, month: 3, day: 16, hour: 9),
                date(year: 2026, month: 4, day: 16, hour: 9)
            ]
        )
    }

    func testUnresolvedEntitlementSuppressesReports() {
        XCTAssertTrue(
            schedules(
                firstLaunchDate: date(year: 2026, month: 1, day: 1),
                hasResolvedEntitlement: false,
                isPro: false,
                isEnabled: true
            ).isEmpty
        )
    }

    func testProOrTrialEntitlementSuppressesReports() {
        XCTAssertTrue(
            schedules(
                firstLaunchDate: date(year: 2026, month: 1, day: 1),
                hasResolvedEntitlement: true,
                isPro: true,
                isEnabled: true
            ).isEmpty
        )
    }

    func testRetentionSupportToggleOffSuppressesReports() {
        XCTAssertTrue(
            schedules(
                firstLaunchDate: date(year: 2026, month: 1, day: 1),
                hasResolvedEntitlement: true,
                isPro: false,
                isEnabled: false
            ).isEmpty
        )
    }

    func testMissingFirstLaunchDateSuppressesReports() {
        XCTAssertTrue(
            schedules(
                firstLaunchDate: nil,
                hasResolvedEntitlement: true,
                isPro: false,
                isEnabled: true
            ).isEmpty
        )
    }

    private func schedules(
        firstLaunchDate: Date?,
        hasResolvedEntitlement: Bool,
        isPro: Bool,
        isEnabled: Bool
    ) -> [FreeMonthlyReportNotificationSchedule] {
        FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: firstLaunchDate,
            hasResolvedEntitlement: hasResolvedEntitlement,
            isPro: isPro,
            isEnabled: isEnabled,
            cancelledCount: 0,
            attemptCount: 0,
            now: date(year: 2026, month: 2, day: 1),
            calendar: calendar
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
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
