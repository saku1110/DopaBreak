import DeviceActivity
import DopaBreakCore
import Foundation
import UserNotifications

protocol DeepFocusMonitoring {
    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: DeepFocusMonitoring {}

/// セッションの終わりを知らせる通知の出し口。テストで差し替えられるように切っておく。
protocol DeepFocusSessionNotifying {
    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: DeepFocusSessionNotifying {}

/// 完全ブロックの窓を、アプリが起きていないあいだも切り替えるための下ごしらえ。
///
/// `NightShieldScheduler` と同じ作りにしてある。拡張の中では権利もルールも見ない。
/// Proだと確定しているあいだにアプリが控え（`DeepFocusShieldSnapshot`）を書き、
/// 権利を落としたら控えごと消す。拡張には「書いてあるものを、いま窓の内なら適用する」だけが残る。
///
/// この機能でいちばん怖いのは「窓が終わったのに開けない」。解除は3つの経路で担保する。
/// 1. 拡張の `intervalDidEnd`（このクラスが張る予定が起こす）
/// 2. アプリが前面へ来たときの再計算（`AppModel.syncShield`）
/// 3. Freeだと確定したときのルール読み取り前の無条件解除（`ShieldSyncPolicy`）
@MainActor
final class DeepFocusScheduler {
    static let sessionActivityName = DeviceActivityName(DeepFocusConstants.sessionActivityName)

    static var allActivityNames: [DeviceActivityName] {
        DeepFocusConstants.allWindowActivityNames.map(DeviceActivityName.init(_:))
    }

    private let ruleStore: RuleStore
    private let settingsStore: SettingsStore
    private let snapshotStore: JSONSnapshotStore
    private let monitoringCenter: any DeepFocusMonitoring
    private let notificationCenter: any DeepFocusSessionNotifying
    private let clearDeepFocusShield: @MainActor () -> Void
    private let now: () -> Date
    private let calendar: Calendar

    private(set) var didLastRebuildFail = false

    init(
        ruleStore: RuleStore,
        settingsStore: SettingsStore,
        snapshotStore: JSONSnapshotStore,
        monitoringCenter: any DeepFocusMonitoring = DeviceActivityCenter(),
        notificationCenter: any DeepFocusSessionNotifying = UNUserNotificationCenter.current(),
        clearDeepFocusShield: @MainActor @escaping () -> Void,
        now: @escaping () -> Date = { Date() },
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.ruleStore = ruleStore
        self.settingsStore = settingsStore
        self.snapshotStore = snapshotStore
        self.monitoringCenter = monitoringCenter
        self.notificationCenter = notificationCenter
        self.clearDeepFocusShield = clearDeepFocusShield
        self.now = now
        self.calendar = calendar
    }

    // MARK: - セッションの開始と終了

    /// 「いますぐ」で完全ブロックを始める。
    /// - Parameter durationMinutes: `nil` なら「自分で戻すまで」（終わる時刻を持たない）。
    func startSession(durationMinutes: Int?) {
        let startedAt = now()
        settingsStore.deepFocusSession = DeepFocusSession(
            startedAt: startedAt,
            endsAt: durationMinutes.map { startedAt.addingTimeInterval(TimeInterval($0 * 60)) }
        )
    }

    /// 進行中の回をその場で終わらせる。終わったことの通知は出さない
    /// （自分で解除した直後に「終わりました」と届くのは事実として重複する）。
    func endSession() {
        settingsStore.deepFocusSession = nil
        cancelSessionEndNotification()
    }

    var activeSession: DeepFocusSession? {
        DeepFocusWindowPolicy.activeSession(settingsStore.deepFocusSession, now: now())
    }

    /// いま完全ブロックを出す窓の中か。`ShieldSyncPolicy` へ渡す入力そのもの。
    var isWindowActive: Bool {
        DeepFocusWindowPolicy.isWindowActive(
            now: now(),
            session: settingsStore.deepFocusSession,
            schedule: settingsStore.deepFocusSchedule,
            calendar: calendar
        )
    }

