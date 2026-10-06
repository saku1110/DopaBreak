import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

protocol DailyOpenLimitMonitoring {
    /// いま登録されている予定（`DeviceActivityCenter.schedule(for:)`）。未登録なら `nil`。
    func schedule(for activity: DeviceActivityName) -> DeviceActivitySchedule?
    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: DailyOpenLimitMonitoring {}

/// 1日に開ける回数を使い切ったあとの完全ブロックを、控え・監視・シールドの3つで動かす。
///
/// 夜・完全ブロックの窓と同じく、拡張の中では権利もルールも見ない。Proだと確定しているあいだに
/// アプリが控えを書き、拡張は「控えの窓の内なら掛け、外なら外す」だけを行う。
///
/// いちばん避けたいのは「起床時刻を過ぎても開けない」。そのため、
/// - 解除を出す監視の登録に成功したときだけ控えを残す（失敗したら控えごと消して掛けない）
/// - 15分未満の窓は監視を張れないので、最初から掛けない（一呼吸の入口の上限画面だけで止める）
/// - 前面へ来るたびに、窓が終わった控えを消してシールドを外す
@MainActor
final class DailyOpenLimitController {
    static let activityName = DeviceActivityName(DailyOpenLimitConstants.activityName)

    /// 回数上限だけを置くストア。夜・予定・手動とは別にして、ここの解除が他の強さに当たらないようにする。
    static func makeShieldWriter() -> any ShieldSettingsWriting {
        ManagedSettingsStore(named: .init(DailyOpenLimitConstants.shieldStoreName))
    }

    private let settingsStore: SettingsStore
    private let ruleStore: RuleStore
    private let logStore: SQLiteLogStore?
    private let store: DailyOpenLimitStore
    private let monitoring: any DailyOpenLimitMonitoring
    private let shieldWriter: any ShieldSettingsWriting
    private let now: () -> Date
    private let calendar: Calendar

    init(
        settingsStore: SettingsStore,
        ruleStore: RuleStore,
        logStore: SQLiteLogStore?,
        store: DailyOpenLimitStore,
        monitoring: any DailyOpenLimitMonitoring,
        shieldWriter: any ShieldSettingsWriting,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.settingsStore = settingsStore
        self.ruleStore = ruleStore
        self.logStore = logStore
        self.store = store
        self.monitoring = monitoring
        self.shieldWriter = shieldWriter
        self.now = now
        self.calendar = calendar
    }

    private var boundaryMinutes: Int {
        settingsStore.wakeTimeMinutes ?? NightShieldConstants.defaultWakeTimeMinutes
    }

    // MARK: - 状態

    /// 予約した変更のうち効く時刻を過ぎたものを反映して返す。
    /// 画面の描画中にも呼ばれるため、ここでは保存しない（保存は `sync` で行う）。
    private func currentSettings() -> DailyOpenLimitSettings {
        DailyOpenLimitPolicy.resolved(settingsStore.dailyOpenLimitSettings, now: now())
    }

    /// 効く時刻を過ぎた予約を保存へ反映する。
    private func persistResolvedSettings() {
        let stored = settingsStore.dailyOpenLimitSettings
        let resolved = DailyOpenLimitPolicy.resolved(stored, now: now())
        if resolved != stored {
            settingsStore.dailyOpenLimitSettings = resolved
        }
    }

    /// 今日の回数の状態。権利の判定は呼び出し側で行う。
    func status() -> DailyOpenLimitStatus {
        let settings = currentSettings()
        let nowValue = now()
        let start = DailyOpenLimitPolicy.countingStart(
            settings: settings,
            now: nowValue,
            boundaryMinutes: boundaryMinutes,
            calendar: calendar
        )
        let end = DailyOpenLimitPolicy.nextDayStart(now: nowValue, boundaryMinutes: boundaryMinutes, calendar: calendar)
        let count = settings.limit == nil ? 0 : ((try? logStore?.openedAttemptCount(from: start, to: end)) ?? 0)
        return DailyOpenLimitPolicy.status(
            settings: settings,
            openedCount: count,
            now: nowValue,
            boundaryMinutes: boundaryMinutes,
            calendar: calendar
        )
    }

    /// 回数上限のシールドがいま掛かっている窓。窓の外なら `nil`。
    func activeSnapshot() -> DailyOpenLimitShieldSnapshot? {
        guard let snapshot = try? store.read(),
              DailyOpenLimitPolicy.isBlockActive(now: now(), snapshot: snapshot) else {
            return nil
        }
        return snapshot
    }

