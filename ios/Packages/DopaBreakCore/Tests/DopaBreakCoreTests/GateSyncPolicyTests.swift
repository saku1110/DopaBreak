import XCTest
@testable import DopaBreakCore

final class GateSyncPolicyTests: XCTestCase {
    func testPreservesEveryUnconfirmedState() {
        for gateAllowed in [true, false] {
            for hasTokens in [true, false] {
                XCTAssertEqual(
                    GateSyncPolicy.action(
                        gateAllowed: gateAllowed,
                        hasConfirmedEntitlement: false,
                        hasTokensToShield: hasTokens
                    ),
                    .preserve
                )
            }
        }
    }

    func testConfirmedFreeAlwaysClears() {
        for hasTokens in [true, false] {
            XCTAssertEqual(
                GateSyncPolicy.action(
                    gateAllowed: false,
                    hasConfirmedEntitlement: true,
                    hasTokensToShield: hasTokens
                ),
                .clear
            )
        }
    }

    func testConfirmedProAppliesWhenTokensRemain() {
        XCTAssertEqual(
            GateSyncPolicy.action(
                gateAllowed: true,
                hasConfirmedEntitlement: true,
                hasTokensToShield: true
            ),
            .apply
        )
    }

    func testConfirmedProClearsWhenNoTokensRemain() {
        XCTAssertEqual(
            GateSyncPolicy.action(
                gateAllowed: true,
                hasConfirmedEntitlement: true,
                hasTokensToShield: false
            ),
            .clear
        )
    }

    func testProviderFailurePreservesForConfirmedPro() {
        XCTAssertEqual(
            GateSyncPolicy.action(
                tokensProvider: { throw TestError.readFailed },
                gateAllowed: true,
                hasConfirmedEntitlement: true
            ),
            .preserve
        )
    }

    /// Free確定時は対象ファイルを読めなくても解除し、provider自体を呼ばない。
    func testProviderIsSkippedForConfirmedFree() {
        var providerWasCalled = false

        let action = GateSyncPolicy.action(
            tokensProvider: {
                providerWasCalled = true
                throw TestError.readFailed
            },
            gateAllowed: false,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
        XCTAssertFalse(providerWasCalled)
    }

    func testProviderIsSkippedWhenEntitlementIsUnconfirmed() {
        var providerWasCalled = false

        let action = GateSyncPolicy.action(
            tokensProvider: {
                providerWasCalled = true
                return true
            },
            gateAllowed: true,
            hasConfirmedEntitlement: false
        )

        XCTAssertEqual(action, .preserve)
        XCTAssertFalse(providerWasCalled)
    }

    private enum TestError: Error {
        case readFailed
    }
}
