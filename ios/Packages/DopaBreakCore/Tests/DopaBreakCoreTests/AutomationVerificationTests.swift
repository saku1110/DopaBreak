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

    func testProgressCountsOnlyVerifiedSelectedTargets() {
        XCTAssertEqual(
            AutomationVerification.progress(
                selectedCatalogIDs: ["instagram", "youtube", "safari"],
                verifiedCatalogIDs: ["instagram", "threads"]
            ),
            AutomationVerification.Progress(verifiedCount: 1, totalCount: 3)
        )
    }

    func testProgressDoesNotInflateDuplicatePersistedIDs() {
        XCTAssertEqual(
            AutomationVerification.progress(
                selectedCatalogIDs: ["instagram", "instagram", "youtube"],
                verifiedCatalogIDs: ["instagram", "instagram"]
            ),
            AutomationVerification.Progress(verifiedCount: 1, totalCount: 2)
        )
    }

    func testProgressWithNoSelectedTargetsIsZeroOfZero() {
        XCTAssertEqual(
            AutomationVerification.progress(
                selectedCatalogIDs: [],
                verifiedCatalogIDs: ["instagram"]
            ),
            AutomationVerification.Progress(verifiedCount: 0, totalCount: 0)
        )
    }
}
