import Foundation

public enum NotificationQuietHours {
    public static func adjustedFireDate(
        _ candidate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let windowStart = localDate(
            onSameDayAs: candidate,
            hour: 9,
            calendar: calendar
        )
        let windowEnd = localDate(
            onSameDayAs: candidate,
            hour: 21,
            calendar: calendar
        )

        if candidate < windowStart {
            return windowStart
        }
        if candidate <= windowEnd {
            return candidate
        }

        return calendar.date(byAdding: .day, value: 1, to: windowStart) ?? candidate
    }

    /// 深夜帯制御を当てたうえで、まだ未来に残っている発火時刻だけを返す。
    /// 繰り延べの結果すでに過去になったものは予約しない（遅れて出す通知は作らない）。
    public static func futureFireDate(
        for candidate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let adjusted = adjustedFireDate(candidate, calendar: calendar)
        return adjusted > now ? adjusted : nil
    }

    /// 「いま条件が揃ったので次に出せる時刻に出す」通知のための発火時刻。
    /// 送信可能窓の中なら直近（`leadTime`後）、窓の外なら翌朝9:00へ繰り延べる。
    public static func nextDeliverableFireDate(
        after now: Date,
        leadTime: TimeInterval = 60,
        calendar: Calendar = .current
    ) -> Date {
        let candidate = now.addingTimeInterval(max(1, leadTime))
        return adjustedFireDate(candidate, calendar: calendar)
    }

    private static func localDate(
        onSameDayAs date: Date,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components) ?? date
    }
}
