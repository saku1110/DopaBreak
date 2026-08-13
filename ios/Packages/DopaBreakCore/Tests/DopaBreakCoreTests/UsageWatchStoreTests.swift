import Foundation
import XCTest
@testable import DopaBreakCore

final class UsageWatchStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UsageWatchStore!

    override func setUp() {
        super.setUp()
        suiteName = "UsageWatchStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = UsageWatchStore(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsAreFreeFifteenMinutesAndEmptyState() {
        XCTAssertEqual(store.loadConfiguration(), UsageWatchConfiguration())
        XCTAssertEqual(store.loadState(), UsageWatchState())
    }

    func testConfigurationAndStateRoundTrip() {
        let configuration = UsageWatchConfiguration(
            isPro: true,
            questionIntervalMinutes: 60,
            nightModeEnabled: true,
            bedTimeMinutes: 1_410,
            wakeTimeMinutes: 390,
            freeThresholdMinutes: 105,
            continuityGapMinutes: 19,
            dailyQuestionCap: 6
        )
        let state = UsageWatchState(
            stepEventTimestamps: [Date(timeIntervalSince1970: 1_800_000_000)],
            mutedUntil: Date(timeIntervalSince1970: 1_800_010_000),
            questionsSentToday: 3,
            freeWarningSentToday: true,
            lastInterventionAt: Date(timeIntervalSince1970: 1_799_999_500),
            dayStart: Date(timeIntervalSince1970: 1_799_971_200)
        )

        store.saveConfiguration(configuration)
        store.saveState(state)

        let reloaded = UsageWatchStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.loadConfiguration(), configuration)
        XCTAssertEqual(reloaded.loadState(), state)
    }

    func testConfigurationMutationPreservesOtherFields() {
        store.saveConfiguration(
            UsageWatchConfiguration(
                isPro: false,
                questionIntervalMinutes: 30,
                nightModeEnabled: true
            )
        )

        store.updateConfiguration { configuration in
            configuration.isPro = true
        }

        XCTAssertEqual(
            store.loadConfiguration(),
            UsageWatchConfiguration(
                isPro: true,
                questionIntervalMinutes: 30,
                nightModeEnabled: true
            )
        )
    }

    func testRecordInterventionOnlyUpdatesInterventionTimestamp() {
        let eventDate = Date(timeIntervalSince1970: 1_800_000_000)
        let intervention = eventDate.addingTimeInterval(60)
        store.saveState(
            UsageWatchState(
                stepEventTimestamps: [eventDate],
                questionsSentToday: 2
            )
        )

        store.recordIntervention(at: intervention)

        XCTAssertEqual(store.loadState().stepEventTimestamps, [eventDate])
        XCTAssertEqual(store.loadState().questionsSentToday, 2)
        XCTAssertEqual(store.loadState().lastInterventionAt, intervention)
    }

    func testMuteForTodayUsesCalendarDayEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 11,
            hour: 10
        ).date!
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!

        store.muteForToday(at: now, calendar: calendar)

        XCTAssertEqual(store.loadState().mutedUntil, nextMidnight)
    }

    func testDailyResetClearsDailyFieldsAndPreservesIntervention() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intervention = now.addingTimeInterval(-30)
        store.saveState(
            UsageWatchState(
                stepEventTimestamps: [now.addingTimeInterval(-60)],
                mutedUntil: now.addingTimeInterval(600),
                questionsSentToday: 4,
                freeWarningSentToday: true,
                lastInterventionAt: intervention
            )
        )

        store.resetDailyState(at: now, calendar: calendar)

        XCTAssertEqual(
            store.loadState(),
            UsageWatchState(
                lastInterventionAt: intervention,
                dayStart: calendar.startOfDay(for: now)
            )
        )
    }

    func testDailyResetIsIdempotentWhenMonitoringRestartsOnSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = UsageWatchState(
            stepEventTimestamps: [now.addingTimeInterval(-60)],
            mutedUntil: now.addingTimeInterval(600),
            questionsSentToday: 4,
            freeWarningSentToday: true,
            lastInterventionAt: now.addingTimeInterval(-30),
            dayStart: calendar.startOfDay(for: now)
        )
        store.saveState(state)

        store.resetDailyState(at: now, calendar: calendar)

        XCTAssertEqual(store.loadState(), state)
    }

    func testClearRemovesPersistedSnapshots() {
        store.saveConfiguration(UsageWatchConfiguration(isPro: true))
        store.saveState(UsageWatchState(questionsSentToday: 3))

        store.clear()

        XCTAssertEqual(store.loadConfiguration(), UsageWatchConfiguration())
        XCTAssertEqual(store.loadState(), UsageWatchState())
    }
}
