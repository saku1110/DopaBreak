import XCTest

@testable import DopaBreak

final class HomeStatsLinkDestinationTests: XCTestCase {
    func testWeeklyReportAccessRoutesToStatsTab() {
        XCTAssertEqual(
            HomeStatsLinkDestination(weeklyReportAllowed: true),
            .statsTab
        )
    }

    func testMissingWeeklyReportAccessRoutesToStatsHistoryGate() {
        XCTAssertEqual(
            HomeStatsLinkDestination(weeklyReportAllowed: false),
            .statsHistoryGate
        )
    }
}
