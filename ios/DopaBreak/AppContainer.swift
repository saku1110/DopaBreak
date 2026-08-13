import DopaBreakCore
import Foundation
import Observation

struct DefaultContainerProvider: ContainerProviding {
    func containerURL() throws -> URL {
        do {
            return try AppGroupContainer().containerURL()
        } catch {
            #if DEBUG
            return try debugContainerURL()
            #else
            throw error
            #endif
        }
    }

    #if DEBUG
    private func debugContainerURL() throws -> URL {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CoreError.fileSystem(
                operation: "resolve",
                path: "Application Support",
                message: "directory is unavailable"
            )
        }

        let containerURL = supportURL.appendingPathComponent("DopaBreak", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: containerURL,
                withIntermediateDirectories: true
            )
            return containerURL
        } catch {
            throw CoreError.fileSystem(
                operation: "createDirectory",
                path: containerURL.path,
                message: "\(error)"
            )
        }
    }
    #endif
}

/// 目標をロック画面へ出せているかの状態。確認導線（LockScreenCheck）の分岐に使う。
enum LockScreenGoalStatus: Equatable {
    /// 掲出できている。
    case visible
    /// 端末側でライブアクティビティがオフになっている。
    case systemDisabled
    /// 出す目標がまだない。
    case noGoal
    /// 許可はあるのに掲出できなかった。
    case failed
}

@MainActor
@Observable
final class AppModel {
    private let goalStore: GoalStore
    let ruleStore: RuleStore
    let targetStore: InterventionTargetStore
    let screenTime: ScreenTimeCenter
    let usageWatch: UsageWatchController
    let shield: ShieldController
    let storeService: StoreService
    let funnelEventStore: FunnelEventStore
    let interventionEngine: InterventionEngine?
    private let logStore: SQLiteLogStore?
    private let settingsStore: SettingsStore
    private let snapshotStore: JSONSnapshotStore
    private let statsService: StatsService?
    private let lockSurfaceCoordinator: LockSurfaceCoordinator
    private let containerProvider: any ContainerProviding
    private let now: () -> Date

    private(set) var goals: [Goal] = []
    private(set) var todayAttemptCount = 0
    private(set) var todayCancelledCount = 0
    private(set) var weekAttemptCount = 0
    private(set) var weekCancelledCount = 0
    private(set) var allTimeCancelledCount = 0
    private(set) var allTimeAttemptCount = 0
    private(set) var purchaseOrRestoreFailedAt: Date?
    var purchaseOrRestoreFailedThisSession: Bool {
        guard let purchaseOrRestoreFailedAt else {
            return false
        }
        return now().timeIntervalSince(purchaseOrRestoreFailedAt) < 5 * 60
    }
    var alertMessage: String?

    /// 開始待ちの介入起動要求（AppIntent / URLスキーム経由）。RootTabView がこれを監視して
    /// InterventionFlowView を全画面表示する。
    var pendingInterventionCatalogID: String?

    /// RootTabViewの自動提示と競合する、各タブ配下のsheet/fullScreenCover表示状態。
    var isChildModalActive = false

    /// 通知タップ（D1/D3/D7）からオートメーション設定ガイドを開く要求。SettingsViewが消費する。
    var pendingAutomationGuideRequest = false

    /// プラン系通知のタップから設定のプラン欄まで送る要求（docs/18 §2f）。
    /// プラン欄は設定の7セクション中5番目で初期表示に入らないため、タブを変えるだけでは着地しない。
    var pendingPlanSettingsFocus = false

    /// オンボーディング後にはじめて目標を追加したとき、ロック画面での確認導線を出す要求。
    private(set) var pendingLockScreenCheck = false

