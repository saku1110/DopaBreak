import XCTest
@testable import DopaBreakCore

final class WakeSleepTimelinePolicyTests: XCTestCase {
    func testTimeForOffsetClampsTrackEdgesAndMapsMidpoint() {
        XCTAssertEqual(WakeSleepTimelinePolicy.time(forOffset: -20, trackWidth: 200), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.time(forOffset: 100, trackWidth: 200), 720)
        XCTAssertEqual(WakeSleepTimelinePolicy.time(forOffset: 220, trackWidth: 200), 1_439)
        XCTAssertEqual(WakeSleepTimelinePolicy.time(forOffset: 100, trackWidth: 0), 0)
    }

    func testOffsetForTimeClampsToTrackAndPreservesMidnightBoundary() {
        XCTAssertEqual(WakeSleepTimelinePolicy.offset(forTime: -1, trackWidth: 200), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.offset(forTime: 720, trackWidth: 200), 100, accuracy: 0.001)
        XCTAssertEqual(WakeSleepTimelinePolicy.offset(forTime: 1_440, trackWidth: 200), 200, accuracy: 0.001)
        XCTAssertEqual(WakeSleepTimelinePolicy.offset(forTime: 720, trackWidth: 0), 0)
    }

    func testSnappedUsesFifteenMinuteStepsAtDayBoundaries() {
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(-1), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(7), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(8), 15)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_432), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_433), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_440), 0)
    }

    func testOvernightSchedulesPreserveBothCircularArcs() {
        XCTAssertTrue(WakeSleepTimelinePolicy.hasValidArcs(wake: 420, bed: 1_380))
        XCTAssertTrue(WakeSleepTimelinePolicy.hasValidArcs(wake: 300, bed: 60))
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(420, bed: 1_380), 420)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(60, wake: 300), 60)
    }

    func testDraggingEitherHandleClampsOnlyMovingHandleInOvernightSchedule() {
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(75, bed: 60), 120)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(30, bed: 60), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(390, wake: 420), 360)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(450, wake: 420), 480)
    }

    func testMidnightBoundaryKeepsAtLeastOneHourOnBothArcs() {
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(0, bed: 60), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(0, wake: 1_380), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(1_425, bed: 0), 1_380)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(15, wake: 0), 60)
    }

    func testPickerPathPreservesExactMinutesWhileApplyingCircularClamp() {
        XCTAssertEqual(
            WakeSleepTimelinePolicy.clampedWake(427, bed: 61, snapToStep: false),
            427
        )
        XCTAssertEqual(
            WakeSleepTimelinePolicy.clampedBed(91, wake: 427, snapToStep: false),
            91
        )
        XCTAssertEqual(
            WakeSleepTimelinePolicy.clampedBed(400, wake: 427, snapToStep: false),
            367
        )
    }

    func testSnapBoundaryAcross2345And0015RemainsCircular() {
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_425), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_433), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(15), 15)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(1_425, bed: 15), 1_395)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(15, wake: 1_425), 45)
    }
}
