import Foundation

public final class SettingsStore: @unchecked Sendable {
    private enum Key {
        static let onboardingCompleted = "onboardingCompleted"
        static let lastAppVersion = "lastAppVersion"
        static let pendingInterventionMode = "pendingInterventionMode"
        static let selectedAppBrands = "selectedAppBrands"
        static let breathDurationSeconds = "breathDurationSeconds"
        static let pendingStartInterventionCatalogID = "pendingStartInterventionCatalogID"
        static let pendingStartInterventionAutoResolve = "pendingStartInterventionAutoResolve"
        static let verifiedAutomationCatalogIDs = "verifiedAutomationCatalogIDs"
        static let targetAppClampKeptCatalogID = "targetAppClampKeptCatalogID"
        static let onboardingSavedGoalID = "onboardingSavedGoalID"
        static let onboardingCompletedAt = "onboardingCompletedAt"
        static let firstLaunchDate = "firstLaunchDate"
        static let lastAppOpenedDateKey = "lastAppOpenedDateKey"
        static let lastWeeklyPaywallShownAt = "lastWeeklyPaywallShownAt"
        static let lastAnyPaywallShownAt = "lastAnyPaywallShownAt"
        static let wakeTimeMinutes = "wakeTimeMinutes"
        static let bedTimeMinutes = "bedTimeMinutes"
        static let morningNotificationEnabled = "morningNotificationEnabled"
        static let morningNotificationMinutes = "morningNotificationMinutes"
        static let weeklyReportNotificationEnabled = "weeklyReportNotificationEnabled"
        static let retentionSupportNotificationsEnabled = "retentionSupportNotificationsEnabled"
        static let planNotificationsEnabled = "planNotificationsEnabled"
        static let reviewPromptEventDates = "reviewPromptEventDates"
        static let annualUpgradeOfferNotificationFireDate = "annualUpgradeOfferNotificationFireDate"
        static let cancelSaveNotificationExpirationDate = "cancelSaveNotificationExpirationDate"
        static let cancelSaveNotificationFireDate = "cancelSaveNotificationFireDate"
        static let entitlementCachedIsPro = "entitlementCachedIsPro"
        static let entitlementCachedAt = "entitlementCachedAt"
        static let liveActivityEnabled = "liveActivityEnabled"
        static let lockScreenCheckCompleted = "lockScreenCheckCompleted"
        static let lockThemeRawValue = "lockThemeRawValue"
        static let pendingNotificationDestination = "pendingNotificationDestination"
        static let deepFocusSession = "deepFocusSession"
        static let deepFocusScheduleEnabled = "deepFocusScheduleEnabled"
        static let deepFocusScheduleWeekdays = "deepFocusScheduleWeekdays"
        static let deepFocusScheduleStartMinutes = "deepFocusScheduleStartMinutes"
        static let deepFocusScheduleEndMinutes = "deepFocusScheduleEndMinutes"
        static let trialReminderLeadDays = "trialReminderLeadDays"

        // firstLaunchDate, reviewPromptEventDates, the entitlement cache, and the one-shot
        // notification markers (annualUpgradeOfferNotificationFireDate /
        // cancelSaveNotification*) are intentionally excluded. They are entitlement/anti-abuse
        // anchors rather than user-created content: clearing them would let a data reset revoke
        // cached access or re-send a "once ever" notification.
        static let resettable = [
            onboardingCompleted,
            lastAppVersion,
            pendingInterventionMode,
            selectedAppBrands,
            breathDurationSeconds,
            pendingStartInterventionCatalogID,
            pendingStartInterventionAutoResolve,
            verifiedAutomationCatalogIDs,
            targetAppClampKeptCatalogID,
            onboardingSavedGoalID,
            onboardingCompletedAt,
            lastAppOpenedDateKey,
            lastWeeklyPaywallShownAt,
            lastAnyPaywallShownAt,
            wakeTimeMinutes,
            bedTimeMinutes,
            morningNotificationEnabled,
            morningNotificationMinutes,
            weeklyReportNotificationEnabled,
            retentionSupportNotificationsEnabled,
            planNotificationsEnabled,
            liveActivityEnabled,
            lockScreenCheckCompleted,
            lockThemeRawValue,
            pendingNotificationDestination,
            deepFocusSession,
            deepFocusScheduleEnabled,
            deepFocusScheduleWeekdays,
            deepFocusScheduleStartMinutes,
            deepFocusScheduleEndMinutes,
            trialReminderLeadDays
        ]

