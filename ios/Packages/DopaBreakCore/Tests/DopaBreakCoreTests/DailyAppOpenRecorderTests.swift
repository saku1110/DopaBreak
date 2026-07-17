import Foundation
import XCTest
@testable import DopaBreakCore

final class DailyAppOpenRecorderTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "DailyAppOpenRecorderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordsOncePerLocalCalendarDayAcrossRecorderInstances() throws {
        let eventStore = try makeEventStore()
        let calendar = tokyoCalendar
        let first = try date(year: 2026, month: 7, day: 17, hour: 0, minute: 1, calendar: calendar)
        let sameDay = try date(year: 2026, month: 7, day: 17, hour: 23, minute: 59, calendar: calendar)
        let nextDay = try date(year: 2026, month: 7, day: 18, hour: 0, minute: 1, calendar: calendar)

        let firstRecorder = DailyAppOpenRecorder(
            settingsStore: settingsStore,
            funnelEventStore: eventStore,
            calendar: calendar
        )
        XCTAssertTrue(try firstRecorder.recordIfNeeded(at: first))

        let reloadedSettingsStore = SettingsStore(userDefaults: defaults)
        let reloadedRecorder = DailyAppOpenRecorder(
            settingsStore: reloadedSettingsStore,
            funnelEventStore: eventStore,
            calendar: calendar
        )
        XCTAssertFalse(try reloadedRecorder.recordIfNeeded(at: sameDay))
        XCTAssertTrue(try reloadedRecorder.recordIfNeeded(at: nextDay))

        XCTAssertEqual(reloadedSettingsStore.lastAppOpenedDateKey, "2026-07-18")
        XCTAssertEqual(
            try eventStore.allEvents(),
            [
                FunnelEvent(name: FunnelEventName.appOpened.rawValue, occurredAt: first),
                FunnelEvent(name: FunnelEventName.appOpened.rawValue, occurredAt: nextDay)
            ]
        )
    }

    func testDoesNotRecordEarlierDayOrDoubleCountAfterClockReturns() throws {
        let eventStore = try makeEventStore()
        let calendar = tokyoCalendar
        let dayD = try date(year: 2026, month: 7, day: 17, hour: 12, minute: 0, calendar: calendar)
        let dayBefore = try date(year: 2026, month: 7, day: 16, hour: 12, minute: 0, calendar: calendar)
        let dayDAgain = try date(year: 2026, month: 7, day: 17, hour: 18, minute: 0, calendar: calendar)
        let dayAfter = try date(year: 2026, month: 7, day: 18, hour: 0, minute: 1, calendar: calendar)
        let recorder = DailyAppOpenRecorder(
            settingsStore: settingsStore,
            funnelEventStore: eventStore,
            calendar: calendar
        )

        XCTAssertTrue(try recorder.recordIfNeeded(at: dayD))
        XCTAssertFalse(try recorder.recordIfNeeded(at: dayBefore))
        XCTAssertFalse(try recorder.recordIfNeeded(at: dayDAgain))
        XCTAssertTrue(try recorder.recordIfNeeded(at: dayAfter))

        XCTAssertEqual(settingsStore.lastAppOpenedDateKey, "2026-07-18")
        XCTAssertEqual(
            try eventStore.allEvents(),
            [
                FunnelEvent(name: FunnelEventName.appOpened.rawValue, occurredAt: dayD),
                FunnelEvent(name: FunnelEventName.appOpened.rawValue, occurredAt: dayAfter)
            ]
        )
    }

    private var tokyoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) throws -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func makeEventStore() throws -> FunnelEventStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyAppOpenRecorderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return FunnelEventStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: url))
        )
    }
}
