// ActivityKit はmacOSでもimportできるが、`ActivityAttributes` はmacOSでは利用不可。
// canImport だけでは素通りするためOS条件を併記する。
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import Foundation

public struct DopaBreakActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var goalTitles: [String]
        public var todayCancelledCount: Int
        public var todayAttemptCount: Int
        public var blockWindows: [BlockWindowStatus]?
        public var themeRawValue: String

        public init(
            goalTitles: [String],
            todayCancelledCount: Int,
            todayAttemptCount: Int,
            themeRawValue: String,
            blockWindows: [BlockWindowStatus]? = nil
        ) {
            self.goalTitles = goalTitles
            self.todayCancelledCount = todayCancelledCount
            self.todayAttemptCount = todayAttemptCount
            self.themeRawValue = themeRawValue
            self.blockWindows = blockWindows
        }
    }

    public init() {}
}
#endif
