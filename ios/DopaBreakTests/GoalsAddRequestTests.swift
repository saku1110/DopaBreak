import Foundation
import XCTest
@testable import DopaBreak

final class GoalsAddRequestTests: XCTestCase {
    func testPresentsFirstRequestAfterNil() {
        XCTAssertTrue(
            GoalsAddRequestPolicy.shouldPresent(
                request: UUID(),
                consumed: nil
            )
        )
    }

    func testDoesNotPresentSameRequestTwice() {
        let request = UUID()

        XCTAssertFalse(
            GoalsAddRequestPolicy.shouldPresent(
                request: request,
                consumed: request
            )
        )
    }

    func testPresentsNewRequestAfterPreviousRequestWasConsumed() {
        XCTAssertTrue(
            GoalsAddRequestPolicy.shouldPresent(
                request: UUID(),
                consumed: UUID()
            )
        )
    }
}
