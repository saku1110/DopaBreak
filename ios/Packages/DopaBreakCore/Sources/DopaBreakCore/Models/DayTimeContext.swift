import Foundation

public enum DayTimeContext: Equatable, Sendable {
    case wake
    case sleep
    case normal

    private static let minutesPerDay = 1_440
    private static let wakeWindowLengthMinutes = 30
    private static let sleepWindowLengthMinutes = 60

    public static func resolve(
        now: Date,
        wakeMinutes: Int?,
        bedMinutes: Int?,
        calendar: Calendar = .current
    ) -> DayTimeContext {
        guard wakeMinutes != nil || bedMinutes != nil else {
            return .normal
        }

        let components = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = ((components.hour ?? 0) * 60) + (components.minute ?? 0)

        if let wakeMinutes, isInWakeWindow(nowMinutes: nowMinutes, wakeMinutes: wakeMinutes) {
            return .wake
        }

        if let bedMinutes,
           isInWindow(
               nowMinutes,
               start: bedMinutes - sleepWindowLengthMinutes,
               lengthMinutes: sleepWindowLengthMinutes
           ) {
            return .sleep
        }

        return .normal
    }

    private static func isInWakeWindow(nowMinutes: Int, wakeMinutes: Int) -> Bool {
        isInWindow(nowMinutes, start: wakeMinutes, lengthMinutes: wakeWindowLengthMinutes)
    }

    private static func isInWindow(_ nowMinutes: Int, start: Int, lengthMinutes: Int) -> Bool {
        guard lengthMinutes > 0 else {
            return false
        }
        if lengthMinutes >= minutesPerDay {
            return true
        }

        let normalizedStart = normalizedMinutes(start)
        let elapsed = normalizedMinutes(nowMinutes - normalizedStart)
        return elapsed < lengthMinutes
    }

    private static func normalizedMinutes(_ value: Int) -> Int {
        ((value % minutesPerDay) + minutesPerDay) % minutesPerDay
    }
}
