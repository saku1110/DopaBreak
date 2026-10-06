import ActivityKit
import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// 控えから取り出した、1つのストアへ流し込むぶんのトークン。
private struct SnapshotTokens {
    var applications = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()
    var webDomains = Set<WebDomainToken>()

    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }
}

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    /// 夜だけ強化の分だけを置くストア。常時ブロック（"dopabreak.rules"）とは別にしてあるため、
    /// ここから朝の解除を出してもディープフォーカスには当たらない。
    private let nightShieldStore = ManagedSettingsStore(
        named: .init(NightShieldConstants.shieldStoreName)
    )
    /// 完全ブロックの窓の分だけを置くストア。夜だけ強化とも旧ストアとも分けてあるため、
    /// ここから窓の終わりの解除を出しても、他の強さには当たらない。
    private let deepFocusShieldStore = ManagedSettingsStore(
        named: .init(DeepFocusConstants.shieldStoreName)
    )
    private let decoder = JSONDecoder()

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity.rawValue.hasPrefix(ReinterventionConstants.activityPrefix) else { return }
        let catalogID = String(activity.rawValue.dropFirst(ReinterventionConstants.activityPrefix.count))
        let now = Date()
        do {
            let didReach = try ReinterventionStore().transaction({ state -> ReinterventionSession? in
                guard let session = state.sessions[catalogID], session.acceptsThreshold(eventID: event.rawValue, now: now) else { return nil }
                state.sessions[catalogID]?.reachedAt = now
                return session.notificationsEnabled ? session : nil
            }, afterCommit: { ReinterventionShield.apply($0, now: now) })
            guard let session = didReach else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "reintervention.notification.title", defaultValue: "選んだ利用時間になりました")
            content.body = String(localized: "reintervention.notification.body", defaultValue: "DopaBreakで振り返り、終了か延長を選んでください。")
            if !session.isBlocking {
                content.title = String(localized: "reintervention.soft.question", defaultValue: "まだ用事の途中ですか？")
                content.body = String(localized: "reintervention.soft.reached", defaultValue: "選んだ利用時間になりました。必要な用事を続けているか確認しましょう。")
            }
            content.sound = .default
            UNUserNotificationCenter.current().add(.init(identifier: session.isBlocking ? NotificationIdentifier.reflectionPrompt : NotificationIdentifier.workCheckIn(catalogID), content: content, trigger: nil))
        } catch {
            // No claim that a limit fired when the cross-process write failed.
            ReinterventionShield.sync()
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        defer { updateBlockLiveActivities() }
        // 回数上限は開始・終了の区別に頼らず、どの通知でも最新の控えで掛け外しを決め直す。
        // 監視の停止でも終了が届き、古い予定ぶんが遅れて届くこともあるため。
        DailyOpenLimitShield.sync()
        if activity.rawValue == DailyOpenLimitConstants.activityName {
            return
        }
        if activity.rawValue.hasPrefix(ReinterventionConstants.activityPrefix) {
            ReinterventionShield.sync(); return
        }

        if DeepFocusConstants.isWindowActivity(activity.rawValue) {
            applyDeepFocusShield()
            return
        }

        switch activity.rawValue {
        case NightShieldConstants.activityName:
            applyNightShield()
        default:
            return
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        defer { updateBlockLiveActivities() }
        DailyOpenLimitShield.sync()
        if activity.rawValue == DailyOpenLimitConstants.activityName {
            return
        }
        if activity.rawValue.hasPrefix(ReinterventionConstants.activityPrefix) {
            // Recompute all sessions; a delayed end callback must not clear a newer budget.
            ReinterventionShield.sync(); return
        }

        if DeepFocusConstants.isWindowActivity(activity.rawValue) {
            clearDeepFocusShieldIfOutsideWindow()
            return
        }

        guard activity.rawValue == NightShieldConstants.activityName else {
            return
        }
        clearNightShieldIfOutsideWindow()
    }

    private func updateBlockLiveActivities() {
        let store = JSONSnapshotStore()
        let windows = BlockWindowStatus.active(
            deepFocus: try? store.read(DeepFocusShieldSnapshot.self, from: .deepFocusShieldSnapshot),
            night: try? store.read(NightShieldSnapshot.self, from: .nightShieldSnapshot),
            now: Date(), calendar: .autoupdatingCurrent)
        Task {
            for activity in Activity<DopaBreakActivityAttributes>.activities {
                var state = activity.content.state
                state.blockWindows = windows
                await activity.update(ActivityContent(state: state, staleDate: windows.compactMap(\.endsAt).min()))
            }
        }
    }

    /// 窓の終わりに完全ブロックを剥がす。ただし、いま別の窓の内にいるなら剥がさない。
    ///
    /// セッションと予定は重なることがある。片方が終わっただけで両方の解除を出すと、
    /// まだ続いているはずのブロックが落ちる。
    ///
    /// 控えが読めないときは剥がす側へ倒す。降格や全データ削除の後始末が走った後か、
    /// 控えが壊れているかのどちらかで、どちらも「掛け続ける根拠がない」状態だからだ。
    /// ここで維持を選ぶと、終わったのに開けないブロックを誰も外せなくなる。
    private func clearDeepFocusShieldIfOutsideWindow() {
        let snapshotStore = JSONSnapshotStore()
        let now = Date()
        if let snapshot = try? snapshotStore.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        ),
        DeepFocusWindowPolicy.isWindowActive(
            now: now,
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) {
            // セッションと予定が重なって片方だけ終わった場合は、残った窓の対象へ
            // 正確に戻す。手動セッションの全モード対象を予定終了まで残さない。
            applyDeepFocusShield(snapshot: snapshot, snapshotStore: snapshotStore, now: now)
            return
        }
        clearDeepFocusShield()
    }

    /// 窓のはじまりに、アプリが書いた控えのぶんだけブロックする。
    ///
    /// 権利の判定もルールの読み取りもここではしない。控えが無い・読めないときは何もしない。
    /// 拡張が独自に判断すると、Freeへ戻った端末でブロックが復活する。
    ///
    /// 控えに書かれた窓で「いま窓の内か」も確かめる。設定を変えた直後は、
    /// 古い予定ぶんの開始が遅れて届くことがあり、時刻を見ずに従うと窓の外でブロックが出る。
    private func applyDeepFocusShield() {
        let snapshotStore = JSONSnapshotStore()
        guard let snapshot = try? snapshotStore.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        ) else {
            return
        }

        applyDeepFocusShield(snapshot: snapshot, snapshotStore: snapshotStore, now: Date())
    }

    private func applyDeepFocusShield(
        snapshot: DeepFocusShieldSnapshot,
        snapshotStore: JSONSnapshotStore,
        now: Date
    ) {
        guard DeepFocusWindowPolicy.isWindowActive(
            now: now,
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) else {
            return
        }

        let selectionDataList = DeepFocusWindowPolicy.selectionDataListToShield(
            now: now,
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        )
        guard !selectionDataList.isEmpty else {
            clearDeepFocusShield()
            return
        }

        let tokens = decodedTokens(from: selectionDataList)
        guard !tokens.isEmpty else {
            return
        }

        // 読んでからここへ来るまでに、アプリが降格の後始末で控えを消していることがある。
        // 消えていれば「もう適用してはいけない」の合図なので、張らずに引き返す。
        // それでも残る極小の競合窓は、次にアプリが前面へ来たときの `syncShield` が必ず剥がす。
        guard snapshotStore.exists(.deepFocusShieldSnapshot) else {
            return
        }

        apply(tokens, to: deepFocusShieldStore)
    }

    private func clearDeepFocusShield() {
        clear(deepFocusShieldStore)
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

        let tokens = decodedTokens(from: snapshot.selectionDataList)
        guard !tokens.isEmpty else {
            return
        }

        // 読んでからここへ来るまでに、アプリが降格の後始末で控えを消していることがある。
        // 消えていれば「もう適用してはいけない」の合図なので、張らずに引き返す。
        // それでも残る極小の競合窓は、次にアプリが前面へ来たときの `syncShield` が必ず剥がす。
        guard snapshotStore.exists(.nightShieldSnapshot) else {
            return
        }

        apply(tokens, to: nightShieldStore)
    }

    private func clearNightShield() {
        clear(nightShieldStore)
    }

    /// 控えに入っている選択データを、実際に止められるトークンへほどく。
    /// 1件でも読めなければその1件だけを飛ばす。壊れた1件で全部を落とさない。
    private func decodedTokens(from selectionDataList: [Data]) -> SnapshotTokens {
        var tokens = SnapshotTokens()
        for selectionData in selectionDataList {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            ) else {
                continue
            }
            tokens.applications.formUnion(selection.applicationTokens)
            tokens.categories.formUnion(selection.categoryTokens)
            tokens.webDomains.formUnion(selection.webDomainTokens)
        }
        return tokens
    }

    private func apply(_ tokens: SnapshotTokens, to store: ManagedSettingsStore) {
        store.shield.applications = tokens.applications.isEmpty ? nil : tokens.applications
        store.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories)
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
    }

    private func clear(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

}