    // MARK: - 同期

    /// 控えと予定を、現在の権利・ルール・窓の設定へ合わせ直す。
    ///
    /// 権利が未確定のあいだは何も触らない（`ShieldSyncPolicy` の `preserve` と同じ考え方）。
    /// 取得に失敗しただけの課金者の完全ブロックを、ここで先に剥がしてしまわないため。
    ///
    /// - Returns: 予定を張れたかどうか。張らないことが正しい場面でも `false` を返す。
    @discardableResult
    func rebuild(entitlementGate: EntitlementGate, hasConfirmedEntitlement: Bool) -> Bool {
        // 終わった回はここで潰す。シールドには触らない後始末なので、権利の確定を待たない。
        // 残したままだと画面が「実行中」と出し続け、実際は解除済みという食い違いになる。
        pruneExpiredSession()

        guard hasConfirmedEntitlement else {
            return false
        }

        // Freeだと確定した時点で、ルールを読む前に止める。
        // ルールの読み取りに失敗する端末でも、降格の後始末だけは必ず通す。
        guard entitlementGate.tier == .pro, entitlementGate.strictModeAllowed else {
            stopAndClear()
            return false
        }

        // Proのまま読めなかったときは触らない。読めないことを理由に、
        // 効いている完全ブロックの予定を消さない。
        guard let rules = try? ruleStore.allRules() else {
            return false
        }

        // ここで窓を作らない。窓を開くのは本人の操作（セッション開始・予定のオン）だけで、
        // 同期の副作用でブロックが始まることは絶対にない。
        let session = DeepFocusWindowPolicy.activeSession(
            settingsStore.deepFocusSession,
            now: now()
        )
        let configuredSchedule = settingsStore.deepFocusSchedule
        let enabledRules = rules.filter {
            $0.isEnabled && !$0.activitySelectionData.isEmpty
        }
        // 手動セッションは一時的な全対象ブロック。保存モードに関係なく、選択データを
        // 持つ有効ルールを対象にする。毎週の予定は従来どおりdeepFocusだけへ効かせる。
        let sessionSelectionDataList = session == nil
            ? []
            : enabledRules.map(\.activitySelectionData)
        let scheduleSelectionDataList = enabledRules
            .filter { $0.mode == .deepFocus }
            .map(\.activitySelectionData)
        let effectiveSession = sessionSelectionDataList.isEmpty ? nil : session
        let effectiveSchedule = scheduleSelectionDataList.isEmpty
            ? DeepFocusSchedule.disabled
            : configuredSchedule

        guard DeepFocusWindowPolicy.hasConfiguredWindow(
                now: now(),
                session: effectiveSession,
                schedule: effectiveSchedule
              ) else {
            stopAndClear()
            return false
        }

        // 控えを先に置く。書けなかったときは既存の予定に触らない。
        // 先に予定を止める形にすると、書き込みに失敗した端末で窓の終わりの解除まで失う。
        do {
            try snapshotStore.write(
                DeepFocusShieldSnapshot(
                    selectionDataList: scheduleSelectionDataList,
                    sessionSelectionDataList: sessionSelectionDataList,
                    schedule: effectiveSchedule,
                    session: effectiveSession,
                    updatedAt: now()
                ),
                to: .deepFocusShieldSnapshot
            )
        } catch {
            didLastRebuildFail = true
            return false
        }

        syncSessionEndNotification(session: effectiveSession)

        monitoringCenter.stopMonitoring(Self.allActivityNames)

        let outcome = startMonitoring(session: effectiveSession, schedule: effectiveSchedule)

        // 1本も張れなかったときだけ、剥がす側へ倒す。
        // 窓の終わりに解除を出す担い手が拡張側に誰もいないため、掛けっぱなしで放置すると
        // 「終わったのに開けない」が残る（`NightShieldScheduler` と同じ裁定）。
        // 一部だけ落ちた場合は倒さない。動いている回の解除まで巻き添えで消す方が害が大きく、
        // 落ちた曜日ぶんは次の `syncShield` で張り直す。
        guard !outcome.didFailCompletely else {
            monitoringCenter.stopMonitoring(Self.allActivityNames)
            // 剥がすなら終了通知も消す。ブロックしていないのに「終わりました」は嘘になる。
            cancelSessionEndNotification()
            clearDeepFocusShield()
            try? snapshotStore.remove(.deepFocusShieldSnapshot)
            didLastRebuildFail = true
            return false
        }

        // セッションの予定だけが落ちたときも、終了通知は残さない。
        // 通知は「解除された」の合図として届くため、解除が伴わない通知は事実とずれる。
        // このあとの前面復帰の再計算が解除を受け持つ。
        if outcome.didRequestSession, !outcome.didStartSession {
            cancelSessionEndNotification()
        }

        didLastRebuildFail = outcome.hasFailure
        return !outcome.hasFailure
    }

