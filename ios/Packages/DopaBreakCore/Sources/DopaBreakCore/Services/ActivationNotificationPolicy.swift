import Foundation

/// 初回起動を基準にした継続サポート通知（D1 / D3 / D7）の発火時刻を決める純粋ロジック（docs/18 §2c・§2d）。
///
/// ローカル通知は「予約した時点の内容」で確定し、発火時に条件を再評価する仕組みはiOSにない。
/// そのため取り消しは常に「次の再スケジュールでpendingを消す」経路で行う。ここは各時点で
/// 「いま予約してよいか」だけを判定する。
public enum ActivationNotificationPolicy {
    /// D1アクティベーション（初回起動+24h）。
    public static let d1Offset: TimeInterval = 24 * 60 * 60
    /// D3再挑戦（初回起動+72h）。
    public static let d3Offset: TimeInterval = 72 * 60 * 60
    /// D7未活性フォールバック（初回起動+7日）。
    public static let d7Offset: TimeInterval = 7 * 24 * 60 * 60

    /// D1: オートメーション未検収のあいだだけ予約する。
    public static func d1FireDate(
        firstLaunchDate: Date?,
        isEnabled: Bool,
        verifiedAutomationCatalogIDs: [String],
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        unverifiedActivationFireDate(
            offset: d1Offset,
            firstLaunchDate: firstLaunchDate,
            isEnabled: isEnabled,
            verifiedAutomationCatalogIDs: verifiedAutomationCatalogIDs,
            now: now,
            calendar: calendar
        )
    }

    /// D3: D1と同じ「未検収」条件。検収されたら次の再スケジュールで消える。
    public static func d3FireDate(
        firstLaunchDate: Date?,
        isEnabled: Bool,
        verifiedAutomationCatalogIDs: [String],
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        unverifiedActivationFireDate(
            offset: d3Offset,
            firstLaunchDate: firstLaunchDate,
            isEnabled: isEnabled,
            verifiedAutomationCatalogIDs: verifiedAutomationCatalogIDs,
            now: now,
            calendar: calendar
        )
    }

    /// D7: 予約時点で介入試行が全期間0件のときだけ予約する。
    /// 週次ふりかえり（直近7日のattempts>0が条件）とは条件が背反のため、同一ユーザーに両方は出ない。
    public static func d7FireDate(
        firstLaunchDate: Date?,
        isEnabled: Bool,
        totalInterventionAttempts: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard isEnabled,
              totalInterventionAttempts == 0,
              let firstLaunchDate else {
            return nil
        }
        return NotificationQuietHours.futureFireDate(
            for: firstLaunchDate.addingTimeInterval(d7Offset),
            now: now,
            calendar: calendar
        )
    }

    private static func unverifiedActivationFireDate(
        offset: TimeInterval,
        firstLaunchDate: Date?,
        isEnabled: Bool,
        verifiedAutomationCatalogIDs: [String],
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard isEnabled,
              verifiedAutomationCatalogIDs.isEmpty,
              let firstLaunchDate else {
            return nil
        }
        return NotificationQuietHours.futureFireDate(
            for: firstLaunchDate.addingTimeInterval(offset),
            now: now,
            calendar: calendar
        )
    }
}
