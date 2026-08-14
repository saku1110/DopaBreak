import XCTest
@testable import DopaBreakCore

final class LossEstimatorTests: XCTestCase {
    func testUsageBucketsMapToDailyMinutes() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1時間未満").dailyMinutes, 45)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1-2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2-4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4-6時間").dailyMinutes, 300)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "6時間以上").dailyMinutes, 390)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4時間以上").dailyMinutes, 270)
    }

    func testWaveDashAliasesMatchDocumentedBuckets() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1〜2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2〜4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4〜6時間").dailyMinutes, 300)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1～2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2～4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4～6時間").dailyMinutes, 300)
    }

    func testOnboardingTimeBucketsMapToEstimate() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1時間未満").dailyMinutes, 45)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1〜2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2〜4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4〜6時間").dailyMinutes, 300)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4〜6時間").yearlyDays, 76)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "6時間以上").dailyMinutes, 390)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "6時間以上").yearlyDays, 99)
    }

    func testLegacyOpenCountBucketsRemainSupportedForPersistedData() throws {
        // These keys must not be removed while old persisted SelfCheckSnapshot data can exist.
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "5回未満").dailyMinutes, 45)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "5〜15回").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "15〜30回").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "30回以上").dailyMinutes, 270)
    }

    func testYearlyDaysFormulaRoundsToNearestDay() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1時間未満").yearlyDays, 11)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1-2時間").yearlyDays, 23)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2-4時間").yearlyDays, 38)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4-6時間").yearlyDays, 76)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "6時間以上").yearlyDays, 99)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4時間以上").yearlyDays, 68)
    }

    func testYearlyDaysExampleMatchesOnboardingSpec() {
        XCTAssertEqual(LossEstimator.yearlyDays(fromDailyMinutes: 150), 38)
    }

    func testThreeYearMonthsCoversEveryUsageBucket() throws {
        let expected: [(bucket: String, months: Double, text: String)] = [
            ("1時間未満", 1.0, "1.0"),
            ("1-2時間", 2.2, "2.2"),
            ("2-4時間", 3.7, "3.7"),
            ("4〜6時間", 7.4, "7.4"),
            ("6時間以上", 9.7, "9.7"),
            ("4時間以上", 6.7, "6.7")
        ]

        for row in expected {
            let yearlyDays = try LossEstimator.estimate(usageBucket: row.bucket).yearlyDays
            let months = LossEstimator.threeYearMonths(fromYearlyDays: yearlyDays)
            XCTAssertEqual(months, row.months, accuracy: 0.0001, "bucket: \(row.bucket)")
            XCTAssertEqual(String(format: "%.1f", months), row.text, "bucket: \(row.bucket)")
        }
    }

    func testThreeYearHorizonMatchesOnboardingCopy() {
        XCTAssertEqual(LossEstimator.threeYearHorizonYears, 3)
    }

    func testLifetimeYearsCoversEveryUsageBucket() throws {
        let expected: [(bucket: String, years: Double, text: String)] = [
            ("1時間未満", 1.5, "1.5"),
            ("1-2時間", 3.1, "3.1"),
            ("2-4時間", 5.2, "5.2"),
            ("4〜6時間", 10.4, "10.4"),
            ("6時間以上", 13.5, "13.5"),
            ("4時間以上", 9.3, "9.3")
        ]

        for row in expected {
            let yearlyDays = try LossEstimator.estimate(usageBucket: row.bucket).yearlyDays
            let years = LossEstimator.lifetimeYears(fromYearlyDays: yearlyDays)
            XCTAssertEqual(years, row.years, accuracy: 0.0001, "bucket: \(row.bucket)")
            // O-03rは1桁小数の文字列を%@へ渡す。書式側で丸め直しが起きないことも固定する。
            XCTAssertEqual(String(format: "%.1f", years), row.text, "bucket: \(row.bucket)")
        }
    }

    /// 23日は 23×50÷365 = 3.1506… 。四捨五入すると3.2になるため、
    /// 3.1のままであることが「切り上げない」ことの証明になる（誇大表示の回避）。
    func testLifetimeYearsTruncatesInsteadOfRounding() {
        XCTAssertEqual(LossEstimator.lifetimeYears(fromYearlyDays: 23), 3.1, accuracy: 0.0001)
        XCTAssertEqual(String(format: "%.1f", LossEstimator.lifetimeYears(fromYearlyDays: 23)), "3.1")
    }

    func testLifetimeHorizonMatchesOnboardingCopy() {
        XCTAssertEqual(LossEstimator.lifetimeHorizonYears, 50)
    }

    func testUnknownBucketThrows() {
        XCTAssertThrowsError(try LossEstimator.estimate(usageBucket: "不明")) { error in
            XCTAssertEqual(error as? LossEstimatorError, .unknownUsageBucket("不明"))
        }
    }
}
