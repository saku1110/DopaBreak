import ActivityKit
import DopaBreakCore
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation
import UIKit
import UserNotifications

@MainActor
private final class BackgroundTaskHandle {
    private let application: UIApplication
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(application: UIApplication) {
        self.application = application
    }

    func begin() {
        identifier = application.beginBackgroundTask { [weak self] in
            MainActor.assumeIsolated {
                self?.end()
            }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        application.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

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
    let shield: ShieldController
    let nightShieldScheduler: NightShieldScheduler
    let deepFocusScheduler: DeepFocusScheduler
    let reinterventionScheduler: ReinterventionScheduler
    var reinterventionRevision = 0
    /// 1日に開ける回数。操作と画面向けの読み出しは `AppModel+DailyOpenLimit.swift`。
    let dailyOpenLimit: DailyOpenLimitController
    /// 回数上限の状態が変わったことを画面へ配るための版番号。
    var dailyOpenLimitRevision = 0
    let reflectionNotificationScheduler: ReflectionNotificationScheduler
    let storeService: StoreService
    let funnelEventStore: FunnelEventStore
    let interventionEngine: InterventionEngine?
    private let logStore: SQLiteLogStore?
    private let settingsStore: SettingsStore
    private let clampBackupStore: TargetClampBackupStore
    let catalogAllowanceStore: CatalogAllowanceStore
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

    /// 夜だけ強化が「画面では有効なのに 実際のブロックが始まっていない」状態か。
    ///
    /// 画面の解放はキャッシュ済みのProで通し、実際のブロックはStoreKitで権利を
    /// 確かめられたときにしか始めない。この差は意図したものだが、差が開いているあいだは
    /// 何も起きないまま画面だけが効いている顔をする。それを設定画面へ持ち出すための旗。
    /// `syncShield()` を通るたびに引き直すので、接続が戻れば自動で下りる。
    private(set) var showsNightBlockUnarmedNotice = false

    /// 完全ブロック（ディープフォーカス）側の同じ旗。
    private(set) var showsDeepFocusUnarmedNotice = false

    /// 開始待ちの一呼吸起動要求。カタログとシールド解除を同じ全画面表示へ送る。
    var pendingOnboardingExperienceCatalogID: String?
    private var isOnboardingExperienceActive = false

    func takeOnboardingExperience(from settings: SettingsStore) -> SNSAppCatalogItem? {
        guard !settings.onboardingExperienceCompleted, !isOnboardingExperienceActive,
              let id = pendingOnboardingExperienceCatalogID,
              let target = SNSAppCatalog.app(catalogID: id) else { return nil }
        pendingOnboardingExperienceCatalogID = nil
        isOnboardingExperienceActive = true
        return target
    }

    /// アプリ内の体験画面から直接始める（ショートカットの自動化を待たない）。
    func beginInAppOnboardingExperience() {
        pendingOnboardingExperienceCatalogID = nil
        isOnboardingExperienceActive = true
    }

    func finishOnboardingExperience() {
        pendingOnboardingExperienceCatalogID = nil
        isOnboardingExperienceActive = false
    }

    var pendingInterventionTarget: InterventionTarget?

    /// 既存のAppIntent / URLスキーム呼び出し向けの互換窓口。
    var pendingInterventionCatalogID: String? {
        get {
            guard case .catalog(let target) = pendingInterventionTarget else {
                return nil
            }
            return target.catalogID
        }
        set {
            guard let newValue else {
                if case .catalog = pendingInterventionTarget {
                    pendingInterventionTarget = nil
                }
                return
            }
            requestStartIntervention(catalogID: newValue)
        }
    }

    /// RootTabViewの自動提示と競合する、各タブ配下のsheet/fullScreenCover表示状態。
    var isChildModalActive = false

    /// 通知タップ（D1/D3/D7）からオートメーション設定ガイドを開く要求。SettingsViewが消費する。
    var pendingAutomationGuideRequest = false

    /// ペイウォールでの購入後に対象アプリが追加され、設定ガイドの提示が必要なことを示す。
    var pendingAutomationGuideAfterPurchase = false

    /// プラン系通知のタップから設定のプラン欄まで送る要求（docs/18 §2f）。
    /// プラン欄は設定の7セクション中5番目で初期表示に入らないため、タブを変えるだけでは着地しない。
    var pendingPlanSettingsFocus = false

    /// ホームの導線から設定の「止める強さ」まで送る要求。SettingsViewが消費する。
    var pendingDeepFocusSettingsFocus = false

    /// オンボーディング後にはじめて目標を追加したとき、ロック画面での確認導線を出す要求。
    private(set) var pendingLockScreenCheck = false

    /// 介入の対象アプリが1つ以上選ばれているか。
    ///
    /// 対象は `JSONSnapshotStore` にあり、読むだけでは変更を観測できない。
    /// クイックアクションの介入枠は対象が0件だと着地先を持たないため、
    /// 書き込みのたびにここへ写して、SwiftUI側が `onChange` で追従できるようにする。
    private(set) var hasInterventionTargets = false

    /// FamilyControlsの現在の認可状態と、完全ブロック対象を持つ有効ルールの写し。
    private(set) var screenTimeAuthorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var blockTargetRuleCount = 0
    var isBlockConfigured: Bool {
        screenTimeAuthorizationStatus == .approved && blockTargetRuleCount > 0
    }

    /// 端末の設定でライブアクティビティが許可されているかの写し。
    /// ロック画面の最初の確認で「許可しない」を選ぶとfalseになる。
    /// `ActivityAuthorizationInfo` は@Observableではないため、ホームと完了画面が
    /// 変化に気づけるようここへ写し、前面復帰ごとに取り直す。
    private(set) var areLiveActivitiesAllowed: Bool
    private let liveActivityAuthorization: () -> Bool

    /// Paywall表示前にユーザーが選んだ操作。購入成立時だけ一度適用する。
    var purchaseContinuation: PurchaseContinuation?

    /// 対象から外れたアプリのShortcuts自動化が発火したときの案内。
    var pendingNonTargetAutomation: NonTargetAutomation?

    /// ロック画面テーマの現在値。正本はUserDefaultsのままだが、
    /// computedのままだと@Observableが変更を配れないため写しを保持する。
    private(set) var lockThemeSelection: LockTheme

    /// 無料ユーザーがProテーマを選んだときの購入待ち選択。
    /// 永続化せず、購入成立時にだけlockThemeSelectionへ確定する。
    var pendingProThemeSelection: LockTheme?

    /// 介入オーバーレイが画面に出ているか。ウォーム復帰時に
    /// 背景シールドをいつ外してよいかの判断に使う。
    var isInterventionOverlayPresented = false

    init(
        containerProvider: any ContainerProviding = DefaultContainerProvider(),
        settingsStore: SettingsStore? = nil,
        clampBackupStore: TargetClampBackupStore? = nil,
        catalogAllowanceStore: CatalogAllowanceStore? = nil,
        nightShieldMonitoringCenter: (any NightShieldMonitoring)? = nil,
        deepFocusMonitoringCenter: (any DeepFocusMonitoring)? = nil,
        deepFocusNotificationCenter: (any DeepFocusSessionNotifying)? = nil,
        reflectionNotificationCenter: (any ReflectionNotificationNotifying)? = nil,
        reinterventionMonitoringCenter: (any DeepFocusMonitoring)? = nil,
        dailyOpenLimitMonitoringCenter: (any DailyOpenLimitMonitoring)? = nil,
        dailyOpenLimitShieldWriter: (any ShieldSettingsWriting)? = nil,
        automaticallyRefreshEntitlement: Bool = true,
        scheduleNotificationsOnInit: Bool = true,
        screenTimeCenter: ScreenTimeCenter? = nil,
        liveActivityAuthorization: @escaping () -> Bool = { ActivityAuthorizationInfo().areActivitiesEnabled },
        now: @escaping () -> Date = { Date() }
    ) {
        let resolvedSettingsStore = settingsStore ?? Self.makeSettingsStore()
        resolvedSettingsStore.migrateStoredValues()
        self.settingsStore = resolvedSettingsStore
        self.lockThemeSelection = resolvedSettingsStore.lockTheme
        self.clampBackupStore = clampBackupStore ?? Self.makeClampBackupStore()
        self.catalogAllowanceStore = catalogAllowanceStore
            ?? ((try? CatalogAllowanceStore()) ?? CatalogAllowanceStore(userDefaults: .standard))
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
        self.liveActivityAuthorization = liveActivityAuthorization
        self.areLiveActivitiesAllowed = liveActivityAuthorization()
        let resolvedRuleStore = RuleStore(snapshotStore: snapshotStore)
        self.goalStore = GoalStore(snapshotStore: snapshotStore)
        self.ruleStore = resolvedRuleStore
        self.targetStore = InterventionTargetStore(snapshotStore: snapshotStore)
        self.screenTime = screenTimeCenter ?? ScreenTimeCenter()
        let resolvedShield = ShieldController(ruleStore: resolvedRuleStore)
        self.shield = resolvedShield
        self.nightShieldScheduler = NightShieldScheduler(
            ruleStore: resolvedRuleStore,
            settingsStore: resolvedSettingsStore,
            snapshotStore: snapshotStore,
            monitoringCenter: nightShieldMonitoringCenter ?? DeviceActivityCenter(),
            clearNightShield: { resolvedShield.clearNightShield() },
            now: now
        )
        self.deepFocusScheduler = DeepFocusScheduler(
            ruleStore: resolvedRuleStore,
            settingsStore: resolvedSettingsStore,
            snapshotStore: snapshotStore,
            monitoringCenter: deepFocusMonitoringCenter ?? DeviceActivityCenter(),
            notificationCenter: deepFocusNotificationCenter ?? UNUserNotificationCenter.current(),
            clearDeepFocusShield: { resolvedShield.clearDeepFocusShield() },
            now: now
        )
        self.reinterventionScheduler = ReinterventionScheduler(store: ReinterventionStore(snapshotStore: snapshotStore), monitoring: reinterventionMonitoringCenter ?? DeviceActivityCenter(), now: now)
        self.reflectionNotificationScheduler = ReflectionNotificationScheduler(
            notificationCenter: reflectionNotificationCenter ?? UNUserNotificationCenter.current()
        )
        self.storeService = StoreService(
            funnelEventStore: funnelEventStore,
            settingsStore: resolvedSettingsStore,
            startsBackgroundTasks: automaticallyRefreshEntitlement,
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
        self.dailyOpenLimit = DailyOpenLimitController(
            settingsStore: resolvedSettingsStore,
            ruleStore: resolvedRuleStore,
            logStore: resolvedLogStore,
            store: DailyOpenLimitStore(snapshotStore: snapshotStore),
            monitoring: dailyOpenLimitMonitoringCenter ?? DeviceActivityCenter(),
            shieldWriter: dailyOpenLimitShieldWriter ?? DailyOpenLimitController.makeShieldWriter(),
            now: now
        )
        if let rules = try? ruleStore.allRules(), !rules.isEmpty || resolvedSettingsStore.pendingInterventionMode != nil {
            resolvedSettingsStore.migrateBlockConfigurationIfNeeded(rules: rules)
        }
        resolvedSettingsStore.reconcileBlockEntitlement(isPro: storeService.isPro,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement)
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

        // AppIntentは別プロセスでApp Groupへ要求を書いてから本体を前面化する。
        // View生成後のactive通知まで待つとホームが1フレーム見えるため、モデルを返す前に同期消費する。
        if resolvedSettingsStore.onboardingCompleted {
            consumePendingInterventionRequest(from: resolvedSettingsStore)
        } else {
            consumeAutomationVerificationOnly(from: resolvedSettingsStore)
        }

        // 完全ブロックは refresh() の中で同期する。起動直後は権利が未確定のため
        // ShieldSyncPolicy が「現状維持」を返し、確定後の refresh() で適用・解除が決まる。
        refresh(scheduleNotifications: scheduleNotificationsOnInit)

        if automaticallyRefreshEntitlement {
            Task { [weak self] in
                guard let self else { return }
                await self.storeService.refreshEntitlement()
                self.refresh()
            }
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
        switch name {
        case .onboardingCompleted:
            AppleAdsMeasurement.shared.record(.onboardingCompleted)
        case .automationVerified:
            AppleAdsMeasurement.shared.record(.automationVerified)
        default:
            break
        }
    }

    var currentDate: Date { now() }

    func scheduleReflectionNotification(
        for reflection: ReflectionLog,
        appDisplayName: String,
        declaredMinutes: Int
    ) {
        let backgroundTask = BackgroundTaskHandle(application: .shared)
        backgroundTask.begin()
        reflectionNotificationScheduler.schedule(
            reflection: reflection,
            appDisplayName: appDisplayName,
            declaredMinutes: declaredMinutes,
            isEnabled: settingsStore.reflectionNotificationEnabled,
            now: now()
        ) { [weak self] didSchedule in
            Task { @MainActor in
                if didSchedule {
                    self?.reflectionNotificationScheduler.getNotificationAuthorizationStatus { [weak self] status in
                        switch status {
                        case .authorized, .provisional, .ephemeral:
                            Task { @MainActor in
                                self?.recordFunnelEvent(.reflectionNotificationScheduled)
                            }
                        case .notDetermined, .denied:
                            break
                        @unknown default:
                            break
                        }
                    }
                }
                backgroundTask.end()
            }
        }
    }

    func cancelReflectionNotification() {
        reflectionNotificationScheduler.cancel()
    }

    func removeDeliveredReflectionNotification() {
        reflectionNotificationScheduler.removeDelivered()
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

    func reclaimedSecondsAllTime() throws -> Int {
        guard let statsService else {
            throw CoreError.fileSystem(
                operation: "read",
                path: "reclaimed_ledger",
                message: "record store is unavailable"
            )
        }
        return try statsService.reclaimedSecondsAllTime()
    }

    func reclaimedSecondsToday() throws -> Int {
        guard let statsService else {
            throw CoreError.fileSystem(
                operation: "read",
                path: "reclaimed_ledger",
                message: "record store is unavailable"
            )
        }
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: now())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return 0
        }
        return try statsService.reclaimedSeconds(from: start, to: end)
    }

    func consecutiveDaysWithCancellations() throws -> Int {
        guard let statsService else {
            throw CoreError.fileSystem(
                operation: "read",
                path: "reclaimed_ledger",
                message: "record store is unavailable"
            )
        }
        return try statsService.consecutiveDaysWithCancellations(endingOn: now())
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
        screenTime.refresh()
        screenTimeAuthorizationStatus = screenTime.authorizationStatus
        refreshLiveActivityAuthorization()
        catalogAllowanceStore.purgeExpired(at: now())
        // 権利の確定・ルールの変更・起動と復帰のすべてがここを通る。
        // 途中のデータ読み込みが失敗しても完全ブロックの同期だけは必ず走らせる。
        // do-catchの中に置くと、目標や記録の読み取りに失敗した端末で
        // Pro失効時の解除が丸ごとスキップされる。
        // 対象アプリの有無も同じ理由でdeferに置く。縮小・復元・全削除のどの経路を通っても
        // 最新の件数がクイックアクション側へ伝わるようにする。
        // 廃止済み通知の掃除も、読み取り失敗で丸ごとスキップされないようにdeferに置く。
        defer {
            lockSurfaceCoordinator.purgeRetiredNotifications()
            refreshInterventionTargetState()
            refreshBlockConfigurationState()
            syncShield()
        }

        if lockThemeSelection != settingsStore.lockTheme {
            lockThemeSelection = settingsStore.lockTheme
        }

        do {
            try reconcileSelectedTargetsWithEntitlement()
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
        state.theme = lockThemeSelection
        if !entitlementGate.lockThemeAllowed(state.theme) {
            state.theme = .e1
        }
        return state
    }

    /// 実機のロック画面とウィジェットに出ているテーマ（権利ガード適用後）
    var liveLockTheme: LockTheme { lockSurfaceState.theme }

    /// ユーザーが選んで保存しているテーマ（無料でもProテーマになりうる）
    var savedLockTheme: LockTheme { lockThemeSelection }

    /// ピッカーと購入前サマリーに表示する選択。購入待ちを保存値より優先する。
    var displayedLockThemeSelection: LockTheme {
        pendingProThemeSelection ?? savedLockTheme
    }

    /// ロック画面テーマを保存し、掲出面と画面へ同時に反映する。
    func updateLockTheme(_ theme: LockTheme) {
        pendingProThemeSelection = nil
        settingsStore.lockTheme = theme
        lockThemeSelection = theme
        refreshLockSurfaces(scheduleNotifications: false)
    }

    /// 購入成立後だけ、メモリ上のProテーマ選択を永続値へ確定する。
    @discardableResult
    func applyPendingProThemeSelectionIfNeeded(hasProEntitlement: Bool) -> Bool {
        guard hasProEntitlement, let pendingProThemeSelection else {
            return false
        }
        updateLockTheme(pendingProThemeSelection)
        return true
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
                state: state,
                weeklySummary: weeklySummary,
                retentionNotifications: retentionNotificationSchedules(),
                // 権利が確定するまでは、権利に紐づく通知を積み直させない。
                // 取得に失敗しただけの課金者の予約を消し、無料向けの予約で置き換えてしまうため
                // （ユーザーが自分でオフにした分の取り消しは確定を待たずに実行される）。
                hasConfirmedEntitlement: storeService.hasConfirmedEntitlement,
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

    /// 端末のライブアクティビティ許可を取り直す。`refresh()` と、オンボーディング中も含む
    /// アプリ全体の前面復帰から呼ぶ。設定アプリで切り替えて戻ってきた変化をここで拾う。
    func refreshLiveActivityAuthorization() {
        let allowed = liveActivityAuthorization()
        if areLiveActivitiesAllowed != allowed {
            areLiveActivitiesAllowed = allowed
        }
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

    /// 完全ブロック（Deep Focus / 夜だけ強化）を現在の権利とルールへ合わせる（docs/12 §5）。
    ///
    /// 適用条件は「権利が確定していて」「Proで」「対象を持つルールがある」こと。
    /// さらにどちらの強さも窓の中でしか出さない。夜だけ強化は就寝から起床まで、
    /// ディープフォーカスは「いますぐ」で始めた回と週に最大2本の予定（2026-08-17オーナー決定④）。
    /// 権利が確定していない間は適用も解除もしない。判断は `ShieldSyncPolicy` にまとめてある。
    ///
    /// 窓の境界そのものは拡張（各スケジューラが張る予定）が動かすが、
    /// コールバックの取りこぼしがあるため、ここでの再計算を復旧経路として残す。
    ///
    /// 順序は「監視と控えの後始末 → シールドの適用・解除」。逆にすると、Freeへ戻った人の
    /// シールドを解除した直後に、まだ生きている監視と古い控えで拡張が張り直せてしまう。
    /// プロセスをまたぐ完全な排他はできないため窓は残るが、解除を最後に置けば
    /// この経路を通るたびに剥がれ、次にアプリが前面へ来たときには必ず解除される。
    func syncShield() {
        // 廃止済み常時ゲートが残した監視だけ、予定を張り直すより先に落とす。
        // DeviceActivityの枠には上限があるため、旧アクティビティが居座ったまま下のrebuildが
        // 新しい予定を登録すると、更新直後の初回だけ登録に失敗しうる。
        // 冪等で、掃除が済んだあとは問い合わせもしない（`ShieldController`）。
        shield.stopRetiredGateMonitoring()
        nightShieldScheduler.rebuild(
            entitlementGate: entitlementGate,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement
        )
        deepFocusScheduler.rebuild(
            entitlementGate: entitlementGate,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement
        )
        shield.syncShield(
            entitlementGate: entitlementGate,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement,
            isNightWindow: isArmedNightWindow,
            // 窓の外なら必ず解除へ倒れる。拡張の境界コールバックを取りこぼしても、
            // 前面へ戻ってきたこの一本で「終わったのに開けない」を必ず剥がす。
            isDeepFocusWindowActive: deepFocusScheduler.isArmedWindowActive,
            isManualDeepFocusSessionActive: deepFocusScheduler.isArmedSessionActive,
            blockConfiguration: settingsStore.blockConfiguration
        )
        // 回数上限は独立したストアと控えで動く。前面へ来るたびに、終わった窓を外し、
        // 使い切ったのに控えが無い状態を直す。
        dailyOpenLimit.sync(
            isPro: entitlementGate.dailyOpenLimitAllowed,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement
        )
        dailyOpenLimitRevision += 1
        blockRevision += 1
        if storeService.hasConfirmedEntitlement {
            lockSurfaceCoordinator.updateBlockWindows(storeService.isPro ? BlockWindowStatus.active(
                deepFocus: deepFocusScheduler.armedSnapshot,
                night: try? snapshotStore.read(NightShieldSnapshot.self, from: .nightShieldSnapshot),
                now: now(), calendar: .autoupdatingCurrent) : [])
        }
        refreshShieldArmingNotices()
        syncReintervention()
    }

    /// 「画面では有効なのに実体が動いていない」状態を画面へ渡し直す。
    ///
    /// スケジューラは`@Observable`ではないため、ここで持ち替えないと設定画面が気づけない。
    /// `syncShield()` の最後に必ず通す。権利が解決した次の同期で旗が下り、注意行も消える。
    private func refreshShieldArmingNotices() {
        let hasAttempted = storeService.hasResolvedEntitlement
        showsNightBlockUnarmedNotice = ShieldArmingNoticePolicy.shouldShowUnarmedNotice(
            outcome: nightShieldScheduler.lastRebuildOutcome,
            hasAttemptedEntitlementResolution: hasAttempted
        )
        showsDeepFocusUnarmedNotice = ShieldArmingNoticePolicy.shouldShowUnarmedNotice(
            outcome: deepFocusScheduler.lastRebuildOutcome,
            hasAttemptedEntitlementResolution: hasAttempted
        )
    }

    var blockMonitoringNeedsAttention: Bool {
        !storeService.hasConfirmedEntitlement || screenTimeAuthorizationStatus != .approved
            || showsNightBlockUnarmedNotice || showsDeepFocusUnarmedNotice
    }

    var reinterventionNotificationsEnabled: Bool { settingsStore.reflectionNotificationEnabled }

    var selectedReinterventionTargets: [SNSAppCatalogItem] {
        ((try? targetStore.selectedCatalogIDs()) ?? []).compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    func reinterventionSession(catalogID: String) -> ReinterventionSession? {
        try? reinterventionScheduler.store.read().sessions[catalogID]
    }

    func reinterventionSession(reflectionID: UUID) -> ReinterventionSession? {
        try? reinterventionScheduler.store.read().sessions.values.first { $0.reflectionID == reflectionID }
    }

    func isReinterventionConnected(catalogID: String) -> Bool {
        (try? reinterventionScheduler.store.read().selections[catalogID]) != nil
    }

    func connectReintervention(catalogID: String, selection: FamilyActivitySelection) throws {
        guard selection.applicationTokens.count == 1, selection.categoryTokens.isEmpty,
              selection.webDomainTokens.isEmpty, isCurrentInterventionTarget(catalogID: catalogID) else { throw ReinterventionError.selection }
        if let token = selection.applicationTokens.first, Application(token: token).bundleIdentifier == Bundle.main.bundleIdentifier { throw ReinterventionError.selection }
        let data = try JSONEncoder().encode(selection)
        try reinterventionScheduler.store.transaction { state in
            for (id, existing) in state.selections where id != catalogID {
                if !ReinterventionShield.tokens(in: existing).isDisjoint(with: selection.applicationTokens) { throw ReinterventionError.duplicate }
            }
            // Reconnecting must not silently reset a running time budget.
            guard state.sessions[catalogID] == nil else { throw ReinterventionError.monitoring }
            state.selections[catalogID] = data
        }
        reinterventionRevision += 1
    }

    func finishReintervention(catalogID: String, disconnect: Bool = false) throws {
        if let id = reinterventionSession(catalogID: catalogID)?.reflectionID { try interventionEngine?.skipReflection(id: id) }
        try reinterventionScheduler.finish(catalogID: catalogID, disconnect: disconnect)
        reflectionNotificationScheduler.cancelWorkCheckIn(catalogID: catalogID)
        catalogAllowanceStore.revoke(catalogID: catalogID)
        reinterventionRevision += 1
    }

    func requestEarlyReinterventionReview(catalogID: String) throws {
        try reinterventionScheduler.finishEarly(catalogID: catalogID)
        catalogAllowanceStore.revoke(catalogID: catalogID)
        syncReintervention()
    }

    func continueWithoutReintervention(catalogID: String) throws {
        guard isCurrentInterventionTarget(catalogID: catalogID), reinterventionSession(catalogID: catalogID) != nil else { return }
        try finishReintervention(catalogID: catalogID)
        cancelReflectionNotification()
        // A one-time routing request, not a persistent allowance. The next SNS open asks again.
        requestPassThrough(catalogID: catalogID, until: now().addingTimeInterval(60))
    }

    func resumeAfterReintervention(catalogID: String) throws {
        try reinterventionScheduler.store.transaction { $0.sessions[catalogID]?.resumeRequested = true }
        requestStartIntervention(catalogID: catalogID)
    }

    func pendingReinterventionReflection() -> ReflectionLog? {
        guard let sessions = try? reinterventionScheduler.store.read().sessions.values else { return nil }
        for session in sessions.sorted(by: { ($0.reachedAt ?? .distantPast) > ($1.reachedAt ?? .distantPast) }) {
            guard session.reachedAt != nil, !session.resumeRequested, let id = session.reflectionID else { continue }
            if let reflection = try? logStore?.reflection(id: id) { return reflection }
        }
        return nil
    }

    func syncReinterventionNotificationPreference() {
        do {
            try reinterventionScheduler.store.transaction { state in
                for id in Array(state.sessions.keys) {
                    state.sessions[id]?.notificationsEnabled = settingsStore.reflectionNotificationEnabled
                }
            }
        } catch { alertMessage = ReinterventionError.monitoring.localizedDescription }
    }

    private func syncReintervention() {
        do {
            let selected = Set(try targetStore.selectedCatalogIDs())
            let sessions = try reinterventionScheduler.store.read().sessions
            for (catalogID, session) in sessions {
                if session.expiresAt <= now() || !selected.contains(catalogID) || screenTimeAuthorizationStatus != .approved {
                    try finishReintervention(catalogID: catalogID)
                } else if !session.isBlocking, session.reachedAt != nil {
                    try finishReintervention(catalogID: catalogID)
                } else if let reachedAt = session.reachedAt, let id = session.reflectionID {
                    try logStore?.makeReflectionReady(id: id, at: reachedAt)
                    catalogAllowanceStore.revoke(catalogID: catalogID)
                }
            }
            // A removal or Free downgrade also disconnects catalog entries no longer selected.
            try reinterventionScheduler.store.transaction { state in
                state.selections = state.selections.filter { selected.contains($0.key) }
                for id in Array(state.sessions.keys) {
                    state.sessions[id]?.notificationsEnabled = settingsStore.reflectionNotificationEnabled
                }
            }
            ReinterventionShield.sync(store: reinterventionScheduler.store, now: now())
            reinterventionRevision += 1
        } catch {
            alertMessage = ReinterventionError.monitoring.localizedDescription
        }
    }

    private(set) var blockRevision = 0

    var blockConfiguration: BlockConfiguration {
        _ = blockRevision
        return settingsStore.blockConfiguration
    }

    func updateBlockTrigger(_ trigger: BlockTrigger, enabled: Bool) throws {
        guard entitlementGate.strictModeAllowed else { return }
        guard deepFocusSession?.isStrict != true else { throw StrictSessionChangeError() }
        var configuration = settingsStore.blockConfiguration
        if enabled { configuration.blockTriggers.insert(trigger) }
        else { configuration.blockTriggers.remove(trigger) }
        configuration.reconcileEntitlement(isPro: storeService.isPro,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement)
        settingsStore.blockConfiguration = configuration
        if trigger == .manual && !enabled { deepFocusScheduler.endSession() }
        syncShield()
    }

    /// 「いますぐ」で完全ブロックを始める。
    /// - Parameter durationMinutes: `nil` なら「自分で戻すまで」。
    func startDeepFocusSession(durationMinutes: Int?, isStrict: Bool = false) {
        guard storeService.isPro, storeService.hasConfirmedEntitlement,
              settingsStore.blockConfiguration.allows(.manual) else { return }
        deepFocusScheduler.startSession(durationMinutes: durationMinutes, isStrict: isStrict)
        syncShield()
    }

    /// 進行中の回をその場で終わらせる。
    func endDeepFocusSession(emergency: Bool = false) {
        deepFocusScheduler.endSession(emergency: emergency)
        syncShield()
    }

    /// 週に最大2本の予定を書き換える。書いたあと必ず同期して、いま窓に入ったかを反映する。
    func updateDeepFocusSchedule(_ schedule: DeepFocusSchedule, index: Int = 0) {
        var schedules = settingsStore.deepFocusSchedules
        guard (0..<2).contains(index) else { return }
        if index == schedules.count { schedules.append(schedule) } else { schedules[index] = schedule }
        settingsStore.deepFocusSchedules = schedules
        syncShield()
    }

    var deepFocusSchedules: [DeepFocusSchedule] { settingsStore.deepFocusSchedules }

    func removeAdditionalDeepFocusSchedule() {
        settingsStore.deepFocusSchedules = [settingsStore.deepFocusSchedule]
        syncShield()
    }

    var deepFocusScheduleWindowEnd: Date? {
        DeepFocusWindowPolicy.scheduleWindowEnd(now: now(), schedules: deepFocusSchedules, calendar: .autoupdatingCurrent)
    }

    var deepFocusSchedule: DeepFocusSchedule {
        settingsStore.deepFocusSchedule
    }

    func requestEmergencyDeepFocusExit() { deepFocusScheduler.requestEmergencyExit() }

    var deepFocusSession: DeepFocusSession? {
        deepFocusScheduler.activeSession
    }

    var isDeepFocusWindowActive: Bool {
        deepFocusScheduler.isWindowActive
    }

    /// いま予定（毎週）の時間帯に入っているか。
    /// セッションの解除では開かない状態を、画面が正しく出し分けるために使う。
    var isDeepFocusScheduleWindowActive: Bool {
        DeepFocusWindowPolicy.isScheduleActive(
            now: now(),
            schedules: settingsStore.deepFocusSchedules,
            calendar: .autoupdatingCurrent
        )
    }

    /// 進行中の回の残り（秒）。「自分で戻すまで」と、進行中でないときは `nil`。
    var deepFocusSessionRemainingSeconds: TimeInterval? {
        DeepFocusWindowPolicy.remainingSeconds(
            now: now(),
            session: settingsStore.deepFocusSession
        )
    }

    private var isArmedNightWindow: Bool {
        guard let snapshot = try? snapshotStore.read(NightShieldSnapshot.self, from: .nightShieldSnapshot) else { return false }
        return NightWindowPolicy.isNight(now: now(), snapshot: snapshot, calendar: .autoupdatingCurrent)
    }

    /// いまが夜（就寝から起床まで）か。夜専用の時間帯は持たず、設定済みの就寝・起床をそのまま使う。
    private var isNightWindow: Bool {
        NightWindowPolicy.isNight(
            now: now(),
            bedTimeMinutes: settingsStore.bedTimeMinutes ?? NightShieldConstants.defaultBedTimeMinutes,
            wakeTimeMinutes: settingsStore.wakeTimeMinutes ?? NightShieldConstants.defaultWakeTimeMinutes,
            calendar: .autoupdatingCurrent
        )
    }

    /// 一呼吸の対象ルールを用意してから、購入結果に応じて選択済みブロックを適用する。
    /// Pro未購入でもトリガー選択は保持し、後日の購入で復帰できるようにする。
    func applyBlockPreference(_ enabled: Bool) throws {
        guard deepFocusSession?.isStrict != true else { throw StrictSessionChangeError() }
        for catalogID in try targetStore.selectedCatalogIDs() {
            guard let target = SNSAppCatalog.app(catalogID: catalogID) else { continue }
            // The free breathing rule stays independent of every block trigger.
            _ = try ruleStore.catalogTargetRule(for: target)
        }
        settingsStore.selectBlockPreference(enabled)
        settingsStore.reconcileBlockEntitlement(isPro: storeService.isPro,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement)
        if !enabled { deepFocusScheduler.endSession() }
        syncShield()
    }

    /// 旧モードのルールを扱う互換入口。現行UIはapplyBlockPreferenceを使用する。
    func applyInterventionMode(_ mode: InterventionMode) throws {
        guard deepFocusSession?.isStrict != true else { throw StrictSessionChangeError() }
        settingsStore.blockConfiguration = .migrating(mode)
        settingsStore.reconcileBlockEntitlement(isPro: storeService.isPro, hasConfirmedEntitlement: storeService.hasConfirmedEntitlement)
        // Compatibility entry point for onboarding and purchase continuation.
        let mode = mode.persistable
        let catalogIDs = try targetStore.selectedCatalogIDs()

        for catalogID in catalogIDs {
            guard let target = SNSAppCatalog.app(catalogID: catalogID) else {
                continue
            }
            let rule = try ruleStore.catalogTargetRule(for: target, modeForNewRule: mode)
            if rule.mode != mode {
                try ruleStore.updateMode(id: rule.id, mode: mode)
            }
        }

        // 選択データを持つ完全ブロック用のルールも同じ強さへ揃える。
        // 設定画面の「止める強さ」は画面上ひとつの設定として見えるため、
        // ルールごとに食い違うと、切り替えたのにブロックが外れない状態になる。
        for rule in try ruleStore.allRules()
        where !rule.activitySelectionData.isEmpty && rule.mode != mode {
            try ruleStore.updateMode(id: rule.id, mode: mode)
        }

        // ディープフォーカスから離れたら、進行中の回はその場で畳む。
        // 残すと「自分で戻すまで」の回が眠ったまま生き残り、あとでディープフォーカスへ
        // 戻した瞬間に、本人が始めていないブロックが復活する。
        // 予定（毎週）は設定として残す。こちらは時間が来るまで何も起こさず、
        // 強さを戻したときに前の設定がそのまま使えるほうが自然なため。
        if mode != .deepFocus {
            deepFocusScheduler.endSession()
        }

        syncShield()
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
        // 孤立シールドが残らないようにする。夜だけ強化は控えと監視も止める。
        // 残すと、ルールを消したあとの夜境界で拡張が同じ対象を張り直す。
        // 順序は「監視停止と控え削除 → 解除」。解除を先に置くと、消しきる前の境界で
        // 拡張が張り直したぶんが残る。
        try? reinterventionScheduler.reset()
        for app in SNSAppCatalog.all { reflectionNotificationScheduler.cancelWorkCheckIn(catalogID: app.catalogID) }
        nightShieldScheduler.stopAndClear()
        deepFocusScheduler.stopAndClear()
        dailyOpenLimit.stopAndClear()
        shield.clearShield()
        lockSurfaceCoordinator.cancelAllNotifications()
        cancelReflectionNotification()

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
            // 全削除のあとに縮小前の並びが蘇らないよう控えも捨てる
            // （`SettingsStore.resettable` の外にあるキーのため、ここで明示的に消す）。
            clampBackupStore.clear()
            pendingInterventionTarget = nil
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

    @discardableResult
    func addGoal(
        title: String,
        category: GoalCategory,
        lockScreenTitle: String?,
        id: UUID = UUID()
    ) -> Bool {
        // 目標の件数制限は撤廃済み（2026-08-17オーナー決定）。Free・Proとも何件でも足せる
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
        // 件数制限は撤廃済み（2026-08-17オーナー決定）。ここで増減を止めない
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

    var isInterventionSuppressedByHardBlock: Bool {
        ReinterventionShield.suppressesIntervention(snapshotStore: snapshotStore, now: now())
    }

    /// アプリ起動要求を受け取る（AppIntent / dopabreak:// URL 経由）。
    func requestStartIntervention(catalogID: String) {
        guard !isInterventionSuppressedByHardBlock else {
            pendingInterventionTarget = nil
            return
        }
        guard let target = SNSAppCatalog.app(catalogID: catalogID) else {
            return
        }
        if let session = reinterventionSession(catalogID: catalogID), session.isBlocking, session.reachedAt != nil, !session.resumeRequested {
            pendingInterventionTarget = nil
            syncReintervention()
            return
        }
        pendingInterventionTarget = .catalog(target)
    }

    func requestPassThrough(catalogID: String, until: Date) {
        guard !isInterventionSuppressedByHardBlock else {
            pendingInterventionTarget = nil
            return
        }
        guard let target = SNSAppCatalog.app(catalogID: catalogID) else {
            return
        }
        guard until > now() else {
            requestStartIntervention(catalogID: catalogID)
            return
        }
        recordFunnelEvent(.interventionPassThrough, detail: catalogID)
        pendingInterventionTarget = .catalogPassThrough(target, until: until)
    }

    /// 非同期の提示callbackが見ていた要求だけを破棄する。
    /// callback後に別要求へ置き換わっていた場合は新しい要求を保持する。
    @discardableResult
    func discardPendingInterventionTarget(ifMatching target: InterventionTarget) -> Bool {
        guard pendingInterventionTarget == target else {
            return false
        }
        pendingInterventionTarget = nil
        return true
    }

    func isCurrentInterventionTarget(catalogID: String) -> Bool {
        guard SNSAppCatalog.contains(catalogID: catalogID),
              let selectedCatalogIDs = try? targetStore.selectedCatalogIDs() else {
            return false
        }
        return selectedCatalogIDs.contains(catalogID)
    }

    func consumePendingIntervention() -> String? {
        guard case .catalog(let target) = pendingInterventionTarget else {
            return nil
        }
        pendingInterventionTarget = nil
        return target.catalogID
    }

    /// AppIntentがApp Groupへ残した要求を、本体プロセスの単一消費点で処理する。
    func consumePendingInterventionRequest(
        from settingsStore: SettingsStore,
        suppressPassThrough: Bool = false
    ) {
        let requestedCatalogID = settingsStore.pendingStartInterventionCatalogID
        let shouldAutoResolve = settingsStore.pendingStartInterventionAutoResolve
        let requestedAt = settingsStore.pendingStartInterventionRequestedAt
        guard requestedCatalogID != nil || shouldAutoResolve else {
            return
        }
        settingsStore.pendingStartInterventionCatalogID = nil
        settingsStore.pendingStartInterventionAutoResolve = false
        settingsStore.pendingStartInterventionRequestedAt = nil

        let selectedCatalogIDs = (try? targetStore.selectedCatalogIDs()) ?? []
        if requestedCatalogID == nil,
           Set(selectedCatalogIDs.filter { SNSAppCatalog.contains(catalogID: $0) }).count > 1 {
            alertMessage = String(localized: "automation_guide.error.select_app", defaultValue: "ショートカットの「DopaBreakで一呼吸」の「アプリ」に、起動するSNSを指定してください。対象が複数あるため自動では判別できません。")
        }
        switch InterventionTargetResolutionPolicy.resolve(
            requested: requestedCatalogID,
            selected: selectedCatalogIDs
        ) {
        case .target(let catalogID):
            markAutomationVerifiedIfNeeded(catalogID: catalogID, settingsStore: settingsStore)
            guard shouldConsumeAutomationRequest(
                catalogID: catalogID,
                requestedAt: requestedAt,
                settingsStore: settingsStore
            ) else {
                return
            }
            consumeInterventionRequest(
                catalogID: catalogID,
                settingsStore: settingsStore,
                suppressPassThrough: suppressPassThrough
            )
        case .none:
            break
        }
    }

    /// オンボーディング中の発火を検証し、permission画面が提示する体験用に保留する。
    /// 同じApp Group要求を通常経路と競合しない形で一度だけ消費する。
    @discardableResult
    func consumeAutomationVerificationOnly(from settingsStore: SettingsStore) -> String? {
        let requestedCatalogID = settingsStore.pendingStartInterventionCatalogID
        let shouldAutoResolve = settingsStore.pendingStartInterventionAutoResolve
        let requestedAt = settingsStore.pendingStartInterventionRequestedAt
        guard requestedCatalogID != nil || shouldAutoResolve else {
            return nil
        }
        settingsStore.pendingStartInterventionCatalogID = nil
        settingsStore.pendingStartInterventionAutoResolve = false
        settingsStore.pendingStartInterventionRequestedAt = nil

        let selectedCatalogIDs = (try? targetStore.selectedCatalogIDs()) ?? []
        if requestedCatalogID == nil,
           Set(selectedCatalogIDs.filter { SNSAppCatalog.contains(catalogID: $0) }).count > 1 {
            alertMessage = String(localized: "automation_guide.error.select_app", defaultValue: "ショートカットの「DopaBreakで一呼吸」の「アプリ」に、起動するSNSを指定してください。対象が複数あるため自動では判別できません。")
        }
        guard case .target(let catalogID) = InterventionTargetResolutionPolicy.resolve(
            requested: requestedCatalogID,
            selected: selectedCatalogIDs
        ) else {
            return nil
        }
        markAutomationVerifiedIfNeeded(catalogID: catalogID, settingsStore: settingsStore)
        guard shouldConsumeAutomationRequest(
            catalogID: catalogID,
            requestedAt: requestedAt,
            settingsStore: settingsStore
        ) else {
            return nil
        }
        if !settingsStore.onboardingExperienceCompleted, !isOnboardingExperienceActive {
            pendingOnboardingExperienceCatalogID = catalogID
        }
        return catalogID
    }

    /// URLスキームを含む本体内の起動要求を、検収記録とともに処理する。
    func consumeInterventionRequest(
        catalogID: String,
        settingsStore: SettingsStore,
        suppressPassThrough: Bool = false
    ) {
        guard SNSAppCatalog.contains(catalogID: catalogID) else {
            return
        }
        markAutomationVerifiedIfNeeded(catalogID: catalogID, settingsStore: settingsStore)
        guard !isInterventionSuppressedByHardBlock else {
            pendingInterventionTarget = nil
            return
        }
        guard let selectedCatalogIDs = try? targetStore.selectedCatalogIDs() else {
            return
        }
        guard selectedCatalogIDs.contains(catalogID) else {
            let wasClamped = clampBackupStore.backup?.originalCatalogIDs.contains(catalogID) == true
            let reason: NonTargetAutomationReason = wasClamped ? .clampedByEntitlement : .removed
            pendingNonTargetAutomation = NonTargetAutomation(catalogID: catalogID, reason: reason)
            recordFunnelEvent(.automationNonTargetShown, detail: reason.rawValue)
            return
        }
        if let session = reinterventionSession(catalogID: catalogID), session.reachedAt != nil {
            requestStartIntervention(catalogID: catalogID)
            return
        }
        if let until = catalogAllowanceStore.activeAllowance(catalogID: catalogID, at: now()) {
            guard !suppressPassThrough else {
                return
            }
            requestPassThrough(catalogID: catalogID, until: until)
            return
        }
        requestStartIntervention(catalogID: catalogID)
    }

    private func shouldConsumeAutomationRequest(
        catalogID: String,
        requestedAt: Date?,
        settingsStore: SettingsStore
    ) -> Bool {
        switch AutomationRequestPolicy.decision(
            requestedCatalogID: catalogID,
            requestedAt: requestedAt,
            now: now(),
            lastSelfOpenedCatalogID: settingsStore.lastSelfOpenedCatalogID,
            lastSelfOpenedAt: settingsStore.lastSelfOpenedAt
        ) {
        case .consume:
            return true
        case .discardStale:
            recordFunnelEvent(.automationRequestDiscarded, detail: "stale")
            return false
        case .discardSelfOpen:
            recordFunnelEvent(.automationRequestDiscarded, detail: "self_open")
            settingsStore.lastSelfOpenedCatalogID = nil
            settingsStore.lastSelfOpenedAt = nil
            return false
        }
    }

    /// 自動化の発火を確認できているアプリ。対象から外した直後の案内判定に使う。
    var verifiedAutomationCatalogIDs: [String] {
        settingsStore.verifiedAutomationCatalogIDs
    }

    /// 本体からそのアプリを開いたことを記録する。
    ///
    /// 開いた先で自動化がもう一度発火しても、`AutomationRequestPolicy` が
    /// 自己起動として捨てられるようにするための記録。
    /// `settingsStore` が private なので、外の画面はこの窓口から書く。
    func markSelfOpened(catalogID: String) {
        settingsStore.lastSelfOpenedCatalogID = catalogID
        settingsStore.lastSelfOpenedAt = now()
    }

    private func markAutomationVerifiedIfNeeded(
        catalogID: String,
        settingsStore: SettingsStore
    ) {
        guard SNSAppCatalog.contains(catalogID: catalogID),
              !settingsStore.isAutomationVerified(catalogID: catalogID) else {
            return
        }
        settingsStore.markAutomationVerified(catalogID: catalogID)
        recordFunnelEvent(.automationVerified, detail: catalogID)
        lockSurfaceCoordinator.cancelActivationNotifications()
    }

    func setTargetCatalogIDs(_ catalogIDs: [String]) throws {
        let previousCatalogIDs = try targetStore.selectedCatalogIDs()
        try targetStore.setTargets(catalogIDs)
        for removedCatalogID in Set(previousCatalogIDs).subtracting(catalogIDs) {
            catalogAllowanceStore.revoke(catalogID: removedCatalogID)
        }
        settingsStore.targetAppClampKeptCatalogID = nil
        // 自分で選び直したのだから、縮小前の並びへ勝手に戻してはいけない。
        clampBackupStore.clear()
        refreshInterventionTargetState()
        refreshLockSurfaces()
    }

    @discardableResult
    func applyPurchaseContinuationIfNeeded() -> Bool {
        guard storeService.isPro else { return false }
        settingsStore.reconcileBlockEntitlement(isPro: storeService.isPro,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement)
        blockRevision += 1
        defer { purchaseContinuation = nil }
        do {
            if case .addTarget = purchaseContinuation?.action {
                try reconcileSelectedTargetsWithEntitlement()
            }
            let selectedCatalogIDs = try targetStore.selectedCatalogIDs()
            guard let action = PurchaseContinuationPolicy.action(
                for: purchaseContinuation,
                isPro: true,
                canAddTarget: entitlementGate.canAddTargetTokens(
                    currentCount: selectedCatalogIDs.count
                ),
                selectedCatalogIDs: selectedCatalogIDs,
                now: now()
            ) else {
                return false
            }
            switch action {
            case .addTargets(let catalogIDs):
                try setTargetCatalogIDs(catalogIDs)
                pendingAutomationGuideAfterPurchase = true
            case .applyMode(let mode):
                try applyBlockPreference(mode != .standard)
            }
            return true
        } catch {
            alertMessage = String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
            return false
        }
    }

    func requestScreenTimeAuthorization() async -> Bool {
        let granted = await screenTime.requestAuthorization()
        screenTimeAuthorizationStatus = screenTime.authorizationStatus
        return granted
    }

    func refreshScreenTimeAuthorizationStatus() {
        screenTime.refresh()
        screenTimeAuthorizationStatus = screenTime.authorizationStatus
    }

    @discardableResult
    func saveBlockedAppSelection(
        _ selection: FamilyActivitySelection,
        mode: InterventionMode
    ) -> Bool {
        guard deepFocusSession?.isStrict != true else {
            alertMessage = StrictSessionChangeError().localizedDescription
            return false
        }
        guard storeService.isPro else { return false }
        let isSelectionEmpty = selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty

        do {
            let existingRule = try ruleStore.allRules().first { !$0.activitySelectionData.isEmpty }
            if let existingRule {
                if isSelectionEmpty {
                    try ruleStore.deleteRule(id: existingRule.id)
                } else {
                    let data = try JSONEncoder().encode(selection)
                    try ruleStore.saveFamilyActivitySelection(
                        data,
                        name: existingRule.name,
                        mode: mode,
                        defaultDurationMinutes: existingRule.defaultDurationMinutes,
                        ruleId: existingRule.id
                    )
                }
            } else if !isSelectionEmpty {
                let data = try JSONEncoder().encode(selection)
                try ruleStore.saveFamilyActivitySelection(data, name: "SNS", mode: mode)
            }
            refreshBlockConfigurationState()
            syncShield()
            return true
        } catch CoreError.validation(let message) {
            alertMessage = message
            return false
        } catch {
            alertMessage = String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
            return false
        }
    }

    func ensureWakeSleepDefaults() {
        if settingsStore.wakeTimeMinutes == nil {
            settingsStore.wakeTimeMinutes = 420
        }
        if settingsStore.bedTimeMinutes == nil {
            settingsStore.bedTimeMinutes = 1_380
        }
    }

    /// 保存済みの対象アプリ件数を観測できる状態へ写す。
    /// 読み取りに失敗したときは0件扱いにせず、直前の値を保つ
    /// （一時的な読み取り失敗で、使えていた介入枠を消さないため）。
    private func refreshInterventionTargetState() {
        guard let catalogIDs = try? targetStore.selectedCatalogIDs() else {
            return
        }
        let hasTargets = !catalogIDs.isEmpty
        guard hasTargets != hasInterventionTargets else {
            return
        }
        hasInterventionTargets = hasTargets
    }

    private func refreshBlockConfigurationState() {
        guard let enabledRules = try? ruleStore.enabledRules() else { return }
        blockTargetRuleCount = enabledRules.filter { !$0.activitySelectionData.isEmpty }.count
    }

    func todayAttemptCount(for ruleId: UUID) -> Int {
        guard let logStore else {
            return todayAttemptCount
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return todayAttemptCount
        }
        let attempts = (try? logStore.fetchAttempts(from: start, to: end)) ?? []
        return attempts.filter { $0.ruleId == ruleId }.count
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

    /// 対象アプリの選択を、確定したEntitlementへ突き合わせる。
    /// 無料枠への縮小と、Pro復帰時の復元の唯一の入口。
    ///
    /// 判断は `hasResolvedEntitlement`（＝解決を1度試した）ではなく
    /// `hasConfirmedEntitlement`（＝StoreKitへ届いたうえで解決できた）で行う。
    /// 取得に失敗しただけの課金者を無料扱いして選択を削ると、復元経路のない永久削除になる。
    private func reconcileSelectedTargetsWithEntitlement() throws {
        let selectedCatalogIDs = try targetStore.selectedCatalogIDs()

        switch TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement,
            isPro: storeService.isPro,
            selectedCatalogIDs: selectedCatalogIDs,
            backup: clampBackupStore.backup
        ) {
        case .skip:
            return
        case .noAction:
            clearClampNoticeIfNeeded()
        case .discardBackup:
            clampBackupStore.clear()
            // 控えを捨てるのはPro確定時だけ。縮小の注記を残すと
            // 「無料プランのため残しました」が課金者の画面に永久に居座る。
            clearClampNoticeIfNeeded()
        case .restore(let catalogIDs):
            try targetStore.setTargets(catalogIDs)
            clampBackupStore.clear()
            clearClampNoticeIfNeeded()
        case .clamp:
            try clampSelectedTargetsToEntitlementLimit(selectedCatalogIDs: selectedCatalogIDs)
        }
    }

    private func clampSelectedTargetsToEntitlementLimit(selectedCatalogIDs: [String]) throws {
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
        // 書き込みの前後で落ちても元の並びへ戻せるよう、開始と完了を分けて記録する。
        // 開始時の控えには書き込み前の選択（＝直前の縮小結果）も残るため、
        // 2回目の縮小が中断しても最初の並びが失われない。
        clampBackupStore.beginClamp(
            originalCatalogIDs: selectedCatalogIDs,
            pendingCatalogIDs: clampedCatalogIDs
        )
        try targetStore.setTargets(clampedCatalogIDs)
        for removedCatalogID in Set(selectedCatalogIDs).subtracting(clampedCatalogIDs) {
            catalogAllowanceStore.revoke(catalogID: removedCatalogID)
        }
        clampBackupStore.commitClamp(appliedCatalogIDs: clampedCatalogIDs)
        settingsStore.targetAppClampKeptCatalogID = clampedCatalogIDs.first
    }

    /// 縮小の注記を消す。Pro確定の経路からのみ呼ぶ。
    /// 書き込みを増やさないよう、残っているときだけ触る。
    private func clearClampNoticeIfNeeded() {
        guard settingsStore.targetAppClampKeptCatalogID != nil else {
            return
        }
        settingsStore.targetAppClampKeptCatalogID = nil
    }

    private func retentionNotificationSchedules() -> RetentionNotificationSchedules {
        // 未確定のまま組み立てると、課金者を無料と誤認した予約（無料向け月次レポート等）を作る。
        guard storeService.hasConfirmedEntitlement else {
            return .empty
        }

        let currentDate = now()
        let calendar = Calendar.current

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

        let freeMonthlySummary: AttemptSummary
        if storeService.hasConfirmedEntitlement,
           !storeService.isPro,
           settingsStore.retentionSupportNotificationsEnabled,
           let firstLaunchDate = settingsStore.firstLaunchDate {
            let trailingMonthStart = calendar.date(
                byAdding: .month,
                value: -1,
                to: currentDate
            ) ?? firstLaunchDate
            // Local notification bodies are fixed when scheduled, so without another app launch
            // this trailing-month summary can represent an older window; that limitation is accepted.
            freeMonthlySummary = attemptSummary(
                from: max(firstLaunchDate, trailingMonthStart),
                to: currentDate
            )
        } else {
            freeMonthlySummary = AttemptSummary(attempts: 0, cancelled: 0)
        }
        let freeMonthlyReports = FreeMonthlyReportNotificationPolicy.schedules(
            firstLaunchDate: settingsStore.firstLaunchDate,
            hasResolvedEntitlement: storeService.hasConfirmedEntitlement,
            isPro: storeService.isPro,
            isEnabled: settingsStore.retentionSupportNotificationsEnabled,
            cancelledCount: freeMonthlySummary.cancelled,
            attemptCount: freeMonthlySummary.attempts,
            now: currentDate,
            calendar: calendar
        )

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
            month1: month1,
            month12: month12,
            freeMonthlyReports: freeMonthlyReports,
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

    nonisolated private static func makeClampBackupStore() -> TargetClampBackupStore {
        (try? TargetClampBackupStore()) ?? TargetClampBackupStore(userDefaults: .standard)
    }
}
