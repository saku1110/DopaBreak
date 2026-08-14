import Foundation

public struct RuleStore: Sendable {
    private let snapshotStore: JSONSnapshotStore
    private let now: @Sendable () -> Date

    public init(
        snapshotStore: JSONSnapshotStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.snapshotStore = snapshotStore
        self.now = now
    }

    public func allRules() throws -> [TargetRule] {
        let rules = try snapshotStore.read([TargetRule].self, from: .rules) ?? []
        return ordered(rules)
    }

    public func rule(id: UUID) throws -> TargetRule? {
        try allRules().first { $0.id == id }
    }

    public func enabledRules() throws -> [TargetRule] {
        try allRules().filter(\.isEnabled)
    }

    /// カタログのアプリに対応するルールを取り出す。無ければ作る。
    ///
    /// `modeForNewRule` は**新規作成時の初期値**であり、既存ルールには適用しない。
    /// 介入フローや起動要求のたびにここを通るため、既定値で上書きすると
    /// ユーザーが設定で選んだモード（ディープフォーカス等）が毎回 `.standard` へ落ちる。
    /// モードを変えるのは `updateMode(id:mode:)` / `saveFamilyActivitySelection` の明示的な経路だけ。
    @discardableResult
    public func catalogTargetRule(
        for target: SNSAppCatalogItem,
        modeForNewRule: InterventionMode = .standard,
        defaultDurationMinutes: Int = 10
    ) throws -> TargetRule {
        let validatedName = try validatedRuleName(target.displayName)
        var rules = try allRules()
        let timestamp = now()

        if let index = rules.firstIndex(where: { $0.activitySelectionData.isEmpty && $0.name == validatedName }) {
            var rule = rules[index]
            rule.defaultDurationMinutes = defaultDurationMinutes
            rule.isEnabled = true
            rule.updatedAt = timestamp
            rules[index] = rule
            try snapshotStore.write(ordered(rules), to: .rules)
            return rule
        }

        let rule = TargetRule(
            id: UUID(),
            name: validatedName,
            activitySelectionData: Data(),
            mode: modeForNewRule,
            schedule: nil,
            delaySeconds: 0,
            maxOpensPerDay: nil,
            defaultDurationMinutes: defaultDurationMinutes,
            isEnabled: true,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        rules.append(rule)
        try snapshotStore.write(ordered(rules), to: .rules)
        return rule
    }

    @discardableResult
    public func saveFamilyActivitySelection(
        _ selectionData: Data,
        name: String,
        mode: InterventionMode,
        defaultDurationMinutes: Int = 10,
        ruleId: UUID? = nil
    ) throws -> TargetRule {
        guard !selectionData.isEmpty else {
            throw CoreError.validation(message: "止めるアプリを選択してください")
        }

        let validatedName = try validatedRuleName(name)
        var rules = try allRules()
        let timestamp = now()
        let savedRule: TargetRule

        if let ruleId {
            guard let index = rules.firstIndex(where: { $0.id == ruleId }) else {
                throw unknownRuleError()
            }

            var updated = rules[index]
            updated.name = validatedName
            updated.activitySelectionData = selectionData
            updated.mode = mode
            updated.defaultDurationMinutes = defaultDurationMinutes
            updated.updatedAt = timestamp
            rules[index] = updated
            savedRule = updated
        } else {
            let rule = TargetRule(
                id: UUID(),
                name: validatedName,
                activitySelectionData: selectionData,
                mode: mode,
                schedule: nil,
                delaySeconds: 0,
                maxOpensPerDay: nil,
                defaultDurationMinutes: defaultDurationMinutes,
                isEnabled: true,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            rules.append(rule)
            savedRule = rule
        }

        try snapshotStore.write(ordered(rules), to: .rules)
        return savedRule
    }

    public func enableRule(id: UUID) throws {
        try updateRule(id: id) { rule in
            rule.isEnabled = true
        }
    }

    public func disableRule(id: UUID) throws {
        try updateRule(id: id) { rule in
            rule.isEnabled = false
        }
    }

    public func updateMode(id: UUID, mode: InterventionMode) throws {
        try updateRule(id: id) { rule in
            rule.mode = mode
        }
    }

    public func updateSchedule(id: UUID, schedule: ScheduleRule?) throws {
        try updateRule(id: id) { rule in
            rule.schedule = schedule
        }
    }

    public func deleteRule(id: UUID) throws {
        var rules = try allRules()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw unknownRuleError()
        }
        rules.remove(at: index)
        try snapshotStore.write(ordered(rules), to: .rules)
    }

    public func deleteAll() throws {
        try snapshotStore.write([TargetRule](), to: .rules)
    }

    private func updateRule(id: UUID, mutate: (inout TargetRule) -> Void) throws {
        var rules = try allRules()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw unknownRuleError()
        }

        mutate(&rules[index])
        rules[index].updatedAt = now()
        try snapshotStore.write(ordered(rules), to: .rules)
    }

    private func validatedRuleName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmed.count) else {
            throw CoreError.validation(message: "ルール名は1文字以上40文字以内で入力してください")
        }
        return trimmed
    }

    private func ordered(_ rules: [TargetRule]) -> [TargetRule] {
        rules.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func unknownRuleError() -> CoreError {
        CoreError.validation(message: "指定されたルールが見つかりません")
    }
}
