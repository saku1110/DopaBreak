import XCTest
@testable import DopaBreakCore

final class ReverseTrialPolicyTests: XCTestCase {
    func testStartsImmediatelyWithThreeDaysRemaining() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(ReverseTrialPolicy.isActive(startedAt: now, now: now))
        XCTAssertEqual(ReverseTrialPolicy.remainingDays(startedAt: now, now: now), 3)
    }

    func testRoundsRemainingDaysUpJustBeforeExpiry() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let justBeforeEnd = ReverseTrialPolicy.endDate(startedAt: startedAt)
            .addingTimeInterval(-1)

        XCTAssertTrue(ReverseTrialPolicy.isActive(startedAt: startedAt, now: justBeforeEnd))
        XCTAssertEqual(ReverseTrialPolicy.remainingDays(startedAt: startedAt, now: justBeforeEnd), 1)
    }

    func testExpiresExactlyAtTheEndBoundary() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let end = ReverseTrialPolicy.endDate(startedAt: startedAt)

        XCTAssertFalse(ReverseTrialPolicy.isActive(startedAt: startedAt, now: end))
        XCTAssertNil(ReverseTrialPolicy.remainingDays(startedAt: startedAt, now: end))
        XCTAssertTrue(
            ReverseTrialPolicy.shouldPresentEndPaywall(
                startedAt: startedAt,
                isPro: false,
                endPaywallShown: false,
                now: end
            )
        )
    }

    func testRemainsExpiredAfterTheEndBoundary() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let afterEnd = ReverseTrialPolicy.endDate(startedAt: startedAt).addingTimeInterval(1)

        XCTAssertFalse(ReverseTrialPolicy.isActive(startedAt: startedAt, now: afterEnd))
        XCTAssertNil(ReverseTrialPolicy.remainingDays(startedAt: startedAt, now: afterEnd))
    }

    func testMissingStartDoesNotBecomeActiveOrPresentPaywall() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertFalse(ReverseTrialPolicy.isActive(startedAt: nil, now: now))
        XCTAssertNil(ReverseTrialPolicy.remainingDays(startedAt: nil, now: now))
        XCTAssertFalse(
            ReverseTrialPolicy.shouldPresentEndPaywall(
                startedAt: nil,
                isPro: false,
                endPaywallShown: false,
                now: now
            )
        )
    }

    func testEndPaywallDoesNotPresentForPurchasedOrAlreadyShownUser() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let now = ReverseTrialPolicy.endDate(startedAt: startedAt)

        XCTAssertFalse(
            ReverseTrialPolicy.shouldPresentEndPaywall(
                startedAt: startedAt,
                isPro: true,
                endPaywallShown: false,
                now: now
            )
        )
        XCTAssertFalse(
            ReverseTrialPolicy.shouldPresentEndPaywall(
                startedAt: startedAt,
                isPro: false,
                endPaywallShown: true,
                now: now
            )
        )
    }
}