    init(
        containerProvider: any ContainerProviding = DefaultContainerProvider(),
        settingsStore: SettingsStore? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        let resolvedSettingsStore = settingsStore ?? Self.makeSettingsStore()
        self.settingsStore = resolvedSettingsStore
        self.containerProvider = containerProvider
        self.now = now
        if resolvedSettingsStore.firstLaunchDate == nil {
            resolvedSettingsStore.firstLaunchDate = now()
        }

        let snapshotStore = JSONSnapshotStore(containerProvider: containerProvider)
        self.snapshotStore = snapshotStore
        let funnelEventStore = FunnelEventStore(snapshotStore: snapshotStore)
        self.funnelEventStore = funnelEventStore
        self.lockSurfaceCoordinator = LockSurfaceCoordinator()
        let resolvedRuleStore = RuleStore(snapshotStore: snapshotStore)
        self.goalStore = GoalStore(snapshotStore: snapshotStore)
        self.ruleStore = resolvedRuleStore
        self.targetStore = InterventionTargetStore(snapshotStore: snapshotStore)
        self.screenTime = ScreenTimeCenter()
        let usageWatchStore = (try? UsageWatchStore())
            ?? UsageWatchStore(userDefaults: .standard)
        let usageWatchSelectionStore = (try? UsageWatchSelectionStore())
            ?? UsageWatchSelectionStore(userDefaults: .standard)
        self.usageWatch = UsageWatchController(
            settingsStore: resolvedSettingsStore,
            usageWatchStore: usageWatchStore,
            selectionStore: usageWatchSelectionStore
        )
        self.shield = ShieldController(ruleStore: resolvedRuleStore)
        self.storeService = StoreService(
            funnelEventStore: funnelEventStore,
            usageWatchStore: usageWatchStore,
            now: now
        )
        let resolvedLogStore = try? SQLiteLogStore(containerProvider: containerProvider)
        self.logStore = resolvedLogStore
        self.statsService = resolvedLogStore.map {
            StatsService(logStore: $0, now: now)
        }
        if let resolvedLogStore {
            self.interventionEngine = InterventionEngine(snapshotStore: snapshotStore, logStore: resolvedLogStore)
        } else {
            self.interventionEngine = nil
        }
        self.alertMessage = nil
        self.storeService.onPurchaseOrRestoreFailure = { [weak self] in
            guard let self else { return }
            self.purchaseOrRestoreFailedAt = self.now()
        }
        // 一回きりの通知は「予約が成立した事実」でマーカーを立てる。
        // 予約前に立てると、通知未許可の端末でマーカーだけ残り二度と送れなくなる。
        self.lockSurfaceCoordinator.onOneShotNotificationScheduled = { [weak resolvedSettingsStore] scheduled in
            guard let resolvedSettingsStore else { return }
            switch scheduled {
            case .annualUpgradeOffer(let fireDate):
                resolvedSettingsStore.annualUpgradeOfferNotificationFireDate = fireDate
            case .cancelSave(let fireDate, let expirationDate):
                resolvedSettingsStore.cancelSaveNotificationExpirationDate = expirationDate
                resolvedSettingsStore.cancelSaveNotificationFireDate = fireDate
            }
        }

        // MVP: standardモードではシールドを適用しない（docs/12 §5）。
        // syncShield() 呼び出しは停止するが、ShieldController自体のコードは温存する。

        refresh()

        Task { [weak self] in
            guard let self else { return }
            await self.storeService.refreshEntitlement()
            self.usageWatch.entitlementDidChange(isPro: self.storeService.isPro)
            self.refresh()
        }

        if logStore == nil {
            alertMessage = String(
                localized: "app.error.record_store_unavailable",
                defaultValue: "記録データを準備できませんでした"
            )
        }
    }

    func recordFunnelEvent(_ name: FunnelEventName, detail: String? = nil) {
        try? funnelEventStore.record(name: name, detail: detail, at: now())
    }

    func reviewPromptRequestDateIfEligible(sessionBlocked: Bool) -> Date? {
        guard let firstLaunchDate = settingsStore.firstLaunchDate,
              let statsService,
              let totalCancelledAllTime = try? statsService.cancelledAttemptsAllTime() else {
            return nil
        }

        let requestDate = now()
        guard ReviewPromptPolicy.shouldRequest(
            totalCancelledAllTime: totalCancelledAllTime,
            firstLaunchDate: firstLaunchDate,
            now: requestDate,
            pastEventDates: settingsStore.reviewPromptEventDates,
            sessionBlocked: sessionBlocked
        ) else {
            return nil
        }
        return requestDate
    }