    /// 最近の1日あたりの開いた回数。記録が1日ぶんも無ければ `nil`。
    func averageDailyOpens() -> Int? {
        let nowValue = now()
        let todayStart = DailyOpenLimitPolicy.dayStart(now: nowValue, boundaryMinutes: boundaryMinutes, calendar: calendar)
        guard let firstLaunchDate = settingsStore.firstLaunchDate,
              let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart) else {
            return nil
        }
        // 今日はまだ途中なので含めない。使い始めて7日未満なら、その日数で割る。
        let start = max(weekStart, DailyOpenLimitPolicy.dayStart(now: firstLaunchDate, boundaryMinutes: boundaryMinutes, calendar: calendar))
        let days = calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0
        guard days >= 1,
              let count = try? logStore?.openedAttemptCount(from: start, to: todayStart),
              count > 0 else {
            return nil
        }
        return Int((Double(count) / Double(days)).rounded())
    }

    // MARK: - 変更

    /// 上限を変える。締める変更で使い切ったら、その場で止める。
    func setLimit(_ limit: Int?, isPro: Bool, hasConfirmedEntitlement: Bool) {
        settingsStore.dailyOpenLimitSettings = DailyOpenLimitPolicy.applying(
            limit: limit,
            to: settingsStore.dailyOpenLimitSettings,
            now: now(),
            boundaryMinutes: boundaryMinutes,
            calendar: calendar
        )
        sync(isPro: isPro, hasConfirmedEntitlement: hasConfirmedEntitlement)
    }

    /// 開いた回を記録した直後に呼ぶ。使い切ったら、決めた時間が終わったところから止める。
    /// - Parameter durationSeconds: 決めた時間。時間なしで開いたときは `nil`。
    func didRecordOpen(durationSeconds: Int?, isPro: Bool, hasConfirmedEntitlement: Bool) {
        guard isPro else { return }
        let status = status()
        guard status.isExhausted else { return }
        let openUntil = DailyOpenLimitPolicy.blockStart(openedAt: now(), durationSeconds: durationSeconds)
        rememberOpenUntil(openUntil)
        guard hasConfirmedEntitlement else { return }
        engage(startsAt: openUntil, openedCount: status.openedCount)
    }

    /// 使い切ったあとに開けている時間の終わりを覚える。表示（「{時刻} まで開けます」）だけに使う。
    private func rememberOpenUntil(_ date: Date) {
        var settings = settingsStore.dailyOpenLimitSettings
        settings.openUntil = date
        settingsStore.dailyOpenLimitSettings = settings
    }

    /// 権利・設定・控えを合わせ直す。前面復帰と設定変更のたびに通る。
    func sync(isPro: Bool, hasConfirmedEntitlement: Bool) {
        // 権利が未確定のあいだは控えを作らない・消さない。ただし終わった窓の掃除と、
        // いま掛けるべきかどうかの反映だけは行う（終わったのに開けない状態を残さない）。
        guard hasConfirmedEntitlement else {
            applyCurrent()
            return
        }
        // Freeだと確定したら、ルールや記録を読む前に止める。設定値は残す（非破壊降格）。
        guard isPro else {
            stopAndClear()
            return
        }
        persistResolvedSettings()
        let status = status()
        guard status.limit != nil, status.isExhausted else {
            if (try? store.read()) != nil {
                stopAndClear()
            }
            return
        }
        let nowValue = now()
        if let snapshot = try? store.read(), DailyOpenLimitPolicy.isSnapshotCurrent(now: nowValue, snapshot: snapshot) {
            // 止まっている（止まる予定の）あいだも、次の3つは合わせ直す。
            // - 起床時刻を変えたら、止まり終わりを今の起床時刻へ
            // - 完全にブロックするアプリを足したら、すぐ止める。外したアプリは翌朝まで止めたまま（緩める変更は翌朝から）
            // - 解除を出す監視が消えていたら張り直す（控えを書いてから登録するまでに終了した等）
            var selections = snapshot.selectionDataList
            for data in blockSelections() where !selections.contains(data) {
                selections.append(data)
            }
            let isMonitored = isRegistered(for: snapshot, now: nowValue)
            if snapshot.blockEndsAt != status.dayEndsAt || selections != snapshot.selectionDataList || !isMonitored {
                engage(
                    startsAt: snapshot.blockStartsAt,
                    openedCount: snapshot.openedCount,
                    selections: selections
                )
            }
        } else {
            // 使い切ったのに控えが無い（記録の直後に終了した・監視を張れなかった・締める変更をした等）。
            // 最後の1回で決めた時間がまだ残っていれば、その終わりから止める。無ければいまから止める。
            // 素通しの許可の期限は使わない（利用時間の通知・制限をつないだアプリは最大12時間になるため）。
            let rememberedOpenUntil = settingsStore.dailyOpenLimitSettings.openUntil ?? nowValue
            engage(startsAt: max(nowValue, rememberedOpenUntil), openedCount: status.openedCount)
        }
        applyCurrent()
    }

