import XCTest
@testable import DopaBreak

@MainActor
final class HapticFeedbackTests: XCTestCase {
    func testFeedbackGeneratorsDoNotCrash() {
        HapticFeedback.selection()
        HapticFeedback.success()
    }
}
