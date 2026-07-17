import DopaBreakCore
import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private static let midSessionPrefix = "dopabreak.midsession."

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

        settingsStore.pendingMidSessionCheckInCatalogID = catalogID
    }
}
