import DopaBreakCore
import XCTest

@testable import DopaBreak

final class StatsReclaimedTimeTests: XCTestCase {
    func testHeroTimeFormattingAcrossAllPeriodsAndBoundaries() throws {
        let bundle = try japaneseBundle()
        let cases: [(seconds: Int, detailed: String, allTime: String, equivalent: String?)] = [
            (59 * 60, "59分", "59分", nil),
            (60 * 60, "1時間", "1時間", nil),
            (23 * 3_600 + 59 * 60, "23時間59分", "23時間", nil),
            (24 * 3_600, "24時間", "24時間", "1日分")
        ]

        for value in cases {
            XCTAssertEqual(
                StatsPresentation.heroTimeText(
                    seconds: value.seconds,
                    period: .today,
                    bundle: bundle,
                    locale: Locale(identifier: "ja")
                ),
                value.detailed
            )
            XCTAssertEqual(
                StatsPresentation.heroTimeText(
                    seconds: value.seconds,
                    period: .week,
                    bundle: bundle,
                    locale: Locale(identifier: "ja")
                ),
                value.detailed
            )
            XCTAssertEqual(
                StatsPresentation.heroTimeText(
                    seconds: value.seconds,
                    period: .all,
                    bundle: bundle,
                    locale: Locale(identifier: "ja")
                ),
                value.allTime
            )
            XCTAssertEqual(
                ReclaimedTimeFormatter.equivalentString(
                    seconds: value.seconds,
                    bundle: bundle,
                    locale: Locale(identifier: "ja")
                ),
                value.equivalent
            )
        }
    }

    func testWeeklyComparisonCoversMoreLessSameAndNoData() {
        XCTAssertEqual(
            StatsWeekComparison(currentSeconds: 7_200, previousSeconds: 3_600),
            .more(3_600)
        )
        XCTAssertEqual(
            StatsWeekComparison(currentSeconds: 1_800, previousSeconds: 3_600),
            .less(1_800)
        )
        XCTAssertEqual(
            StatsWeekComparison(currentSeconds: 3_600, previousSeconds: 3_600),
            .same
        )
        XCTAssertEqual(
            StatsWeekComparison(currentSeconds: 3_600, previousSeconds: nil),
            .noData
        )
    }

    func testBasisVisibilityAndZeroSecondFallback() {
        XCTAssertFalse(StatsPresentation.shouldShowBasis(cancellationCount: 0))
        XCTAssertTrue(StatsPresentation.shouldShowBasis(cancellationCount: 1))
        XCTAssertEqual(
            ReclaimedTimeFormatter.estimatedMinutesPerCancellation(
                todayReclaimedSeconds: 0,
                todayCancellationCount: 1,
                fallbackSeconds: 900
            ),
            15
        )
    }

    func testAppAndIntentOrderingUsesReclaimedSeconds() {
        XCTAssertTrue(
            StatsPresentation.appSortsBefore(
                title: "Later alphabetically",
                seconds: 600,
                than: "Earlier alphabetically",
                rhsSeconds: 300
            )
        )
        XCTAssertTrue(
            StatsPresentation.appSortsBefore(
                title: "A app",
                seconds: 300,
                than: "B app",
                rhsSeconds: 300
            )
        )
        XCTAssertTrue(
            StatsPresentation.intentSortsBefore(
                category: .unconscious,
                seconds: 600,
                than: .workRequired,
                rhsSeconds: 0
            )
        )
        XCTAssertTrue(
            StatsPresentation.intentSortsBefore(
                category: .workRequired,
                seconds: 0,
                than: .research,
                rhsSeconds: 0
            )
        )
        XCTAssertTrue(StatsPresentation.shouldShowIntent(attemptCount: 1))
        XCTAssertFalse(StatsPresentation.shouldShowIntent(attemptCount: 0))
    }

    func testAppMetricsLinkReclaimedSecondsBeforeSortingRows() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let rules = [
            targetRule(id: firstID, name: "First"),
            targetRule(id: secondID, name: "Second")
        ]

        let metrics = StatsPresentation.appMetrics(
            from: [
                firstID: (attempts: 4, cancelled: 2),
                secondID: (attempts: 3, cancelled: 1)
            ],
            reclaimedSeconds: [firstID: 120, secondID: 600],
            rules: rules
        )

