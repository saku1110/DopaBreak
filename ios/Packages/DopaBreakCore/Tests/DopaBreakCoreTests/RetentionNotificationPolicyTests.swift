import Foundation
import XCTest
@testable import DopaBreakCore

final class RetentionNotificationPolicyTests: XCTestCase {
    func testAnnualIntroductoryOfferIsTheOnlyTrialSignal() {
        let purchaseDate = date(year: 2026, month: 7, day: 1)

        XCTAssertTrue(
            SubscriptionEntitlementSnapshot(
                productID: ProProductID.annual.rawValue,
                purchaseDate: purchaseDate,
                offerType: .introductory
            ).isAnnualIntroductoryTrial
        )
        XCTAssertFalse(
            SubscriptionEntitlementSnapshot(
                productID: ProProductID.annual.rawValue,
                purchaseDate: purchaseDate,
                offerType: nil
            ).isAnnualIntroductoryTrial
        )
        XCTAssertFalse(
            SubscriptionEntitlementSnapshot(
                productID: ProProductID.monthly.rawValue,
                purchaseDate: purchaseDate,
                offerType: .introductory
            ).isAnnualIntroductoryTrial
        )
    }

    func testRetentionNotificationDatesUseCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let purchaseDate = date(year: 2026, month: 7, day: 1, hour: 9)

        XCTAssertEqual(
            RetentionNotificationDateCalculator.month12Date(
                from: purchaseDate,
                calendar: calendar
            ),
            date(year: 2027, month: 6, day: 24, hour: 9)
        )
    }

    func testInitialPurchaseDatePrefersOriginalPurchaseDate() {
        let originalDate = date(year: 2026, month: 6, day: 1)
        let renewalDate = date(year: 2027, month: 6, day: 1)
        let snapshot = SubscriptionEntitlementSnapshot(
            productID: ProProductID.annual.rawValue,
            purchaseDate: renewalDate,
            originalPurchaseDate: originalDate,
            offerType: nil
        )

        XCTAssertEqual(snapshot.initialPurchaseDate, originalDate)
    }

    func testNextMonthlyReportUsesFirstFutureCalendarAnniversary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let purchaseDate = date(year: 2026, month: 1, day: 15, hour: 10)

        XCTAssertEqual(
            RetentionNotificationDateCalculator.nextMonthlyReportDate(
                from: purchaseDate,
                now: date(year: 2026, month: 2, day: 14, hour: 10),
                calendar: calendar
            ),
            date(year: 2026, month: 2, day: 15, hour: 10)
        )
        XCTAssertEqual(
            RetentionNotificationDateCalculator.nextMonthlyReportDate(
                from: purchaseDate,
                now: date(year: 2026, month: 2, day: 15, hour: 10),
                calendar: calendar
            ),
            date(year: 2026, month: 3, day: 15, hour: 10)
        )
    }

    func testNextMonthlyReportSkipsPastAnniversaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertEqual(
            RetentionNotificationDateCalculator.nextMonthlyReportDate(
                from: date(year: 2026, month: 1, day: 15, hour: 10),
                now: date(year: 2026, month: 4, day: 20, hour: 10),
                calendar: calendar
            ),
            date(year: 2026, month: 5, day: 15, hour: 10)
        )
    }

    func testNextMonthlyReportClampsToMonthEndFromOriginalPurchaseDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let purchaseDate = date(year: 2027, month: 1, day: 31, hour: 10)

        XCTAssertEqual(
            RetentionNotificationDateCalculator.nextMonthlyReportDate(
                from: purchaseDate,
                now: purchaseDate,
                calendar: calendar
            ),
            date(year: 2027, month: 2, day: 28, hour: 10)
        )
        XCTAssertEqual(
            RetentionNotificationDateCalculator.nextMonthlyReportDate(
                from: purchaseDate,
                now: date(year: 2027, month: 2, day: 28, hour: 10),
                calendar: calendar
            ),
            date(year: 2027, month: 3, day: 31, hour: 10)
        )
    }

    func testNextMonthlyReportKeepsAnniversaryWhoseQuietHoursFireDateIsStillFuture() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let purchaseDate = date(year: 2026, month: 1, day: 15, hour: 23, minute: 30)
        let deferredFireDate = date(year: 2026, month: 2, day: 16, hour: 9)

        let anniversary = RetentionNotificationDateCalculator.nextMonthlyReportDate(
            from: purchaseDate,
            now: date(year: 2026, month: 2, day: 16, hour: 8, minute: 10),
            calendar: calendar
        )

        XCTAssertEqual(anniversary, date(year: 2026, month: 2, day: 15, hour: 23, minute: 30))
        XCTAssertEqual(
            anniversary.map {
                NotificationQuietHours.adjustedFireDate($0, calendar: calendar)
            },
            deferredFireDate
        )
    }

    func testWeeklyPaywallRequiresResolvedFreeUserAndFirstWeekHasPassed() {
        let onboardingDate = date(year: 2026, month: 7, day: 1)
        let firstEligibleDate = onboardingDate.addingTimeInterval(WeeklyPaywallPolicy.interval)

        XCTAssertFalse(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: false,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: nil,
                lastAnyPaywallShownAt: nil,
                now: firstEligibleDate
            )
        )
        XCTAssertFalse(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: true,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: nil,
                lastAnyPaywallShownAt: nil,
                now: firstEligibleDate.addingTimeInterval(-1)
            )
        )
        XCTAssertTrue(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: true,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: nil,
                lastAnyPaywallShownAt: nil,
                now: firstEligibleDate
            )
        )
    }

    func testWeeklyPaywallWaitsSevenDaysAfterLastPresentation() {
        let onboardingDate = date(year: 2026, month: 7, day: 1)
        let lastShownAt = date(year: 2026, month: 7, day: 10)

        XCTAssertFalse(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: true,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: lastShownAt,
                lastAnyPaywallShownAt: nil,
                now: lastShownAt.addingTimeInterval(WeeklyPaywallPolicy.interval - 1)
            )
        )
        XCTAssertTrue(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: true,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: lastShownAt,
                lastAnyPaywallShownAt: nil,
                now: lastShownAt.addingTimeInterval(WeeklyPaywallPolicy.interval)
            )
        )
    }

    func testWeeklyPaywallWaits24HoursAfterAnyPaywallPresentation() {
        let onboardingDate = date(year: 2026, month: 7, day: 1)
        let anyPaywallShownAt = date(year: 2026, month: 7, day: 10)
        let eligibleDate = anyPaywallShownAt.addingTimeInterval(WeeklyPaywallPolicy.anyPaywallCooldown)

        XCTAssertFalse(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: true,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: nil,
                lastAnyPaywallShownAt: anyPaywallShownAt,
                now: eligibleDate.addingTimeInterval(-1)
            )
        )
        XCTAssertTrue(
            WeeklyPaywallPolicy.shouldPresent(
                isPro: false,
                hasResolvedEntitlement: true,
                onboardingCompleted: true,
                onboardingCompletedAt: onboardingDate,
                lastShownAt: nil,
                lastAnyPaywallShownAt: anyPaywallShownAt,
                now: eligibleDate
            )
        )
    }

    func testRenewalNotificationsRequireKnownAutoRenewal() {
        XCTAssertTrue(
            RetentionNotificationPolicy.shouldScheduleRenewalNotification(willAutoRenew: true)
        )
        XCTAssertFalse(
            RetentionNotificationPolicy.shouldScheduleRenewalNotification(willAutoRenew: false)
        )
        XCTAssertFalse(
            RetentionNotificationPolicy.shouldScheduleRenewalNotification(willAutoRenew: nil)
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