        /// `Key` から取り除かれた旧キー。既存インストールには値が残り続けるため、
        /// 「全データを削除」で消えるように掃除対象として保持する。
        /// - `day14ClampKeptCatalogID`: `targetAppClampKeptCatalogID` へ改名（2026-08-11）
        /// - `pendingDay14Warning`: 14日時限開放の撤回で廃止（2026-08-11）
        /// - `reverseTrial*`: リバーストライアル全廃で廃止（2026-08-11・docs/11 §18）
        static let legacyResettable = [
            "day14ClampKeptCatalogID",
            "pendingDay14Warning",
            "pendingMidSessionCheckIn",
            "usageWatchEnabled",
            "usageWatchQuestionIntervalMinutes",
            "usageWatchNightModeEnabled",
            "usageWatch.configuration",
            "usageWatch.state",
            "usageWatch.familyActivitySelection",
            "reverseTrialStartedAt",
            "reverseTrialEndPaywallShown"
        ]
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public convenience init() throws {
        guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
            throw CoreError.appGroupUnavailable(AppGroup.identifier)
        }
        self.init(userDefaults: userDefaults)
    }

    public var onboardingCompleted: Bool {
        get { userDefaults.bool(forKey: Key.onboardingCompleted) }
        set { userDefaults.set(newValue, forKey: Key.onboardingCompleted) }
    }

    public var lastAppVersion: String? {
        get { userDefaults.string(forKey: Key.lastAppVersion) }
        set { userDefaults.set(newValue, forKey: Key.lastAppVersion) }
    }

    public var pendingInterventionMode: String? {
        get { userDefaults.string(forKey: Key.pendingInterventionMode) }
        set { setOptional(newValue, forKey: Key.pendingInterventionMode) }
    }

    public var selectedAppBrands: [String]? {
        get { userDefaults.stringArray(forKey: Key.selectedAppBrands) }
        set { setOptional(newValue, forKey: Key.selectedAppBrands) }
    }

    public var breathDurationSeconds: Int {
        get {
            let stored = userDefaults.integer(forKey: Key.breathDurationSeconds)
            return [3, 5, 8].contains(stored) ? stored : 3
        }
        set {
            userDefaults.set([3, 5, 8].contains(newValue) ? newValue : 3, forKey: Key.breathDurationSeconds)
        }
    }

    public var pendingStartInterventionCatalogID: String? {
        get { userDefaults.string(forKey: Key.pendingStartInterventionCatalogID) }
        set { setOptional(newValue, forKey: Key.pendingStartInterventionCatalogID) }
    }

    public var pendingStartInterventionAutoResolve: Bool {
        get { userDefaults.bool(forKey: Key.pendingStartInterventionAutoResolve) }
        set { userDefaults.set(newValue, forKey: Key.pendingStartInterventionAutoResolve) }
    }

    public var verifiedAutomationCatalogIDs: [String] {
        get { userDefaults.stringArray(forKey: Key.verifiedAutomationCatalogIDs) ?? [] }
        set { userDefaults.set(newValue, forKey: Key.verifiedAutomationCatalogIDs) }
    }

    public func markAutomationVerified(catalogID: String) {
        guard !isAutomationVerified(catalogID: catalogID) else {
            return
        }
        verifiedAutomationCatalogIDs.append(catalogID)
    }

    public func isAutomationVerified(catalogID: String) -> Bool {
        verifiedAutomationCatalogIDs.contains(catalogID)
    }

    public var targetAppClampKeptCatalogID: String? {
        get { userDefaults.string(forKey: Key.targetAppClampKeptCatalogID) }
        set { setOptional(newValue, forKey: Key.targetAppClampKeptCatalogID) }
    }

