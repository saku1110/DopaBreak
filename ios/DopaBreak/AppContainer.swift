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

@MainActor
@Observable
final class AppModel {
    private let goalStore: GoalStore
    let ruleStore: RuleStore
    let targetStore: InterventionTargetStore
    let screenTime: ScreenTimeCenter
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
    var alertMessage: String?

    /// 開始待ちの介入起動要求（AppIntent / URLスキーム経由）。RootTabView がこれを監視して
    /// InterventionFlowView を全画面表示する。
    var pendingInterventionCatalogID: String?

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
        self.shield = ShieldController(ruleStore: resolvedRuleStore)
        self.storeService = StoreService(funnelEventStore: funnelEventStore, now: now)
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

        // MVP: standardモードではシールドを適用しない（docs/12 §5）。
        // syncShield() 呼び出しは停止するが、ShieldController自体のコードは温存する。

        refresh()

        Task { [weak self] in
            guard let self else { return }
            await self.storeService.refreshEntitlement()
            self.refresh()
        }

        if logStore == nil {
            alertMessage = "記録データを準備できませんでした"
        }
    }

    func recordFunnelEvent(_ name: FunnelEventName, detail: String? = nil) {
        try? funnelEventStore.record(name: name, detail: detail, at: now())
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
            alertMessage = "データを読み込めませんでした"
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
        let displayTitles = goals.map { goal in
            let short = goal.lockScreenTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            return short.flatMap { $0.isEmpty ? nil : $0 } ?? goal.title
        }
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
                weeklySummary: weeklySummary
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

    var entitlementGate: EntitlementGate {
        EntitlementGate(
            isPro: storeService.isPro,
            now: now(),
            firstLaunchDate: settingsStore.firstLaunchDate
        )
    }

    /// MVPではシールド同期を無効化（docs/12 §5）。ShieldControllerのコードは温存し、
    /// v1.1でdeepFocus/nightOnly向けに再配線する。
    func syncShield() {
        // 意図的に no-op。
    }

    @discardableResult
    func deleteAllLocalData() -> Bool {
        // ルールを消す前に必ずManagedSettingsを解除し、削除済み選択を参照する
        // 孤立シールドが残らないようにする。
        shield.clearShield()
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
            alertMessage = nil
            refresh(scheduleNotifications: false)
            return true
        } catch {
            refresh(scheduleNotifications: false)
            alertMessage = "データを削除できませんでした"
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
        lockScreenTitle: String?
    ) -> Bool {
        guard canAddGoal else {
            alertMessage = "目標の追加にはProが必要です"
            return false
        }
        let now = Date()
        return persistGoal(
            Goal(
                id: UUID(),
                title: title,
                lockScreenTitle: normalizedLockTitle(lockScreenTitle),
                category: category,
                displayImagePath: nil,
                createdAt: now,
                updatedAt: now
            )
        )
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

    private func persistGoal(_ goal: Goal) -> Bool {
        do {
            try goalStore.save(goal)
            refresh()
            return true
        } catch CoreError.validation(let message) {
            alertMessage = message
            return false
        } catch {
            alertMessage = "目標を保存できませんでした"
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
            alertMessage = "目標を削除できませんでした"
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
            alertMessage = "並び替えできませんでした"
        }
    }

    /// アプリ起動要求を受け取る（AppIntent / dopabreak:// URL 経由）。
    func requestStartIntervention(catalogID: String) {
        guard SNSAppCatalog.contains(catalogID: catalogID) else {
            return
        }
        pendingInterventionCatalogID = catalogID
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
        guard SNSAppCatalog.contains(catalogID: catalogID) else {
            return
        }
        if !settingsStore.isAutomationVerified(catalogID: catalogID) {
            settingsStore.markAutomationVerified(catalogID: catalogID)
            recordFunnelEvent(.automationVerified, detail: catalogID)
        }
        requestStartIntervention(catalogID: catalogID)
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
    }

    private func clampSelectedTargetsToEntitlementLimit() throws {
        guard storeService.hasResolvedEntitlement else {
            return
        }
        let selectedCatalogIDs = try targetStore.selectedCatalogIDs()
        let clampedCatalogIDs = entitlementGate.clampedTargetAppCatalogIDs(selectedCatalogIDs)
        guard clampedCatalogIDs != selectedCatalogIDs else {
            return
        }
        try targetStore.setTargets(clampedCatalogIDs)
    }

    private func normalizedLockTitle(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func makeSettingsStore() -> SettingsStore {
        (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)
    }
}
