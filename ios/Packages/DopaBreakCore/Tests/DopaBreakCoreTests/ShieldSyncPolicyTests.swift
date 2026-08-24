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
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
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
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .apply(rules: [first, second]))
    }

    // MARK: - 解除

    func testClearsWhenOnlyStandardRulesExist() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .standard)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsForConfirmedFreeEvenWithDeepFocusRule() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsWhenDeepFocusRuleIsDisabled() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus, isEnabled: false)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// カタログ由来のルール（選択データが空）は通常介入のためのもので、完全ブロックの対象ではない。
    func testClearsWhenDeepFocusRuleHasNoSelection() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus, selection: nil)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsWhenThereAreNoRules() {
        let action = ShieldSyncPolicy.action(
            rules: [],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    // MARK: - 夜の窓（nightOnly）

    func testAppliesNightOnlyRulesInsideTheNightWindow() {
        let nightOnly = makeRule(mode: .nightOnly)

        let action = ShieldSyncPolicy.action(
            rules: [nightOnly],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .apply(rules: [nightOnly]))
    }

    /// 昼は何も出さない。夜だけ強化の対象しか無ければ、夜間ぶんは解除になる。
    func testClearsNightOnlyRulesOutsideTheNightWindow() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .nightOnly)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// ディープフォーカスは夜の窓に関係なく通す。夜の判定を足したことで常時ブロックが揺れない。
    func testDeepFocusIsUnaffectedByTheNightWindow() {
        let deepFocus = makeRule(mode: .deepFocus)

        for isNightWindow in [true, false] {
            XCTAssertEqual(
                ShieldSyncPolicy.action(
                    rules: [deepFocus],
                    isPro: true,
                    strictModeAllowed: true,
                    hasConfirmedEntitlement: true,
                    isNightWindow: isNightWindow,
                    isDeepFocusWindowActive: true
                ),
                .apply(rules: [deepFocus]),
                "isNightWindow=\(isNightWindow)"
            )
        }
    }

    func testAppliesBothModesInsideTheNightWindow() {
        let deepFocus = makeRule(mode: .deepFocus, selection: 1)
        let nightOnly = makeRule(mode: .nightOnly, selection: 2)

        let action = ShieldSyncPolicy.action(
            rules: [deepFocus, nightOnly, makeRule(mode: .standard, selection: 3)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .apply(rules: [deepFocus, nightOnly]))
    }

    func testClearsWhenNightOnlyRuleIsDisabledInsideTheNightWindow() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .nightOnly, isEnabled: false)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    func testClearsWhenNightOnlyRuleHasNoSelectionInsideTheNightWindow() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .nightOnly, selection: nil)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// 夜のまっただ中でも、Freeだと確定していれば解除する。
    /// 夜間ぶんだけが降格の判定から漏れると、Freeへ戻った人の夜のブロックが残り続ける。
    func testClearsForConfirmedFreeInsideTheNightWindow() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .nightOnly), makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// 夜でも権利が未確定なら触らない。取得に失敗しただけの課金者から剥がさない。
    func testPreservesInsideTheNightWindowWhenUnconfirmed() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .nightOnly)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .preserve)
    }

    // MARK: - 維持（未確定）

    func testPreservesWhenEntitlementIsUnconfirmedForPro() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .preserve)
    }

    /// 取得に失敗しただけの課金者を無料扱いして解除しない。
    func testPreservesWhenEntitlementIsUnconfirmedForFree() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .preserve)
    }

    func testPreservesWhenUnconfirmedEvenWithoutRules() {
        let action = ShieldSyncPolicy.action(
            rules: [],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .preserve)
    }

    // MARK: - rulesToShield

    func testRulesToShieldKeepsOnlyDeepFocusRulesWithSelectionDuringTheDay() {
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
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(rules, [deepFocus])
    }

    func testRulesToShieldKeepsNightOnlyRulesWithSelectionInsideTheNightWindow() {
        let deepFocus = makeRule(mode: .deepFocus, selection: 1)
        let nightOnly = makeRule(mode: .nightOnly, selection: 3)

        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [
                deepFocus,
                makeRule(mode: .standard, selection: 2),
                nightOnly,
                makeRule(mode: .nightOnly, selection: nil),
                makeRule(mode: .nightOnly, selection: 4, isEnabled: false)
            ],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(rules, [deepFocus, nightOnly])
    }

    func testRulesToShieldIsEmptyWithoutProEntitlement() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus), makeRule(mode: .nightOnly)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertTrue(rules.isEmpty)
    }

    /// `isPro` だけが真で `strictModeAllowed` が偽になる組み合わせでも解放しない。
    func testRulesToShieldIsEmptyWhenStrictModeIsNotAllowed() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus), makeRule(mode: .nightOnly)],
            isPro: true,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertTrue(rules.isEmpty)
    }

    func testRulesToShieldIsEmptyWhenUnconfirmed() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus), makeRule(mode: .nightOnly)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false,
            isNightWindow: true,
            isDeepFocusWindowActive: true
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
    /// 夜の窓の内外どちらでも同じであることまで含めて固定する。
    func testUnconditionalClearAgreesWithActionForEveryEntitlementCombination() {
        for isPro in [true, false] {
            for strictModeAllowed in [true, false] {
                for hasConfirmed in [true, false] {
                    for isNightWindow in [true, false] {
                        let unconditional = ShieldSyncPolicy.requiresUnconditionalClear(
                            isPro: isPro,
                            strictModeAllowed: strictModeAllowed,
                            hasConfirmedEntitlement: hasConfirmed
                        )
                        guard unconditional else {
                            continue
                        }
                        let action = ShieldSyncPolicy.action(
                            rules: [makeRule(mode: .deepFocus), makeRule(mode: .nightOnly)],
                            isPro: isPro,
                            strictModeAllowed: strictModeAllowed,
                            hasConfirmedEntitlement: hasConfirmed,
                            isNightWindow: isNightWindow,
                            isDeepFocusWindowActive: true
                        )
                        XCTAssertEqual(
                            action,
                            .clear,
                            "isPro=\(isPro) strict=\(strictModeAllowed) "
                                + "confirmed=\(hasConfirmed) night=\(isNightWindow)"
                        )
                    }
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
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
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
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// Proで読み取りに失敗したときは維持する。読めないことを理由に剥がさない。
    /// 夜の窓に入っていても同じで、読めないまま夜間ぶんを外したりしない。
    func testPreservesForConfirmedProWhenRuleStoreThrows() {
        for isNightWindow in [true, false] {
            XCTAssertEqual(
                ShieldSyncPolicy.action(
                    rulesProvider: { throw TestRuleStoreError.unreadable },
                    isPro: true,
                    strictModeAllowed: true,
                    hasConfirmedEntitlement: true,
                    isNightWindow: isNightWindow,
                    isDeepFocusWindowActive: true
                ),
                .preserve,
                "isNightWindow=\(isNightWindow)"
            )
        }
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
            hasConfirmedEntitlement: false,
            isNightWindow: true,
            isDeepFocusWindowActive: true
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
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .apply(rules: [deepFocus]))
    }

    func testProviderResultDrivesApplyForNightOnlyInsideTheNightWindow() {
        let nightOnly = makeRule(mode: .nightOnly)

        let action = ShieldSyncPolicy.action(
            rulesProvider: { [nightOnly, self.makeRule(mode: .standard)] },
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .apply(rules: [nightOnly]))
    }

    // MARK: - 完全ブロックの窓（deepFocus）

    /// 2026-08-17より前は「選んでいるあいだ常時」だった。窓の外では何も出さない。
    /// ここが通らないと「窓が終わったのに開けない」がそのまま残る。
    func testClearsDeepFocusRulesOutsideTheDeepFocusWindow() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(action, .clear)
    }

    func testAppliesDeepFocusRulesInsideTheDeepFocusWindow() {
        let deepFocus = makeRule(mode: .deepFocus)

        let action = ShieldSyncPolicy.action(
            rules: [deepFocus],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .apply(rules: [deepFocus]))
    }

    func testManualDeepFocusSessionAppliesSelectedRulesRegardlessOfMode() {
        let standard = makeRule(mode: .standard, selection: 1)
        let deepFocus = makeRule(mode: .deepFocus, selection: 2)
        let nightOnly = makeRule(mode: .nightOnly, selection: 3)

        let action = ShieldSyncPolicy.action(
            rules: [standard, deepFocus, nightOnly],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true,
            isManualDeepFocusSessionActive: true
        )

        XCTAssertEqual(action, .apply(rules: [standard, deepFocus, nightOnly]))
    }

    func testManualDeepFocusSessionDoesNotApplyWithoutConfirmedProEntitlement() {
        let standard = makeRule(mode: .standard, selection: 1)

        XCTAssertEqual(
            ShieldSyncPolicy.action(
                rules: [standard],
                isPro: false,
                strictModeAllowed: false,
                hasConfirmedEntitlement: false,
                isNightWindow: false,
                isDeepFocusWindowActive: true,
                isManualDeepFocusSessionActive: true
            ),
            .preserve
        )
        XCTAssertEqual(
            ShieldSyncPolicy.action(
                rules: [standard],
                isPro: false,
                strictModeAllowed: false,
                hasConfirmedEntitlement: true,
                isNightWindow: false,
                isDeepFocusWindowActive: true,
                isManualDeepFocusSessionActive: true
            ),
            .clear
        )
    }

    func testEndingManualSessionRemovesStandardTargetButKeepsActiveNightTarget() {
        let standard = makeRule(mode: .standard, selection: 1)
        let nightOnly = makeRule(mode: .nightOnly, selection: 2)

        XCTAssertEqual(
            ShieldSyncPolicy.action(
                rules: [standard, nightOnly],
                isPro: true,
                strictModeAllowed: true,
                hasConfirmedEntitlement: true,
                isNightWindow: true,
                isDeepFocusWindowActive: true,
                isManualDeepFocusSessionActive: true
            ),
            .apply(rules: [standard, nightOnly])
        )
        XCTAssertEqual(
            ShieldSyncPolicy.action(
                rules: [standard, nightOnly],
                isPro: true,
                strictModeAllowed: true,
                hasConfirmedEntitlement: true,
                isNightWindow: true,
                isDeepFocusWindowActive: false,
                isManualDeepFocusSessionActive: false
            ),
            .apply(rules: [nightOnly])
        )
    }

    /// 夜だけ強化は完全ブロックの窓に左右されない。2つの窓が互いを消し合わないことを固定する。
    func testNightOnlyIsUnaffectedByTheDeepFocusWindow() {
        let nightOnly = makeRule(mode: .nightOnly)

        for isDeepFocusWindowActive in [true, false] {
            XCTAssertEqual(
                ShieldSyncPolicy.action(
                    rules: [nightOnly],
                    isPro: true,
                    strictModeAllowed: true,
                    hasConfirmedEntitlement: true,
                    isNightWindow: true,
                    isDeepFocusWindowActive: isDeepFocusWindowActive
                ),
                .apply(rules: [nightOnly]),
                "isDeepFocusWindowActive=\(isDeepFocusWindowActive)"
            )
        }
    }

    /// 完全ブロックの窓が閉じていても、夜の窓が開いていれば夜のぶんだけ出す。
    func testAppliesOnlyNightOnlyWhenTheDeepFocusWindowIsClosed() {
        let nightOnly = makeRule(mode: .nightOnly, selection: 2)

        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus, selection: 1), nightOnly],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(action, .apply(rules: [nightOnly]))
    }

    /// 完全ブロックの窓のまっただ中でも、Freeだと確定していれば解除する。
    func testClearsForConfirmedFreeInsideTheDeepFocusWindow() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: false,
            strictModeAllowed: false,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .clear)
    }

    /// Freeだと確定したら、ルールを読む前に解除が決まる（読み取り失敗で解除が落ちない）。
    /// 窓の入力を足しても、この到達性は変わらない。
    func testDoesNotReadRulesForConfirmedFreeRegardlessOfTheDeepFocusWindow() {
        for isDeepFocusWindowActive in [true, false] {
            var didCallProvider = false
            let action = ShieldSyncPolicy.action(
                rulesProvider: {
                    didCallProvider = true
                    return []
                },
                isPro: false,
                strictModeAllowed: false,
                hasConfirmedEntitlement: true,
                isNightWindow: false,
                isDeepFocusWindowActive: isDeepFocusWindowActive
            )

            XCTAssertEqual(action, .clear, "isDeepFocusWindowActive=\(isDeepFocusWindowActive)")
            XCTAssertFalse(didCallProvider, "isDeepFocusWindowActive=\(isDeepFocusWindowActive)")
        }
    }

    /// 権利が未確定なら窓の内でも触らない。取得に失敗しただけの課金者から剥がさない。
    func testPreservesInsideTheDeepFocusWindowWhenUnconfirmed() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .preserve)
    }

    /// 窓が閉じていても、未確定なら解除も適用もしない（preserveのままであることを固定する）。
    func testPreservesOutsideTheDeepFocusWindowWhenUnconfirmed() {
        let action = ShieldSyncPolicy.action(
            rules: [makeRule(mode: .deepFocus)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(action, .preserve)
    }

    /// ルールを読めなかったときは維持。窓の入力を足しても変わらない。
    func testPreservesWhenRuleProviderThrowsInsideTheDeepFocusWindow() {
        let action = ShieldSyncPolicy.action(
            rulesProvider: { throw TestRuleStoreError.unreadable },
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: true
        )

        XCTAssertEqual(action, .preserve)
    }

    func testPreservesWhenRuleProviderThrowsOutsideTheDeepFocusWindow() {
        let action = ShieldSyncPolicy.action(
            rulesProvider: { throw TestRuleStoreError.unreadable },
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(action, .preserve)
    }

    func testRulesToShieldDropsDeepFocusRulesOutsideTheDeepFocusWindow() {
        let nightOnly = makeRule(mode: .nightOnly, selection: 3)

        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus, selection: 1), nightOnly],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: true,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(rules, [nightOnly])
    }

    /// 両方の窓が閉じていれば、Proでも対象は残らない。
    func testRulesToShieldIsEmptyWhenBothWindowsAreClosed() {
        let rules = ShieldSyncPolicy.rulesToShield(
            rules: [makeRule(mode: .deepFocus, selection: 1), makeRule(mode: .nightOnly, selection: 2)],
            isPro: true,
            strictModeAllowed: true,
            hasConfirmedEntitlement: true,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertTrue(rules.isEmpty)
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
