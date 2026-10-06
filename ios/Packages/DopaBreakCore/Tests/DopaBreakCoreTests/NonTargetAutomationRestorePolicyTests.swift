import XCTest
@testable import DopaBreakCore

final class NonTargetAutomationRestorePolicyTests: XCTestCase {
    // MARK: - decision

    func testFreeSlotAvailableAddsWithoutPaywall() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: [],
                limit: 1
            ),
            .add
        )
    }

    func testFullFreeSlotSwapsInsteadOfRequiringPro() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x"],
                limit: 1
            ),
            .swap(displacedCatalogIDs: ["x"])
        )
    }

    func testProHasNoLimitSoItAlwaysAdds() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x", "youtube", "tiktok"],
                limit: nil
            ),
            .add
        )
    }

    func testClampedByEntitlementAlwaysRequiresPro() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .clampedByEntitlement,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x"],
                limit: 1
            ),
            .requiresPro
        )
    }

    /// Pro失効の経路は枠が空いていても課金導線を維持する（2026-09-03の決定）。
    func testClampedByEntitlementRequiresProEvenWithFreeSlot() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .clampedByEntitlement,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: [],
                limit: 1
            ),
            .requiresPro
        )
    }

    func testAlreadySelectedTargetAddsWithoutDisplacingItself() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["instagram"],
                limit: 1
            ),
            .add
        )
    }

    func testMultipleTargetsOverLimitDisplaceEveryTargetOutsideTheLimit() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x", "youtube"],
                limit: 1
            ),
            .swap(displacedCatalogIDs: ["x", "youtube"])
        )
    }

    func testSwapKeepsTargetsThatStillFitInsideTheLimit() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x", "youtube"],
                limit: 2
            ),
            .swap(displacedCatalogIDs: ["x"])
        )
    }

    /// 上限0は現行のEntitlementGateでは起こらない。
    /// 起きても入れ替えにはしない。保存すると全対象が消えたうえで対象外の一呼吸が始まるため。
    func testZeroLimitRequiresProInsteadOfWipingTargets() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: [],
                limit: 0
            ),
            .requiresPro
        )
    }

    func testZeroLimitWithAnExistingTargetAlsoRequiresPro() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.decision(
                reason: .removed,
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x"],
                limit: 0
            ),
            .requiresPro
        )
    }

    // MARK: - resultingCatalogIDs

    func testResultingCatalogIDsSwapsTheOnlyFreeSlot() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.resultingCatalogIDs(
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x"],
                limit: 1
            ),
            ["instagram"]
        )
    }

    func testResultingCatalogIDsAppendsWhenSlotIsFree() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.resultingCatalogIDs(
                restoredCatalogID: "instagram",
                selectedCatalogIDs: [],
                limit: 1
            ),
            ["instagram"]
        )
    }

    func testResultingCatalogIDsDoesNotDuplicateAnAlreadySelectedTarget() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.resultingCatalogIDs(
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["instagram"],
                limit: 1
            ),
            ["instagram"]
        )
    }

    func testResultingCatalogIDsKeepsEveryTargetForPro() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.resultingCatalogIDs(
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x", "youtube"],
                limit: nil
            ),
            ["x", "youtube", "instagram"]
        )
    }

    func testResultingCatalogIDsKeepsTheNewestTargetsWithinTheLimit() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.resultingCatalogIDs(
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x", "youtube"],
                limit: 2
            ),
            ["youtube", "instagram"]
        )
    }

    func testResultingCatalogIDsIsEmptyForZeroLimit() {
        XCTAssertEqual(
            NonTargetAutomationRestorePolicy.resultingCatalogIDs(
                restoredCatalogID: "instagram",
                selectedCatalogIDs: ["x"],
                limit: 0
            ),
            []
        )
    }

    /// 同じ入力からは同じ並びが出る。保存順が揺れると次回の判定まで揺れるため。
    func testResultingCatalogIDsIsDeterministic() {
        let first = NonTargetAutomationRestorePolicy.resultingCatalogIDs(
            restoredCatalogID: "instagram",
            selectedCatalogIDs: ["youtube", "x", "instagram", "tiktok"],
            limit: 3
        )
        let second = NonTargetAutomationRestorePolicy.resultingCatalogIDs(
            restoredCatalogID: "instagram",
            selectedCatalogIDs: ["youtube", "x", "instagram", "tiktok"],
            limit: 3
        )
        XCTAssertEqual(first, ["x", "tiktok", "instagram"])
        XCTAssertEqual(first, second)
    }

    /// 決定と保存後の並びが食い違うと、押し出したはずのアプリが残る。
    func testDisplacedTargetsMatchTheResultingOrder() {
        let selected = ["youtube", "x", "tiktok"]
        let decision = NonTargetAutomationRestorePolicy.decision(
            reason: .removed,
            restoredCatalogID: "instagram",
            selectedCatalogIDs: selected,
            limit: 2
        )
        let resulting = NonTargetAutomationRestorePolicy.resultingCatalogIDs(
            restoredCatalogID: "instagram",
            selectedCatalogIDs: selected,
            limit: 2
        )
        XCTAssertEqual(decision, .swap(displacedCatalogIDs: ["youtube", "x"]))
        XCTAssertEqual(resulting, ["tiktok", "instagram"])
    }
}
