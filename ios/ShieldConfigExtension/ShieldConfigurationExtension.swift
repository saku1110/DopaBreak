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
        return makeConfiguration(for: .application(token), gateToken: token)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        // この入口はカテゴリシールドで呼ばれる。ゲートはアプリ単位だけなので、
        // カテゴリの完全ブロックを日常ゲートの解除表示へ取り違えない。
        if let token = category.token {
            return makeConfiguration(for: .category(token), gateToken: nil)
        }
        if let token = application.token {
            return makeConfiguration(for: .application(token), gateToken: nil)
        }
        return minimalConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        guard let token = webDomain.token else {
            return minimalConfiguration()
        }
        // Webドメインはゲート対象外。Deep Focus / 夜の完全ブロック表示だけを分岐する。
        return makeConfiguration(for: .webDomain(token), gateToken: nil)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        // カテゴリ由来のシールドでは、控えにもカテゴリトークンが入っている。
        // 先にカテゴリを照合し、夜・Deep Focusの表示を従来どおり保つ。
        if let token = category.token {
            return makeConfiguration(for: .category(token), gateToken: nil)
        }
        if let token = webDomain.token {
            return makeConfiguration(for: .webDomain(token), gateToken: nil)
        }
        return minimalConfiguration()
    }

    /// 表示のたびに控えと台帳を同期読みし、同じ入力を`GatePolicy`へ渡す。
    /// 目標と完全ブロック控えの破損はそれぞれ局所的に無視し、ゲート判定を巻き込まない。
    private func makeConfiguration(
        for item: ShieldedItem,
        gateToken: ApplicationToken?
    ) -> ShieldConfiguration {
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
        let goal = try? GoalStore(snapshotStore: snapshotStore).primaryGoal()

        guard let gateToken else {
            return hardWindowOrMinimalConfiguration(
                deepFocusActive: deepFocusActive,
                nightActive: nightActive,
                goal: goal
            )
        }

        // 旧ストア・残存した夜/DFストア・Freeのシールドへ解除UIを出さない。
        // 権利確認済みアプリが書いたゲート控えに、このトークンが実在するときだけ進む。
        let gateSnapshot = try? GateShieldSnapshotStore(
            snapshotStore: snapshotStore
        ).snapshot()
        guard let gateSnapshot,
              contains(.application(gateToken), in: gateSnapshot.selectionDataList) else {
            return hardWindowOrMinimalConfiguration(
                deepFocusActive: deepFocusActive,
                nightActive: nightActive,
                goal: goal
            )
        }

        do {
            let tokenData = try GateTokenCoding.encode(gateToken)
            let settings = try GateAppSettingsStore(snapshotStore: snapshotStore)
                .setting(for: tokenData)
            let ledger = try GateLedgerStore(snapshotStore: snapshotStore).ledger()
            let pendingRequest = try? GateUnlockRequestStore(
                snapshotStore: snapshotStore
            ).request()
            let state = GatePolicy.shieldState(
                tokenData: tokenData,
                now: now,
                settings: settings,
                ledger: ledger,
                pendingUnlockRequest: pendingRequest,
                isDeepFocusWindowActive: deepFocusActive,
                isNightWindow: nightActive,
                calendar: calendar
            )
            return configuration(for: state, goal: goal)
        } catch {
            return hardWindowOrMinimalConfiguration(
                deepFocusActive: deepFocusActive,
                nightActive: nightActive,
                goal: goal
            )
        }
    }

    private func hardWindowOrMinimalConfiguration(
        deepFocusActive: Bool,
        nightActive: Bool,
        goal: Goal?
    ) -> ShieldConfiguration {
        if deepFocusActive {
            return configuration(for: .hardWindow(kind: .deepFocus), goal: goal)
        }
        if nightActive {
            return configuration(for: .hardWindow(kind: .night), goal: goal)
        }
        return minimalConfiguration()
    }

    private func configuration(
        for state: GateShieldState,
        goal: Goal?
    ) -> ShieldConfiguration {
        switch state {
        case .hardWindow(let kind):
            return baseConfiguration(
                title: hardWindowTitle(kind),
                subtitle: hardWindowSubtitle(kind, goal: goal),
                primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"),
                secondaryAction: nil
            )
        case .canUnlock(let opensToday, let limit):
            let nextOpen = Int64(opensToday + 1)
            let subtitle: String
            if let limit {
                let limitValue = Int64(limit)
                subtitle = String(
                    localized: "shield.gate.subtitle.count_limit",
                    defaultValue: "今日 \(nextOpen)/\(limitValue)回"
                )
            } else {
                subtitle = String(
                    localized: "shield.gate.subtitle.count",
                    defaultValue: "今日 \(nextOpen)回目"
                )
            }
            return baseConfiguration(
                title: String(
                    localized: "shield.gate.title",
                    defaultValue: "開く前にひと呼吸"
                ),
                subtitle: subtitle,
                primaryAction: String(
                    localized: "shield.gate.action.breathe",
                    defaultValue: "一呼吸して開く"
                ),
                secondaryAction: String(
                    localized: "shield.gate.action.cancel",
                    defaultValue: "開かない"
                )
            )
        case .waitingForApp:
            let notificationUnavailable = UserDefaults(suiteName: AppGroup.identifier)?
                .bool(forKey: GateConstants.notificationUnavailableDefaultsKey) ?? false
            let subtitle = notificationUnavailable
                ? String(
                    localized: "shield.gate.waiting.denied",
                    defaultValue: "通知をオンにすると、このアプリを開けます"
                )
                : String(
                    localized: "shield.gate.waiting.subtitle",
                    defaultValue: "画面上部の通知をタップすると、DopaBreakで一呼吸できます"
                )
            return baseConfiguration(
                title: String(
                    localized: "shield.gate.waiting.title",
                    defaultValue: "通知をタップ"
                ),
                subtitle: subtitle,
                primaryAction: String(
                    localized: "shield.gate.waiting.retry",
                    defaultValue: "通知をもう一度送る"
                ),
                secondaryAction: String(
                    localized: "shield.gate.action.cancel",
                    defaultValue: "開かない"
                )
            )
        case .limitReached(let limit):
            let value = Int64(limit)
            return baseConfiguration(
                title: String(
                    localized: "shield.gate.limit.title",
                    defaultValue: "今日はここまで"
                ),
                subtitle: String(
                    localized: "shield.gate.limit.subtitle",
                    defaultValue: "今日の上限（\(value)回）に達しました。0時にリセットされます。"
                ),
                primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"),
                secondaryAction: nil
            )
        case .cooldown(let until):
            let time = timeText(until)
            return baseConfiguration(
                title: String(
                    localized: "shield.gate.cooldown.title",
                    defaultValue: "まだ開けません"
                ),
                subtitle: String(
                    localized: "shield.gate.cooldown.subtitle",
                    defaultValue: "\(time)から開けます"
                ),
                primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"),
                secondaryAction: nil
            )
        case .alreadyOpen:
            // 通常は開放中のアプリにシールド自体が無い。古い表示が残った場合も
            // 二重grantを作らず、ゲート由来だと分かる中立表示から閉じるだけにする。
            return baseConfiguration(
                title: String(
                    localized: "shield.gate.title",
                    defaultValue: "開く前にひと呼吸"
                ),
                subtitle: nil,
                primaryAction: String(localized: "shield.action.close", defaultValue: "閉じる"),
                secondaryAction: nil
            )
        }
    }

    private func hardWindowTitle(_ kind: HardKind) -> String {
        switch kind {
        case .deepFocus:
            return String(localized: "shield.title", defaultValue: "完全ブロック中")
        case .night:
            return String(localized: "shield.night.title", defaultValue: "就寝時間中です")
        }
    }

    private func hardWindowSubtitle(_ kind: HardKind, goal: Goal?) -> String {
        if let goal {
            let lockScreenTitle = goal.lockScreenTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = lockScreenTitle.isEmpty ? goal.title : lockScreenTitle
            return String(
                localized: "shield.subtitle.goal",
                defaultValue: "守っている目標 \(title)"
            )
        }

        switch kind {
        case .deepFocus:
            return String(
                localized: "shield.subtitle.fallback",
                defaultValue: "いまは開かない時間"
            )
        case .night:
            return String(
                localized: "shield.night.subtitle",
                defaultValue: "起きたら開けます"
            )
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        return contains(item, in: snapshot.selectionDataList)
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