    func recordReviewPromptShown(at date: Date) {
        settingsStore.reviewPromptEventDates = ReviewPromptPolicy.prunedEventDates(
            settingsStore.reviewPromptEventDates + [date],
            now: date
        )
        try? funnelEventStore.record(name: .reviewPromptShown, at: date)
    }

    func recordAppOpenedIfNeeded() {
        let recorder = DailyAppOpenRecorder(
            settingsStore: settingsStore,
            funnelEventStore: funnelEventStore
        )
        try? recorder.recordIfNeeded(at: now())
    }

    func refresh(
        restartLiveActivity: Bool = false,
        scheduleNotifications: Bool = true
    ) {
        do {
            try clampSelectedTargetsToEntitlementLimit()
            goals = try goalStore.goals()
            try refreshLogCounts()
            refreshLockSurfaces(
                restartLiveActivity: restartLiveActivity,
                scheduleNotifications: scheduleNotifications
            )
        } catch {
            alertMessage = String(localized: "app.error.data_load", defaultValue: "データを読み込めませんでした")
        }
    }

    /// ロック画面に出す表示名。短縮名があればそちらを使う。
    var lockScreenDisplayTitles: [String] {
        goals.map { goal in
            let short = goal.lockScreenTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            return short.flatMap { $0.isEmpty ? nil : $0 } ?? goal.title
        }
    }

    var lockSurfaceState: LockSurfaceState {
        var state = settingsStore.lockSurfaceState
        if !entitlementGate.lockThemeAllowed(state.theme) {
            state.theme = .e1
        }
        return state
    }

    func refreshLockSurfaces(
        restartLiveActivity: Bool = false,
        scheduleNotifications: Bool = true
    ) {
        let state = lockSurfaceState
        let goalTitles = goals.map(\.title)
        let displayTitles = lockScreenDisplayTitles
        let snapshot = WidgetSnapshot(
            primaryGoalTitle: goalTitles.first ?? "",
            displayTitle: displayTitles.first ?? "",
            todayCancelledCount: todayCancelledCount,
            todayAttemptCount: todayAttemptCount,
            theme: state.theme,
            updatedAt: now(),
            goalTitles: goalTitles,
            displayTitles: displayTitles
        )
        try? snapshotStore.write(snapshot, to: .widgetSnapshot)
        lockSurfaceCoordinator.reloadWidgets()

        if scheduleNotifications {
            let weeklySummary: WeeklySummary?
            if let statsService {
                weeklySummary = try? statsService.weeklySummary()
            } else {
                weeklySummary = nil
            }
            lockSurfaceCoordinator.rescheduleNotifications(
                goals: goals,
                state: state,
                weeklySummary: weeklySummary,
                retentionNotifications: retentionNotificationSchedules(),
                firstLaunchDate: settingsStore.firstLaunchDate,
                verifiedAutomationCatalogIDs: settingsStore.verifiedAutomationCatalogIDs,
                totalInterventionAttempts: allTimeAttemptCount,
                now: now()
            )
        }
        Task {
            await lockSurfaceCoordinator.refreshLiveActivity(
                goals: goals,
                state: state,
                todayCancelledCount: todayCancelledCount,
                todayAttemptCount: todayAttemptCount,
                restart: restartLiveActivity
            )
        }
    }

    func rescheduleNotificationsAfterAuthorization() async {
        refreshLockSurfaces()
        await lockSurfaceCoordinator.waitForNotificationReschedule()
    }

    /// 端末の許可状態と実際の掲出状況から、いまロック画面に目標が出ているかを返す。
    var lockScreenGoalStatus: LockScreenGoalStatus {
        guard !goals.isEmpty else {
            return .noGoal
        }
        guard lockSurfaceCoordinator.areActivitiesEnabled else {
            return .systemDisabled
        }
        return lockSurfaceCoordinator.isLiveActivityRunning ? .visible : .failed
    }

