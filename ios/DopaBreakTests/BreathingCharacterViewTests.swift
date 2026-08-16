import XCTest

@testable import DopaBreak

final class BreathingCharacterViewTests: XCTestCase {
    func testSupportedDurationsProduceExactlyOneBreathPeak() {
        for totalSeconds in [3, 5, 8] {
            let timeline = BreathCharacterTimeline(totalSeconds: totalSeconds)
            let milliseconds = totalSeconds * 1_000
            let scales = (0...milliseconds).map { millisecond in
                Double(timeline.scale(at: TimeInterval(millisecond) / 1_000))
            }
            let reducedMotionOpacities = (0...milliseconds).map { millisecond in
                timeline.opacity(
                    at: TimeInterval(millisecond) / 1_000,
                    reduceMotion: true
                )
            }

            XCTAssertEqual(localMaximumCount(in: scales), 1)
            XCTAssertEqual(
                localMaximumCount(in: reducedMotionOpacities),
                1
            )
        }
    }

    func testReducedMotionUsesOpacityBreathingWhileStandardMotionStaysOpaque() {
        for totalSeconds in [3, 5, 8] {
            let timeline = BreathCharacterTimeline(totalSeconds: totalSeconds)
            let milliseconds = totalSeconds * 1_000
            var maximumCurveDifference = 0.0

            for millisecond in 0..<Int(timeline.reliefStart * 1_000) {
                let elapsed = TimeInterval(millisecond) / 1_000
                let scaleLevel = (Double(timeline.scale(at: elapsed)) - 1) / 0.06
                let opacityLevel = (
                    timeline.opacity(at: elapsed, reduceMotion: true) - 0.85
                ) / 0.15
                maximumCurveDifference = max(
                    maximumCurveDifference,
                    abs(scaleLevel - opacityLevel)
                )
            }

            XCTAssertLessThanOrEqual(maximumCurveDifference, 0.000_001)
            XCTAssertEqual(
                timeline.opacity(at: 0, reduceMotion: true),
                0.85,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                timeline.opacity(
                    at: timeline.totalDuration / 2,
                    reduceMotion: true
                ),
                1,
                accuracy: 0.000_001
            )

            for millisecond in Int(timeline.reliefStart * 1_000)...milliseconds {
                let elapsed = TimeInterval(millisecond) / 1_000
                XCTAssertEqual(
                    timeline.opacity(at: elapsed, reduceMotion: true),
                    1,
                    accuracy: 0.000_001
                )
            }

            XCTAssertTrue((0...milliseconds).allSatisfy { millisecond in
                timeline.opacity(
                    at: TimeInterval(millisecond) / 1_000,
                    reduceMotion: false
                ) == 1
            })
        }
    }

    func testThreeSecondTimelineMovesDirectlyFromBlinkToRelief() {
        let timeline = BreathCharacterTimeline(totalSeconds: 3)

        XCTAssertEqual(timeline.expression(at: 0).rawValue, CharacterExpression.blink.rawValue)
        XCTAssertEqual(timeline.expression(at: 2.19).rawValue, CharacterExpression.blink.rawValue)
        XCTAssertEqual(timeline.expression(at: 2.20).rawValue, CharacterExpression.relief.rawValue)
        XCTAssertEqual(timeline.scale(at: 1.5), 1.06, accuracy: 0.000_001)
        XCTAssertEqual(timeline.scale(at: 3), 1, accuracy: 0.000_001)
    }

    func testThreeSecondTimelineNeverUsesDoomAcrossEntireDuration() {
        let timeline = BreathCharacterTimeline(totalSeconds: 3)

        for millisecond in 0...3_000 {
            let elapsed = TimeInterval(millisecond) / 1_000
            XCTAssertNotEqual(
                timeline.expression(at: elapsed).rawValue,
                CharacterExpression.doom.rawValue,
                "Unexpected doom expression at elapsed=\(elapsed)"
            )
        }
    }

    func testFiveSecondTimelineSwitchesToReliefAtFourPointTwoSeconds() {
        let timeline = BreathCharacterTimeline(totalSeconds: 5)

        XCTAssertEqual(timeline.reliefStart, 4.2, accuracy: 0.000_001)
        XCTAssertEqual(
            timeline.expression(at: 2.49).rawValue,
            CharacterExpression.blink.rawValue
        )
        XCTAssertEqual(
            timeline.expression(at: 2.50).rawValue,
            CharacterExpression.doom.rawValue
        )
        XCTAssertEqual(
            timeline.expression(at: timeline.reliefStart - 0.000_001).rawValue,
            CharacterExpression.doom.rawValue
        )
        XCTAssertEqual(
            timeline.expression(at: timeline.reliefStart).rawValue,
            CharacterExpression.relief.rawValue
        )
        XCTAssertEqual(
            timeline.expression(at: timeline.reliefStart + 0.000_001).rawValue,
            CharacterExpression.relief.rawValue
        )
    }

    func testLongerTimelineUsesDoomDuringExhaleAndReliefAtPointEightSecondsRemaining() {
        let timeline = BreathCharacterTimeline(totalSeconds: 8)

        XCTAssertEqual(timeline.reliefStart, 7.2, accuracy: 0.000_001)
        XCTAssertEqual(timeline.expression(at: 3.99).rawValue, CharacterExpression.blink.rawValue)
        XCTAssertEqual(timeline.expression(at: 4.00).rawValue, CharacterExpression.doom.rawValue)
        XCTAssertEqual(
            timeline.expression(at: timeline.reliefStart - 0.000_001).rawValue,
            CharacterExpression.doom.rawValue
        )
        XCTAssertEqual(
            timeline.expression(at: timeline.reliefStart).rawValue,
            CharacterExpression.relief.rawValue
        )
    }

    func testScaleAlwaysStaysWithinRequiredBounds() {
        for totalSeconds in [3, 5, 8] {
            let timeline = BreathCharacterTimeline(totalSeconds: totalSeconds)
            for step in 0...1_000 {
                let elapsed = timeline.totalDuration * Double(step) / 1_000
                let scale = timeline.scale(at: elapsed)
                XCTAssertGreaterThanOrEqual(scale, 1)
                XCTAssertLessThanOrEqual(scale, 1.06)
            }
            XCTAssertEqual(
                timeline.scale(at: timeline.totalDuration / 2),
                1.06,
                accuracy: 0.000_001
            )
        }
    }

    private func localMaximumCount(in values: [Double]) -> Int {
        var wasIncreasing = false
        var maximumCount = 0

        for (previous, current) in zip(values, values.dropFirst()) {
            let delta = current - previous
            if delta > 0.000_000_000_001 {
                wasIncreasing = true
            } else if delta < -0.000_000_000_001, wasIncreasing {
                maximumCount += 1
                wasIncreasing = false
            }
        }

        return maximumCount
    }
}
