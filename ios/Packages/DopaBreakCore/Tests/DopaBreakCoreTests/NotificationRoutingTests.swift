import Foundation
import XCTest
@testable import DopaBreakCore

final class NotificationRoutingTests: XCTestCase {
    func testFreeMonthlyIdentifiersAreStable() {
        XCTAssertEqual(
            NotificationIdentifier.freeMonthlyReports,
            [
                "dopabreak.freeMonthly1",
                "dopabreak.freeMonthly2",
                "dopabreak.freeMonthly3"
            ]
        )
    }

    func testReportNotificationsLandOnStats() {
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.morning),
            .stats
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.weekly),
            .stats
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.month1Report),
            .stats
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.freeMonthly1),
            .stats
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.freeMonthly2),
            .stats
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.freeMonthly3),
            .stats
        )
    }

    func testPlanNotificationsLandOnPlanSettings() {
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.trialDay5),
            .planSettings
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.month12Renewal),
            .planSettings
        )
        XCTAssertEqual(
            NotificationRouting.destination(
                forIdentifier: NotificationIdentifier.annualUpgradeOffer
            ),
            .planSettings
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.cancelSave),
            .planSettings
        )
    }

    func testActivationNotificationsLandOnAutomationGuide() {
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.d1Activation),
            .automationGuide
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.d3Activation),
            .automationGuide
        )
        XCTAssertEqual(
            NotificationRouting.destination(forIdentifier: NotificationIdentifier.d7Inactive),
            .automationGuide
        )
    }

    func testLegacyTimedInterventionAndUnknownIdentifiersHaveNoDestination() {
        XCTAssertEqual(
            NotificationIdentifier.legacyPrefixes,
            ["dopabreak.timeup.", "dopabreak.midsession.", "dopabreak.usagewatch."]
        )
        XCTAssertNil(
            NotificationRouting.destination(
                forIdentifier: "dopabreak.midsession.instagram.\(UUID().uuidString)"
            )
        )
        XCTAssertNil(
            NotificationRouting.destination(
                forIdentifier: "dopabreak.timeup.\(UUID().uuidString)"
            )
        )
        XCTAssertNil(
            NotificationRouting.destination(
                forIdentifier: "dopabreak.usagewatch.\(UUID().uuidString)"
            )
        )
        XCTAssertNil(NotificationRouting.destination(forIdentifier: "dopabreak.day14warning"))
        XCTAssertNil(NotificationRouting.destination(forIdentifier: ""))
    }

    func testDestinationRawValuesSurviveUserDefaultsRoundTrip() {
        for destination in NotificationDestination.allCases {
            XCTAssertEqual(
                NotificationDestination(rawValue: destination.rawValue),
                destination
            )
        }
        // Batch 2 が保存していた値との互換を保つ。
        XCTAssertEqual(NotificationDestination(rawValue: "stats"), .stats)
    }
}
