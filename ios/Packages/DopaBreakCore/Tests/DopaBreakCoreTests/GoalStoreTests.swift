import Foundation
import XCTest
@testable import DopaBreakCore

final class GoalStoreTests: XCTestCase {
    func testSavesFlatGoalListInInsertionOrder() throws {
        let store = try makeStore()
        let first = sampleGoal(id: uuid(1), title: "First")
        let second = sampleGoal(id: uuid(2), title: "Second")
        let third = sampleGoal(id: uuid(3), title: "Third")

        try store.save(first)
        try store.save(second)
        try store.save(third)

        XCTAssertEqual(try store.goals().map(\.title), ["First", "Second", "Third"])
        XCTAssertEqual(try store.primaryGoal()?.title, "First")
    }

    func testUpdatesByIdPreservingPositionAndCreatedAt() throws {
        let store = try makeStore()
        let original = sampleGoal(
            id: uuid(1),
            title: " Original ",
            lockScreenTitle: " Short ",
            category: .study,
            createdAt: date(1),
            updatedAt: date(2)
        )
        let second = sampleGoal(id: uuid(2), title: "Second")
        let replacement = sampleGoal(
            id: uuid(1),
            title: " Replacement ",
            lockScreenTitle: " New ",
            category: .work,
            displayImagePath: "images/new.png",
            createdAt: date(3),
            updatedAt: date(4)
        )

        try store.save(original)
        try store.save(second)
        try store.save(replacement)

        let saved = try XCTUnwrap(store.goals().first)
        XCTAssertEqual(try store.goals().map(\.id), [original.id, second.id])
        XCTAssertEqual(saved.id, original.id)
        XCTAssertEqual(saved.createdAt, original.createdAt)
        XCTAssertEqual(saved.title, "Replacement")
        XCTAssertEqual(saved.lockScreenTitle, "New")
        XCTAssertEqual(saved.category, .work)
        XCTAssertEqual(saved.displayImagePath, "images/new.png")
        XCTAssertGreaterThan(saved.updatedAt, original.updatedAt)
    }

    func testDeleteByIDRemovesOnlyRequestedGoal() throws {
        let store = try makeStore()
        let first = sampleGoal(id: uuid(1), title: "First")
        let second = sampleGoal(id: uuid(2), title: "Second")
        try store.save(first)
        try store.save(second)

        try store.delete(id: first.id)

        XCTAssertEqual(try store.goals().map(\.id), [second.id])
    }

    func testMoveGoalChangesListOrder() throws {
        let store = try makeStore()
        try store.save(sampleGoal(id: uuid(1), title: "First"))
        try store.save(sampleGoal(id: uuid(2), title: "Second"))
        try store.save(sampleGoal(id: uuid(3), title: "Third"))

        try store.moveGoal(from: 2, to: 0)

        XCTAssertEqual(try store.goals().map(\.title), ["Third", "First", "Second"])
        XCTAssertEqual(try store.primaryGoal()?.title, "Third")
    }

    func testStoredArrayOrderIsPreservedWhenLoading() throws {
        let containerURL = try makeTemporaryDirectory()
        let snapshotStore = JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        let second = sampleGoal(id: uuid(2), title: "Second")
        let first = sampleGoal(id: uuid(1), title: "First")
        try snapshotStore.write([second, first], to: .goals)

        let store = GoalStore(snapshotStore: snapshotStore)

        XCTAssertEqual(try store.goals().map(\.title), ["Second", "First"])
        XCTAssertEqual(try store.primaryGoal()?.title, "Second")
    }