        XCTAssertEqual(metrics.map(\.title), ["Second", "First"])
        XCTAssertEqual(metrics.map(\.reclaimedSeconds), [600, 120])
        XCTAssertEqual(metrics.map(\.cancelled), [1, 2])
    }

    func testAppMetricsAggregateRemovedAndUnnamedRulesAtEndWithoutLosingHeroSeconds() throws {
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let removedID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let unnamedID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let rules = [
            targetRule(id: activeID, name: "Active"),
            targetRule(id: unnamedID, name: "  \n ")
        ]
        let reclaimedByRule = [activeID: 120, removedID: 600, unnamedID: 300]
        let heroSeconds = reclaimedByRule.values.reduce(0, +)

        let metrics = StatsPresentation.appMetrics(
            from: [
                activeID: (attempts: 2, cancelled: 1),
                removedID: (attempts: 4, cancelled: 3),
                unnamedID: (attempts: 2, cancelled: 2)
            ],
            reclaimedSeconds: reclaimedByRule,
            rules: rules,
            bundle: try japaneseBundle()
        )

        XCTAssertEqual(metrics.map(\.title), ["Active", "対象から外したアプリ"])
        XCTAssertEqual(metrics.last?.ruleID, StatsAppMetric.removedAggregateRuleID)
        XCTAssertEqual(metrics.last?.attempts, 6)
        XCTAssertEqual(metrics.last?.cancelled, 5)
        XCTAssertEqual(metrics.last?.reclaimedSeconds, 900)
        XCTAssertEqual(metrics.map(\.reclaimedSeconds).reduce(0, +), heroSeconds)
    }

    func testLegacyAnxietyMergesIntoCommunicationForCountsAndSeconds() {
        let merged = StatsPresentation.mergedLegacyIntentValues(
            counts: [.communication: 2, .anxietyCheck: 3, .research: 1],
            reclaimedSeconds: [.communication: 120, .anxietyCheck: 300, .research: 60]
        )

        XCTAssertEqual(merged.counts[.communication], 5)
        XCTAssertEqual(merged.reclaimedSeconds[.communication], 420)
        XCTAssertNil(merged.counts[.anxietyCheck])
        XCTAssertNil(merged.reclaimedSeconds[.anxietyCheck])
    }

    func testZeroSecondIntentMetricDisplaysZeroMinutes() throws {
        let bundle = try japaneseBundle()
        XCTAssertEqual(
            StatsPresentation.intentMetricText(
                title: "連絡を確認",
                seconds: 0,
                bundle: bundle,
                locale: Locale(identifier: "ja")
            ),
            "連絡を確認 0分"
        )
    }

    func testComparisonTextAndAccentRangeAreAvailableInAllSupportedLanguages() throws {
        let cases = [
            ("ja", "先週より +1時間"),
            ("en", "1 hr more than last week"),
            ("ko", "지난주보다 +1시간")
        ]

        for (language, expected) in cases {
            let bundle = try localizedBundle(language: language)
            let locale = Locale(identifier: language)
            let text = StatsPresentation.comparisonText(
                currentSeconds: 7_200,
                previousSeconds: 3_600,
                isComparable: true,
                bundle: bundle,
                locale: locale
            )
            let attributed = AttributedString(text)

            XCTAssertEqual(text, expected, language)
            XCTAssertNotNil(
                StatsPresentation.comparisonDeltaRange(
                    in: attributed,
                    currentSeconds: 7_200,
                    previousSeconds: 3_600,
                    isComparable: true,
                    bundle: bundle,
                    locale: locale
                ),
                language
            )
        }
    }

    func testHourlyVisibilityFactThresholdAndEarliestPeak() {
        XCTAssertFalse(StatsPresentation.shouldShowHourlyCard(period: .today, attempts: 5))
        XCTAssertFalse(StatsPresentation.shouldShowHourlyCard(period: .week, attempts: 0))
        XCTAssertTrue(StatsPresentation.shouldShowHourlyCard(period: .week, attempts: 1))
        XCTAssertTrue(StatsPresentation.shouldShowHourlyCard(period: .all, attempts: 1))
        XCTAssertFalse(HourBars.shouldShowPeakFact(for: [22: 4]))
        XCTAssertTrue(HourBars.shouldShowPeakFact(for: [22: 5]))
        XCTAssertEqual(HourBars.peakHour(in: [8: 2, 22: 2]), 8)
    }

    func testHourlyBarsClampNonzeroValuesAndHideInaccessiblePeakFactBelowThreshold() {
        XCTAssertEqual(HourBars.barHeight(count: 0, maximumCount: 200, availableHeight: 56), 2)
        XCTAssertEqual(HourBars.barHeight(count: 1, maximumCount: 200, availableHeight: 56), 2)
        XCTAssertEqual(HourBars.barHeight(count: 200, maximumCount: 200, availableHeight: 56), 56)

        let titleSummary = HourBars.accessibilitySummary(for: [:])
        XCTAssertEqual(HourBars.accessibilitySummary(for: [22: 4]), titleSummary)
        XCTAssertNotEqual(HourBars.accessibilitySummary(for: [22: 5]), titleSummary)
    }

    func testSnapshotStatsCalendarUsesFixedUTCZone() {
        XCTAssertEqual(CoreScreensSnapshotCapturePolicy.fixedCalendar.timeZone.secondsFromGMT(), 0)
    }

    private func japaneseBundle() throws -> Bundle {
        try localizedBundle(language: "ja")
    }

    private func localizedBundle(language: String) throws -> Bundle {
        let appBundle = Bundle(for: AppDelegate.self)
        let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func targetRule(id: UUID, name: String) -> TargetRule {
        TargetRule(
            id: id,
            name: name,
            activitySelectionData: Data(),
            mode: .standard,
            schedule: nil,
            delaySeconds: 0,
            maxOpensPerDay: nil,
            defaultDurationMinutes: 10,
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
