import Foundation
import XCTest
@testable import DopaBreakCore

final class ReviewPromptPolicyTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSecondCancellationIsEligibleButFirstIsNot() {
        XCTAssertTrue(shouldRequest(totalCancelledAllTime: 2))
        XCTAssertFalse(shouldRequest(totalCancelledAllTime: 1))
    }

    func testSameDayIsEligibleButFutureFirstLaunchIsNot() {
        XCTAssertTrue(
            shouldRequest(firstLaunchDate: now)
        )
        XCTAssertFalse(
            shouldRequest(firstLaunchDate: now.addingTimeInterval(1))
        )
    }

    func testThirdCancellationAfterPromptIsBlockedByCooldown() {
        XCTAssertTrue(shouldRequest(totalCancelledAllTime: 2, firstLaunchDate: now))
        XCTAssertFalse(shouldRequest(totalCancelledAllTime: 3, firstLaunchDate: now, pastEventDates: [now]))
    }

    func testEventAtNinetyDayBoundaryIsEligibleButNewerEventIsNot() {
        XCTAssertTrue(
            shouldRequest(pastEventDates: [now.addingTimeInterval(-90 * day)])
        )
        XCTAssertFalse(
            shouldRequest(pastEventDates: [now.addingTimeInterval((-90 * day) + 1)])
        )
    }

    func testThirdEventWithinThreeHundredSixtyFiveDaysBlocksRequest() {
        let twoEvents = [100.0, 200.0].map { now.addingTimeInterval(-$0 * day) }
        let threeEvents = twoEvents + [now.addingTimeInterval(-300 * day)]

        XCTAssertTrue(shouldRequest(pastEventDates: twoEvents))
        XCTAssertFalse(shouldRequest(pastEventDates: threeEvents))
    }

    func testBlockedSessionIsNeverEligible() {
        XCTAssertFalse(shouldRequest(sessionBlocked: true))
    }

    func testPruningDropsOnlyEventsOlderThanThreeHundredSixtyFiveDays() {
        let tooOld = now.addingTimeInterval(-366 * day)
        let boundary = now.addingTimeInterval(-365 * day)
        let recent = now.addingTimeInterval(-10 * day)

        XCTAssertEqual(
            ReviewPromptPolicy.prunedEventDates(
                [tooOld, boundary, recent],
                now: now
            ),
            [boundary, recent]
        )
    }

    private func shouldRequest(
        totalCancelledAllTime: Int = 5,
        firstLaunchDate: Date? = nil,
        pastEventDates: [Date] = [],
        sessionBlocked: Bool = false
    ) -> Bool {
        ReviewPromptPolicy.shouldRequest(
            totalCancelledAllTime: totalCancelledAllTime,
            firstLaunchDate: firstLaunchDate ?? now.addingTimeInterval(-3 * day),
            now: now,
            pastEventDates: pastEventDates,
            sessionBlocked: sessionBlocked
        )
    }
}
