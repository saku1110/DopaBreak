import Foundation
import XCTest
@testable import DopaBreakCore

final class AutomationRequestPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testMissingOrOlderThanTwentySecondsIsStale() {
        XCTAssertEqual(decision(requestedAt: nil), .discardStale)
        XCTAssertEqual(
            decision(requestedAt: now.addingTimeInterval(-20.001)),
            .discardStale
        )
    }

    func testExactlyTwentySecondsOldIsConsumed() {
        XCTAssertEqual(
            decision(requestedAt: now.addingTimeInterval(-20)),
            .consume
        )
    }

    func testSameCatalogWithinEightSecondsOfRequestIsSelfOpen() {
        XCTAssertEqual(
            decision(
                requestedAt: now.addingTimeInterval(-1),
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: now.addingTimeInterval(-8.999)
            ),
            .discardSelfOpen
        )
    }

    func testSameCatalogAtEightSecondsBeforeRequestIsConsumed() {
        XCTAssertEqual(
            decision(
                requestedAt: now.addingTimeInterval(-1),
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: now.addingTimeInterval(-9)
            ),
            .consume
        )
    }

    func testNormalAutomationRequestIsConsumed() {
        let requestedAt = now.addingTimeInterval(-1)

        XCTAssertEqual(decision(requestedAt: requestedAt), .consume)
    }

    func testSelfOpenEchoDiscardedWhenAppImmediatelyBecomesActive() {
        let selfOpenedAt = now.addingTimeInterval(-1)
        let requestedAt = selfOpenedAt.addingTimeInterval(0.5)

        XCTAssertEqual(
            decision(
                requestedAt: requestedAt,
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: selfOpenedAt
            ),
            .discardSelfOpen
        )
    }

    func testSelfOpenEchoIsNeverConsumedWhenUserOpensAppLater() {
        let selfOpenedAt = now.addingTimeInterval(-40)
        let requestedAt = selfOpenedAt.addingTimeInterval(0.5)

        XCTAssertEqual(
            decision(
                requestedAt: requestedAt,
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: selfOpenedAt
            ),
            .discardStale
        )
    }

    func testRequestMoreThanEightSecondsAfterSelfOpenIsConsumed() {
        let selfOpenedAt = now.addingTimeInterval(-31)
        let requestedAt = selfOpenedAt.addingTimeInterval(30)

        XCTAssertEqual(
            decision(
                requestedAt: requestedAt,
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: selfOpenedAt
            ),
            .consume
        )
    }

    func testThirtySecondOldRequestIsStale() {
        XCTAssertEqual(
            decision(requestedAt: now.addingTimeInterval(-30)),
            .discardStale
        )
    }

    func testRequestCreatedBeforeSelfOpenIsNotSelfOpenEcho() {
        XCTAssertEqual(
            decision(
                requestedAt: now.addingTimeInterval(-1),
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: now.addingTimeInterval(-0.5)
            ),
            .consume
        )
    }

    func testDifferentCatalogIsConsumedWithinSelfOpenWindow() {
        XCTAssertEqual(
            decision(
                requestedCatalogID: "youtube",
                requestedAt: now,
                lastSelfOpenedCatalogID: "instagram",
                lastSelfOpenedAt: now.addingTimeInterval(-1)
            ),
            .consume
        )
    }

    private func decision(
        requestedCatalogID: String = "instagram",
        requestedAt: Date?,
        lastSelfOpenedCatalogID: String? = nil,
        lastSelfOpenedAt: Date? = nil
    ) -> AutomationRequestDecision {
        AutomationRequestPolicy.decision(
            requestedCatalogID: requestedCatalogID,
            requestedAt: requestedAt,
            now: now,
            lastSelfOpenedCatalogID: lastSelfOpenedCatalogID,
            lastSelfOpenedAt: lastSelfOpenedAt
        )
    }
}
