import Foundation

public enum LossEstimatorError: Error, Equatable, Sendable {
    case unknownUsageBucket(String)
}

public enum LossEstimator {
    public struct Estimate: Equatable, Sendable {
        public let dailyMinutes: Int
        public let yearlyDays: Int

        public init(dailyMinutes: Int, yearlyDays: Int) {
            self.dailyMinutes = dailyMinutes
            self.yearlyDays = yearlyDays
        }
    }

    public static func estimate(usageBucket: String) throws -> Estimate {
        guard let dailyMinutes = dailyMinutesByBucket[normalized(usageBucket)] else {
            throw LossEstimatorError.unknownUsageBucket(usageBucket)
        }

        return Estimate(
            dailyMinutes: dailyMinutes,
            yearlyDays: yearlyDays(fromDailyMinutes: dailyMinutes)
        )
    }

    /// 人生換算の前提年数。文中に明示して誇大表示を避ける（docs/07 §O-03r）。
    public static let lifetimeHorizonYears = 50

    /// 3年換算の前提年数。
    public static let threeYearHorizonYears = 3

    public static func yearlyDays(fromDailyMinutes dailyMinutes: Int) -> Int {
        Int((Double(dailyMinutes) * 365.0 / 1_440.0).rounded())
    }

    /// 年間損失日数を3年分に伸ばし、月単位へ換算する。
    /// 実値より大きい数字を出さないため、四捨五入せず1桁小数へ切り捨てる（lifetimeYears と同方針）。
    public static func threeYearMonths(fromYearlyDays yearlyDays: Int) -> Double {
        let months = Double(yearlyDays) * Double(threeYearHorizonYears) / (365.0 / 12.0)
        return (months * 10).rounded(.down) / 10
    }

    /// 年間損失日数を lifetimeHorizonYears 分に伸ばし、年単位へ換算する。
    /// 実値より大きい数字を出さないため、四捨五入せず1桁小数へ切り捨てる。
    public static func lifetimeYears(fromYearlyDays yearlyDays: Int) -> Double {
        let years = Double(yearlyDays) * Double(lifetimeHorizonYears) / 365.0
        return (years * 10).rounded(.down) / 10
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "〜", with: "-")
            .replacingOccurrences(of: "～", with: "-")
    }

    private static let dailyMinutesByBucket = [
        "5回未満": 45,
        "5-15回": 90,
        "15-30回": 150,
        "30回以上": 270,
        "1時間未満": 45,
        "1-2時間": 90,
        "2-4時間": 150,
        "4-6時間": 300,
        "6時間以上": 390,
        "4時間以上": 270
    ]
}
