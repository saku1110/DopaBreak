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
        XCTAssertEqual(EntitlementGate(isPro: false, now: now, firstLaunchDate: nil).tier, .free)
        XCTAssertEqual(EntitlementGate(isPro: true, now: now, firstLaunchDate: nil).tier, .pro)
    }

    func testFreeGateValues() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.heroGoalAllowed)
        XCTAssertEqual(gate.goalsLimit, 1)
        XCTAssertEqual(gate.targetRulesLimit, 1)
        XCTAssertEqual(gate.targetAppTokensLimit, 1)
        XCTAssertEqual(gate.statsDays, 1)
        XCTAssertFalse(gate.weeklyReportAllowed)
        XCTAssertFalse(gate.strictModeAllowed)
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
        XCTAssertTrue(gate.themesAllowed)
    }

    func testFreeGoalLimitBoundaries() {
        let gate = makeGate(tier: .free)

        XCTAssertTrue(gate.canAddGoal(currentCount: 0))
        XCTAssertFalse(gate.canAddGoal(currentCount: 1))
        XCTAssertFalse(gate.canAddGoal(currentCount: 2))
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

    func testFreeTargetTokenLimitAcrossInitialWindow() {
        let firstLaunchDate = Date(timeIntervalSince1970: 1_750_000_000)

        let dayZero = makeGate(
            tier: .free,
            now: firstLaunchDate,
            firstLaunchDate: firstLaunchDate
        )
        let dayThirteenPointNine = makeGate(
            tier: .free,
            now: firstLaunchDate.addingTimeInterval(13.9 * 86_400),
            firstLaunchDate: firstLaunchDate
        )
        let dayFourteen = makeGate(
            tier: .free,
            now: firstLaunchDate.addingTimeInterval(14 * 86_400),
            firstLaunchDate: firstLaunchDate
        )
        let dayThirty = makeGate(
            tier: .free,
            now: firstLaunchDate.addingTimeInterval(30 * 86_400),
            firstLaunchDate: firstLaunchDate
        )
        let missingFirstLaunchDate = makeGate(
            tier: .free,
            now: firstLaunchDate,
            firstLaunchDate: nil
        )

        XCTAssertEqual(dayZero.targetAppTokensLimit, 3)
        XCTAssertEqual(dayThirteenPointNine.targetAppTokensLimit, 3)
        XCTAssertEqual(dayFourteen.targetAppTokensLimit, 1)
        XCTAssertEqual(dayThirty.targetAppTokensLimit, 1)
        XCTAssertEqual(missingFirstLaunchDate.targetAppTokensLimit, 1)
        XCTAssertTrue(dayZero.canAddTargetTokens(currentCount: 2))
        XCTAssertFalse(dayZero.canAddTargetTokens(currentCount: 3))
    }

    func testFutureFirstLaunchDateUsesInitialWindowLimit() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let futureFirstLaunchDate = now.addingTimeInterval(86_400)
        let gate = makeGate(tier: .free, now: now, firstLaunchDate: futureFirstLaunchDate)

        XCTAssertEqual(gate.targetAppTokensLimit, 3)
    }

    func testProTargetTokenLimitIsUnlimitedRegardlessOfInitialWindow() {
        let firstLaunchDate = Date(timeIntervalSince1970: 1_750_000_000)
        let dates = [
            firstLaunchDate.addingTimeInterval(-86_400),
            firstLaunchDate,
            firstLaunchDate.addingTimeInterval(14 * 86_400),
            firstLaunchDate.addingTimeInterval(30 * 86_400)
        ]

        for now in dates {
            let gate = makeGate(tier: .pro, now: now, firstLaunchDate: firstLaunchDate)
            XCTAssertNil(gate.targetAppTokensLimit)
            XCTAssertTrue(gate.canAddTargetTokens(currentCount: 50))
        }
    }

    func testTargetAppClampKeepsLeadingItemsWhenOverLimit() {
        let gate = makeGate(tier: .free)

        XCTAssertEqual(
            gate.clampedTargetAppCatalogIDs(["youtube", "instagram", "safari"]),
            ["youtube"]
        )
    }

    func testTargetAppClampLeavesItemsWithinLimitUnchanged() {
        let firstLaunchDate = Date(timeIntervalSince1970: 1_750_000_000)
        let gate = makeGate(tier: .free, now: firstLaunchDate, firstLaunchDate: firstLaunchDate)
        let catalogIDs = ["youtube", "instagram", "safari"]

        XCTAssertEqual(gate.clampedTargetAppCatalogIDs(catalogIDs), catalogIDs)
    }

    func testTargetAppClampLeavesProItemsUnchanged() {
        let gate = makeGate(tier: .pro)
        let catalogIDs = ["youtube", "instagram", "safari", "line"]

        XCTAssertEqual(gate.clampedTargetAppCatalogIDs(catalogIDs), catalogIDs)
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
        now: Date = Date(timeIntervalSince1970: 1_750_000_000),
        firstLaunchDate: Date? = nil
    ) -> EntitlementGate {
        EntitlementGate(tier: tier, now: now, firstLaunchDate: firstLaunchDate)
    }
}
