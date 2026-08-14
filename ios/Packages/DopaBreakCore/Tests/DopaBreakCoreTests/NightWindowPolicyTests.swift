import Foundation
import XCTest
@testable import DopaBreakCore

final class NightWindowPolicyTests: XCTestCase {
    // MARK: - 跨日の窓（23:00→7:00）

    func testIsNightAfterBedTimeOnTheSameDay() {
        XCTAssertTrue(isNight(hour: 23, minute: 30))
        XCTAssertTrue(isNight(hour: 2, minute: 0))
        XCTAssertTrue(isNight(hour: 6, minute: 59))
    }

    func testIsNotNightDuringTheDay() {
        XCTAssertFalse(isNight(hour: 7, minute: 1))
        XCTAssertFalse(isNight(hour: 12, minute: 0))
        XCTAssertFalse(isNight(hour: 22, minute: 59))
    }

    /// 就寝時刻ちょうどは夜。設定した時刻から止まらないと、1分の隙が残る。
    func testBedTimeItselfIsNight() {
        XCTAssertTrue(isNight(hour: 23, minute: 0))
    }

    /// 起床時刻ちょうどは昼。起きた瞬間まで止めない。
    func testWakeTimeItselfIsNotNight() {
        XCTAssertFalse(isNight(hour: 7, minute: 0))
    }

    // MARK: - 同日内の窓（1:00→5:00）

    func testSameDayWindowIncludesOnlyItsOwnRange() {
        XCTAssertTrue(isNight(hour: 1, minute: 0, bed: 60, wake: 300))
        XCTAssertTrue(isNight(hour: 4, minute: 59, bed: 60, wake: 300))
        XCTAssertFalse(isNight(hour: 5, minute: 0, bed: 60, wake: 300))
        XCTAssertFalse(isNight(hour: 0, minute: 59, bed: 60, wake: 300))
        XCTAssertFalse(isNight(hour: 23, minute: 0, bed: 60, wake: 300))
    }

    // MARK: - 縮退（就寝=起床）

    /// 幅ゼロを24時間と読むと、設定の初期化に失敗した端末が終日ブロックになる。
    func testSameBedAndWakeTimeIsNeverNight() {
        for hour in 0..<24 {
            XCTAssertFalse(
                isNight(hour: hour, minute: 0, bed: 1_380, wake: 1_380),
                "hour=\(hour)"
            )
        }
    }

    // MARK: - 窓の長さと最短15分

    func testWindowLengthCountsAcrossMidnight() {
        XCTAssertEqual(
            NightWindowPolicy.windowLengthMinutes(bedTimeMinutes: 1_380, wakeTimeMinutes: 420),
            480
        )
    }

    func testWindowLengthWithinTheSameDay() {
        XCTAssertEqual(
            NightWindowPolicy.windowLengthMinutes(bedTimeMinutes: 60, wakeTimeMinutes: 300),
            240
        )
    }

    /// 幅ゼロは0分。24時間とは読まない。
    func testWindowLengthIsZeroWhenBedEqualsWake() {
        XCTAssertEqual(
            NightWindowPolicy.windowLengthMinutes(bedTimeMinutes: 1_380, wakeTimeMinutes: 1_380),
            0
        )
    }

    func testWindowLengthNormalizesOutOfRangeMinutes() {
        XCTAssertEqual(
            NightWindowPolicy.windowLengthMinutes(
                bedTimeMinutes: 1_380 + 1_440,
                wakeTimeMinutes: 420 - 1_440
            ),
            480
        )
    }

    /// DeviceActivityが受け付けない14分の窓は、窓なしとして扱う。
    func testWindowShorterThanFifteenMinutesIsNotAWindow() {
        XCTAssertFalse(
            NightWindowPolicy.hasWindow(bedTimeMinutes: 1_380, wakeTimeMinutes: 1_380 + 14)
        )
        XCTAssertFalse(isNight(hour: 23, minute: 5, bed: 1_380, wake: 1_380 + 14))
    }

