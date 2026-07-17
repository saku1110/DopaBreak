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

    public static func yearlyDays(fromDailyMinutes dailyMinutes: Int) -> Int {
        Int((Double(dailyMinutes) * 365.0 / 1_440.0).rounded())
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
        "4時間以上": 270
    ]
}