    /// 使い切ったあと、まだ開けている時間の終わり。最後の1回の決めた時間や、緊急で開いた時間のあいだだけ返す。
    ///
    /// 止まっている最中は必ず `nil`。素通しの許可の期限は使わない（利用時間の通知・制限を
    /// つないだアプリは許可が最大12時間になり、止まっているのに「開けます」と出てしまうため）。
    func openUntil() -> Date? {
        let nowValue = now()
        if let snapshot = try? store.read(), DailyOpenLimitPolicy.isSnapshotCurrent(now: nowValue, snapshot: snapshot) {
            return snapshot.blockStartsAt > nowValue ? snapshot.blockStartsAt : nil
        }
        guard let until = settingsStore.dailyOpenLimitSettings.openUntil, until > nowValue else {
            return nil
        }
        return until
    }

    // MARK: - 緊急で開く

    func emergencyState() -> DailyOpenLimitPolicy.EmergencyState {
        DailyOpenLimitPolicy.emergencyState(
            requestedAt: settingsStore.dailyOpenLimitSettings.emergencyRequestedAt,
            now: now()
        )
    }

    /// 30秒の待ちを始める。待っている途中・待ち終わったあとに押し直しても、待ちは延びない。
    func requestEmergency() {
        guard emergencyState() == .notRequested else { return }
        var settings = settingsStore.dailyOpenLimitSettings
        settings.emergencyRequestedAt = now()
        settingsStore.dailyOpenLimitSettings = settings
    }

    /// 待ち終わったあとに、決めた時間だけ回数上限のシールドを外す。
    ///
    /// 止め直しの監視を先に登録し、登録できたときだけ外す。外したあとに登録が失敗すると、
    /// 選んだ時間が過ぎても止まらないため。
    /// - Returns: 開いてよいか。待ちが済んでいない・止め直しを登録できなかったときは `false`。
    func openForEmergency(durationSeconds: Int) -> Bool {
        guard durationSeconds > 0, emergencyState() == .ready else { return false }
        let nowValue = now()
        let resumeAt = nowValue.addingTimeInterval(TimeInterval(durationSeconds))

        if let current = try? store.read(), DailyOpenLimitPolicy.isSnapshotCurrent(now: nowValue, snapshot: current) {
            if let window = DailyOpenLimitPolicy.blockWindow(startsAt: resumeAt, endsAt: current.blockEndsAt) {
                guard register(window) else {
                    // 新しい窓を張れなかった。元の窓を張り直せたら外さずに止め続ける。
                    if let original = DailyOpenLimitPolicy.blockWindow(
                        startsAt: max(current.blockStartsAt, nowValue),
                        endsAt: current.blockEndsAt
                    ), register(original) {
                        return false
                    }
                    // どちらも張れない。解除の担い手がいないまま掛け続けないよう、今日はもう止めない。
                    stopAndClear()
                    consumeEmergencyRequest()
                    rememberOpenUntil(resumeAt)
                    return true
                }
                var moved = current
                moved.blockStartsAt = window.start
                moved.updatedAt = nowValue
                do {
                    try store.transaction { $0 = moved }
                } catch {
                    stopAndClear()
                }
            } else {
                // 起床まで15分を切る。止め直しは張れないので、今日はもう止めない。
                stopAndClear()
            }
        }
        consumeEmergencyRequest()
        rememberOpenUntil(resumeAt)
        applyCurrent()
        return true
    }

    private func consumeEmergencyRequest() {
        var settings = settingsStore.dailyOpenLimitSettings
        settings.emergencyRequestedAt = nil
        settingsStore.dailyOpenLimitSettings = settings
    }

    // MARK: - 後始末

