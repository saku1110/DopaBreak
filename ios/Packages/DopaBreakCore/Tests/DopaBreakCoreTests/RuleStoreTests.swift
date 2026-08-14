import Foundation
import XCTest
@testable import DopaBreakCore

final class RuleStoreTests: XCTestCase {
    func testCreatesRuleWithDefaultValues() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })

        let rule = try store.saveFamilyActivitySelection(sampleSelectionData(), name: " SNS ", mode: .standard)

        XCTAssertEqual(rule.name, "SNS")
        XCTAssertEqual(rule.activitySelectionData, sampleSelectionData())
        XCTAssertEqual(rule.mode, .standard)
        XCTAssertNil(rule.schedule)
        XCTAssertEqual(rule.delaySeconds, 0)
        XCTAssertNil(rule.maxOpensPerDay)
        XCTAssertEqual(rule.defaultDurationMinutes, 10)
        XCTAssertTrue(rule.isEnabled)
        XCTAssertEqual(rule.createdAt, date(0))
        XCTAssertEqual(rule.updatedAt, date(0))
    }

    func testAllRulesAreSortedByCreatedAtAscending() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })

        let third = try store.saveFamilyActivitySelection(sampleSelectionData(3), name: "Third", mode: .standard)
        clock.advance()
        let first = try store.saveFamilyActivitySelection(sampleSelectionData(1), name: "First", mode: .standard)
        clock.advance()
        let second = try store.saveFamilyActivitySelection(sampleSelectionData(2), name: "Second", mode: .standard)

        XCTAssertEqual(try store.allRules().map(\.id), [third.id, first.id, second.id])
    }

    func testUpdatesExistingRuleAndAdvancesUpdatedAt() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let original = try store.saveFamilyActivitySelection(
            sampleSelectionData(1),
            name: "SNS",
            mode: .standard
        )
        clock.advance()

        let updated = try store.saveFamilyActivitySelection(
            sampleSelectionData(2),
            name: " Work ",
            mode: .deepFocus,
            defaultDurationMinutes: 20,
            ruleId: original.id
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.name, "Work")
        XCTAssertEqual(updated.activitySelectionData, sampleSelectionData(2))
        XCTAssertEqual(updated.mode, .deepFocus)
        XCTAssertEqual(updated.defaultDurationMinutes, 20)
        XCTAssertEqual(updated.createdAt, original.createdAt)
        XCTAssertGreaterThan(updated.updatedAt, original.updatedAt)
        XCTAssertEqual(try store.allRules().count, 1)
    }

    func testEnabledRulesReturnsOnlyEnabledRules() throws {
        let store = try makeStore()
        let enabled = try store.saveFamilyActivitySelection(sampleSelectionData(1), name: "Enabled", mode: .standard)
        let disabled = try store.saveFamilyActivitySelection(sampleSelectionData(2), name: "Disabled", mode: .standard)
        try store.disableRule(id: disabled.id)

        XCTAssertEqual(try store.enabledRules().map(\.id), [enabled.id])
    }

    func testEnableAndDisableRoundTrip() throws {
        let store = try makeStore()
        let rule = try store.saveFamilyActivitySelection(sampleSelectionData(), name: "SNS", mode: .standard)

        try store.disableRule(id: rule.id)
        XCTAssertFalse(try XCTUnwrap(store.rule(id: rule.id)).isEnabled)

        try store.enableRule(id: rule.id)
        XCTAssertTrue(try XCTUnwrap(store.rule(id: rule.id)).isEnabled)
    }

    func testEnableAndDisableAdvanceUpdatedAt() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let rule = try store.saveFamilyActivitySelection(sampleSelectionData(), name: "SNS", mode: .standard)

        clock.advance()
        try store.disableRule(id: rule.id)
        let disabled = try XCTUnwrap(store.rule(id: rule.id))
        XCTAssertGreaterThan(disabled.updatedAt, rule.updatedAt)

        clock.advance()
        try store.enableRule(id: rule.id)
        let enabled = try XCTUnwrap(store.rule(id: rule.id))
        XCTAssertGreaterThan(enabled.updatedAt, disabled.updatedAt)
    }

    func testUpdateMode() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let rule = try store.saveFamilyActivitySelection(sampleSelectionData(), name: "SNS", mode: .standard)
        clock.advance()

        try store.updateMode(id: rule.id, mode: .nightOnly)

        let updated = try XCTUnwrap(store.rule(id: rule.id))
        XCTAssertEqual(updated.mode, .nightOnly)
        XCTAssertGreaterThan(updated.updatedAt, rule.updatedAt)
    }

    func testUpdateScheduleAndClearSchedule() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let rule = try store.saveFamilyActivitySelection(sampleSelectionData(), name: "SNS", mode: .standard)
        let schedule = ScheduleRule(
            weekdays: [2, 3, 4, 5, 6],
            startTime: DateComponents(hour: 9, minute: 0),
            endTime: DateComponents(hour: 18, minute: 30)
        )

        clock.advance()
        try store.updateSchedule(id: rule.id, schedule: schedule)
        let scheduled = try XCTUnwrap(store.rule(id: rule.id))
        XCTAssertEqual(scheduled.schedule, schedule)
        XCTAssertGreaterThan(scheduled.updatedAt, rule.updatedAt)

        clock.advance()
        try store.updateSchedule(id: rule.id, schedule: nil)
        let cleared = try XCTUnwrap(store.rule(id: rule.id))
        XCTAssertNil(cleared.schedule)
        XCTAssertGreaterThan(cleared.updatedAt, scheduled.updatedAt)
    }

    func testDeleteRule() throws {
        let store = try makeStore()
        let first = try store.saveFamilyActivitySelection(sampleSelectionData(1), name: "First", mode: .standard)
        let second = try store.saveFamilyActivitySelection(sampleSelectionData(2), name: "Second", mode: .standard)

        try store.deleteRule(id: first.id)

        XCTAssertNil(try store.rule(id: first.id))
        XCTAssertEqual(try store.allRules().map(\.id), [second.id])
    }

    func testUnknownIdThrowsValidationForSaveUpdate() throws {
        let store = try makeStore()

        XCTAssertValidationError(
            try store.saveFamilyActivitySelection(
                sampleSelectionData(),
                name: "SNS",
                mode: .standard,
                ruleId: uuid(404)
            )
        )
    }

    func testUnknownIdThrowsValidationForEnableDisableModeScheduleAndDelete() throws {
        let store = try makeStore()
        let missingId = uuid(404)

        XCTAssertValidationError(try store.enableRule(id: missingId))
        XCTAssertValidationError(try store.disableRule(id: missingId))
        XCTAssertValidationError(try store.updateMode(id: missingId, mode: .deepFocus))
        XCTAssertValidationError(try store.updateSchedule(id: missingId, schedule: nil))
        XCTAssertValidationError(try store.deleteRule(id: missingId))
    }

    func testPersistsAcrossStoreInstances() throws {
        let clock = TestClock()
        let containerURL = try makeTemporaryDirectory()
        let provider = FixedContainer(url: containerURL)
        let firstStore = RuleStore(
            snapshotStore: JSONSnapshotStore(containerProvider: provider),
            now: { clock.now() }
        )
        let saved = try firstStore.saveFamilyActivitySelection(
            sampleSelectionData(),
            name: "SNS",
            mode: .standard
        )

        let secondStore = RuleStore(snapshotStore: JSONSnapshotStore(containerProvider: provider))

        XCTAssertEqual(try secondStore.rule(id: saved.id), saved)
    }

    func testEmptyNameFailsValidation() throws {
        let store = try makeStore()

        XCTAssertValidationError(
            try store.saveFamilyActivitySelection(sampleSelectionData(), name: "   ", mode: .standard)
        )
    }

    func testNameLongerThanFortyCharactersFailsValidation() throws {
        let store = try makeStore()

        XCTAssertValidationError(
            try store.saveFamilyActivitySelection(
                sampleSelectionData(),
                name: String(repeating: "a", count: 41),
                mode: .standard
            )
        )
    }

    func testEmptySelectionDataFailsValidation() throws {
        let store = try makeStore()

        XCTAssertValidationError(
            try store.saveFamilyActivitySelection(Data(), name: "SNS", mode: .standard)
        )
    }

    func testCatalogTargetRuleAllowsEmptySelectionData() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))

        let rule = try store.catalogTargetRule(for: target)

        XCTAssertEqual(rule.name, "Instagram")
        XCTAssertTrue(rule.activitySelectionData.isEmpty)
        XCTAssertEqual(rule.mode, .standard)
        XCTAssertTrue(rule.isEnabled)
        XCTAssertEqual(try store.allRules(), [rule])
    }

    func testCatalogTargetRuleReusesExistingCatalogRule() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "youtube"))
        let first = try store.catalogTargetRule(for: target)
        clock.advance()

        let second = try store.catalogTargetRule(for: target)

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(try store.allRules().count, 1)
        XCTAssertGreaterThan(second.updatedAt, first.updatedAt)
    }

    /// 介入フローや起動要求は毎回 `catalogTargetRule(for:)` を通る。
    /// ここで既定値の `.standard` を書き戻すと、設定で選んだディープフォーカスが
    /// 開くたびに解除され、ペイウォールで売った機能が実体を失う（監査P0-B⑤）。
    func testCatalogTargetRuleKeepsStoredModeOfExistingRule() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let created = try store.catalogTargetRule(for: target)
        try store.updateMode(id: created.id, mode: .deepFocus)
        clock.advance()

        let reused = try store.catalogTargetRule(for: target)

        XCTAssertEqual(reused.id, created.id)
        XCTAssertEqual(reused.mode, .deepFocus)
        XCTAssertEqual(try store.rule(id: created.id)?.mode, .deepFocus)
    }

    /// 新規作成のときだけ初期モードを受け取る。既存ルールには適用しない。
    func testCatalogTargetRuleAppliesModeOnlyWhenCreating() throws {
        let clock = TestClock()
        let store = try makeStore(now: { clock.now() })
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "youtube"))

        let created = try store.catalogTargetRule(for: target, modeForNewRule: .deepFocus)
        XCTAssertEqual(created.mode, .deepFocus)

        clock.advance()
        let reused = try store.catalogTargetRule(for: target, modeForNewRule: .standard)

        XCTAssertEqual(reused.id, created.id)
        XCTAssertEqual(reused.mode, .deepFocus)
    }

    private func makeStore(now: @escaping @Sendable () -> Date = { Date() }) throws -> RuleStore {
        RuleStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory())),
            now: now
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuleStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func sampleSelectionData(_ value: UInt8 = 1) -> Data {
        Data([value, value + 1, value + 2])
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + offset))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func XCTAssertValidationError<T>(
        _ expression: @autoclosure () throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case CoreError.validation = error else {
                return XCTFail("Expected validation error, got \(error)", file: file, line: line)
            }
        }
    }
}

private final class TestClock: @unchecked Sendable {
    private var offset = 0

    func now() -> Date {
        Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + offset))
    }

    func advance() {
        offset += 1
    }
}
