import Foundation

public enum ReviewPromptPolicy {
    public static let minimumCancelledCount = 2
    public static let minimumAccountAge: TimeInterval = 0
    public static let requestCooldown: TimeInterval = 90 * 24 * 60 * 60
    public static let eventRetentionInterval: TimeInterval = 365 * 24 * 60 * 60
    public static let maximumRequestsPerYear = 3

    public static func shouldRequest(
        totalCancelledAllTime: Int,
        firstLaunchDate: Date,
        now: Date,
        pastEventDates: [Date],
        sessionBlocked: Bool
    ) -> Bool {
        guard !sessionBlocked,
              totalCancelledAllTime >= minimumCancelledCount,
              now.timeIntervalSince(firstLaunchDate) >= minimumAccountAge else {
            return false
        }

        let cooldownBoundary = now.addingTimeInterval(-requestCooldown)
        guard !pastEventDates.contains(where: { $0 > cooldownBoundary }) else {
            return false
        }

        let retentionBoundary = now.addingTimeInterval(-eventRetentionInterval)
        let eventsWithinLastYear = pastEventDates.filter { $0 >= retentionBoundary }
        return eventsWithinLastYear.count < maximumRequestsPerYear
    }

    public static func prunedEventDates(
        _ eventDates: [Date],
        now: Date
    ) -> [Date] {
        let retentionBoundary = now.addingTimeInterval(-eventRetentionInterval)
        return eventDates.filter { $0 >= retentionBoundary }
    }
}
