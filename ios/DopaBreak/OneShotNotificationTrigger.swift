import Foundation
import UserNotifications

/// 一回きりのローカル通知のトリガー。
///
/// `UNTimeIntervalNotificationTrigger` を使わないのは、端末をまたぐ時計のずれや
/// スリープで秒が溶けると発火時刻が前後するため。暦の一点として指定して固定する。
///
/// 暦は `.gregorian` に固定する。和暦などの端末設定でも同じ一点を指すようにするため、
/// `era` まで含めて渡す。タイムゾーンは端末の現在値をそのまま使う。
///
/// 通知を予約する側（`LockSurfaceCoordinator` / `ReflectionNotificationScheduler`）が
/// 同じ組み立てを二重に持たないよう、ここを正本にする。
enum OneShotNotificationTrigger {
    static func make(for date: Date) -> UNCalendarNotificationTrigger {
        var components = Calendar(identifier: .gregorian).dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