    public var onboardingSavedGoalID: String? {
        get { userDefaults.string(forKey: Key.onboardingSavedGoalID) }
        set { setOptional(newValue, forKey: Key.onboardingSavedGoalID) }
    }

    public var onboardingCompletedAt: Date? {
        get { userDefaults.object(forKey: Key.onboardingCompletedAt) as? Date }
        set { setOptional(newValue, forKey: Key.onboardingCompletedAt) }
    }

    public var firstLaunchDate: Date? {
        get { userDefaults.object(forKey: Key.firstLaunchDate) as? Date }
        set { setOptional(newValue, forKey: Key.firstLaunchDate) }
    }

    public var lastAppOpenedDateKey: String? {
        get { userDefaults.string(forKey: Key.lastAppOpenedDateKey) }
        set { setOptional(newValue, forKey: Key.lastAppOpenedDateKey) }
    }

    public var lastWeeklyPaywallShownAt: Date? {
        get { userDefaults.object(forKey: Key.lastWeeklyPaywallShownAt) as? Date }
        set { setOptional(newValue, forKey: Key.lastWeeklyPaywallShownAt) }
    }

    public var lastAnyPaywallShownAt: Date? {
        get { userDefaults.object(forKey: Key.lastAnyPaywallShownAt) as? Date }
        set { setOptional(newValue, forKey: Key.lastAnyPaywallShownAt) }
    }

    public var wakeTimeMinutes: Int? {
        get { userDefaults.object(forKey: Key.wakeTimeMinutes) as? Int }
        set { setOptional(newValue.map(Self.normalizedMinutes), forKey: Key.wakeTimeMinutes) }
    }

    public var bedTimeMinutes: Int? {
        get { userDefaults.object(forKey: Key.bedTimeMinutes) as? Int }
        set { setOptional(newValue.map(Self.normalizedMinutes), forKey: Key.bedTimeMinutes) }
    }

    public var morningNotificationEnabled: Bool {
        get { bool(forKey: Key.morningNotificationEnabled, defaultValue: true) }
        set { userDefaults.set(newValue, forKey: Key.morningNotificationEnabled) }
    }

    public var morningNotificationMinutes: Int {
        get {
            let fallback = wakeTimeMinutes ?? 420
            guard let stored = userDefaults.object(forKey: Key.morningNotificationMinutes) as? Int else {
                return Self.normalizedMinutes(fallback)
            }
            return Self.normalizedMinutes(stored)
        }
        set { userDefaults.set(Self.normalizedMinutes(newValue), forKey: Key.morningNotificationMinutes) }
    }

    public var weeklyReportNotificationEnabled: Bool {
        get { bool(forKey: Key.weeklyReportNotificationEnabled, defaultValue: true) }
        set { userDefaults.set(newValue, forKey: Key.weeklyReportNotificationEnabled) }
    }

    public var retentionSupportNotificationsEnabled: Bool {
        get { bool(forKey: Key.retentionSupportNotificationsEnabled, defaultValue: true) }
        set { userDefaults.set(newValue, forKey: Key.retentionSupportNotificationsEnabled) }
    }

    public var planNotificationsEnabled: Bool {
        get { bool(forKey: Key.planNotificationsEnabled, defaultValue: true) }
        set { userDefaults.set(newValue, forKey: Key.planNotificationsEnabled) }
    }

