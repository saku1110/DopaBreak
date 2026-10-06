import DopaBreakCore
import Foundation
import UserNotifications

protocol ReflectionNotificationNotifying {
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: ((Error?) -> Void)?
    )
    func getNotificationAuthorizationStatus(
        withCompletionHandler completionHandler: @escaping (UNAuthorizationStatus) -> Void
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: ReflectionNotificationNotifying {
    func getNotificationAuthorizationStatus(
        withCompletionHandler completionHandler: @escaping (UNAuthorizationStatus) -> Void
    ) {
        getNotificationSettings { settings in
            completionHandler(settings.authorizationStatus)
        }
    }
}

@MainActor
final class ReflectionNotificationScheduler {
    private let notificationCenter: any ReflectionNotificationNotifying

    init(
        notificationCenter: any ReflectionNotificationNotifying = UNUserNotificationCenter.current()
    ) {
        self.notificationCenter = notificationCenter
    }

    func getNotificationAuthorizationStatus(
        withCompletionHandler completionHandler: @escaping (UNAuthorizationStatus) -> Void
    ) {
        notificationCenter.getNotificationAuthorizationStatus(
            withCompletionHandler: completionHandler
        )
    }

    func schedule(
        reflection: ReflectionLog,
        appDisplayName: String,
        declaredMinutes: Int,
        isEnabled: Bool,
        now: Date,
        completion: @escaping (Bool) -> Void
    ) {
        guard let fireDate = ReflectionNotificationPolicy.fireDate(
            promptedAt: reflection.promptedAt,
            now: now,
            isEnabled: isEnabled
        ) else {
            cancel()
            completion(false)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "notification.reflection.title",
            defaultValue: "\(appDisplayName)を開いて\(declaredMinutes)分がたちました"
        )
        content.body = String(
            localized: "notification.reflection.body",
            defaultValue: "SNSを見たあとの気持ちは？"
        )
        content.sound = .default

        let identifier = NotificationIdentifier.reflectionPrompt
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        notificationCenter.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: OneShotNotificationTrigger.make(for: fireDate)
            ),
            withCompletionHandler: { error in
                completion(error == nil)
            }
        )
    }

    func cancelWorkCheckIn(catalogID: String) {
        let ids = [NotificationIdentifier.workCheckIn(catalogID)]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func scheduleWorkCheckIn(catalogID: String, minutes: Int, isEnabled: Bool, now: Date) {
        cancelWorkCheckIn(catalogID: catalogID)
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "reintervention.soft.question", defaultValue: "まだ用事の途中ですか？")
        content.body = String(localized: "reintervention.soft.elapsed", defaultValue: "開いてから\(minutes)分がたちました。目的なく使い続けていないか確認しましょう。")
        content.sound = .default
        notificationCenter.add(.init(identifier: NotificationIdentifier.workCheckIn(catalogID), content: content,
            trigger: OneShotNotificationTrigger.make(for: now.addingTimeInterval(Double(minutes * 60)))), withCompletionHandler: nil)
    }

    func cancel() {
        let identifiers = [NotificationIdentifier.reflectionPrompt]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeDelivered() {
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [NotificationIdentifier.reflectionPrompt]
        )
    }
}