    /// 予定を止めて控えを消す。降格と全データ削除の後始末はここに一本化する。
    ///
    /// 順序は「予定停止 → 控え削除」。逆にすると、控えを消してから予定が止まるまでの
    /// あいだに境界が来たとき、拡張が消したはずの対象を張り直す余地が広がる。
    /// 呼び出し側は、このあとにシールドの解除を置くこと。
    ///
    /// ルールに保存された `deepFocus` は書き換えない（2026-08-14の非破壊降格の裁定）。
    /// 窓の設定（セッション・予定）も消さない。再びProになったときにそのまま戻るようにするため。
    ///
    /// - Returns: 控えを消しきれたか。消せなかったことを握りつぶさず、
    ///   次の `syncShield` で消し直せるように失敗として残す。
    @discardableResult
    func stopAndClear() -> Bool {
        monitoringCenter.stopMonitoring(Self.allActivityNames)
        cancelSessionEndNotification()

        do {
            try snapshotStore.remove(.deepFocusShieldSnapshot)
            didLastRebuildFail = false
            return true
        } catch {
            // 予定は止まっているため、新たな境界で拡張が起きることはない。
            // 残った控えは次の同期で消し直す。
            didLastRebuildFail = true
            return false
        }
    }

    // MARK: - 内部

    private func pruneExpiredSession() {
        guard let session = settingsStore.deepFocusSession,
              DeepFocusWindowPolicy.isExpired(session: session, now: now()) else {
            return
        }
        settingsStore.deepFocusSession = nil
    }

    /// 予定を1本ずつ張り、どれが張れたかを返す。
    ///
    /// 1本の失敗で全部を巻き添えにしない。曜日の予定が1つ落ちても、成功した
    /// セッションの一回きりの予定は生かす（これを落とすと、いま動いている回の
    /// 終わりに解除を出す担い手が消える）。
    ///
    /// - Returns: セッションと曜日それぞれの成否。
    private func startMonitoring(
        session: DeepFocusSession?,
        schedule: DeepFocusSchedule
    ) -> MonitoringOutcome {
        var outcome = MonitoringOutcome()

        if let session, let endsAt = session.endsAt {
            outcome.didRequestSession = true
            do {
                try monitoringCenter.startMonitoring(
                    Self.sessionActivityName,
                    during: sessionSchedule(startedAt: session.startedAt, endsAt: endsAt),
                    events: [:]
                )
                outcome.didStartSession = true
            } catch {
                // 張れなかった回だけを止め直す。残しても境界は来ない。
                monitoringCenter.stopMonitoring([Self.sessionActivityName])
            }
        }

        guard DeepFocusWindowPolicy.isScheduleUsable(schedule) else {
            return outcome
        }

        for weekday in schedule.weekdays {
            let activityName = DeviceActivityName(
                DeepFocusConstants.scheduleActivityName(weekday: weekday)
            )
            outcome.requestedWeekdayCount += 1
            do {
                try monitoringCenter.startMonitoring(
                    activityName,
                    during: Self.weekdaySchedule(
                        weekday: weekday,
                        startMinutes: schedule.startMinutes,
                        endMinutes: schedule.endMinutes
                    ),
                    events: [:]
                )
                outcome.startedWeekdayCount += 1
            } catch {
                monitoringCenter.stopMonitoring([activityName])
            }
        }
        return outcome
    }