    func testWindowOfExactlyFifteenMinutesIsAWindow() {
        XCTAssertTrue(
            NightWindowPolicy.hasWindow(bedTimeMinutes: 1_380, wakeTimeMinutes: 1_380 + 15)
        )
        XCTAssertTrue(isNight(hour: 23, minute: 5, bed: 1_380, wake: 1_380 + 15))
        XCTAssertFalse(isNight(hour: 23, minute: 15, bed: 1_380, wake: 1_380 + 15))
    }

    /// 日をまたぐ短い窓（23:55→0:05＝10分）も窓なし。
    func testShortWindowAcrossMidnightIsNotAWindow() {
        XCTAssertFalse(NightWindowPolicy.hasWindow(bedTimeMinutes: 1_435, wakeTimeMinutes: 5))
        XCTAssertFalse(isNight(hour: 0, minute: 0, bed: 1_435, wake: 5))
    }

    func testBedEqualsWakeIsNotAWindow() {
        XCTAssertFalse(NightWindowPolicy.hasWindow(bedTimeMinutes: 1_380, wakeTimeMinutes: 1_380))
    }

    // MARK: - 控えでの検算（拡張の境界コールバック）

    func testSnapshotOverloadUsesTheStoredWindow() {
        let snapshot = NightShieldSnapshot(
            selectionDataList: [Data([0x01])],
            bedTimeMinutes: 1_380,
            wakeTimeMinutes: 420,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(
            NightWindowPolicy.isNight(
                now: date(hour: 2, minute: 0),
                snapshot: snapshot,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            NightWindowPolicy.isNight(
                now: date(hour: 9, minute: 0),
                snapshot: snapshot,
                calendar: calendar
            )
        )
    }

    /// 古い起床時刻の終了コールバックが新しい窓の最中に届く場面。
    /// 控えの窓で見れば夜のままなので、解除してはいけないと分かる。
    func testSnapshotOverloadKeepsNightAfterWakeTimeMovesLater() {
        let updated = NightShieldSnapshot(
            selectionDataList: [Data([0x01])],
            bedTimeMinutes: 1_380,
            wakeTimeMinutes: 540,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(
            NightWindowPolicy.isNight(
                now: date(hour: 7, minute: 0),
                snapshot: updated,
                calendar: calendar
            )
        )
    }

    // MARK: - 分の正規化

    func testNormalizesOutOfRangeMinutes() {
        // 1380+1440 と 420-1440 は、それぞれ 23:00 と 7:00 と同じ扱いになる。
        XCTAssertTrue(isNight(hour: 23, minute: 30, bed: 1_380 + 1_440, wake: 420 - 1_440))
        XCTAssertFalse(isNight(hour: 12, minute: 0, bed: 1_380 + 1_440, wake: 420 - 1_440))
    }

    func testNormalizedMinutesWrapsIntoASingleDay() {
        XCTAssertEqual(NightWindowPolicy.normalizedMinutes(0), 0)
        XCTAssertEqual(NightWindowPolicy.normalizedMinutes(1_439), 1_439)
        XCTAssertEqual(NightWindowPolicy.normalizedMinutes(1_440), 0)
        XCTAssertEqual(NightWindowPolicy.normalizedMinutes(1_500), 60)
        XCTAssertEqual(NightWindowPolicy.normalizedMinutes(-60), 1_380)
        XCTAssertEqual(NightWindowPolicy.normalizedMinutes(-1_440), 0)
    }

    /// 正規化で就寝と起床が同じ分に落ちる組み合わせも、窓なしとして扱う。
    func testWindowIsEmptyWhenNormalizationCollapsesBothEnds() {
        XCTAssertFalse(isNight(hour: 23, minute: 30, bed: 1_380, wake: 1_380 + 1_440))
    }

    // MARK: - Helpers

    private func isNight(
        hour: Int,
        minute: Int,
        bed: Int = 1_380,
        wake: Int = 420
    ) -> Bool {
        NightWindowPolicy.isNight(
            now: date(hour: hour, minute: minute),
            bedTimeMinutes: bed,
            wakeTimeMinutes: wake,
            calendar: calendar
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func date(hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2_026,
            month: 8,
            day: 14,
            hour: hour,
            minute: minute
        )
        guard let date = components.date else {
            XCTFail("failed to build a date for \(hour):\(minute)")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }
}
