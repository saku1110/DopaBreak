import XCTest

@testable import DopaBreak

final class HomeStatsLinkDestinationTests: XCTestCase {
    func testWeeklyReportAccessRoutesToStatsTab() {
        XCTAssertEqual(
            HomeStatsLinkDestination(weeklyReportAllowed: true),
            .statsTab
        )
    }

    func testMissingWeeklyReportAccessRoutesToStatsHistoryGate() {
        XCTAssertEqual(
            HomeStatsLinkDestination(weeklyReportAllowed: false),
            .statsHistoryGate
        )
    }

    func testReclaimedTimeFormatterBoundariesInAllSupportedLanguages() throws {
        let cases: [(
            seconds: Int,
            ja: (time: String, equivalent: String?),
            en: (time: String, equivalent: String?),
            ko: (time: String, equivalent: String?)
        )] = [
            (59 * 60, ("59分", nil), ("59 min", nil), ("59분", nil)),
            (60 * 60, ("1時間", nil), ("1 hr", nil), ("1시간", nil)),
            (23 * 3_600 + 59 * 60, ("23時間", nil), ("23 hr", nil), ("23시간", nil)),
            (24 * 3_600, ("24時間", "1日分"), ("24 hr", "= 1 day"), ("24시간", "1일치")),
            (
                364 * 86_400 + 23 * 3_600,
                ("8759時間", "364日分"),
                ("8759 hr", "= 364 days"),
                ("8759시간", "364일치")
            ),
            (365 * 86_400, ("8760時間", "1年分"), ("8760 hr", "= 1 yr"), ("8760시간", "1년치")),
            (
                366 * 86_400,
                ("8784時間", "1年 1日分"),
                ("8784 hr", "= 1 yr 1 day"),
                ("8784시간", "1년 1일치")
            )
        ]
        let appBundle = Bundle(for: AppDelegate.self)
        let jaBundle = try localizedBundle(language: "ja", in: appBundle)
        let enBundle = try localizedBundle(language: "en", in: appBundle)
        let koBundle = try localizedBundle(language: "ko", in: appBundle)

        for value in cases {
            assertFormatted(value.ja, seconds: value.seconds, bundle: jaBundle, locale: Locale(identifier: "ja"))
            assertFormatted(value.en, seconds: value.seconds, bundle: enBundle, locale: Locale(identifier: "en"))
            assertFormatted(value.ko, seconds: value.seconds, bundle: koBundle, locale: Locale(identifier: "ko"))
        }
    }

    func testEstimatedMinutesFallsBackWhenTodayHasCountButNoSeconds() {
        XCTAssertEqual(
            ReclaimedTimeFormatter.estimatedMinutesPerCancellation(
                todayReclaimedSeconds: 0,
                todayCancellationCount: 1,
                fallbackSeconds: 300
            ),
            5
        )
    }

    private func localizedBundle(language: String, in bundle: Bundle) throws -> Bundle {
        let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func assertFormatted(
        _ expected: (time: String, equivalent: String?),
        seconds: Int,
        bundle: Bundle,
        locale: Locale,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            ReclaimedTimeFormatter.string(seconds: seconds, bundle: bundle, locale: locale),
            expected.time,
            file: file,
            line: line
        )
        XCTAssertEqual(
            ReclaimedTimeFormatter.equivalentString(seconds: seconds, bundle: bundle, locale: locale),
            expected.equivalent,
            file: file,
            line: line
        )
    }
}
