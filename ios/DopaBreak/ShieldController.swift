import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class ShieldController {
    private let ruleStore: RuleStore
    private let managedSettingsStore = ManagedSettingsStore(named: .init("dopabreak.rules"))
    private let decoder = JSONDecoder()

    init(ruleStore: RuleStore) {
        self.ruleStore = ruleStore
    }

    /// 完全ブロック（Deep Focus）を現在の権利とルールへ合わせる。
    ///
    /// 適用対象は `deepFocus` かつ選択データを持つ有効なルールだけ（docs/12 §5）。
    /// カタログ由来の通常介入ルールは選択データが空のため、ここでは触れない。
    ///
    /// `hasConfirmedEntitlement` が偽のあいだは何もしない。取得に失敗しただけの課金者から
    /// 完全ブロックを剥がさないため（`ShieldSyncPolicy` の `preserve`）。
    ///
    /// 解除だけはルールの読み取りより先に済ませる。読み取りが失敗する端末で
    /// `return` すると、Freeへ戻った人の完全ブロックが二度と外れなくなるため。
    func syncShield(entitlementGate: EntitlementGate, hasConfirmedEntitlement: Bool) {
        // ルールの取得も含めて `ShieldSyncPolicy` に判断させる。
        // 取得してから判断する形にすると、読み取りが失敗する端末で
        // Freeへ戻った人の解除が落ちる（判断の順序をここで持たない）。
        switch ShieldSyncPolicy.action(
            rulesProvider: { try ruleStore.allRules() },
            isPro: entitlementGate.tier == .pro,
            strictModeAllowed: entitlementGate.strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement
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
        var applicationTokens = Set<ApplicationToken>()
        var categoryTokens = Set<ActivityCategoryToken>()
        var webDomainTokens = Set<WebDomainToken>()
        var didFailDecodingSelection = false
        var remainingTargetTokenLimit = entitlementGate.targetAppTokensLimit

        for rule in applicableRules(from: rules, entitlementGate: entitlementGate) {
            do {
                let selection = try decoder.decode(
                    FamilyActivitySelection.self,
                    from: rule.activitySelectionData
                )

                appendTokens(
                    selection.applicationTokens,
                    to: &applicationTokens,
                    remainingLimit: &remainingTargetTokenLimit
                )
                appendTokens(
                    selection.categoryTokens,
                    to: &categoryTokens,
                    remainingLimit: &remainingTargetTokenLimit
                )
                appendTokens(
                    selection.webDomainTokens,
                    to: &webDomainTokens,
                    remainingLimit: &remainingTargetTokenLimit
                )
            } catch {
                didFailDecodingSelection = true
                continue
            }
        }

        guard !applicationTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty else {
            if didFailDecodingSelection {
                return
            }
            clearShield()
            return
        }

        managedSettingsStore.shield.applications = applicationTokens.isEmpty ? nil : applicationTokens
        managedSettingsStore.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        managedSettingsStore.shield.webDomains = webDomainTokens.isEmpty ? nil : webDomainTokens
    }

    func clearShield() {
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = nil
        managedSettingsStore.shield.webDomains = nil
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

    private func appendTokens<Token: Hashable>(
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
