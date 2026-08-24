import XCTest
@testable import DopaBreakCore

final class EntitlementGateTests: XCTestCase {
    func testProductIDsMatchStoreKitCatalog() {
        XCTAssertEqual(ProProductID.monthly.rawValue, "dopabreak.pro.monthly")
        XCTAssertEqual(ProProductID.annual.rawValue, "dopabreak.pro.annual")
        XCTAssertEqual(ProProductID.annualLaunch.rawValue, "dopabreak.pro.annual.launch")
        XCTAssertEqual(ProProductID.lifetime.rawValue, "dopabreak.pro.lifetime")
        XCTAssertEqual(
            ProProductID.allIDs,
            [
                "dopabreak.pro.monthly",
                "dopabreak.pro.annual",
                "dopabreak.pro.annual.launch",
                "dopabreak.pro.lifetime"
            ]
        )
    }

    func testProductClassification() {
        XCTAssertEqual(ProProductID.allSubscriptionIDs, [
            "dopabreak.pro.monthly",
            "dopabreak.pro.annual",
            "dopabreak.pro.annual.launch"
        ])
        XCTAssertEqual(ProProductID.lifetimeID, "dopabreak.pro.lifetime")

        XCTAssertEqual(ProProductID.productKind(for: ProProductID.monthly.rawValue), .subscription)
        XCTAssertEqual(ProProductID.productKind(for: ProProductID.annual.rawValue), .subscription)
        XCTAssertEqual(ProProductID.productKind(for: ProProductID.annualLaunch.rawValue), .subscription)
        XCTAssertEqual(ProProductID.productKind(for: ProProductID.lifetime.rawValue), .nonConsumable)
        XCTAssertNil(ProProductID.productKind(for: "dopabreak.pro.unknown"))

        XCTAssertTrue(ProProductID.isSubscription(ProProductID.monthly.rawValue))
        XCTAssertTrue(ProProductID.isSubscription(ProProductID.annual.rawValue))
        XCTAssertTrue(ProProductID.isSubscription(ProProductID.annualLaunch.rawValue))
        XCTAssertFalse(ProProductID.isSubscription(ProProductID.lifetime.rawValue))
        XCTAssertFalse(ProProductID.isSubscription("dopabreak.pro.unknown"))

        XCTAssertTrue(ProProductID.isNonConsumable(ProProductID.lifetime.rawValue))
        XCTAssertFalse(ProProductID.isNonConsumable(ProProductID.monthly.rawValue))
        XCTAssertFalse(ProProductID.isNonConsumable("dopabreak.pro.unknown"))
    }

