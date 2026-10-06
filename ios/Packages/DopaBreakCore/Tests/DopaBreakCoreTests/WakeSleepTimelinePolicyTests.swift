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
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_433), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_435), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_439), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_440), 1_425)
    }

    func testTrackRightEdgeNeverSnapsBackToMidnight() {
        let trackWidth = 300.0

        for offset in [trackWidth - 1, trackWidth] {
            let time = WakeSleepTimelinePolicy.time(forOffset: offset, trackWidth: trackWidth)
            XCTAssertEqual(WakeSleepTimelinePolicy.snapped(time), WakeSleepTimelinePolicy.latestMinute)
        }
    }

    func testOvernightSchedulesPreserveBothCircularArcs() {
        XCTAssertTrue(WakeSleepTimelinePolicy.hasValidArcs(wake: 420, bed: 1_380))
        XCTAssertTrue(WakeSleepTimelinePolicy.hasValidArcs(wake: 300, bed: 60))
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(420, bed: 1_380, current: 420), 420)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(60, wake: 300, current: 60), 60)
    }

    func testDraggingEitherHandleClampsOnlyMovingHandleInOvernightSchedule() {
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(75, bed: 60, current: 120), 120)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(30, bed: 60, current: 0), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(390, wake: 420, current: 360), 360)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(450, wake: 420, current: 480), 480)
    }

    func testMidnightBoundaryKeepsAtLeastOneHourOnBothArcs() {
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(0, bed: 60, current: 0), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(0, wake: 1_380, current: 0), 0)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(1_425, bed: 0, current: 1_380), 1_380)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(15, wake: 0, current: 60), 60)
    }

    func testPickerPathPreservesExactMinutesWhileApplyingCircularClamp() {
        XCTAssertEqual(
            WakeSleepTimelinePolicy.clampedWake(427, bed: 61, current: 420, snapToStep: false),
            427
        )
        XCTAssertEqual(
            WakeSleepTimelinePolicy.clampedBed(91, wake: 427, current: 60, snapToStep: false),
            91
        )
        XCTAssertEqual(
            WakeSleepTimelinePolicy.clampedBed(400, wake: 427, current: 367, snapToStep: false),
            367
        )
    }

    func testSnapBoundaryAcross2345And0015RemainsCircular() {
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_425), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(1_433), 1_425)
        XCTAssertEqual(WakeSleepTimelinePolicy.snapped(15), 15)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedWake(1_425, bed: 15, current: 1_395), 1_395)
        XCTAssertEqual(WakeSleepTimelinePolicy.clampedBed(15, wake: 1_425, current: 45), 45)
    }

    func testWakeDragStaysOnItsStartingSideWhenSweepingAcrossBedtime() {
        let bed = 23 * 60
        var currentWake = 22 * 60

        for proposedWake in (22 * 60)...WakeSleepTimelinePolicy.minutesPerDay {
            let nextWake = WakeSleepTimelinePolicy.clampedWake(
                proposedWake,
                bed: bed,
                current: currentWake
            )
            XCTAssertLessThanOrEqual(
                circularDistance(currentWake, nextWake),
                WakeSleepTimelinePolicy.stepMinutes
            )
            currentWake = nextWake
        }

        for proposedWake in 0...(1 * 60) {
            let nextWake = WakeSleepTimelinePolicy.clampedWake(
                proposedWake,
                bed: bed,
                current: currentWake
            )
            XCTAssertEqual(nextWake, 22 * 60)
            currentWake = nextWake
        }
    }

    func testWakeDragStaysOnItsStartingSideWhenSweepingBackAcrossBedtime() {
        let bed = 23 * 60
        var currentWake = 1 * 60

        for proposedWake in stride(from: 1 * 60, through: 0, by: -1) {
            let nextWake = WakeSleepTimelinePolicy.clampedWake(
                proposedWake,
                bed: bed,
                current: currentWake
            )
            XCTAssertLessThanOrEqual(
                circularDistance(currentWake, nextWake),
                WakeSleepTimelinePolicy.stepMinutes
            )
            currentWake = nextWake
        }

        for proposedWake in stride(from: WakeSleepTimelinePolicy.minutesPerDay - 1, through: 22 * 60, by: -1) {
            let nextWake = WakeSleepTimelinePolicy.clampedWake(
                proposedWake,
                bed: bed,
                current: currentWake
            )
            XCTAssertEqual(nextWake, 0)
            currentWake = nextWake
        }
    }

    func testPickerCanSetDaytimeSleepScheduleAcrossTheOtherHandle() {
        let wake = WakeSleepTimelinePolicy.clampedWake(
            17 * 60,
            bed: 23 * 60,
            current: 7 * 60,
            snapToStep: false
        )
        let bed = WakeSleepTimelinePolicy.clampedBed(
            9 * 60,
            wake: wake,
            current: 23 * 60,
            snapToStep: false
        )

        XCTAssertEqual(wake, 17 * 60)
        XCTAssertEqual(bed, 9 * 60)
        XCTAssertTrue(WakeSleepTimelinePolicy.hasValidArcs(wake: wake, bed: bed))
    }

    private func circularDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let forward = WakeSleepTimelinePolicy.normalized(rhs - lhs)
        return min(forward, WakeSleepTimelinePolicy.minutesPerDay - forward)
    }
}