    /// 監視を止め、控えを消し、シールドを外す。降格と全データ削除で使う。設定値は残す。
    ///
    /// 順序は「監視停止 → 控え削除 → 解除」（夜だけ強化と同じ）。
    func stopAndClear() {
        monitoring.stopMonitoring([Self.activityName])
        do {
            try store.transaction({ $0 = nil }, afterCommit: { _ in clearShield() })
        } catch {
            clearShield()
        }
    }

    // MARK: - 内部

    /// 使い切ったあとの完全ブロックを始める。止まっている途中の合わせ直しにも使う。
    @discardableResult
    private func engage(startsAt: Date, openedCount: Int, selections explicitSelections: [Data]? = nil) -> Bool {
        let nowValue = now()
        let endsAt = DailyOpenLimitPolicy.nextDayStart(now: nowValue, boundaryMinutes: boundaryMinutes, calendar: calendar)
        guard let window = DailyOpenLimitPolicy.blockWindow(startsAt: max(startsAt, nowValue), endsAt: endsAt) else {
            // 起床まで15分未満。監視を張れないので、一呼吸の入口の上限画面だけで止める。
            stopAndClear()
            return false
        }
        let selections = explicitSelections ?? blockSelections()
        guard !selections.isEmpty else {
            // 完全ブロックのアプリが無い。止める対象が無いので、入口の上限画面だけになる。
            stopAndClear()
            return false
        }
        let snapshot = DailyOpenLimitShieldSnapshot(
            selectionDataList: selections,
            openedCount: openedCount,
            blockStartsAt: window.start,
            blockEndsAt: window.end,
            updatedAt: nowValue
        )
        // 拡張は開始の通知で控えを読むため、控えを先に置いてから監視を張る。
        do {
            try store.transaction { $0 = snapshot }
        } catch {
            return false
        }
        guard register(window) else {
            stopAndClear()
            return false
        }
        applyCurrent()
        return true
    }

    /// 控えの窓どおりに監視が登録されているか。名前の有無だけでは、起床時刻を変えた直後に
    /// 終了した場合などに古い終わりの予定が残っていても気づけないため、時刻まで照合する。
    private func isRegistered(for snapshot: DailyOpenLimitShieldSnapshot, now: Date) -> Bool {
        guard let schedule = monitoring.schedule(for: Self.activityName),
              let start = calendar.date(from: schedule.intervalStart),
              let end = calendar.date(from: schedule.intervalEnd),
              abs(end.timeIntervalSince(snapshot.blockEndsAt)) < 1 else {
            return false
        }
        if snapshot.blockStartsAt > now {
            return abs(start.timeIntervalSince(snapshot.blockStartsAt)) < 1
        }
        return start <= now.addingTimeInterval(1)
    }

    private func register(_ window: DateInterval) -> Bool {
        let fields: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
        monitoring.stopMonitoring([Self.activityName])
        do {
            try monitoring.startMonitoring(
                Self.activityName,
                during: DeviceActivitySchedule(
                    intervalStart: calendar.dateComponents(fields, from: window.start),
                    intervalEnd: calendar.dateComponents(fields, from: window.end),
                    repeats: false
                ),
                events: [:]
            )
            return true
        } catch {
            return false
        }
    }

    /// 終わった控えを消し、いまの窓に合わせてシールドを掛け外しする。
    private func applyCurrent() {
        let nowValue = now()
        do {
            try store.transaction({ snapshot in
                if let current = snapshot, !DailyOpenLimitPolicy.isSnapshotCurrent(now: nowValue, snapshot: current) {
                    snapshot = nil
                }
            }, afterCommit: { snapshot in
                let tokens = DailyOpenLimitShield.tokensToShield(snapshot, now: nowValue)
                shieldWriter.setShield(
                    applications: tokens.applications,
                    categories: tokens.categories,
                    webDomains: tokens.webDomains
                )
            })
        } catch {
            clearShield()
        }
    }

    private func clearShield() {
        shieldWriter.setShield(applications: [], categories: [], webDomains: [])
    }

    /// 完全ブロックの対象。夜・予定の切り替えに関係なく、有効で選択データを持つルールすべて。
    private func blockSelections() -> [Data] {
        let rules = (try? ruleStore.allRules()) ?? []
        var seen = Set<Data>()
        return rules
            .filter { $0.isEnabled && !$0.activitySelectionData.isEmpty }
            .map(\.activitySelectionData)
            .filter { seen.insert($0).inserted }
    }
}
