import XCTest
@testable import DopaBreakCore

final class SNSAppCatalogTests: XCTestCase {
    func testCatalogMatchesApprovedMVPOrder() {
        XCTAssertEqual(
            SNSAppCatalog.all.map(\.catalogID),
            ["instagram", "x", "tiktok", "youtube", "facebook", "threads", "line", "safari"]
        )
    }

    func testLookupReturnsDisplayNameAndURLScheme() throws {
        let instagram = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        XCTAssertEqual(instagram.displayName, "Instagram")
        XCTAssertEqual(instagram.urlScheme, "instagram://app")
        XCTAssertEqual(instagram.automationBundleID, "com.burbn.instagram")

        let safari = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
        XCTAssertEqual(safari.displayName, "Safari")
        XCTAssertNil(safari.urlScheme)
        XCTAssertEqual(safari.automationBundleID, "com.apple.mobilesafari")
    }

    func testUnknownLookupReturnsNil() {
        XCTAssertNil(SNSAppCatalog.app(catalogID: "unknown"))
        XCTAssertFalse(SNSAppCatalog.contains(catalogID: "unknown"))
    }
}
