import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let decoder = JSONDecoder()

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        guard let token = application.token else {
            return minimalConfiguration()
        }
        return makeConfiguration(for: .application(token))
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        if let token = category.token {
            return makeConfiguration(for: .category(token))
        }
        if let token = application.token {
            return makeConfiguration(for: .application(token))
        }
        return minimalConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        guard let token = webDomain.token else {
            return minimalConfiguration()
        }
        return makeConfiguration(for: .webDomain(token))
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        // カテゴリ由来のシールドでは、控えにもカテゴリトークンが入っている。
        // 先にカテゴリを照合し、夜・Deep Focusの表示を従来どおり保つ。
        if let token = category.token {
            return makeConfiguration(for: .category(token))
        }
        if let token = webDomain.token {
            return makeConfiguration(for: .webDomain(token))
        }
        return minimalConfiguration()
    }

    /// 表示のたびに時間窓の控えを同期読みし、この対象が現在の窓に含まれるかを判定する。
    private func makeConfiguration(for item: ShieldedItem) -> ShieldConfiguration {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let snapshotStore = JSONSnapshotStore()
        let deepFocusSnapshot = try? snapshotStore.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        )
        let nightSnapshot = try? snapshotStore.read(
            NightShieldSnapshot.self,
            from: .nightShieldSnapshot
        )
        let deepFocusActive = isDeepFocusActive(
            for: item,
            snapshot: deepFocusSnapshot,
            now: now,
            calendar: calendar
        )
        let nightActive = isNightActive(
            for: item,
            snapshot: nightSnapshot,
            now: now,
            calendar: calendar
        )
        let openLimitSnapshot = DailyOpenLimitShield.activeSnapshot(now: now)
            .flatMap { contains(item, in: $0.selectionDataList) ? $0 : nil }
        if !deepFocusActive, !nightActive, case .application(let token) = item,
           !ReinterventionShield.hasHardBlock(for: token, now: now), ReinterventionShield.session(for: token) != nil {
            return reinterventionConfiguration()
        }
        var matchingDeepFocus = deepFocusSnapshot
        if let snapshot = matchingDeepFocus {
            if !contains(item, in: snapshot.sessionSelectionDataList ?? snapshot.selectionDataList) { matchingDeepFocus?.session = nil }
            if !contains(item, in: snapshot.selectionDataList) { matchingDeepFocus?.selectionDataList = [] }
        }
        let windows = BlockWindowStatus.active(deepFocus: matchingDeepFocus,
            night: nightActive ? nightSnapshot : nil, now: now, calendar: calendar)
        guard !windows.isEmpty else {
            if let openLimitSnapshot {
                return openLimitConfiguration(openLimitSnapshot, item: item, now: now, calendar: calendar)
            }
            return minimalConfiguration()
        }
        // 夜・予定・手動と重なるときは従来の表示に1行足す。緊急で外せるのは回数上限ぶんだけなので、
        // ここではDopaBreakを開くボタンを出さない。
        var lines = windows.map { blockSubtitle($0, now: now) }
        if let openLimitSnapshot {
            lines.append(openLimitCombinedLine(openLimitSnapshot, now: now, calendar: calendar))
        }
        return baseConfiguration(
            title: String(localized: "shield.title", defaultValue: "完全ブロック中"),
            subtitle: lines.joined(separator: "\n"),
            primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"), secondaryAction: nil)
    }

    /// 回数上限だけで止めているときの表示。理由と終わる時刻だけを書く。
    private func openLimitConfiguration(
        _ snapshot: DailyOpenLimitShieldSnapshot,
        item: ShieldedItem,
        now: Date,
        calendar: Calendar
    ) -> ShieldConfiguration {
        let count = snapshot.openedCount
        var lines = [openLimitEndLine(snapshot.blockEndsAt, now: now, calendar: calendar)]
        var secondaryAction: String?
        if #available(iOS 26.5, *), case .application = item {
            secondaryAction = String(localized: "open_limit.shield.open_app", defaultValue: "DopaBreakを開く")
            lines.append(String(localized: "open_limit.shield.emergency_hint", defaultValue: "急ぐときはDopaBreakで30秒待つと開けます"))
        } else {
            lines.append(String(localized: "open_limit.shield.emergency_hint_manual", defaultValue: "急ぐときはDopaBreakを開いて30秒待つと開けます"))
        }
        return baseConfiguration(
            title: String(localized: "open_limit.shield.title", defaultValue: "今日は\(count)回開きました"),
            subtitle: lines.joined(separator: "\n"),
            primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"),
            secondaryAction: secondaryAction
        )
    }

    private func openLimitEndLine(_ end: Date, now: Date, calendar: Calendar) -> String {
        let time = end.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(end, inSameDayAs: now) {
            return String(localized: "open_limit.shield.until_today", defaultValue: "\(time) まで開けません")
        }
        return String(localized: "open_limit.shield.until_tomorrow", defaultValue: "明日 \(time) まで開けません")
    }

    private func openLimitCombinedLine(_ snapshot: DailyOpenLimitShieldSnapshot, now: Date, calendar: Calendar) -> String {
        let time = snapshot.blockEndsAt.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(snapshot.blockEndsAt, inSameDayAs: now) {
            return String(localized: "open_limit.shield.combined_today", defaultValue: "今日の回数を使い切りました \(time)まで")
        }
        return String(localized: "open_limit.shield.combined_tomorrow", defaultValue: "今日の回数を使い切りました 明日\(time)まで")
    }

    private func blockSubtitle(_ window: BlockWindowStatus, now: Date) -> String {
        guard let end = window.endsAt else {
            return String(localized: "shield.subtitle.fallback", defaultValue: "いまは開かない時間")
        }
        let time = end.formatted(date: .omitted, time: .shortened)
        switch window.trigger {
        case .manual:
            let minutes = Int(ceil(max(0, end.timeIntervalSince(now)) / 60))
            return String(localized: "block.shield.manual", defaultValue: "手動ブロック あと\(minutes)分")
        case .weeklySchedule:
            return String(localized: "block.shield.weekly", defaultValue: "予定のブロック \(time)まで")
        case .night:
            return String(localized: "block.shield.night", defaultValue: "起床時刻の\(time)までブロック")
        }
    }

    private func isDeepFocusActive(
        for item: ShieldedItem,
        snapshot: DeepFocusShieldSnapshot?,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let snapshot,
              DeepFocusWindowPolicy.isWindowActive(
                now: now,
                snapshot: snapshot,
                calendar: calendar
              ) else {
            return false
        }
        return contains(item, in: DeepFocusWindowPolicy.selectionDataListToShield(now: now, snapshot: snapshot, calendar: calendar))
    }

    private func isNightActive(
        for item: ShieldedItem,
        snapshot: NightShieldSnapshot?,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let snapshot,
              NightWindowPolicy.isNight(
                now: now,
                snapshot: snapshot,
                calendar: calendar
              ) else {
            return false
        }
        return contains(item, in: snapshot.selectionDataList)
    }

    /// 対象の選択だけを照合する。別ルールの窓が開いていても、このアプリの表示を
    /// 完全ブロックへ誤って切り替えないため、窓の時刻だけでは判断しない。
    private func contains(_ item: ShieldedItem, in selectionDataList: [Data]) -> Bool {
        for selectionData in selectionDataList {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            ) else {
                continue
            }
            switch item {
            case .application(let token) where selection.applicationTokens.contains(token):
                return true
            case .category(let token) where selection.categoryTokens.contains(token):
                return true
            case .webDomain(let token) where selection.webDomainTokens.contains(token):
                return true
            default:
                continue
            }
        }
        return false
    }

    private func reinterventionConfiguration() -> ShieldConfiguration {
        let subtitle: String
        let action: String
        if #available(iOS 26.5, *) {
            subtitle = String(localized: "reintervention.shield.body", defaultValue: "満足度を振り返って、終了か延長を選びましょう。")
            action = String(localized: "reintervention.shield.open", defaultValue: "DopaBreakで振り返る")
        } else {
            subtitle = String(localized: "reintervention.shield.manual", defaultValue: "通知から、またはホーム画面からDopaBreakを開き、終了か延長を選んでください。")
            action = String(localized: "shield.action.close", defaultValue: "閉じる")
        }
        return baseConfiguration(title: String(localized: "reintervention.shield.title", defaultValue: "選んだ利用時間になりました"), subtitle: subtitle, primaryAction: action, secondaryAction: nil)
    }

    private func minimalConfiguration() -> ShieldConfiguration {
        baseConfiguration(
            title: String(localized: "shield.title", defaultValue: "完全ブロック中"),
            subtitle: nil,
            primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"),
            secondaryAction: nil
        )
    }

    private func baseConfiguration(
        title: String,
        subtitle: String?,
        primaryAction: String,
        secondaryAction: String?
    ) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: ShieldColors.inkBlack,
            title: ShieldConfiguration.Label(text: title, color: ShieldColors.paper),
            subtitle: subtitle.map {
                ShieldConfiguration.Label(text: $0, color: ShieldColors.muted)
            },
            primaryButtonLabel: ShieldConfiguration.Label(
                text: primaryAction,
                color: ShieldColors.inkBlack
            ),
            primaryButtonBackgroundColor: ShieldColors.electricLime,
            secondaryButtonLabel: secondaryAction.map {
                ShieldConfiguration.Label(text: $0, color: ShieldColors.paper)
            }
        )
    }
}

private enum ShieldedItem {
    case application(ApplicationToken)
    case category(ActivityCategoryToken)
    case webDomain(WebDomainToken)
}



private enum ShieldColors {
    static let inkBlack = UIColor(
        red: 10.0 / 255.0,
        green: 11.0 / 255.0,
        blue: 13.0 / 255.0,
        alpha: 1
    )
    static let paper = UIColor(
        red: 244.0 / 255.0,
        green: 245.0 / 255.0,
        blue: 242.0 / 255.0,
        alpha: 1
    )
    static let muted = UIColor(
        red: 126.0 / 255.0,
        green: 134.0 / 255.0,
        blue: 148.0 / 255.0,
        alpha: 1
    )
    static let electricLime = UIColor(
        red: 199.0 / 255.0,
        green: 249.0 / 255.0,
        blue: 77.0 / 255.0,
        alpha: 1
    )
}
