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
    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        super.init()
        removeRetiredNotificationCategories()
    }

    // デリゲートはasync版ではなく完了ハンドラ版で実装する。async版にすると、Swiftが
    // ObjCの didReceive:withCompletionHandler: へ橋渡しするために生成した完了ハンドラが、
    // 中断からの再開スレッド（協調プール）で呼ばれる。UIKitはその延長で
    // スナップショットと状態復元の更新に入るため、メインスレッド外だとNSAssertionで
    // SIGABRTになる（通知をタップしても画面が出る前に落ちる実機クラッシュ）。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        onMainThread {
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleResponse(
            identifier: response.notification.request.identifier,
            actionIdentifier: response.actionIdentifier,
            completion: completionHandler
        )
    }

    /// 通知タップを受けたときの本処理。`UNNotificationResponse` はテストから作れないため、
    /// 識別子とアクション識別子だけを受け取る形に切り出している。
    nonisolated func handleResponse(
        identifier: String,
        actionIdentifier: String,
        completion: @escaping () -> Void
    ) {
        guard actionIdentifier == UNNotificationDefaultActionIdentifier else {
            onMainThread(completion)
            return
        }
        routeToDestination(forIdentifier: identifier, completion: completion)
    }

    /// 識別子から着地先を決めて保存する（docs/18 §2f）。
    /// 実際の画面遷移は本体プロセスのRootTabViewが、介入フローなど他の提示と競合しない時点で行う。
    private nonisolated func routeToDestination(
        forIdentifier identifier: String,
        completion: @escaping () -> Void
    ) {
        guard let destination = NotificationRouting.destination(forIdentifier: identifier) else {
            onMainThread(completion)
            return
        }
        onMainThread { [settingsStore = self.settingsStore] in
            settingsStore.pendingNotificationDestination = PendingNotificationDestination(
                destination: destination,
                writtenAt: Date()
            )
            NotificationCenter.default.post(name: .notificationDestinationDidChange, object: nil)
            completion()
        }
    }

    /// 着地先の保存・通知のポスト・完了ハンドラの呼び出しは必ずメインスレッドで行う。
    /// すでにメインスレッドならそのまま実行し、そうでなければホップしてから実行する。
    private nonisolated func onMainThread(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
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
