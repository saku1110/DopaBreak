import XCTest
@testable import DopaBreakCore

final class PostUseSatisfactionTests: XCTestCase {
    func testSatisfiedImpliesIncreasedHappiness() {
        XCTAssertEqual(PostUseSatisfaction.satisfied.impliedHappinessDelta, .increased)
    }

    func testFunImpliesIncreasedHappiness() {
        XCTAssertEqual(PostUseSatisfaction.fun.impliedHappinessDelta, .increased)
    }

    func testNothingGainedImpliesUnchangedHappiness() {
        XCTAssertEqual(PostUseSatisfaction.nothingGained.impliedHappinessDelta, .unchanged)
    }

    func testLostTimeImpliesDecreasedHappiness() {
        XCTAssertEqual(PostUseSatisfaction.lostTime.impliedHappinessDelta, .decreased)
    }

    func testFeltWorseImpliesDecreasedHappiness() {
        XCTAssertEqual(PostUseSatisfaction.feltWorse.impliedHappinessDelta, .decreased)
    }
}
