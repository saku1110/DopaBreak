import DopaBreakCore
import Foundation
import XCTest
@testable import DopaBreak

final class CharacterViewTests: XCTestCase {
    func testPostUseSatisfactionMapsEveryCaseToItsCharacterExpression() {
        let expected: [(satisfaction: PostUseSatisfaction, expression: CharacterExpression)] = [
            (.satisfied, .awake),
            (.fun, .awake),
            (.nothingGained, .blank),
            (.lostTime, .doom),
            (.feltWorse, .worse),
        ]

        XCTAssertEqual(expected.map(\.satisfaction), PostUseSatisfaction.allCases)
        for mapping in expected {
            XCTAssertEqual(mapping.satisfaction.characterExpression, mapping.expression)
        }
    }

    @MainActor
    func testReduceMotionDisablesIdleFloatOffset() {
        let quarterCycle: TimeInterval = 0.4

        XCTAssertEqual(
            CharacterView.idleFloatOffset(elapsed: quarterCycle, reduceMotion: true),
            0
        )
        XCTAssertEqual(
            CharacterView.idleFloatOffset(elapsed: quarterCycle, reduceMotion: false),
            4,
            accuracy: 0.0001
        )
    }
}
