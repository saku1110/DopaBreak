import XCTest
@testable import DopaBreakCore

final class LossEstimatorTests: XCTestCase {
    func testUsageBucketsMapToDailyMinutes() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1時間未満").dailyMinutes, 45)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1-2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2-4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4時間以上").dailyMinutes, 270)
    }

    func testWaveDashAliasesMatchDocumentedBuckets() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1〜2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2〜4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1～2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2～4時間").dailyMinutes, 150)
    }

    func testOnboardingTimeBucketsMapToEstimate() throws {
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1時間未満").dailyMinutes, 45)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "1〜2時間").dailyMinutes, 90)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "2〜4時間").dailyMinutes, 150)
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4時間以上").dailyMinutes, 270)
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
        XCTAssertEqual(try LossEstimator.estimate(usageBucket: "4時間以上").yearlyDays, 68)
    }

    func testYearlyDaysExampleMatchesOnboardingSpec() {
        XCTAssertEqual(LossEstimator.yearlyDays(fromDailyMinutes: 150), 38)
    }

    func testUnknownBucketThrows() {
        XCTAssertThrowsError(try LossEstimator.estimate(usageBucket: "不明")) { error in
            XCTAssertEqual(error as? LossEstimatorError, .unknownUsageBucket("不明"))
        }
    }
}
