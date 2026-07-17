import XCTest
@testable import DopaBreakCore

final class IntentInterventionStyleTests: XCTestCase {
    func testPurposefulIntentsUseDirectFlow() {
        let purposeful: [IntentCategory] = [.workRequired, .research, .communication, .posting]
        XCTAssertTrue(purposeful.allSatisfy { $0.interventionStyle == .direct })
    }

    func testReflexiveIntentsUseReflectiveFlow() {
        let reflexive: [IntentCategory] = [.boredom, .anxietyCheck, .unconscious, .other]
        XCTAssertTrue(reflexive.allSatisfy { $0.interventionStyle == .reflective })
    }
}