    /// 確認導線から呼ぶ即時掲出。アプリ内トグルがオフなら戻したうえで再掲出する。
    /// ユーザーがロック画面を見る前に出しておくことで、iOSの許可プロンプトを
    /// 「目標が出ている状態」と一緒に見せられる。
    func presentGoalOnLockScreen() async -> LockScreenGoalStatus {
        guard !goals.isEmpty else {
            return .noGoal
        }
        if !settingsStore.liveActivityEnabled {
            settingsStore.liveActivityEnabled = true
        }
        guard lockSurfaceCoordinator.areActivitiesEnabled else {
            return .systemDisabled
        }
        // すでに出ているものは更新で足りる。作り直すと、requestが失敗したときに
        // 有効だった掲出まで失う。
        await lockSurfaceCoordinator.refreshLiveActivity(
            goals: goals,
            state: lockSurfaceState,
            todayCancelledCount: todayCancelledCount,
            todayAttemptCount: todayAttemptCount,
            restart: false
        )
        return lockScreenGoalStatus
    }

    var lockScreenCheckCompleted: Bool {
        settingsStore.lockScreenCheckCompleted
    }

    func markLockScreenCheckCompleted() {
        settingsStore.lockScreenCheckCompleted = true
        pendingLockScreenCheck = false
    }

    func dismissPendingLockScreenCheck() {
        pendingLockScreenCheck = false
    }

    var entitlementGate: EntitlementGate {
        EntitlementGate(
            isPro: storeService.isPro,
            now: now()
        )
    }

    /// 対象アプリを上限まで縮小したときの補足。
    /// 文言キー名は14日時限開放時代の名残だが、現在はPro失効・無料枠での縮小の説明として現役
    /// （`clampSelectedTargetsToEntitlementLimit` が唯一の設定元・.claude/specs/design-decisions.md §733）。
    var targetAppClampNotice: String? {
        guard let catalogID = settingsStore.targetAppClampKeptCatalogID,
              let app = SNSAppCatalog.app(catalogID: catalogID) else {
            return nil
        }
        return String(
            localized: "app.day14_clamp.notice",
            defaultValue: "無料プランのため、よく開こうとしていた\(app.displayName)を残しました"
        )
    }

    /// MVPではシールド同期を無効化（docs/12 §5）。ShieldControllerのコードは温存し、
    /// v1.1でdeepFocus/nightOnly向けに再配線する。
    func syncShield() {
        // 意図的に no-op。
    }

    func syncUsageWatchEntitlement() {
        usageWatch.entitlementDidChange(isPro: storeService.isPro)
    }

