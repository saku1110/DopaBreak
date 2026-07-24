import XCTest
@testable import DopaBreakCore

final class AutomationVerificationTests: XCTestCase {
    func testNoSelectedTargetsHasNoUnverifiedTargets() {
        XCTAssertEqual(
            AutomationVerification.unverifiedCatalogIDs(
                selectedCatalogIDs: [],
                verifiedCatalogIDs: []
            ),
            []
        )
    }

    func testPartiallyVerifiedTargetsReturnOnlyUnverifiedTargets() {
        XCTAssertEqual(
            AutomationVerification.unverifiedCatalogIDs(
                selectedCatalogIDs: ["instagram", "youtube", "safari"],
                verifiedCatalogIDs: ["instagram"]
            ),
            ["youtube", "safari"]
        )
    }

    func testAllSelectedTargetsVerifiedHasNoUnverifiedTargets() {
        XCTAssertEqual(
            AutomationVerification.unverifiedCatalogIDs(
                selectedCatalogIDs: ["instagram", "youtube"],
                verifiedCatalogIDs: ["youtube", "instagram"]
            ),
            []
        )
    }
}
