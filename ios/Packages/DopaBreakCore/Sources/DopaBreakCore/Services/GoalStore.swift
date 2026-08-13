import Foundation

public struct GoalStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore) {
        self.snapshotStore = snapshotStore
    }

    public func goals() throws -> [Goal] {
        try migrateLegacyGoalOrderIfNeeded()
        return try snapshotStore.read([Goal].self, from: .goals) ?? []
    }

    public func allGoals() throws -> [Goal] {
        try goals()
    }

    public func primaryGoal() throws -> Goal? {
        try goals().first
    }

    public func save(_ goal: Goal) throws {
        let validated = try validatedGoal(goal)
        var goals = try goals()
        let now = Date()

        if let index = goals.firstIndex(where: { $0.id == validated.id }) {
            let existing = goals[index]
            goals[index] = replacing(existing, with: validated, updatedAt: now)
        } else {
            goals.append(inserting(validated, updatedAt: now))
        }

        try snapshotStore.write(goals, to: .goals)
    }

    /// 目標の全件を一度に置き換える。
    ///
    /// 削除・更新・追加を`save`/`delete`で積み上げると、途中で失敗したときに
    /// 半分だけ適用された状態が残る。まとめて確定したい経路（オンボーディングの目標同期）のために、
    /// 全件を検証してから1回だけ書き込む。1件でも検証に落ちたら何も書かない。
    ///
    /// `createdAt`は既存の値を保つ。`updatedAt`は中身が変わった目標だけ進める。
    public func replace(goals newGoals: [Goal]) throws {
        let validated = try newGoals.map(validatedGoal)
        guard Set(validated.map(\.id)).count == validated.count else {
            throw CoreError.validation(message: "同じ目標が重複しています")
        }

        let existingByID = Dictionary(
            try goals().map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let now = Date()
        let normalized = validated.map { goal -> Goal in
            guard let existing = existingByID[goal.id] else {
                return inserting(goal, updatedAt: now)
            }
            // 中身が同じ目標のupdatedAtは動かさない
            let unchanged = replacing(existing, with: goal, updatedAt: existing.updatedAt)
            return unchanged == existing ? existing : replacing(existing, with: goal, updatedAt: now)
        }

        try snapshotStore.write(normalized, to: .goals)
    }

    public func delete(id: UUID) throws {
        var goals = try goals()
        guard let index = goals.firstIndex(where: { $0.id == id }) else {
            throw CoreError.validation(message: "指定された目標が見つかりません")
        }
        goals.remove(at: index)
        try snapshotStore.write(goals, to: .goals)
    }

    public func deleteAll() throws {
        try snapshotStore.write([Goal](), to: .goals)
    }

    public func moveGoal(from sourceIndex: Int, to destinationIndex: Int) throws {
        var goals = try goals()
        guard goals.indices.contains(sourceIndex) else {
            throw CoreError.validation(message: "指定された目標が見つかりません")
        }
        guard destinationIndex >= 0 && destinationIndex < goals.count else {
            throw CoreError.validation(message: "指定された移動先が見つかりません")
        }
        guard sourceIndex != destinationIndex else {
            return
        }

        let goal = goals.remove(at: sourceIndex)
        goals.insert(goal, at: min(destinationIndex, goals.count))
        try snapshotStore.write(goals, to: .goals)
    }

    private func validatedGoal(_ goal: Goal) throws -> Goal {
        let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(title.count) else {
            throw CoreError.validation(message: "目標は1文字以上40文字以内で入力してください")
        }

        let lockScreenTitle = try validatedLockScreenTitle(goal.lockScreenTitle)
        var validated = goal
        validated.title = title
        validated.lockScreenTitle = lockScreenTitle
        return validated
    }

    private func validatedLockScreenTitle(_ value: String?) throws -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...16).contains(trimmed.count) else {
            throw CoreError.validation(message: "ロック画面用の表示名は16文字以内で入力してください")
        }
        return trimmed
    }

    private func replacing(_ existing: Goal, with newGoal: Goal, updatedAt: Date) -> Goal {
        Goal(
            id: existing.id,
            title: newGoal.title,
            lockScreenTitle: newGoal.lockScreenTitle,
            category: newGoal.category,
            displayImagePath: newGoal.displayImagePath,
            createdAt: existing.createdAt,
            updatedAt: updatedAt
        )
    }

    private func inserting(_ goal: Goal, updatedAt: Date) -> Goal {
        var inserted = goal
        inserted.updatedAt = updatedAt
        return inserted
    }

    private func migrateLegacyGoalOrderIfNeeded() throws {
        guard let legacyGoals = try? snapshotStore.read([LegacyPersistedGoal].self, from: .goals),
              legacyGoals.allSatisfy({ $0.goalType == "hero" || $0.goalType == "year" }) else {
            return
        }

        let heroIndices = legacyGoals.indices.filter { legacyGoals[$0].goalType == "hero" }
        guard heroIndices.count == 1, let heroIndex = heroIndices.first, heroIndex != legacyGoals.startIndex else {
            return
        }

        var reorderedGoals = legacyGoals
        let heroGoal = reorderedGoals.remove(at: heroIndex)
        reorderedGoals.insert(heroGoal, at: 0)
        try snapshotStore.write(reorderedGoals.map(\.goal), to: .goals)
    }
}

private struct LegacyPersistedGoal: Decodable {
    let id: UUID
    let goalType: String
    let title: String
    let lockScreenTitle: String?
    let category: GoalCategory
    let displayImagePath: String?
    let createdAt: Date
    let updatedAt: Date

    var goal: Goal {
        Goal(
            id: id,
            title: title,
            lockScreenTitle: lockScreenTitle,
            category: category,
            displayImagePath: displayImagePath,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