    public var reviewPromptEventDates: [Date] {
        get {
            (userDefaults.array(forKey: Key.reviewPromptEventDates) ?? []).compactMap { value in
                (value as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            }
        }
        set {
            userDefaults.set(
                newValue.map(\.timeIntervalSince1970),
                forKey: Key.reviewPromptEventDates
            )
        }
    }

    /// 年額移行オファー通知を予約した発火時刻。非nilなら「一生に1回」の枠を使い切っている。
    public var annualUpgradeOfferNotificationFireDate: Date? {
        get { userDefaults.object(forKey: Key.annualUpgradeOfferNotificationFireDate) as? Date }
        set { setOptional(newValue, forKey: Key.annualUpgradeOfferNotificationFireDate) }
    }

    /// 解約セーブ通知を送った請求期間の期限日。同じ期間に二重送信しないためのキー。
    public var cancelSaveNotificationExpirationDate: Date? {
        get { userDefaults.object(forKey: Key.cancelSaveNotificationExpirationDate) as? Date }
        set { setOptional(newValue, forKey: Key.cancelSaveNotificationExpirationDate) }
    }

    /// 解約セーブ通知の発火時刻。まだ未来なら再スケジュール時に同じ時刻で積み直す。
    public var cancelSaveNotificationFireDate: Date? {
        get { userDefaults.object(forKey: Key.cancelSaveNotificationFireDate) as? Date }
        set { setOptional(newValue, forKey: Key.cancelSaveNotificationFireDate) }
    }

    public var entitlementCachedIsPro: Bool? {
        get {
            guard userDefaults.object(forKey: Key.entitlementCachedIsPro) != nil else {
                return nil
            }
            return userDefaults.bool(forKey: Key.entitlementCachedIsPro)
        }
        set { setOptional(newValue, forKey: Key.entitlementCachedIsPro) }
    }

    public var entitlementCachedAt: Date? {
        get { userDefaults.object(forKey: Key.entitlementCachedAt) as? Date }
        set { setOptional(newValue, forKey: Key.entitlementCachedAt) }
    }

    public var liveActivityEnabled: Bool {
        get { bool(forKey: Key.liveActivityEnabled, defaultValue: true) }
        set { userDefaults.set(newValue, forKey: Key.liveActivityEnabled) }
    }

    /// ロック画面での掲出確認（Live Activityを実際に見せる導線）を一度通したか。
    public var lockScreenCheckCompleted: Bool {
        get { userDefaults.bool(forKey: Key.lockScreenCheckCompleted) }
        set { userDefaults.set(newValue, forKey: Key.lockScreenCheckCompleted) }
    }

    public var lockThemeRawValue: String? {
        get { userDefaults.string(forKey: Key.lockThemeRawValue) }
        set { setOptional(newValue, forKey: Key.lockThemeRawValue) }
    }

    public var lockTheme: LockTheme {
        get {
            guard let rawValue = lockThemeRawValue else { return .e1 }
            return LockTheme(migratingRawValue: rawValue)
        }
        set { lockThemeRawValue = newValue == .e1 ? nil : newValue.rawValue }
    }

    /// 起動時に旧テーマ値を一度だけ正規化する。getterは読み出し専用に保つ。
    public func migrateStoredValues() {
        userDefaults.removeObject(forKey: "pendingMidSessionCheckIn")
        for key in [
            "usageWatchEnabled",
            "usageWatchQuestionIntervalMinutes",
            "usageWatchNightModeEnabled",
            "usageWatch.configuration",
            "usageWatch.state",
            "usageWatch.familyActivitySelection"
        ] {
            userDefaults.removeObject(forKey: key)
        }
        guard let rawValue = lockThemeRawValue else { return }
        let migrated = LockTheme(migratingRawValue: rawValue)
        let normalizedRawValue = migrated == .e1 ? nil : migrated.rawValue
        guard rawValue != normalizedRawValue else { return }
        lockThemeRawValue = normalizedRawValue
    }

    /// 無料トライアル終了の何日前に知らせるか。ペイウォールで選び、終了前通知の予約日に使う。
    /// 未保存でも `integer(forKey:)` が返す0を既定へ寄せるため、許容値以外は既定に丸める。
    public var trialReminderLeadDays: Int {
        get {
            TrialReminderLeadDays.normalized(
                userDefaults.integer(forKey: Key.trialReminderLeadDays)
            )
        }
        set {
            userDefaults.set(
                TrialReminderLeadDays.normalized(newValue),
                forKey: Key.trialReminderLeadDays
            )
        }
    }

    /// 書き込み時刻つきで持ち、消費されないまま残ったものを後から実行しないための
    /// 有効期限を呼び出し側が判定できるようにする。
    public var pendingNotificationDestination: PendingNotificationDestination? {
        get {
            guard let data = userDefaults.data(forKey: Key.pendingNotificationDestination) else {
                return nil
            }
            return try? JSONDecoder().decode(PendingNotificationDestination.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                userDefaults.removeObject(forKey: Key.pendingNotificationDestination)
                return
            }
            userDefaults.set(data, forKey: Key.pendingNotificationDestination)
        }
    }

    /// 「いますぐ」で始めた完全ブロックの回。進行中でなければ `nil`。
    ///
    /// 終わった回はここに残さない（`DeepFocusScheduler` の同期で潰す）。
    /// 残したままにすると、画面が「実行中」と出したまま実際は解除されている状態になる。
    public var deepFocusSession: DeepFocusSession? {
        get {
            guard let data = userDefaults.data(forKey: Key.deepFocusSession) else {
                return nil
            }
            return try? JSONDecoder().decode(DeepFocusSession.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                userDefaults.removeObject(forKey: Key.deepFocusSession)
                return
            }
            userDefaults.set(data, forKey: Key.deepFocusSession)
        }
    }

    /// 週に1本の完全ブロックの時間帯。曜日と時刻は個別のキーに置き、
    /// 片方の保存だけ失敗しても残りが読めるようにする。
    public var deepFocusSchedule: DeepFocusSchedule {
        get {
            let storedWeekdays = (userDefaults.array(forKey: Key.deepFocusScheduleWeekdays) ?? [])
                .compactMap { ($0 as? NSNumber)?.intValue }
            return DeepFocusSchedule(
                isEnabled: userDefaults.bool(forKey: Key.deepFocusScheduleEnabled),
                weekdays: storedWeekdays,
                startMinutes: intOrDefault(
                    forKey: Key.deepFocusScheduleStartMinutes,
                    defaultValue: DeepFocusConstants.defaultScheduleStartMinutes
                ),
                endMinutes: intOrDefault(
                    forKey: Key.deepFocusScheduleEndMinutes,
                    defaultValue: DeepFocusConstants.defaultScheduleEndMinutes
                )
            )
        }
        set {
            // 正規化は `DeepFocusSchedule` のイニシャライザが済ませている。ここでは書くだけ。
            userDefaults.set(newValue.isEnabled, forKey: Key.deepFocusScheduleEnabled)
            userDefaults.set(newValue.weekdays, forKey: Key.deepFocusScheduleWeekdays)
            userDefaults.set(newValue.startMinutes, forKey: Key.deepFocusScheduleStartMinutes)
            userDefaults.set(newValue.endMinutes, forKey: Key.deepFocusScheduleEndMinutes)
        }
    }

    public var lockSurfaceState: LockSurfaceState {
        let minutes = morningNotificationMinutes
        return LockSurfaceState(
            morningNotificationEnabled: morningNotificationEnabled,
            morningNotificationTime: DateComponents(hour: minutes / 60, minute: minutes % 60),
            weeklyReportEnabled: weeklyReportNotificationEnabled,
            retentionSupportNotificationsEnabled: retentionSupportNotificationsEnabled,
            planNotificationsEnabled: planNotificationsEnabled,
            liveActivityEnabled: liveActivityEnabled,
            liveActivityStartedAt: nil,
            theme: lockTheme
        )
    }

    public func resetToDefaults() {
        Key.resettable.forEach(userDefaults.removeObject(forKey:))
        Key.legacyResettable.forEach(userDefaults.removeObject(forKey:))
    }

    private func setOptional(_ value: Any?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return userDefaults.bool(forKey: key)
    }

    /// 未保存と「0を保存した」を区別する。`integer(forKey:)` は未保存でも0を返すため、
    /// 0時ちょうどを設定した人の値が既定へ戻されてしまう。
    private func intOrDefault(forKey key: String, defaultValue: Int) -> Int {
        guard let stored = userDefaults.object(forKey: key) as? Int else {
            return defaultValue
        }
        return stored
    }

    private static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }
}
