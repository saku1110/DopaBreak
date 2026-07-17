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
