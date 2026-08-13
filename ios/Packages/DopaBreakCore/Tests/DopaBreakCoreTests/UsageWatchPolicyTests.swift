import Foundation
import XCTest
@testable import DopaBreakCore

final class UsageWatchPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testContinuityGapAtTwentyMinutesJoinsCurrentRun() {
        let configuration = proConfiguration(interval: 15)
        let first = evaluate(at: date(day: 11, hour: 10), step: 1, config: configuration)

        let second = evaluate(
            at: date(day: 11, hour: 10, minute: 20),
            step: 2,
            state: first.state,
            config: configuration
        )

        XCTAssertEqual(first.decision, .question(.q15))
        XCTAssertEqual(second.decision, .question(.q30))
        XCTAssertEqual(second.state.stepEventTimestamps.count, 2)
    }

    func testContinuityGapOverTwentyMinutesStartsNewRun() {
        let configuration = proConfiguration(interval: 15)
        let first = evaluate(at: date(day: 11, hour: 10), step: 1, config: configuration)

        let second = evaluate(
            at: date(day: 11, hour: 10, minute: 20, second: 1),
            step: 2,
            state: first.state,
            config: configuration
        )

        XCTAssertEqual(second.decision, .question(.q15))
    }

    func testFreeWarningFiresAtTwoHoursAndOnlyOncePerDay() {
        let configuration = UsageWatchConfiguration(isPro: false)
        var state = UsageWatchState()
        var decisions: [UsageWatchDecision] = []

        for step in 1...9 {
            let result = evaluate(
                at: date(day: 11, hour: 10, minute: (step - 1) * 15),
                step: step,
                state: state,
                config: configuration
            )
            decisions.append(result.decision)
            state = result.state
        }

        XCTAssertEqual(Array(decisions.prefix(7)), Array(repeating: .none, count: 7))
        XCTAssertEqual(decisions[7], .freeWarning)
        XCTAssertEqual(decisions[8], .none)
        XCTAssertTrue(state.freeWarningSentToday)
    }

    func testProQuestionsEscalateByContinuousRunElapsedTime() {
        let configuration = proConfiguration(interval: 15)
        var state = UsageWatchState()
        var decisions: [UsageWatchDecision] = []

        for step in 1...8 {
            let result = evaluate(
                at: date(day: 11, hour: 10, minute: (step - 1) * 15),
                step: step,
                state: state,
                config: configuration
            )
            decisions.append(result.decision)
            state = result.state
        }

        // 15/30/45分は毎段、60分以降は1時間ごと（75/90/105分は鳴らさない）。
        XCTAssertEqual(
            decisions,
            [
                .question(.q15),
                .question(.q30),
                .question(.q45),
                .question(.hourly),
                .none,
                .none,
                .none,
                .question(.hourly)
            ]
        )
        XCTAssertEqual(state.questionsSentToday, 5)
    }

    func testNightModeDoesNotShortenHourlyPhaseBelowOneHour() {
        let configuration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 30,
            nightModeEnabled: true,
            bedTimeMinutes: 1_260,
            wakeTimeMinutes: 420
        )
        var state = UsageWatchState()
        var decisions: [UsageWatchDecision] = []

        for step in 1...6 {
            let result = evaluate(
                at: date(day: 11, hour: 22, minute: (step - 1) * 15),
                step: step,
                state: state,
                config: configuration
            )
            decisions.append(result.decision)
            state = result.state
        }

        // 夜間は30分→15分へ詰まるが、60分以降は1時間ごとのまま。
        XCTAssertEqual(
            decisions,
            [
                .question(.q15),
                .question(.q30),
                .question(.q45),
                .question(.hourly),
                .none,
                .none
            ]
        )
    }

    func testThirtyMinuteIntervalOnlyQuestionsAtMultiples() {
        let decisions = decisionsForFourContinuousSteps(configuration: proConfiguration(interval: 30))

        XCTAssertEqual(decisions, [.none, .question(.q30), .none, .question(.hourly)])
    }

    func testSixtyMinuteIntervalOnlyQuestionsAtMultiples() {
        let decisions = decisionsForFourContinuousSteps(configuration: proConfiguration(interval: 60))

        XCTAssertEqual(decisions, [.none, .none, .none, .question(.hourly)])
    }

    func testNightModeHalvesSixtyMinuteIntervalToThirty() {
        let configuration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 60,
            nightModeEnabled: true,
            bedTimeMinutes: 0,
            wakeTimeMinutes: 420
        )
        let first = evaluate(at: date(day: 11, hour: 23), step: 1, config: configuration)
        let second = evaluate(
            at: date(day: 11, hour: 23, minute: 15),
            step: 2,
            state: first.state,
            config: configuration
        )

        XCTAssertEqual(first.decision, .none)
        XCTAssertEqual(second.decision, .question(.q30))
    }

    func testNightModeWindowWrapsAcrossMidnight() {
        let configuration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 30,
            nightModeEnabled: true,
            bedTimeMinutes: 30,
            wakeTimeMinutes: 420
        )

        let beforeMidnight = evaluate(
            at: date(day: 11, hour: 23, minute: 45),
            step: 1,
            config: configuration
        )
        let afterMidnight = evaluate(
            at: date(day: 12, hour: 0, minute: 15),
            step: 1,
            config: configuration
        )
        let wakeBoundaryConfiguration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 60,
            nightModeEnabled: true,
            bedTimeMinutes: 30,
            wakeTimeMinutes: 420
        )
        let beforeWake = evaluate(
            at: date(day: 12, hour: 6, minute: 45),
            step: 1,
            config: wakeBoundaryConfiguration
        )
        let atWakeTime = evaluate(
            at: date(day: 12, hour: 7),
            step: 2,
            state: beforeWake.state,
            config: wakeBoundaryConfiguration
        )

        XCTAssertEqual(beforeMidnight.decision, .question(.q15))
        XCTAssertEqual(afterMidnight.decision, .question(.q15))
        XCTAssertEqual(atWakeTime.decision, .none)
    }

    func testNightModeNeverReducesIntervalBelowLadderGranularity() {
        let configuration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 15,
            nightModeEnabled: true,
            bedTimeMinutes: 0,
            wakeTimeMinutes: 420
        )

        let result = evaluate(at: date(day: 11, hour: 23), step: 1, config: configuration)

        XCTAssertEqual(result.decision, .question(.q15))
    }

    func testDailyQuestionCapSuppressesAdditionalQuestions() {
        let configuration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 15,
            dailyQuestionCap: 2
        )
        var state = UsageWatchState()

        let first = evaluate(at: date(day: 11, hour: 10), step: 1, state: state, config: configuration)
        state = first.state
        let second = evaluate(at: date(day: 11, hour: 10, minute: 15), step: 2, state: state, config: configuration)
        state = second.state
        let third = evaluate(at: date(day: 11, hour: 10, minute: 30), step: 3, state: state, config: configuration)

        XCTAssertEqual(first.decision, .question(.q15))
        XCTAssertEqual(second.decision, .question(.q30))
        XCTAssertEqual(third.decision, .none)
        XCTAssertEqual(third.state.questionsSentToday, 2)
    }

    func testMuteSuppressesQuestionButStillRecordsEvent() {
        let eventDate = date(day: 11, hour: 10)
        let state = UsageWatchState(mutedUntil: date(day: 12, hour: 0))

        let result = evaluate(
            at: eventDate,
            step: 1,
            state: state,
            config: proConfiguration(interval: 15)
        )

        XCTAssertEqual(result.decision, .none)
        XCTAssertEqual(result.state.stepEventTimestamps, [eventDate])
        XCTAssertEqual(result.state.questionsSentToday, 0)
    }

    func testExpiredMuteIsCleared() {
        let state = UsageWatchState(mutedUntil: date(day: 11, hour: 9))

        let result = evaluate(
            at: date(day: 11, hour: 10),
            step: 1,
            state: state,
            config: proConfiguration(interval: 15)
        )

        XCTAssertEqual(result.decision, .question(.q15))
        XCTAssertNil(result.state.mutedUntil)
    }

    func testInterventionInsideApproximateRunSuppressesQuestionsUntilRunEnds() {
        let intervention = date(day: 11, hour: 10, minute: 5)
        var state = UsageWatchState(lastInterventionAt: intervention)

        let first = evaluate(
            at: date(day: 11, hour: 10, minute: 15),
            step: 1,
            state: state,
            config: proConfiguration(interval: 15)
        )
        state = first.state
        let second = evaluate(
            at: date(day: 11, hour: 10, minute: 30),
            step: 2,
            state: state,
            config: proConfiguration(interval: 15)
        )
        state = second.state
        let newRun = evaluate(
            at: date(day: 11, hour: 11),
            step: 3,
            state: state,
            config: proConfiguration(interval: 15)
        )

        XCTAssertEqual(first.decision, .none)
        XCTAssertEqual(second.decision, .none)
        XCTAssertEqual(newRun.decision, .question(.q15))
    }

    func testDayRolloverResetsDailyFieldsAndRetainsLastIntervention() {
        let intervention = date(day: 11, hour: 18)
        let state = UsageWatchState(
            stepEventTimestamps: [date(day: 11, hour: 23, minute: 45)],
            mutedUntil: date(day: 12, hour: 0),
            questionsSentToday: 8,
            freeWarningSentToday: true,
            lastInterventionAt: intervention,
            dayStart: date(day: 11, hour: 0)
        )

        let result = evaluate(
            at: date(day: 12, hour: 0, minute: 15),
            step: 1,
            state: state,
            config: proConfiguration(interval: 15)
        )

        XCTAssertEqual(result.decision, .question(.q15))
        XCTAssertEqual(result.state.stepEventTimestamps, [date(day: 12, hour: 0, minute: 15)])
        XCTAssertEqual(result.state.questionsSentToday, 1)
        XCTAssertFalse(result.state.freeWarningSentToday)
        XCTAssertNil(result.state.mutedUntil)
        XCTAssertEqual(result.state.lastInterventionAt, intervention)
        XCTAssertEqual(result.state.dayStart, date(day: 12, hour: 0))
    }

    func testInvalidStepIndexIsIgnored() {
        let result = evaluate(
            at: date(day: 11, hour: 10),
            step: 25,
            config: proConfiguration(interval: 15)
        )

        XCTAssertEqual(result.decision, .none)
        XCTAssertEqual(result.state, UsageWatchState())
    }

    private func decisionsForFourContinuousSteps(
        configuration: UsageWatchConfiguration
    ) -> [UsageWatchDecision] {
        var state = UsageWatchState()
        return (1...4).map { step in
            let result = evaluate(
                at: date(day: 11, hour: 10, minute: (step - 1) * 15),
                step: step,
                state: state,
                config: configuration
            )
            state = result.state
            return result.decision
        }
    }

    private func proConfiguration(interval: Int) -> UsageWatchConfiguration {
        UsageWatchConfiguration(isPro: true, questionIntervalMinutes: interval)
    }

    private func evaluate(
        at eventDate: Date,
        step: Int,
        state: UsageWatchState = UsageWatchState(),
        config: UsageWatchConfiguration
    ) -> (decision: UsageWatchDecision, state: UsageWatchState) {
        UsageWatchPolicy.evaluate(
            newEventAt: eventDate,
            stepIndex: step,
            state: state,
            config: config,
            calendar: calendar
        )
    }

    private func date(
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ).date!
    }
}
