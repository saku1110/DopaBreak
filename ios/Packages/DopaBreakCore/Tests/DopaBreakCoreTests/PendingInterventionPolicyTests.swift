import Foundation
import XCTest
@testable import DopaBreakCore

final class PendingInterventionPolicyTests: XCTestCase {
    func testTemporaryAllowanceIsActiveForMatchingRuleBeforeItsDeadline() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ruleId = UUID()
        let activeState = InterventionState(
            currentStep: .temporarilyAllowed,
            ruleId: ruleId,
            startedAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60),
            allowedUntil: now.addingTimeInterval(60)
        )

        XCTAssertTrue(activeState.hasActiveTemporaryAllowance(at: now, for: ruleId))
    }

    func testTemporaryAllowanceIsInactiveForDifferentRule() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = InterventionState(
            currentStep: .temporarilyAllowed,
            ruleId: UUID(),
            startedAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60),
            allowedUntil: now.addingTimeInterval(60)
        )

        XCTAssertFalse(state.hasActiveTemporaryAllowance(at: now, for: UUID()))
    }

    func testTemporaryAllowanceExpiresAtDeadline() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ruleId = UUID()
        let state = InterventionState(
            currentStep: .temporarilyAllowed,
            ruleId: ruleId,
            startedAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60),
            allowedUntil: now
        )

        XCTAssertFalse(
            state.hasActiveTemporaryAllowance(at: now, for: ruleId),
            "the allowance expires at allowedUntil"
        )
    }

    func testTemporaryAllowanceIsInactiveOutsideTemporaryStep() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ruleId = UUID()
        let state = InterventionState(
            currentStep: .decision,
            ruleId: ruleId,
            startedAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60),
            allowedUntil: now.addingTimeInterval(60)
        )

        XCTAssertFalse(state.hasActiveTemporaryAllowance(at: now, for: ruleId))
    }

}
