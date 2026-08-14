import Foundation
import XCTest
@testable import DopaBreakCore

final class ShieldSyncPolicyTests: XCTestCase {
    // MARK: - 適用

    func testAppliesDeepFocusRulesForConfirmedPro() {
        let deepFocus = makeRule(mode: .deepFocus)
        let standard = makeRule(mode: .standard)

        let action = ShieldSyncPolicy.action(
            rules: [deepFocus, standard],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .apply(rules: [deepFocus]))
    }

    func testAppliesEveryDeepFocusRuleNotJustTheFirst() {
        let first = makeRule(mode: .deepFocus, selection: 1)
        let second = makeRule(mode: .deepFocus, selection: 2)

        let action = ShieldSyncPolicy.action(
            rules: [first, second],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .apply(rules: [first, second]))
    }

    // MARK: - 解除

    func testClearsWhenOnlyStandardRulesExist() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .standard)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// 時間帯制御は未実装のため、`nightOnly` は完全ブロックの対象にしない。
    func testClearsWhenOnlyNightOnlyRulesExist() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .nightOnly)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsForConfirmedFreeEvenWithDeepFocusRule() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsWhenDeepFocusRuleIsDisabled() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus, isEnabled: false)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// カタログ由来のルール（選択データが空）は通常介入のためのもので、完全ブロックの対象ではない。
    func testClearsWhenDeepFocusRuleHasNoSelection() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus, selection: nil)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsWhenThereAreNoRules() {
        let action = ShieldSyncPolicy.action(
            rules: [],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    // MARK: - 維持（未確定）

    func testPreservesWhenEntitlementIsUnconfirmedForPro() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false
        )

        XCTAssertEqual(action, .preserve)
    }

    /// 取得に失敗しただけの課金者を無料扱いして解除しない。
    func testPreservesWhenEntitlementIsUnconfirmedForFree() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: false
        )

        XCTAssertEqual(action, .preserve)
    }

    func testPreservesWhenUnconfirmedEvenWithoutRules() {
        let action = ShieldSyncPolicy.action(
            rules: [],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false
        )

        XCTAssertEqual(action, .preserve)
    }

    // MARK: - rulesToShield

    func testRulesToShieldKeepsOnlyDeepFocusRulesWithSelection() {
        let deepFocus = makeRule(mode: .deepFocus, selection: 1)

        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [
                deepFocus,
                makeRule(mode: .standard, selection: 2),
                makeRule(mode: .nightOnly, selection: 3),
                makeRule(mode: .deepFocus, selection: nil),
                makeRule(mode: .deepFocus, selection: 4, isEnabled: false)
            ],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(rules, [deepFocus])
    }

    func testRulesToShieldIsEmptyWithoutProEntitlement() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true
        )

        XCTAssertTrue(rules.isEmpty)
    }

    /// `isPro` だけが真で `strictModeAllowed` が偽になる組み合わせでも解放しない。
    func testRulesToShieldIsEmptyWhenStrictModeIsNotAllowed() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true
        )

        XCTAssertTrue(rules.isEmpty)
    }

    func testRulesToShieldIsEmptyWhenUnconfirmed() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false
        )

        XCTAssertTrue(rules.isEmpty)
    }

    // MARK: - requiresUnconditionalClear（ルールを読めない端末での解除保証）

    func testRequiresUnconditionalClearForConfirmedFree() {
        XCTAssertTrue(
            ShieldSyncPolicy.requiresUnconditionalClear(
                isPro: false,
                strictModeAllowed: false,
                hasConfirmedEntitlement: true
            )
        )
    }

    func testRequiresUnconditionalClearWhenStrictModeIsRevokedForProTier() {
        XCTAssertTrue(
            ShieldSyncPolicy.requiresUnconditionalClear(
                isPro: true,
                strictModeAllowed: false,
                hasConfirmedEntitlement: true
            )
        )
    }

    func testDoesNotRequireUnconditionalClearForConfirmedPro() {
        XCTAssertFalse(
            ShieldSyncPolicy.requiresUnconditionalClear(
                isPro: true,
                strictModeAllowed: true,
                hasConfirmedEntitlement: true
            )
        )
    }

    /// 未確定では解除しない。取得に失敗しただけの課金者から剥がさないため。
    func testDoesNotRequireUnconditionalClearWhenUnconfirmed() {
        XCTAssertFalse(
            ShieldSyncPolicy.requiresUnconditionalClear(
                isPro: false,
                strictModeAllowed: false,
                hasConfirmedEntitlement: false
            )
        )
    }

    /// `action` が `.clear` を返す組み合わせは、必ず無条件解除でも解除になる。
    /// 片方だけ直したときに判定がずれないよう、両者の整合をテストで固定する。
    func testUnconditionalClearAgreesWithActionForEveryEntitlementCombination() {
        for isPro in [true, false] {
            for strictModeAllowed in [true, false] {
                for hasConfirmed in [true, false] {
                    let unconditional = ShieldSyncPolicy.requiresUnconditionalClear(
                        isPro: isPro,
                        strictModeAllowed: strictModeAllowed,
                        hasConfirmedEntitlement: hasConfirmed
                    )
                    guard unconditional else {
                        continue
                    }
                    let action = ShieldSyncPolicy.action(
                        rules: [makeRule(mode: .deepFocus)],
                        isPro: isPro,
                        strictModeAllowed: strictModeAllowed,
                        hasConfirmedEntitlement: hasConfirmed
                    )
                    XCTAssertEqual(
                        action,
                        .clear,
                        "isPro=\(isPro) strict=\(strictModeAllowed) confirmed=\(hasConfirmed)"
                    )
                }
            }
        }
    }

    // MARK: - rulesProvider（ルールを読めない端末での挙動）

    /// 読み取りが失敗しても、Freeだと確定していれば解除する。
    /// ここが `preserve` に落ちると、Freeへ戻った人の完全ブロックが恒久的に残る。
    func testClearsForConfirmedFreeEvenWhenRuleStoreThrows() {
        var didCallProvider = false

        let action = ShieldSyncPolicy.action(
            rulesProvider: {
                didCallProvider = true
                throw TestRuleStoreError.unreadable
            },
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
        // 解除が確定している場面では、そもそも読みに行かない。
        XCTAssertFalse(didCallProvider)
    }

    func testClearsWhenStrictModeIsRevokedEvenWhenRuleStoreThrows() {
        let action = ShieldSyncPolicy.action(
            rulesProvider: { throw TestRuleStoreError.unreadable },
            isPro: true,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// Proで読み取りに失敗したときは維持する。読めないことを理由に剥がさない。
    func testPreservesForConfirmedProWhenRuleStoreThrows() {
        let action = ShieldSyncPolicy.action(
            rulesProvider: { throw TestRuleStoreError.unreadable },
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .preserve)
    }

    /// 未確定では読みにも行かず、現状を維持する。
    func testPreservesWithoutReadingRulesWhenUnconfirmed() {
        var didCallProvider = false

        let action = ShieldSyncPolicy.action(
            rulesProvider: {
                didCallProvider = true
                return []
            },
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false
        )

        XCTAssertEqual(action, .preserve)
        XCTAssertFalse(didCallProvider)
    }

    func testProviderResultDrivesApplyForConfirmedPro() {
        let deepFocus = makeRule(mode: .deepFocus)

        let action = ShieldSyncPolicy.action(
            rulesProvider: { [deepFocus, self.makeRule(mode: .standard)] },
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true
        )

        XCTAssertEqual(action, .apply(rules: [deepFocus]))
    }

    // MARK: - Helpers

    private enum TestRuleStoreError: Error {
        case unreadable
    }

    private func makeRule(
        mode: InterventionMode,
        selection: Int? = 1,
        isEnabled: Bool = true
    ) -> TargetRule {
        let timestamp = Date(timeIntervalSince1970: 0)
        return TargetRule(
            id: UUID(),
            name: "rule-\(mode.rawValue)-\(selection.map(String.init) ?? "empty")",
            activitySelectionData: selection.map { Data([UInt8($0)]) } ?? Data(),
            mode: mode,
            schedule: nil,
            delaySeconds: 0,
            maxOpensPerDay: nil,
            defaultDurationMinutes: 10,
            isEnabled: isEnabled,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
