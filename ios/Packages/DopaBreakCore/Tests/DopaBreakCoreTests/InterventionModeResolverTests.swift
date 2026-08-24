import XCTest
@testable import DopaBreakCore

final class InterventionModeResolverTests: XCTestCase {
    func testConfirmedFreeClampsShieldModesToStandard() {
        for mode in [InterventionMode.deepFocus, .nightOnly] {
            XCTAssertEqual(
                InterventionModeResolver.resolve(
                    mode,
                    hasConfirmedEntitlement: true,
                    strictModeAllowed: false
                ),
                .standard
            )
        }
    }

    func testUnconfirmedEntitlementPreservesTheStoredMode() {
        XCTAssertEqual(
            InterventionModeResolver.resolve(
                .deepFocus,
                hasConfirmedEntitlement: false,
                strictModeAllowed: false
            ),
            .deepFocus
        )
    }

    func testAllowedOrStandardModesPassThrough() {
        XCTAssertEqual(
            InterventionModeResolver.resolve(
                .nightOnly,
                hasConfirmedEntitlement: true,
                strictModeAllowed: true
            ),
            .nightOnly
        )
        XCTAssertEqual(
            InterventionModeResolver.resolve(
                .standard,
                hasConfirmedEntitlement: true,
                strictModeAllowed: false
            ),
            .standard
        )
    }
}
