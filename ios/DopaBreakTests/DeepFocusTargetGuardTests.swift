import DopaBreakCore
import XCTest
@testable import DopaBreak

final class DeepFocusTargetGuardTests: XCTestCase {
    func testHasDeepFocusTargetsIsFalseWithoutRules() {
        XCTAssertFalse(DeepFocusTargetGuard.hasTargets(in: []))
    }

    func testHasDeepFocusTargetsIsFalseForEmptySelectionData() {
        XCTAssertFalse(DeepFocusTargetGuard.hasTargets(in: [rule(selectionData: Data())]))
    }

    func testHasDeepFocusTargetsIsTrueForNonemptySelectionData() {
        XCTAssertTrue(DeepFocusTargetGuard.hasTargets(in: [rule(selectionData: Data([0x01]))]))
    }

    private func rule(selectionData: Data) -> TargetRule {
        TargetRule(
            id: UUID(),
            name: "Target",
            activitySelectionData: selectionData,
            mode: .deepFocus,
            schedule: nil,
            delaySeconds: 3,
            maxOpensPerDay: nil,
            defaultDurationMinutes: 15,
            isEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
