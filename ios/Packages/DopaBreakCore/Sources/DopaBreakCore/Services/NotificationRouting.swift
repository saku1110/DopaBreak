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
    /// 宣言時間終了後の利用後振り返り。
    case reflection
}

/// ローカル通知の識別子。取り消し・ルーティングの単一の正本にする。
public enum NotificationIdentifier {
    public static let weekly = "dopabreak.lock.weekly"
    public static let d1Activation = "dopabreak.d1activation"
    public static let d3Activation = "dopabreak.d3activation"
    public static let d7Inactive = "dopabreak.d7inactive"
    public static let month1Report = "dopabreak.month1report"
    public static let freeMonthly1 = "dopabreak.freeMonthly1"
    public static let freeMonthly2 = "dopabreak.freeMonthly2"
    public static let freeMonthly3 = "dopabreak.freeMonthly3"
    public static let freeMonthlyReports = [freeMonthly1, freeMonthly2, freeMonthly3]
    public static let month12Renewal = "dopabreak.month12renewal"
    public static let annualUpgradeOffer = "dopabreak.annualoffer"
    public static let cancelSave = "dopabreak.cancelsave"

    /// 「いますぐ」で始めた完全ブロックが終わったことだけを伝える通知。
    /// ユーザーが自分で決めた終わりなので、深夜帯の繰り延べは当てない。
    public static let deepFocusSessionEnd = "dopabreak.deepfocus.sessionend"
    public static func workCheckIn(_ catalogID: String) -> String { "dopabreak.workcheckin." + catalogID }
    public static let reflectionPrompt = "dopabreak.reflection.prompt"

    /// 廃止済み通知の識別子。予約が端末に残っていると古いコピーで発火するため掃除し続ける。
    /// - `dopabreak.day14warning`: 14日時限開放の撤回（2026-08-11）に伴い廃止。
    /// - dopabreak.lock.morning: 目標の通知を廃止（2026-09-03・Live Activityに一本化）。
    /// - dopabreak.trialday5: トライアル終了前通知を廃止（2026-09-20）。
    public static let legacyIdentifiers = ["dopabreak.day14warning", "dopabreak.lock.morning", "dopabreak.trialday5"]

    /// UUIDを末尾に持つため完全一致で消せない廃止済み通知の接頭辞。
    /// 通常SNSの実利用時間は取得できないため、時間切れと中間チェックインを廃止した。
    public static let legacyPrefixes = [
        "dopabreak.timeup.",
        "dopabreak.midsession.",
        "dopabreak.usagewatch."
    ]
}

/// 識別子から着地先を決める（docs/18 §2f）。
public enum NotificationRouting {
    public static func destination(forIdentifier identifier: String) -> NotificationDestination? {
        switch identifier {
        case NotificationIdentifier.weekly,
             NotificationIdentifier.month1Report,
             NotificationIdentifier.freeMonthly1,
             NotificationIdentifier.freeMonthly2,
             NotificationIdentifier.freeMonthly3:
            return .stats
        case NotificationIdentifier.month12Renewal,
             NotificationIdentifier.annualUpgradeOffer,
             NotificationIdentifier.cancelSave:
            return .planSettings
        case NotificationIdentifier.d1Activation,
             NotificationIdentifier.d3Activation,
             NotificationIdentifier.d7Inactive:
            return .automationGuide
        case NotificationIdentifier.reflectionPrompt:
            return .reflection
        default:
            return nil
        }
    }
}
