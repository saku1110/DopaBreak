import DopaBreakCore
import Foundation
import UserNotifications

extension Notification.Name {
    static let pendingMidSessionCheckInDidChange = Notification.Name(
        "DopaBreak.pendingMidSessionCheckInDidChange"
    )
    /// 通知タップの着地先が書き込まれた（docs/18 §2f）。コールドスタートでは
    /// RootTabViewのonAppearより後に届くことがあるため、保存値と通知の両方で消費する。
    static let notificationDestinationDidChange = Notification.Name(
        "DopaBreak.notificationDestinationDidChange"
    )
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private static let midSessionPrefix = NotificationIdentifier.midSessionPrefix

    private let settingsStore: SettingsStore
    private let usageWatchStore: UsageWatchStore

    init(settingsStore: SettingsStore, usageWatchStore: UsageWatchStore? = nil) {
        self.settingsStore = settingsStore
        self.usageWatchStore = usageWatchStore
            ?? ((try? UsageWatchStore()) ?? UsageWatchStore(userDefaults: .standard))
        super.init()
        registerUsageWatchCategory()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        if categoryIdentifier == UsageWatchConstants.notificationCategoryIdentifier
            || identifier.hasPrefix(UsageWatchConstants.notificationIdentifierPrefix) {
            if response.actionIdentifier == UsageWatchConstants.muteTodayActionIdentifier {
                usageWatchStore.muteForToday(at: Date(), calendar: .autoupdatingCurrent)
                return
            }

            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
                return
            }
            await routeToDestination(forIdentifier: identifier)
            return
        }

        guard identifier.hasPrefix(Self.midSessionPrefix) else {
            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
                return
            }
            await routeToDestination(forIdentifier: identifier)
            return
        }

        let remainder = identifier.dropFirst(Self.midSessionPrefix.count)
        guard let separatorIndex = remainder.firstIndex(of: ".") else {
            return
        }

        let catalogID = String(remainder[..<separatorIndex])
        let uuidStartIndex = remainder.index(after: separatorIndex)
        let uuidString = String(remainder[uuidStartIndex...])
        guard !catalogID.isEmpty,
              SNSAppCatalog.contains(catalogID: catalogID),
              UUID(uuidString: uuidString) != nil else {
            return
        }

        await MainActor.run {
            settingsStore.pendingMidSessionCheckIn = PendingMidSessionCheckIn(
                catalogID: catalogID,
                writtenAt: Date()
            )
            NotificationCenter.default.post(name: .pendingMidSessionCheckInDidChange, object: nil)
        }
    }

    /// 識別子から着地先を決めて保存する（docs/18 §2f）。
    /// 実際の画面遷移は本体プロセスのRootTabViewが、介入フローなど他の提示と競合しない時点で行う。
    private func routeToDestination(forIdentifier identifier: String) async {
        guard let destination = NotificationRouting.destination(forIdentifier: identifier) else {
            return
        }
        await MainActor.run {
            settingsStore.pendingNotificationDestination = PendingNotificationDestination(
                destination: destination,
                writtenAt: Date()
            )
            NotificationCenter.default.post(name: .notificationDestinationDidChange, object: nil)
        }
    }

    private func registerUsageWatchCategory() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
            let muteAction = UNNotificationAction(
                identifier: UsageWatchConstants.muteTodayActionIdentifier,
                title: String(
                    localized: "usage_watch.notification.action.mute_today",
                    defaultValue: "今日は止める"
                )
            )
            let category = UNNotificationCategory(
                identifier: UsageWatchConstants.notificationCategoryIdentifier,
                actions: [muteAction],
                intentIdentifiers: []
            )
            // 端末の言語が変わるとアクション名が変わり、update(with:)では
            // 同じidentifierのカテゴリが二重に残るため、先に取り除いてから入れ直す。
            var updatedCategories = categories.filter {
                $0.identifier != UsageWatchConstants.notificationCategoryIdentifier
            }
            updatedCategories.insert(category)
            center.setNotificationCategories(updatedCategories)
        }
    }
}
