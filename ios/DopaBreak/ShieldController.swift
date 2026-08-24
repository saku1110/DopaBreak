import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class ShieldController {
    private let ruleStore: RuleStore
    /// 完全ブロック（ディープフォーカス）の分を置くストア。窓の境界で拡張が
    /// ここだけを触れるように、夜だけ強化とも旧ストアとも分ける。
    private let deepFocusManagedSettingsStore = ManagedSettingsStore(
        named: .init(DeepFocusConstants.shieldStoreName)
    )
    /// 夜だけ強化の分は別ストアに置く。朝の解除でディープフォーカスまで外さないため、
    /// また拡張が夜間分だけを触れるようにするため（`NightShieldConstants.shieldStoreName`）。
    private let nightManagedSettingsStore = ManagedSettingsStore(
        named: .init(NightShieldConstants.shieldStoreName)
    )
    /// 常時ブロックだった頃の置き場。もう誰も書かないが、更新前に掛かったままの端末が残る。
    /// 空にし続けないと、窓が終わっても剥がれないブロックが更新直後の全員に残る。
    private let legacyManagedSettingsStore = ManagedSettingsStore(
        named: .init(DeepFocusConstants.legacyShieldStoreName)
    )
    /// 全解除・Free確定時に、日常ゲートの専用ストアも取り残さない。
    private let gateManagedSettingsStore = ManagedSettingsStore(
        named: .init(GateConstants.shieldStoreName)
    )
    private let decoder = JSONDecoder()

    init(ruleStore: RuleStore) {
        self.ruleStore = ruleStore
    }

    /// 完全ブロックを現在の権利とルールへ合わせる。
    ///
    /// 適用対象は選択データを持つ有効なルールのうち、窓のなかの `deepFocus` と、
    /// 夜の窓のなかの `nightOnly`（docs/12 §5）。
    /// カタログ由来の通常介入ルールは選択データが空のため触れない。
    ///
    /// `isNightWindow` と `isDeepFocusWindowActive` は呼び出し側が現在時刻から決めて渡す。
    /// 拡張の境界コールバックは取りこぼしがあるため、アプリが前面に来るたびのこの同期が
    /// 復旧経路になる。とくに完全ブロックは、窓が終わったのに解除が届かない状態を作らないため、
    /// ここを通るたびに窓の外なら必ず剥がす。
    ///
    /// `hasConfirmedEntitlement` が偽のあいだは何もしない。取得に失敗しただけの課金者から
    /// 完全ブロックを剥がさないため（`ShieldSyncPolicy` の `preserve`）。
    ///
    /// 解除だけはルールの読み取りより先に済ませる。読み取りが失敗する端末で
    /// `return` すると、Freeへ戻った人の完全ブロックが二度と外れなくなるため。
    func syncShield(
        entitlementGate: EntitlementGate,
        hasConfirmedEntitlement: Bool,
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool
    ) {
        // ルールの取得も含めて `ShieldSyncPolicy` に判断させる。
        // 取得してから判断する形にすると、読み取りが失敗する端末で
        // Freeへ戻った人の解除が落ちる（判断の順序をここで持たない）。
        switch ShieldSyncPolicy.action(
            rulesProvider: { try ruleStore.allRules() },
            isPro: entitlementGate.tier == .pro,
            strictModeAllowed: entitlementGate.strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            isNightWindow: isNightWindow,
            isDeepFocusWindowActive: isDeepFocusWindowActive
        ) {
        case .preserve:
            return
        case .clear:
            clearShield()
        case .apply(let rules):
            applyShield(rules: rules, entitlementGate: entitlementGate)
        }
    }

    private func applyShield(rules: [TargetRule], entitlementGate: EntitlementGate) {
        var deepFocusTokens = ShieldTokens()
        var nightTokens = ShieldTokens()
        // 上限は2つのストアで分け合う。ルールの並び順のまま先頭から数えるところは変えない。
        var remainingTargetTokenLimit = entitlementGate.targetAppTokensLimit

        for rule in applicableRules(from: rules, entitlementGate: entitlementGate) {
            let isNightRule = rule.mode == .nightOnly

            do {
                let selection = try decoder.decode(
                    FamilyActivitySelection.self,
                    from: rule.activitySelectionData
                )

                if isNightRule {
                    nightTokens.append(selection, remainingLimit: &remainingTargetTokenLimit)
                } else {
                    deepFocusTokens.append(selection, remainingLimit: &remainingTargetTokenLimit)
                }
            } catch {
                if isNightRule {
                    nightTokens.didFailDecodingSelection = true
                } else {
                    deepFocusTokens.didFailDecodingSelection = true
                }
                continue
            }
        }

        apply(deepFocusTokens, to: deepFocusManagedSettingsStore)
        apply(nightTokens, to: nightManagedSettingsStore)
        clear(legacyManagedSettingsStore)
    }

    func clearShield() {
        clear(deepFocusManagedSettingsStore)
        clear(nightManagedSettingsStore)
        clear(legacyManagedSettingsStore)
        clear(gateManagedSettingsStore)
    }

    /// 完全ブロックぶんだけを剥がす。窓の予定を張れなかったときに、
    /// 終わりの解除を出す担い手がいないままブロックを残さないための出口（`DeepFocusScheduler`）。
    func clearDeepFocusShield() {
        clear(deepFocusManagedSettingsStore)
    }

    /// 夜間ぶんだけを剥がす。夜の監視を張れなかったときに、朝の解除を出す担い手が
    /// いないままブロックを残さないための出口（`NightShieldScheduler`）。
    func clearNightShield() {
        clear(nightManagedSettingsStore)
    }

    /// 読み取れたぶんだけを反映する。1件でもデコードに失敗したときは解除しない。
    /// 壊れたルールを理由に、いま効いているブロックを剥がさないため。
    private func apply(_ tokens: ShieldTokens, to store: ManagedSettingsStore) {
        guard !tokens.isEmpty else {
            if tokens.didFailDecodingSelection {
                return
            }
            clear(store)
            return
        }

        store.shield.applications = tokens.applications.isEmpty ? nil : tokens.applications
        store.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories)
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
    }

    private func clear(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    private func applicableRules(
        from rules: [TargetRule],
        entitlementGate: EntitlementGate
    ) -> [TargetRule] {
        guard let limit = entitlementGate.targetRulesLimit else {
            return rules
        }
        return Array(rules.prefix(limit))
    }
}

/// 1つのストアへ流し込むぶんのトークン。昼と夜で別々に数える。
private struct ShieldTokens {
    var applications = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()
    var webDomains = Set<WebDomainToken>()
    var didFailDecodingSelection = false

    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }

    mutating func append(_ selection: FamilyActivitySelection, remainingLimit: inout Int?) {
        Self.appendTokens(
            selection.applicationTokens,
            to: &applications,
            remainingLimit: &remainingLimit
        )
        Self.appendTokens(
            selection.categoryTokens,
            to: &categories,
            remainingLimit: &remainingLimit
        )
        Self.appendTokens(
            selection.webDomainTokens,
            to: &webDomains,
            remainingLimit: &remainingLimit
        )
    }

    private static func appendTokens<Token: Hashable>(
        _ source: Set<Token>,
        to target: inout Set<Token>,
        remainingLimit: inout Int?
    ) {
        guard let limit = remainingLimit else {
            target.formUnion(source)
            return
        }

        guard limit > 0 else {
            return
        }

        let selected = source.prefix(limit)
        target.formUnion(selected)
        remainingLimit = limit - selected.count
    }
}
