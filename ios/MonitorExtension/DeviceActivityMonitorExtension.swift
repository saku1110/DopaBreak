import DeviceActivity
import DopaBreakCore
import Foundation
import UserNotifications

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity.rawValue == UsageWatchConstants.activityName,
              let store = try? UsageWatchStore() else {
            return
        }
        store.resetDailyState()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity.rawValue == UsageWatchConstants.activityName,
              let stepIndex = UsageWatchConstants.stepIndex(eventName: event.rawValue),
              let store = try? UsageWatchStore() else {
            return
        }

        let eventDate = Date()
        let result = UsageWatchPolicy.evaluate(
            newEventAt: eventDate,
            stepIndex: stepIndex,
            state: store.loadState(),
            config: store.loadConfiguration(),
            calendar: .autoupdatingCurrent
        )
        store.saveState(result.state)

        guard result.decision != .none else {
            return
        }
        postNotification(for: result.decision)
    }

    private func postNotification(for decision: UsageWatchDecision) {
        let content = UNMutableNotificationContent()
        switch decision {
        case .none:
            return
        case .freeWarning:
            content.title = String(
                localized: "usage_watch.notification.free_warning.title",
                defaultValue: "連続で2時間になりました⏰"
            )
            content.body = String(
                localized: "usage_watch.notification.free_warning.body",
                defaultValue: "見ようとしていたものは見つかりましたか？"
            )
        case .question(let question):
            let copy = notificationCopy(for: question)
            content.title = copy.title
            content.body = copy.body
        }

        content.sound = .default
        content.categoryIdentifier = UsageWatchConstants.notificationCategoryIdentifier
        let request = UNNotificationRequest(
            identifier: UsageWatchConstants.notificationIdentifierPrefix + UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func notificationCopy(for question: UsageWatchQuestion) -> (title: String, body: String) {
        switch question {
        case .q15:
            return (
                String(
                    localized: "usage_watch.notification.q15.title",
                    defaultValue: "15分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q15.body",
                    defaultValue: "SNSをまだ見ますか？"
                )
            )
        case .q30:
            return (
                String(
                    localized: "usage_watch.notification.q30.title",
                    defaultValue: "30分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q30.body",
                    defaultValue: "SNSで満足感を得られましたか？👀"
                )
            )
        case .q45:
            return (
                String(
                    localized: "usage_watch.notification.q45.title",
                    defaultValue: "45分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q45.body",
                    defaultValue: "あと何分で終わりにしますか？⏳"
                )
            )
        case .hourly:
            return (
                String(
                    localized: "usage_watch.notification.hourly.title",
                    defaultValue: "また1時間たちました"
                ),
                String(
                    localized: "usage_watch.notification.hourly.body",
                    defaultValue: "この1時間で何が残りましたか？💭"
                )
            )
        }
    }
}
