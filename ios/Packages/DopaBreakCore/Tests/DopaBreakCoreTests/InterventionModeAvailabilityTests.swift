import Foundation
import XCTest
@testable import DopaBreakCore

final class InterventionModeAvailabilityTests: XCTestCase {
    /// 時間帯での切り替えが未実装のため、`nightOnly` は選ばせない（docs/12 §1）。
    func testSelectableModesExcludeNightOnly() {
        XCTAssertEqual(InterventionMode.selectable, [.standard, .deepFocus])
        XCTAssertFalse(InterventionMode.selectable.contains(.nightOnly))
    }

    func testIsSelectableMatchesTheSelectableList() {
        XCTAssertTrue(InterventionMode.standard.isSelectable)
        XCTAssertTrue(InterventionMode.deepFocus.isSelectable)
        XCTAssertFalse(InterventionMode.nightOnly.isSelectable)
    }

    /// 永続化の境界でもう一度落とす。画面側の列挙漏れが保存まで通らないようにする。
    func testPersistableMovesUnsupportedModesToStandard() {
        XCTAssertEqual(InterventionMode.nightOnly.persistable, .standard)
    }

    func testPersistableKeepsSupportedModes() {
        XCTAssertEqual(InterventionMode.standard.persistable, .standard)
        XCTAssertEqual(InterventionMode.deepFocus.persistable, .deepFocus)
    }

    /// 選べるモードは必ず保存できる。片方だけ足したときのずれを防ぐ。
    func testEverySelectableModeSurvivesPersistence() {
        for mode in InterventionMode.selectable {
            XCTAssertEqual(mode.persistable, mode)
        }
    }

    /// 未実装のモードが保存されても、完全ブロックの対象にはならない。
    func testNightOnlyIsNeverShielded() {
        let rule = TargetRule(
            id: UUID(),
            name: "night",
            activitySelectionData: Data([1]),
            mode: .nightOnly,
            schedule: nil,
            delaySeconds: 0,
            maxOpensPerDay: nil,
            defaultDurationMinutes: 10,
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(
            ShieldSyncPolicy.action(
                rules: [rule],
                isPro: true,
                strictModeAllowed: true,
                hasConfirmedEntitlement: true
            ),
            .clear
        )
    }
}