    func testInitFromIsProMapsTier() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        XCTAssertEqual(EntitlementGate(isPro: false, now: now).tier, .free)
        XCTAssertEqual(EntitlementGate(isPro: true, now: now).tier, .pro)
    }

    func testFreeGateValues() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.heroGoalAllowed)
        XCTAssertNil(gate.goalsLimit)
        XCTAssertEqual(gate.targetRulesLimit, 1)
        XCTAssertEqual(gate.targetAppTokensLimit, 1)
        XCTAssertEqual(gate.statsDays, 1)
        XCTAssertFalse(gate.weeklyReportAllowed)
        XCTAssertFalse(gate.strictModeAllowed)
        XCTAssertFalse(gate.gateAllowed)
        XCTAssertFalse(gate.themesAllowed)
    }

    func testProGateValues() {
        let gate = makeGate(tier: .pro)

        XCTAssertTrue(gate.heroGoalAllowed)
        XCTAssertNil(gate.goalsLimit)
        XCTAssertNil(gate.targetRulesLimit)
        XCTAssertNil(gate.targetAppTokensLimit)
        XCTAssertNil(gate.statsDays)
        XCTAssertTrue(gate.weeklyReportAllowed)
        XCTAssertTrue(gate.strictModeAllowed)
        XCTAssertTrue(gate.gateAllowed)
        XCTAssertTrue(gate.themesAllowed)
    }

    /// 目標はFreeでも無制限（2026-08-17オーナー決定）。Proとの差はない
    func testFreeGoalLimitBoundaries() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.canAddGoal(currentCount: 0))
        XCTAssertTrue(gate.canAddGoal(currentCount: 1))
        XCTAssertTrue(gate.canAddGoal(currentCount: 50))
    }

    func testProGoalLimitBoundaries() {
        let gate = makeGate(tier: .pro)

        XCTAssertTrue(gate.canAddGoal(currentCount: 0))
        XCTAssertTrue(gate.canAddGoal(currentCount: 1))
        XCTAssertTrue(gate.canAddGoal(currentCount: 50))
    }

    func testFreeRuleLimitBoundaries() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.canAddRule(currentCount: 0))
        XCTAssertFalse(gate.canAddRule(currentCount: 1))
        XCTAssertFalse(gate.canAddRule(currentCount: 2))
    }

    func testProRuleLimitBoundaries() {
        let gate = makeGate(tier: .pro)

        XCTAssertTrue(gate.canAddRule(currentCount: 0))
        XCTAssertTrue(gate.canAddRule(currentCount: 1))
        XCTAssertTrue(gate.canAddRule(currentCount: 50))
    }

    func testFreeTargetTokenLimitBoundaries() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.canAddTargetTokens(currentCount: 0))
        XCTAssertFalse(gate.canAddTargetTokens(currentCount: 1))
        XCTAssertFalse(gate.canAddTargetTokens(currentCount: 2))
    }

    func testProTargetTokenLimitBoundaries() {
        let gate = makeGate(tier: .pro)

        XCTAssertTrue(gate.canAddTargetTokens(currentCount: 0))
        XCTAssertTrue(gate.canAddTargetTokens(currentCount: 1))
        XCTAssertTrue(gate.canAddTargetTokens(currentCount: 50))
    }

    func testFreeTargetTokenLimitIsAlwaysOne() {
        let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)
        let dates = [
            referenceDate.addingTimeInterval(-86_400),
            referenceDate,
            referenceDate.addingTimeInterval(30 * 86_400)
        ]

        for now in dates {
            let gate = makeGate(tier: .free, now: now)
            XCTAssertEqual(gate.targetAppTokensLimit, 1)
            XCTAssertTrue(gate.canAddTargetTokens(currentCount: 0))
            XCTAssertFalse(gate.canAddTargetTokens(currentCount: 1))
        }
    }

    func testProTargetTokenLimitIsUnlimited() {
        let gate = makeGate(tier: .pro)

        XCTAssertNil(gate.targetAppTokensLimit)
        XCTAssertTrue(gate.canAddTargetTokens(currentCount: 50))
    }

    func testTargetAppClampKeepsLeadingItemsWhenOverLimit() {
        let gate = makeGate(tier: .free)

        XCTAssertEqual(
            gate.clampedTargetAppCatalogIDs(["youtube", "instagram", "safari"]),
            ["youtube"]
        )
    }

    func testTargetAppClampLeavesItemsWithinLimitUnchanged() {
        let gate = makeGate(tier: .free)
        let catalogIDs = ["youtube"]

        XCTAssertEqual(gate.clampedTargetAppCatalogIDs(catalogIDs), catalogIDs)
    }

    func testTargetAppClampKeepsTopOneByAttempts() {
        let gate = makeGate(tier: .free)

        XCTAssertEqual(
            gate.clampedTargetAppCatalogIDs(
                ["youtube", "instagram", "safari", "line"],
                attemptCountsByCatalogID: [
                    "youtube": 1,
                    "instagram": 7,
                    "safari": 3,
                    "line": 7
                ]
            ),
            ["instagram"]
        )
    }

    func testTargetAppClampWithAttemptsLeavesItemsWithinLimitUnchanged() {
        let gate = makeGate(tier: .free)
        let catalogIDs = ["youtube"]

        XCTAssertEqual(
            gate.clampedTargetAppCatalogIDs(
                catalogIDs,
                attemptCountsByCatalogID: ["youtube": 1, "instagram": 5, "safari": 3]
            ),
            catalogIDs
        )
    }

    func testTargetAppClampLeavesProItemsUnchanged() {
        let gate = makeGate(tier: .pro)
        let catalogIDs = ["youtube", "instagram", "safari", "line"]

        XCTAssertEqual(gate.clampedTargetAppCatalogIDs(catalogIDs), catalogIDs)
    }

    func testPreferredTargetAppUsesMostAttempts() {
        XCTAssertEqual(
            EntitlementGate.preferredTargetAppCatalogID(
                ["instagram", "youtube", "safari"],
                attemptCountsByCatalogID: ["instagram": 2, "youtube": 5, "safari": 1]
            ),
            "youtube"
        )
    }

    func testPreferredTargetAppUsesSelectionOrderForTies() {
        XCTAssertEqual(
            EntitlementGate.preferredTargetAppCatalogID(
                ["instagram", "youtube", "safari"],
                attemptCountsByCatalogID: ["instagram": 3, "youtube": 3, "safari": 1]
            ),
            "instagram"
        )
    }

    func testPreferredTargetAppFallsBackToFirstWhenAllAttemptsAreZero() {
        XCTAssertEqual(
            EntitlementGate.preferredTargetAppCatalogID(
                ["instagram", "youtube"],
                attemptCountsByCatalogID: [:]
            ),
            "instagram"
        )
    }

    func testFreeThemeGateAllowsOnlyE1() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.lockThemeAllowed(.e1))
        for theme in LockTheme.allCases where theme != .e1 {
            XCTAssertFalse(gate.lockThemeAllowed(theme), "\(theme) should be Pro-only")
        }
    }

    func testProThemeGateAllowsAllThemes() {
        let gate = makeGate(tier: .pro)

        for theme in LockTheme.allCases {
            XCTAssertTrue(gate.lockThemeAllowed(theme), "\(theme) should be allowed for Pro")
        }
    }

    private func makeGate(
        tier: EntitlementTier,
        now: Date = Date(timeIntervalSince1970: 1_750_000_000)
    ) -> EntitlementGate {
        EntitlementGate(tier: tier, now: now)
    }
}
