import DopaBreakCore
import Foundation
import UserNotifications

extension Notification.Name {
    /// 通知タップの着地先が書き込まれた（docs/18 §2f）。コールドスタートでは
    /// RootTabViewのonAppearより後に届くことがあるため、保存値と通知の両方で消費する。
    static let notificationDestinationDidChange = Notification.Name(
        "DopaBreak.notificationDestinationDidChange"
    )
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let settingsStore: SettingsStore
    private let onGateUnlockRequest: @MainActor () -> Void

    init(
        settingsStore: SettingsStore,
        onGateUnlockRequest: @MainActor @escaping () -> Void = {}
    ) {
        self.settingsStore = settingsStore
        self.onGateUnlockRequest = onGateUnlockRequest
        super.init()
        removeRetiredNotificationCategories()
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
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let requestID = response.notification.request.content.userInfo[
               GateConstants.unlockRequestUserInfoKey
           ] as? String,
           UUID(uuidString: requestID) != nil {
            await MainActor.run {
                onGateUnlockRequest()
            }
            return
        }

        let identifier = response.notification.request.identifier
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return
        }
        await routeToDestination(forIdentifier: identifier)
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

    private func removeRetiredNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
            let retained = categories.filter {
                $0.identifier != "dopabreak.usagewatch"
            }
            center.setNotificationCategories(retained)
        }
    }

}
