import XCTest
@testable import DopaBreakCore

final class TargetRemovalNoticePolicyTests: XCTestCase {
    func testVerifiedAutomationNotifiesAfterRemoval() {
        XCTAssertTrue(
            TargetRemovalNoticePolicy.shouldNotify(
                removedCatalogID: "instagram",
                verifiedAutomationCatalogIDs: ["youtube", "instagram"]
            )
        )
    }

    func testUnverifiedAutomationDoesNotNotify() {
        XCTAssertFalse(
            TargetRemovalNoticePolicy.shouldNotify(
                removedCatalogID: "instagram",
                verifiedAutomationCatalogIDs: ["youtube"]
            )
        )
    }

    func testUnknownCatalogIDDoesNotNotify() {
        XCTAssertFalse(
            TargetRemovalNoticePolicy.shouldNotify(
                removedCatalogID: "unknown-app",
                verifiedAutomationCatalogIDs: ["unknown-app"]
            )
        )
    }

    func testEmptyVerifiedListDoesNotNotify() {
        XCTAssertFalse(
            TargetRemovalNoticePolicy.shouldNotify(
                removedCatalogID: "instagram",
                verifiedAutomationCatalogIDs: []
            )
        )
    }
}
