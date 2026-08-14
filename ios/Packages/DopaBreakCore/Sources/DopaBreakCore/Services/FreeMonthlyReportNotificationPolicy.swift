import Foundation

public enum FreeMonthlyReportNotificationBody: Equatable, Sendable {
    case counts(cancelled: Int, attempts: Int)
    case fixed
}

public struct FreeMonthlyReportNotificationSchedule: Equatable, Sendable {
    public let fireDate: Date
    public let body: FreeMonthlyReportNotificationBody

    init(fireDate: Date, body: FreeMonthlyReportNotificationBody) {
        self.fireDate = fireDate
        self.body = body
    }
}

public enum FreeMonthlyReportNotificationPolicy {
    private static let ladderCount = 3

    public static func schedules(
        firstLaunchDate: Date?,
        hasResolvedEntitlement: Bool,
        isPro: Bool,
        isEnabled: Bool,
        cancelledCount: Int,
        attemptCount: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [FreeMonthlyReportNotificationSchedule] {
        guard hasResolvedEntitlement,
              !isPro,
              isEnabled,
              let firstLaunchDate else {
            return []
        }

        var schedules: [FreeMonthlyReportNotificationSchedule] = []
        var nextSearchDate = now

        while schedules.count < ladderCount,
              let anniversary = RetentionNotificationDateCalculator.nextMonthlyReportDate(
                  from: firstLaunchDate,
                  now: nextSearchDate,
                  calendar: calendar
              ) {
            let fireDate = NotificationQuietHours.adjustedFireDate(
                anniversary,
                calendar: calendar
            )
            let body: FreeMonthlyReportNotificationBody = schedules.isEmpty && attemptCount > 0
                ? .counts(cancelled: cancelledCount, attempts: attemptCount)
                : .fixed
            schedules.append(
                FreeMonthlyReportNotificationSchedule(
                    fireDate: fireDate,
                    body: body
                )
            )
            nextSearchDate = fireDate
        }

        return schedules
    }
}
