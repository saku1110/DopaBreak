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

    func syncShield(entitlementGate: EntitlementGate) {
        let rules: [TargetRule]
        do {
            rules = try ruleStore.enabledRules()
        } catch {
            return
        }

        guard !rules.isEmpty else {
            clearShield()
            return
        }

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
