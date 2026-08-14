import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    /// 夜だけ強化の分だけを置くストア。常時ブロック（"dopabreak.rules"）とは別にしてあるため、
    /// ここから朝の解除を出してもディープフォーカスには当たらない。
    private let nightShieldStore = ManagedSettingsStore(
        named: .init(NightShieldConstants.shieldStoreName)
    )
    private let decoder = JSONDecoder()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        switch activity.rawValue {
        case UsageWatchConstants.activityName:
            guard let store = try? UsageWatchStore() else {
                return
            }
            store.resetDailyState()
        case NightShieldConstants.activityName:
            applyNightShield()
        default:
            return
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity.rawValue == NightShieldConstants.activityName else {
            return
        }
        clearNightShieldIfOutsideWindow()
    }

    /// 起床時刻に夜間ぶんを剥がす。ただし、いま新しい窓の内にいるなら剥がさない。
    ///
    /// 就寝・起床を変えると、古いスケジュールぶんの終了が新しい窓の最中に届くことがある。
    /// 控えが無いときは降格や全データ削除の後始末が走った後なので、そのまま解除でよい。
    private func clearNightShieldIfOutsideWindow() {
        if let snapshot = try? JSONSnapshotStore().read(
            NightShieldSnapshot.self,
            from: .nightShieldSnapshot
        ),
        NightWindowPolicy.isNight(
            now: Date(),
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) {
            return
        }
        clearNightShield()
    }

    /// 就寝時刻に、アプリが書いた控えのぶんだけブロックする。
    ///
    /// 権利の判定もルールの読み取りもここではしない。控えが無い・読めないときは何もしない。
    /// 拡張が独自に判断すると、Freeへ戻った端末で夜だけブロックが復活する。
    ///
    /// 控えに書かれた就寝・起床で「いま窓の内か」も確かめる。就寝時刻を変えた直後は、
    /// 古いスケジュールぶんの開始が遅れて届くことがあり、時刻を見ずに従うと昼にブロックが出る。
    private func applyNightShield() {
        let snapshotStore = JSONSnapshotStore()
        guard let snapshot = try? snapshotStore.read(
            NightShieldSnapshot.self,
            from: .nightShieldSnapshot
        ) else {
            return
        }

        guard NightWindowPolicy.isNight(
            now: Date(),
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) else {
            return
        }

        var applicationTokens = Set<ApplicationToken>()
        var categoryTokens = Set<ActivityCategoryToken>()
        var webDomainTokens = Set<WebDomainToken>()

        for selectionData in snapshot.selectionDataList {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            ) else {
                continue
            }
            applicationTokens.formUnion(selection.applicationTokens)
            categoryTokens.formUnion(selection.categoryTokens)
            webDomainTokens.formUnion(selection.webDomainTokens)
        }

        guard !applicationTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty else {
            return
        }

        // 読んでからここへ来るまでに、アプリが降格の後始末で控えを消していることがある。
        // 消えていれば「もう適用してはいけない」の合図なので、張らずに引き返す。
        // それでも残る極小の競合窓は、次にアプリが前面へ来たときの `syncShield` が必ず剥がす。
        guard snapshotStore.exists(.nightShieldSnapshot) else {
            return
        }

        nightShieldStore.shield.applications = applicationTokens.isEmpty ? nil : applicationTokens
        nightShieldStore.shield.applicationCategories = categoryTokens.isEmpty
            ? nil
            : .specific(categoryTokens)
        nightShieldStore.shield.webDomains = webDomainTokens.isEmpty ? nil : webDomainTokens
    }

    private func clearNightShield() {
        nightShieldStore.shield.applications = nil
        nightShieldStore.shield.applicationCategories = nil
        nightShieldStore.shield.webDomains = nil
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity.rawValue == UsageWatchConstants.activityName,
              let stepIndex = UsageWatchConstants.stepIndex(eventName: event.rawValue),
              let store = try? UsageWatchStore() else {
            return
        }

        let eventDate = Date()
        let result = UsageWatchPolicy.evaluate(
            newEventAt: eventDate,
            stepIndex: stepIndex,
            state: store.loadState(),
            config: store.loadConfiguration(),
            calendar: .autoupdatingCurrent
        )
        store.saveState(result.state)

        guard result.decision != .none else {
            return
        }
        postNotification(for: result.decision)
    }

    private func postNotification(for decision: UsageWatchDecision) {
        let content = UNMutableNotificationContent()
        switch decision {
        case .none:
            return
        case .freeWarning:
            content.title = String(
                localized: "usage_watch.notification.free_warning.title",
                defaultValue: "連続で2時間になりました⏰"
            )
            content.body = String(
                localized: "usage_watch.notification.free_warning.body",
                defaultValue: "見ようとしていたものは見つかりましたか？"
            )
        case .question(let question):
            let copy = notificationCopy(for: question)
            content.title = copy.title
            content.body = copy.body
        }

        content.sound = .default
        content.categoryIdentifier = UsageWatchConstants.notificationCategoryIdentifier
        let request = UNNotificationRequest(
            identifier: UsageWatchConstants.notificationIdentifierPrefix + UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func notificationCopy(for question: UsageWatchQuestion) -> (title: String, body: String) {
        switch question {
        case .q15:
            return (
                String(
                    localized: "usage_watch.notification.q15.title",
                    defaultValue: "15分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q15.body",
                    defaultValue: "SNSをまだ見ますか？"
                )
            )
        case .q30:
            return (
                String(
                    localized: "usage_watch.notification.q30.title",
                    defaultValue: "30分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q30.body",
                    defaultValue: "SNSで満足感を得られましたか？👀"
                )
            )
        case .q45:
            return (
                String(
                    localized: "usage_watch.notification.q45.title",
                    defaultValue: "45分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q45.body",
                    defaultValue: "あと何分で終わりにしますか？⏳"
                )
            )
        case .hourly:
            return (
                String(
                    localized: "usage_watch.notification.hourly.title",
                    defaultValue: "また1時間たちました"
                ),
                String(
                    localized: "usage_watch.notification.hourly.body",
                    defaultValue: "この1時間で何が残りましたか？💭"
                )
            )
        }
    }
}
