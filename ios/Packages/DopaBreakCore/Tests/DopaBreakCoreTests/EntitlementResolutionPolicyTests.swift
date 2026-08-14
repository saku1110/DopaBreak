import XCTest
@testable import DopaBreakCore

final class EntitlementResolutionPolicyTests: XCTestCase {
    func testVerifiedEntitlementConfirmsProDespiteUnverifiedSiblingEvidence() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: false,
            evidence: evidence(
                currentEntitlements: .verifiedEntitlement,
                storeReachability: .unavailable,
                encounteredUnverifiedEntitlement: true
            )
        )

        XCTAssertTrue(resolution.isPro)
        XCTAssertTrue(resolution.hasConfirmedEntitlement)
    }

    func testEmptyEntitlementsWithAvailableProductsConfirmsFree() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: false,
            evidence: evidence(storeReachability: .productsAvailable)
        )

        XCTAssertFalse(resolution.isPro)
        XCTAssertTrue(resolution.hasConfirmedEntitlement)
    }

    func testEmptyProductResponseIsUnavailable() {
        XCTAssertEqual(
            EntitlementResolutionPolicy.storeReachability(loadedProductCount: 0),
            .unavailable
        )
    }

    func testNonemptyProductResponseIsAvailable() {
        XCTAssertEqual(
            EntitlementResolutionPolicy.storeReachability(loadedProductCount: 1),
            .productsAvailable
        )
    }

    func testAvailableProductsWithoutDowngradeCorroborationPreserveCachedPro() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: true,
            evidence: evidence(storeReachability: .productsAvailable)
        )

        XCTAssertTrue(resolution.isPro)
        XCTAssertFalse(resolution.hasConfirmedEntitlement)
    }

    func testAvailableProductsWithDowngradeCorroborationConfirmFree() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: true,
            evidence: evidence(
                storeReachability: .productsAvailable,
                proDowngradeConfirmation: .confirmedNoEntitlement
            )
        )

        XCTAssertFalse(resolution.isPro)
        XCTAssertTrue(resolution.hasConfirmedEntitlement)
    }

    func testUnverifiedEvidenceDoesNotConfirmFreeWithoutDowngradeCorroboration() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: true,
            evidence: evidence(
                storeReachability: .productsAvailable,
                encounteredUnverifiedEntitlement: true
            )
        )

        XCTAssertTrue(resolution.isPro)
        XCTAssertFalse(resolution.hasConfirmedEntitlement)
    }

    func testUnverifiedEvidenceDoesNotBlockCorroboratedCachedProDowngrade() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: true,
            evidence: evidence(
                storeReachability: .productsAvailable,
                encounteredUnverifiedEntitlement: true,
                proDowngradeConfirmation: .confirmedNoEntitlement
            )
        )

        XCTAssertFalse(resolution.isPro)
        XCTAssertTrue(resolution.hasConfirmedEntitlement)
    }

    func testUnverifiedEvidenceOnlyWithholdsConfirmationForExistingFreeState() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: false,
            evidence: evidence(
                storeReachability: .productsAvailable,
                encounteredUnverifiedEntitlement: true
            )
        )

        XCTAssertFalse(resolution.isPro)
        XCTAssertFalse(resolution.hasConfirmedEntitlement)
    }

    func testUnavailableStorePreservesCachedPro() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: true,
            evidence: evidence(storeReachability: .unavailable)
        )

        XCTAssertTrue(resolution.isPro)
        XCTAssertFalse(resolution.hasConfirmedEntitlement)
    }

    func testUnavailableStorePreservesCachedFree() {
        let resolution = EntitlementResolutionPolicy.resolve(
            previousIsPro: false,
            evidence: evidence(storeReachability: .unavailable)
        )

        XCTAssertFalse(resolution.isPro)
        XCTAssertFalse(resolution.hasConfirmedEntitlement)
    }

    private func evidence(
        currentEntitlements: EntitlementResolutionPolicy.CurrentEntitlementEvidence = .noVerifiedEntitlement,
        storeReachability: EntitlementResolutionPolicy.StoreReachabilityEvidence,
        encounteredUnverifiedEntitlement: Bool = false,
        proDowngradeConfirmation: EntitlementResolutionPolicy.ProDowngradeConfirmation = .notConfirmed
    ) -> EntitlementResolutionPolicy.Evidence {
        EntitlementResolutionPolicy.Evidence(
            currentEntitlements: currentEntitlements,
            storeReachability: storeReachability,
            encounteredUnverifiedEntitlement: encounteredUnverifiedEntitlement,
            proDowngradeConfirmation: proDowngradeConfirmation
        )
    }
}
