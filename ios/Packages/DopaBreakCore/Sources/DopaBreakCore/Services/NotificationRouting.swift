import Foundation

/// 通知タップの着地先（docs/18 §2f）。
/// `SettingsStore.pendingNotificationDestination` に保存され、本体プロセスが起動後に消費する。
public enum NotificationDestination: String, Codable, Sendable, CaseIterable {
    /// 統計タブ。
    case stats
    /// 設定タブのプラン周り。ペイウォールは自動提示しない（文脈説明→ユーザー操作で開く）。
    case planSettings = "plan_settings"
    /// オートメーション設定ガイド。
    case automationGuide = "automation_guide"
}

/// ローカル通知の識別子。取り消し・ルーティングの単一の正本にする。
public enum NotificationIdentifier {
    public static let morning = "dopabreak.lock.morning"
    public static let weekly = "dopabreak.lock.weekly"
    public static let d1Activation = "dopabreak.d1activation"
    public static let d3Activation = "dopabreak.d3activation"
    public static let d7Inactive = "dopabreak.d7inactive"
    public static let trialDay5 = "dopabreak.trialday5"
    public static let month1Report = "dopabreak.month1report"
    public static let freeMonthly1 = "dopabreak.freeMonthly1"
    public static let freeMonthly2 = "dopabreak.freeMonthly2"
    public static let freeMonthly3 = "dopabreak.freeMonthly3"
    public static let freeMonthlyReports = [freeMonthly1, freeMonthly2, freeMonthly3]
    public static let month12Renewal = "dopabreak.month12renewal"
    public static let annualUpgradeOffer = "dopabreak.annualoffer"
    public static let cancelSave = "dopabreak.cancelsave"

    /// 介入セッションの中間チェックイン通知の接頭辞（着地先ではなくシート提示を持つ）。
    public static let midSessionPrefix = "dopabreak.midsession."

    /// 廃止済み通知の識別子。予約が端末に残っていると古いコピーで発火するため掃除し続ける。
    /// - `dopabreak.day14warning`: 14日時限開放の撤回（2026-08-11）に伴い廃止。
    public static let legacyIdentifiers = ["dopabreak.day14warning"]
}

/// 識別子から着地先を決める（docs/18 §2f）。
public enum NotificationRouting {
    public static func destination(forIdentifier identifier: String) -> NotificationDestination? {
        if identifier.hasPrefix(UsageWatchConstants.notificationIdentifierPrefix) {
            return .stats
        }
        if identifier.hasPrefix(NotificationIdentifier.midSessionPrefix) {
            return nil
        }

        switch identifier {
        case NotificationIdentifier.morning,
             NotificationIdentifier.weekly,
             NotificationIdentifier.month1Report,
             NotificationIdentifier.freeMonthly1,
             NotificationIdentifier.freeMonthly2,
             NotificationIdentifier.freeMonthly3:
            return .stats
        case NotificationIdentifier.trialDay5,
             NotificationIdentifier.month12Renewal,
             NotificationIdentifier.annualUpgradeOffer,
             NotificationIdentifier.cancelSave:
            return .planSettings
        case NotificationIdentifier.d1Activation,
             NotificationIdentifier.d3Activation,
             NotificationIdentifier.d7Inactive:
            return .automationGuide
        default:
            return nil
        }
    }
}
