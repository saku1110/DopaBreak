import Foundation
import XCTest
@testable import DopaBreakCore

final class InterventionModeAvailabilityTests: XCTestCase {
    /// 夜だけ強化は時間帯での切り替えを実装した2026-08-14に解禁した（docs/12 §1）。
    func testSelectableModesIncludeNightOnly() {
        XCTAssertEqual(InterventionMode.selectable, [.standard, .deepFocus, .nightOnly])
    }

    func testIsSelectableMatchesTheSelectableList() {
        XCTAssertTrue(InterventionMode.standard.isSelectable)
        XCTAssertTrue(InterventionMode.deepFocus.isSelectable)
        XCTAssertTrue(InterventionMode.nightOnly.isSelectable)
    }

    func testPersistableKeepsSupportedModes() {
        XCTAssertEqual(InterventionMode.standard.persistable, .standard)
        XCTAssertEqual(InterventionMode.deepFocus.persistable, .deepFocus)
        XCTAssertEqual(InterventionMode.nightOnly.persistable, .nightOnly)
    }

    /// 選べるモードは必ず保存できる。片方だけ足したときのずれを防ぐ。
    func testEverySelectableModeSurvivesPersistence() {
        for mode in InterventionMode.selectable {
            XCTAssertEqual(mode.persistable, mode)
        }
    }

    /// 完全ブロックを使う強さはPro専用。画面側の解放判定はこの旗を見る。
    func testUsesShieldMarksTheProOnlyModes() {
        XCTAssertTrue(InterventionMode.deepFocus.usesShield)
        XCTAssertTrue(InterventionMode.nightOnly.usesShield)
        XCTAssertFalse(InterventionMode.standard.usesShield)
    }

    /// 夜だけ強化は夜の窓のなかだけ完全ブロックを出す。
    func testNightOnlyIsShieldedOnlyInsideTheNightWindow() {
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
                hasConfirmedEntitlement: true,
                isNightWindow: true,
                isDeepFocusWindowActive: true
            ),
            .apply(rules: [rule])
        )
        XCTAssertEqual(
            ShieldSyncPolicy.action(
                rules: [rule],
                isPro: true,
                strictModeAllowed: true,
                hasConfirmedEntitlement: true,
                isNightWindow: false,
                isDeepFocusWindowActive: true
            ),
            .clear
        )
    }
}