    /// 張り直しの結果。「全部落ちた」と「一部だけ落ちた」を分けて扱うために持つ。
    private struct MonitoringOutcome {
        var didRequestSession = false
        var didStartSession = false
        var requestedWeekdayCount = 0
        var startedWeekdayCount = 0

        var requestedCount: Int {
            (didRequestSession ? 1 : 0) + requestedWeekdayCount
        }

        var startedCount: Int {
            (didStartSession ? 1 : 0) + startedWeekdayCount
        }

        /// 1本も張れなかった。窓の終わりに解除を出す担い手が誰もいない状態。
        var didFailCompletely: Bool {
            requestedCount > 0 && startedCount == 0
        }

        var hasFailure: Bool {
            startedCount < requestedCount
        }
    }

    /// 一回きりの予定。開始は実際に押した時刻のまま残す。
    ///
    /// アプリを開き直したときの張り直しで開始を「いま」へ寄せると、残りが15分を切った回が
    /// `intervalTooShort` で弾かれ、終わりの解除を出す担い手がいなくなる。
    private func sessionSchedule(startedAt: Date, endsAt: Date) -> DeviceActivitySchedule {
        // DeviceActivityが見るのは分までなので秒は渡さない。
        let fields: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute]
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: startedAt),
            intervalEnd: calendar.dateComponents(fields, from: endsAt),
            repeats: false
        )
    }

    /// 曜日ごとに1本ずつ張る繰り返しの予定。
    /// 跨日（22:00→翌6:00）は終わりの曜日を翌日へずらす。
    ///
    /// 週次（`weekday` 付き）のDeviceActivityが実機で発火するかは要実機検証。
    /// 不発なら「毎日1本の予定＋拡張側で曜日を照合して適用を見送る」形へ切り替える
    /// （`DeepFocusWindowPolicy.isScheduleActive` が既に曜日を判定しているため、
    /// 拡張側の検算はそのまま使える）。
    static func weekdaySchedule(
        weekday: Int,
        startMinutes: Int,
        endMinutes: Int
    ) -> DeviceActivitySchedule {
        let start = DeepFocusWindowPolicy.normalizedMinutes(startMinutes)
        let end = DeepFocusWindowPolicy.normalizedMinutes(endMinutes)
        let endWeekday = DeepFocusWindowPolicy.crossesMidnight(
            startMinutes: start,
            endMinutes: end
        ) ? DeepFocusWindowPolicy.nextWeekday(weekday) : weekday

        return DeviceActivitySchedule(
            intervalStart: DateComponents(
                hour: start / 60,
                minute: start % 60,
                weekday: weekday
            ),
            intervalEnd: DateComponents(
                hour: end / 60,
                minute: end % 60,
                weekday: endWeekday
            ),
            repeats: true
        )
    }

    // MARK: - セッション終了の通知

    /// 進行中の回の終わりに1本だけ予約し直す。深夜帯の繰り延べは当てない
    /// （本人が決めた終わりなので、翌朝へずらすと事実とずれる）。
    private func syncSessionEndNotification(session: DeepFocusSession?) {
        cancelSessionEndNotification()

        guard let session,
              let endsAt = session.endsAt else {
            return
        }
        let interval = endsAt.timeIntervalSince(now())
        guard interval > 0 else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "deep_focus.session_end.notification.title",
            defaultValue: "完全ブロックが終わりました"
        )
        content.body = String(
            localized: "deep_focus.session_end.notification.body",
            defaultValue: "選んだアプリをまた開けます。"
        )
        content.sound = .default

        notificationCenter.add(
            UNNotificationRequest(
                identifier: NotificationIdentifier.deepFocusSessionEnd,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: interval,
                    repeats: false
                )
            ),
            withCompletionHandler: nil
        )
    }

    private func cancelSessionEndNotification() {
        let identifiers = [NotificationIdentifier.deepFocusSessionEnd]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