    /// フォアグラウンド復帰のたびに権利を取り直す。
    /// iOS設定での自動更新オフは `Transaction` を流さないため、これがないと
    /// `willAutoRenew == false` をプロセスが生きている間ずっと検知できず、
    /// 解約セーブ通知（docs/18 §4）が一度も予約されないまま期限3日前を過ぎる。
    /// 完了時の `entitlementRevision` 変化をRootTabViewが拾って再スケジュールする。
    @discardableResult
    func refreshEntitlementOnForeground() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else {
                return
            }
            await self.storeService.refreshEntitlement()
        }
    }

    @discardableResult
    func deleteAllLocalData() -> Bool {
        // ルールを消す前に必ずManagedSettingsを解除し、削除済み選択を参照する
        // 孤立シールドが残らないようにする。
        shield.clearShield()
        usageWatch.stopAndClearAllData()
        lockSurfaceCoordinator.cancelAllNotifications()

        do {
            try LocalDataResetter(
                goalStore: goalStore,
                ruleStore: ruleStore,
                targetStore: targetStore,
                logStore: logStore,
                funnelEventStore: funnelEventStore,
                settingsStore: settingsStore,
                snapshotStore: snapshotStore,
                interventionEngine: interventionEngine,
                containerProvider: containerProvider
            ).deleteAllLocalData()
            pendingInterventionCatalogID = nil
            pendingLockScreenCheck = false
            alertMessage = nil
            refresh(scheduleNotifications: false)
            return true
        } catch {
            refresh(scheduleNotifications: false)
            alertMessage = String(localized: "app.error.data_delete", defaultValue: "データを削除できませんでした")
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        let restored = await storeService.restore()
        if !restored, let message = storeService.alertMessage {
            alertMessage = message
        }
        return restored
    }

    var canAddGoal: Bool {
        entitlementGate.canAddGoal(currentCount: goals.count)
    }

    @discardableResult
    func addGoal(
        title: String,
        category: GoalCategory,
        lockScreenTitle: String?,
        id: UUID = UUID()
    ) -> Bool {
        guard canAddGoal else {
            alertMessage = String(localized: "app.error.goal_pro_required", defaultValue: "目標の追加にはProが必要です")
            return false
        }
        let now = Date()
        let saved = persistGoal(
            Goal(
                id: id,
                title: title,
                lockScreenTitle: normalizedLockTitle(lockScreenTitle),
                category: category,
                displayImagePath: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        // オンボーディング中は専用ステップが確認導線を持つため、ここでは要求しない。
        if saved, settingsStore.onboardingCompleted, !settingsStore.lockScreenCheckCompleted {
            pendingLockScreenCheck = true
        }
        return saved
    }

    @discardableResult
    func updateGoal(
        _ goal: Goal,
        title: String,
        category: GoalCategory,
        lockScreenTitle: String?
    ) -> Bool {
        var updated = goal
        updated.title = title
        updated.category = category
        updated.lockScreenTitle = normalizedLockTitle(lockScreenTitle)
        return persistGoal(updated)
    }

    /// 目標の全件を一度に置き換える。オンボーディングの目標同期のように、
    /// 削除・更新・追加をまとめて確定する経路で使う。途中失敗で既存の目標を落とさない。
    ///
    /// ロック画面確認の要求はここでは出さない。オンボーディングには専用の確認ステップがある。
    @discardableResult
    func replaceGoals(_ newGoals: [Goal]) -> Bool {
        // 上限を超えて「増やす」操作だけを止める。
        // すでに上限を超えている既存データ（Proから戻った利用者など）はそのまま保てるようにする
        if let limit = entitlementGate.goalsLimit,
           newGoals.count > goals.count,
           newGoals.count > limit {
            alertMessage = String(localized: "app.error.goal_pro_required", defaultValue: "目標の追加にはProが必要です")
            return false
        }

        do {
            try goalStore.replace(goals: newGoals)
            refresh()
            return true
        } catch CoreError.validation(let message) {
            alertMessage = message
            return false
        } catch {
            alertMessage = String(localized: "app.error.goal_save", defaultValue: "目標を保存できませんでした")
            return false
        }
    }

    private func persistGoal(_ goal: Goal) -> Bool {
        do {
            try goalStore.save(goal)
            refresh()
            return true
        } catch CoreError.validation(let message) {
            alertMessage = message
            return false
        } catch {
            alertMessage = String(localized: "app.error.goal_save", defaultValue: "目標を保存できませんでした")
            return false
        }
    }

    @discardableResult
    func deleteGoal(id: UUID) -> Bool {
        do {
            try goalStore.delete(id: id)
            refresh()
            return true
        } catch {
            alertMessage = String(localized: "app.error.goal_delete", defaultValue: "目標を削除できませんでした")
            return false
        }
    }

    func moveGoal(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else {
            return
        }
        do {
            try goalStore.moveGoal(from: sourceIndex, to: destination)
            refresh()
        } catch {
            alertMessage = String(localized: "app.error.goal_reorder", defaultValue: "並び替えできませんでした")
        }
    }

    /// アプリ起動要求を受け取る（AppIntent / dopabreak:// URL 経由）。
    func requestStartIntervention(catalogID: String) {
        guard SNSAppCatalog.contains(catalogID: catalogID) else {
            return
        }
        pendingInterventionCatalogID = catalogID
    }

    func isCurrentInterventionTarget(catalogID: String) -> Bool {
        guard SNSAppCatalog.contains(catalogID: catalogID),
              let selectedCatalogIDs = try? targetStore.selectedCatalogIDs() else {
            return false
        }
        return selectedCatalogIDs.contains(catalogID)
    }

    func consumePendingIntervention() -> String? {
        let value = pendingInterventionCatalogID
        pendingInterventionCatalogID = nil
        return value
    }

    /// AppIntentがApp Groupへ残した要求を、本体プロセスの単一消費点で処理する。
    func consumePendingInterventionRequest(from settingsStore: SettingsStore) {
        guard let catalogID = settingsStore.pendingStartInterventionCatalogID else {
            return
        }
        settingsStore.pendingStartInterventionCatalogID = nil
        consumeInterventionRequest(catalogID: catalogID, settingsStore: settingsStore)
    }

    /// URLスキームを含む本体内の起動要求を、検収記録とともに処理する。
    func consumeInterventionRequest(catalogID: String, settingsStore: SettingsStore) {
        guard let target = SNSAppCatalog.app(catalogID: catalogID) else {
            return
        }
        if !settingsStore.isAutomationVerified(catalogID: catalogID) {
            settingsStore.markAutomationVerified(catalogID: catalogID)
            recordFunnelEvent(.automationVerified, detail: catalogID)
            lockSurfaceCoordinator.cancelActivationNotifications()
        }
        guard let selectedCatalogIDs = try? targetStore.selectedCatalogIDs(),
              selectedCatalogIDs.contains(catalogID) else {
            return
        }
        if let interventionEngine {
            try? interventionEngine.reshieldIfExpired()
            if let rule = try? ruleStore.catalogTargetRule(for: target),
               let state = try? interventionEngine.currentState(),
               state.hasActiveTemporaryAllowance(at: now(), for: rule.id) {
                return
            }
        }
        requestStartIntervention(catalogID: catalogID)
    }

    func setTargetCatalogIDs(_ catalogIDs: [String]) throws {
        try targetStore.setTargets(catalogIDs)
        settingsStore.targetAppClampKeptCatalogID = nil
        refreshLockSurfaces()
    }

    func todayAttemptCountForCurrentRule(catalogID: String) -> Int {
        guard let logStore else {
            return todayAttemptCount
        }
        guard let target = SNSAppCatalog.app(catalogID: catalogID),
              let rule = try? ruleStore.catalogTargetRule(for: target) else {
            return todayAttemptCount
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return todayAttemptCount
        }
        let attempts = (try? logStore.fetchAttempts(from: start, to: end)) ?? []
        return attempts.filter { $0.ruleId == rule.id }.count
    }

    private func refreshLogCounts() throws {
        guard let logStore else {
            resetLogCounts()
            return
        }

        let calendar = Calendar.current
        let today = Date()
        todayAttemptCount = try logStore.attemptCount(onDay: today, calendar: calendar)
        let todayAttempts = try attempts(onDay: today, calendar: calendar, logStore: logStore)
        todayCancelledCount = todayAttempts.filter { $0.decision == .cancelled }.count

        let weekAttempts = try attemptsInLastSevenDays(calendar: calendar, logStore: logStore)
        weekAttemptCount = weekAttempts.count
        weekCancelledCount = weekAttempts.filter { $0.decision == .cancelled }.count

        if let statsService {
            allTimeCancelledCount = try statsService.cancelledAttemptsAllTime()
            allTimeAttemptCount = try statsService.attemptsAllTime()
        } else {
            allTimeCancelledCount = 0
            allTimeAttemptCount = 0
        }
    }

    private func attempts(
        onDay day: Date,
        calendar: Calendar,
        logStore: SQLiteLogStore
    ) throws -> [AttemptLog] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        return try logStore.fetchAttempts(from: start, to: end)
    }

    private func attemptsInLastSevenDays(
        calendar: Calendar,
        logStore: SQLiteLogStore
    ) throws -> [AttemptLog] {
        let todayStart = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: todayStart),
              let end = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return []
        }
        return try logStore.fetchAttempts(from: start, to: end)
    }

    private func resetLogCounts() {
        todayAttemptCount = 0
        todayCancelledCount = 0
        weekAttemptCount = 0
        weekCancelledCount = 0
        allTimeCancelledCount = 0
        allTimeAttemptCount = 0
    }

    private func clampSelectedTargetsToEntitlementLimit() throws {
        guard storeService.hasResolvedEntitlement else {
            return
        }
        let selectedCatalogIDs = try targetStore.selectedCatalogIDs()
        let fallbackCatalogIDs = entitlementGate.clampedTargetAppCatalogIDs(selectedCatalogIDs)
        let clampedCatalogIDs: [String]
        if let logStore,
           selectedCatalogIDs.count > (entitlementGate.targetAppTokensLimit ?? Int.max) {
            do {
                let rules = try ruleStore.allRules()
                let ruleIDToCatalogID: [UUID: String] = Dictionary(uniqueKeysWithValues: selectedCatalogIDs.compactMap { catalogID in
                    guard let target = SNSAppCatalog.app(catalogID: catalogID),
                          let rule = rules.first(where: {
                              $0.activitySelectionData.isEmpty && $0.name == target.displayName
                          }) else {
                        return nil
                    }
                    return (rule.id, catalogID)
                })
                let end = now()
                let attempts = try logStore.fetchAttempts(
                    from: end.addingTimeInterval(-14 * 86_400),
                    to: end
                )
                var countsByCatalogID: [String: Int] = [:]
                for attempt in attempts {
                    guard let catalogID = ruleIDToCatalogID[attempt.ruleId] else {
                        continue
                    }
                    countsByCatalogID[catalogID, default: 0] += 1
                }
                clampedCatalogIDs = entitlementGate.clampedTargetAppCatalogIDs(
                    selectedCatalogIDs,
                    attemptCountsByCatalogID: countsByCatalogID
                )
            } catch {
                clampedCatalogIDs = fallbackCatalogIDs
            }
        } else {
            clampedCatalogIDs = fallbackCatalogIDs
        }
        guard clampedCatalogIDs != selectedCatalogIDs else {
            return
        }
        try targetStore.setTargets(clampedCatalogIDs)
        settingsStore.targetAppClampKeptCatalogID = clampedCatalogIDs.first
    }

    private func retentionNotificationSchedules() -> RetentionNotificationSchedules {
        guard storeService.hasResolvedEntitlement else {
            return .empty
        }

        let currentDate = now()
        let calendar = Calendar.current

        let trialDay5: RetentionNotificationSchedule?
        if let trial = storeService.annualTrialEntitlement,
           RetentionNotificationPolicy.shouldScheduleRenewalNotification(
               willAutoRenew: trial.willAutoRenew
           ),
           let fireDate = RetentionNotificationDateCalculator.trialDay5Date(
               from: trial.purchaseDate,
               calendar: calendar
           ) {
            trialDay5 = RetentionNotificationSchedule(
                fireDate: fireDate,
                cancelledCount: attemptSummary(from: trial.purchaseDate, to: currentDate).cancelled,
                attemptCount: 0
            )
        } else {
            trialDay5 = nil
        }

        let month1: RetentionNotificationSchedule?
        if let subscription = storeService.activeSubscriptionEntitlement,
           let fireDate = RetentionNotificationDateCalculator.nextMonthlyReportDate(
               from: subscription.initialPurchaseDate,
               now: currentDate,
               calendar: calendar
           ) {
            let firstMonthlyReportDate = RetentionNotificationDateCalculator.nextMonthlyReportDate(
                from: subscription.initialPurchaseDate,
                now: subscription.initialPurchaseDate,
                calendar: calendar
            )
            let trailingMonthStart = calendar.date(
                byAdding: .month,
                value: -1,
                to: currentDate
            ) ?? subscription.initialPurchaseDate
            // Local notification bodies are fixed when scheduled, so without another app launch
            // this trailing-month summary can represent an older window; that limitation is accepted.
            let summary = attemptSummary(
                from: max(subscription.initialPurchaseDate, trailingMonthStart),
                to: currentDate
            )
            month1 = RetentionNotificationSchedule(
                fireDate: fireDate,
                cancelledCount: summary.cancelled,
                attemptCount: summary.attempts,
                isFirstMonthlyReport: fireDate == firstMonthlyReportDate
            )
        } else {
            month1 = nil
        }

        let month12: RetentionNotificationSchedule?
        if let subscription = storeService.activeSubscriptionEntitlement,
           RetentionNotificationPolicy.shouldScheduleRenewalNotification(
               willAutoRenew: subscription.willAutoRenew
           ),
           subscription.isAnnual,
           let fireDate = RetentionNotificationDateCalculator.month12Date(
               from: subscription.purchaseDate,
               calendar: calendar
           ) {
            month12 = RetentionNotificationSchedule(
                fireDate: fireDate,
                cancelledCount: attemptSummary(from: subscription.purchaseDate, to: currentDate).cancelled,
                attemptCount: 0
            )
        } else {
            month12 = nil
        }

        // 年額移行オファー（docs/18 §4）。月額を3ヶ月続けた人へ一生に1回だけ。
        // プラン通知をオフにされた時点で予約は消えるため、まだ発火前のマーカーは戻す。
        // 残すと「オフにした数十秒」だけで一生に1回の機会を失う。
        if AnnualUpgradeOfferPolicy.shouldClearScheduledFireDate(
            isEnabled: settingsStore.planNotificationsEnabled,
            scheduledFireDate: settingsStore.annualUpgradeOfferNotificationFireDate,
            now: currentDate
        ) {
            settingsStore.annualUpgradeOfferNotificationFireDate = nil
        }
        let annualUpgradeOffer: RetentionNotificationSchedule?
        if let fireDate = AnnualUpgradeOfferPolicy.fireDate(
            subscription: storeService.activeSubscriptionEntitlement,
            isEnabled: settingsStore.planNotificationsEnabled,
            scheduledFireDate: settingsStore.annualUpgradeOfferNotificationFireDate,
            now: currentDate,
            calendar: calendar
        ) {
            annualUpgradeOffer = RetentionNotificationSchedule(
                fireDate: fireDate,
                cancelledCount: allTimeCancelledCount,
                attemptCount: 0
            )
        } else {
            annualUpgradeOffer = nil
        }

        // 解約セーブ（docs/18 §4）。自動更新オフのまま期限3日前に1回だけ。
        // 期限3日前を過ぎてから検知した場合は送らない（遅れて出す通知は作らない）。
        let cancelSave: CancelSaveNotificationSchedule?
        if let subscription = storeService.activeSubscriptionEntitlement,
           let expirationDate = subscription.expirationDate,
           let fireDate = CancelSaveNotificationPolicy.fireDate(
               subscription: subscription,
               isEnabled: settingsStore.planNotificationsEnabled,
               sentExpirationDate: settingsStore.cancelSaveNotificationExpirationDate,
               sentFireDate: settingsStore.cancelSaveNotificationFireDate,
               now: currentDate,
               calendar: calendar
           ) {
            cancelSave = CancelSaveNotificationSchedule(
                fireDate: fireDate,
                cancelledCount: allTimeCancelledCount,
                expirationDate: expirationDate
            )
        } else {
            cancelSave = nil
        }

        return RetentionNotificationSchedules(
            trialDay5: trialDay5,
            month1: month1,
            month12: month12,
            annualUpgradeOffer: annualUpgradeOffer,
            cancelSave: cancelSave
        )
    }

    private func attemptSummary(from start: Date, to end: Date) -> AttemptSummary {
        guard start < end, let statsService else {
            return AttemptSummary(attempts: 0, cancelled: 0)
        }
        return (try? statsService.attemptSummary(from: start, to: end)) ??
            AttemptSummary(attempts: 0, cancelled: 0)
    }

    private func normalizedLockTitle(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func makeSettingsStore() -> SettingsStore {
        (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)
    }
}