    func testLegacyYearFirstOrderMigratesAndPersistsHeroFirst() throws {
        let containerURL = try makeTemporaryDirectory()
        let snapshotStore = JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        let year = sampleGoal(id: uuid(2), title: "Year")
        let hero = sampleGoal(id: uuid(1), title: "Hero")
        try snapshotStore.write(
            [
                LegacyGoalFixture(goal: year, goalType: "year"),
                LegacyGoalFixture(goal: hero, goalType: "hero")
            ],
            to: .goals
        )

        let store = GoalStore(snapshotStore: snapshotStore)

        XCTAssertEqual(try store.goals().map(\.id), [hero.id, year.id])
        XCTAssertEqual(try store.primaryGoal()?.id, hero.id)

        let persistedData = try Data(contentsOf: snapshotStore.url(for: .goals))
        let persistedJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: persistedData) as? [[String: Any]]
        )
        XCTAssertEqual(persistedJSON.compactMap { $0["title"] as? String }, ["Hero", "Year"])
        XCTAssertTrue(persistedJSON.allSatisfy { $0["goalType"] == nil })
    }

    // MARK: - replace（まとめて置き換え）

    func testReplaceAppliesDeletionUpdateAndInsertionInOnePass() throws {
        let store = try makeStore()
        let kept = sampleGoal(id: uuid(1), title: "Kept", createdAt: date(1), updatedAt: date(2))
        let edited = sampleGoal(id: uuid(2), title: "Edited", category: .study, createdAt: date(3), updatedAt: date(4))
        let removed = sampleGoal(id: uuid(3), title: "Removed")
        try store.save(kept)
        try store.save(edited)
        try store.save(removed)

        var replacement = try store.goals()
        replacement.removeAll { $0.id == uuid(3) }
        replacement[1].title = "Renamed"
        replacement[1].lockScreenTitle = nil
        replacement.append(sampleGoal(id: uuid(4), title: "Added", lockScreenTitle: nil))

        try store.replace(goals: replacement)

        let stored = try store.goals()
        XCTAssertEqual(stored.map(\.id), [uuid(1), uuid(2), uuid(4)])
        XCTAssertEqual(stored.map(\.title), ["Kept", "Renamed", "Added"])
        // 書き換えた目標は作成日とカテゴリを保つ
        XCTAssertEqual(stored[1].category, .study)
        XCTAssertEqual(stored[1].createdAt, date(3))
        XCTAssertNil(stored[1].lockScreenTitle)
    }

    /// 16字の目標（オンボーディングの入力上限）はそのまま通る。
    func testReplaceAcceptsTitlesWithinTheStoreLimit() throws {
        let store = try makeStore()
        let sixteen = String(repeating: "あ", count: 16)

        try store.replace(goals: [sampleGoal(id: uuid(1), title: sixteen, lockScreenTitle: nil)])

        XCTAssertEqual(try store.goals().map(\.title), [sixteen])
    }

    /// 1件でも検証に落ちたら、何も書かずに元の状態を残す。
    func testReplaceRejectsInvalidGoalsWithoutTouchingStoredData() throws {
        let store = try makeStore()
        try store.save(sampleGoal(id: uuid(1), title: "First"))
        try store.save(sampleGoal(id: uuid(2), title: "Second"))
        let before = try store.goals()

        // 空タイトル
        XCTAssertValidationError(
            try store.replace(goals: [
                sampleGoal(id: uuid(1), title: "Renamed"),
                sampleGoal(id: uuid(2), title: "   ")
            ])
        )
        XCTAssertEqual(try store.goals(), before, "検証に落ちたのに書き込まれている")

        // 40字超
        XCTAssertValidationError(
            try store.replace(goals: [sampleGoal(id: uuid(1), title: String(repeating: "a", count: 41))])
        )
        XCTAssertEqual(try store.goals(), before)

        // ロック表示名の16字超
        XCTAssertValidationError(
            try store.replace(goals: [
                sampleGoal(id: uuid(1), title: "First", lockScreenTitle: String(repeating: "b", count: 17))
            ])
        )
        XCTAssertEqual(try store.goals(), before)

        // ID重複
        XCTAssertValidationError(
            try store.replace(goals: [
                sampleGoal(id: uuid(1), title: "First"),
                sampleGoal(id: uuid(1), title: "Duplicate")
            ])
        )
        XCTAssertEqual(try store.goals(), before)
    }

    /// 全消し（空配列）も置き換えとして通す。
    func testReplaceWithEmptyListClearsGoals() throws {
        let store = try makeStore()
        try store.save(sampleGoal(id: uuid(1), title: "First"))

        try store.replace(goals: [])

        XCTAssertTrue(try store.goals().isEmpty)
    }

    /// 中身が変わっていない目標の更新日時は動かさない。変わった目標だけ進める。
    func testReplaceKeepsUpdatedAtForUnchangedGoals() throws {
        let store = try makeStore()
        try store.save(sampleGoal(id: uuid(1), title: "Kept", lockScreenTitle: nil))
        try store.save(sampleGoal(id: uuid(2), title: "Edited", lockScreenTitle: nil))
        let before = try store.goals()

        // 保存日時はミリ秒までしか保たないため、同じミリ秒に収まると差が出ない。
        // 進んだことを見るために、書き込みの間隔を明示的に空ける
        Thread.sleep(forTimeInterval: 0.002)

        var replacement = before
        replacement[1].title = "Renamed"
        try store.replace(goals: replacement)

        let stored = try store.goals()
        XCTAssertEqual(stored[0], before[0], "触っていない目標が書き換わっている")
        XCTAssertGreaterThan(stored[1].updatedAt, before[1].updatedAt)
    }

    func testEmptyTitleFailsValidation() throws {
        let store = try makeStore()
        XCTAssertValidationError(try store.save(sampleGoal(title: "   ")))
    }

    func testTitleLongerThanFortyCharactersFailsValidation() throws {
        let store = try makeStore()
        XCTAssertValidationError(try store.save(sampleGoal(title: String(repeating: "a", count: 41))))
    }

    func testLockScreenTitleLongerThanSixteenCharactersFailsValidation() throws {
        let store = try makeStore()
        XCTAssertValidationError(
            try store.save(sampleGoal(lockScreenTitle: String(repeating: "b", count: 17)))
        )
    }

    func testPersistsAcrossStoreInstances() throws {
        let containerURL = try makeTemporaryDirectory()
        let provider = FixedContainer(url: containerURL)
        let firstStore = GoalStore(snapshotStore: JSONSnapshotStore(containerProvider: provider))
        try firstStore.save(sampleGoal(id: uuid(1), title: "Persisted"))
        try firstStore.save(sampleGoal(id: uuid(2), title: "Also Persisted"))

        let secondStore = GoalStore(snapshotStore: JSONSnapshotStore(containerProvider: provider))

        XCTAssertEqual(try secondStore.goals().map(\.title), ["Persisted", "Also Persisted"])
    }

    private func makeStore() throws -> GoalStore {
        GoalStore(snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory())))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func sampleGoal(
        id: UUID = UUID(),
        title: String = "Focus",
        lockScreenTitle: String? = "Focus",
        category: GoalCategory = .other,
        displayImagePath: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_001)
    ) -> Goal {
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

    private func XCTAssertValidationError(
        _ expression: @autoclosure () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case CoreError.validation = error else {
                return XCTFail("Expected validation error, got \(error)", file: file, line: line)
            }
        }
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + offset))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

private struct LegacyGoalFixture: Encodable {
    let id: UUID
    let goalType: String
    let title: String
    let lockScreenTitle: String?
    let category: GoalCategory
    let displayImagePath: String?
    let createdAt: Date
    let updatedAt: Date

    init(goal: Goal, goalType: String) {
        self.id = goal.id
        self.goalType = goalType
        self.title = goal.title
        self.lockScreenTitle = goal.lockScreenTitle
        self.category = goal.category
        self.displayImagePath = goal.displayImagePath
        self.createdAt = goal.createdAt
        self.updatedAt = goal.updatedAt
    }
}
