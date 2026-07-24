import DopaBreakCore
import Foundation
import UserNotifications

extension Notification.Name {
    static let pendingMidSessionCheckInDidChange = Notification.Name(
        "DopaBreak.pendingMidSessionCheckInDidChange"
    )
    static let pendingDay14WarningDidChange = Notification.Name(
        "DopaBreak.pendingDay14WarningDidChange"
    )
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private static let midSessionPrefix = "dopabreak.midsession."
    private static let day14WarningIdentifier = "dopabreak.day14warning"

    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
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
        if identifier == Self.day14WarningIdentifier {
            await MainActor.run {
                settingsStore.pendingDay14Warning = PendingDay14Warning(writtenAt: Date())
                NotificationCenter.default.post(name: .pendingDay14WarningDidChange, object: nil)
            }
            return
        }

        guard identifier.hasPrefix(Self.midSessionPrefix) else {
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
}
