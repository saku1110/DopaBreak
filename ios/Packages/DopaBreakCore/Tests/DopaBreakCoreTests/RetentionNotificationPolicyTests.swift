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
            RetentionNotificationDateCalculator.trialDay5Date(
                from: purchaseDate,
                calendar: calendar
            ),
            date(year: 2026, month: 7, day: 6, hour: 9)
        )
        XCTAssertEqual(
            RetentionNotificationDateCalculator.month1Date(
                from: purchaseDate,
                calendar: calendar
            ),
            date(year: 2026, month: 7, day: 31, hour: 9)
        )
        XCTAssertEqual(
            RetentionNotificationDateCalculator.month12Date(
                from: purchaseDate,
                calendar: calendar
            ),
            date(year: 2027, month: 6, day: 24, hour: 9)
        )
    }

    func testInitialPurchaseDateIsPreferredForMonth1() {
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
        hour: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}
