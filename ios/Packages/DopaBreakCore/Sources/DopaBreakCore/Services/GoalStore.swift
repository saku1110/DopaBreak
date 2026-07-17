import Foundation

public struct GoalStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore) {
        self.snapshotStore = snapshotStore
    }

    public func goals() throws -> [Goal] {
        let goals = try snapshotStore.read([Goal].self, from: .goals) ?? []
        return orderedForMigration(goals)
    }

    public func allGoals() throws -> [Goal] {
        try goals()
    }

    public func primaryGoal() throws -> Goal? {
        try goals().first
    }

    public func goal(of type: GoalType) throws -> Goal? {
        try goals().first { $0.goalType == type }
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

    public func delete(id: UUID) throws {
        var goals = try goals()
        guard let index = goals.firstIndex(where: { $0.id == id }) else {
            throw CoreError.validation(message: "指定された目標が見つかりません")
        }
        goals.remove(at: index)
        try snapshotStore.write(goals, to: .goals)
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

    public func deleteGoal(of type: GoalType) throws {
        var goals = try goals()
        guard let index = goals.firstIndex(where: { $0.goalType == type }) else {
            return
        }
        goals.remove(at: index)
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
            goalType: newGoal.goalType,
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

    private func orderedForMigration(_ goals: [Goal]) -> [Goal] {
        guard goals.count <= GoalType.allCases.count else {
            return goals
        }

        let goalTypes = goals.map(\.goalType)
        guard Set(goalTypes).count == goalTypes.count else {
            return goals
        }

        return GoalType.allCases.compactMap { type in
            goals.first { $0.goalType == type }
        }
    }
}
