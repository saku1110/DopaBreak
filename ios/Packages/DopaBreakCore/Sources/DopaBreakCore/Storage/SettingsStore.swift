import Foundation

public final class SettingsStore: @unchecked Sendable {
    private enum Key {
        static let onboardingCompleted = "onboardingCompleted"
        static let lastAppVersion = "lastAppVersion"
        static let pendingInterventionMode = "pendingInterventionMode"
        static let selectedAppBrands = "selectedAppBrands"
        static let breathDurationSeconds = "breathDurationSeconds"
        static let pendingStartInterventionCatalogID = "pendingStartInterventionCatalogID"
        static let pendingMidSessionCheckIn = "pendingMidSessionCheckIn"
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
        static let liveActivityEnabled = "liveActivityEnabled"
        static let lockScreenCheckCompleted = "lockScreenCheckCompleted"
        static let lockThemeRawValue = "lockThemeRawValue"
        static let usageWatchEnabled = "usageWatchEnabled"
        static let usageWatchQuestionIntervalMinutes = "usageWatchQuestionIntervalMinutes"
        static let usageWatchNightModeEnabled = "usageWatchNightModeEnabled"
        static let pendingNotificationDestination = "pendingNotificationDestination"

        // firstLaunchDate, reviewPromptEventDates and the one-shot notification markers
        // (annualUpgradeOfferNotificationFireDate / cancelSaveNotification*) are intentionally
        // excluded. They are entitlement/anti-abuse anchors rather than user-created content:
        // clearing them would let a data reset re-send a "once ever" notification.
        static let resettable = [
            onboardingCompleted,
            lastAppVersion,
            pendingInterventionMode,
            selectedAppBrands,
            breathDurationSeconds,
            pendingStartInterventionCatalogID,
            pendingMidSessionCheckIn,
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
            usageWatchEnabled,
            usageWatchQuestionIntervalMinutes,
            usageWatchNightModeEnabled,
            pendingNotificationDestination
        ]

        /// `Key` から取り除かれた旧キー。既存インストールには値が残り続けるため、
        /// 「全データを削除」で消えるように掃除対象として保持する。
        /// - `day14ClampKeptCatalogID`: `targetAppClampKeptCatalogID` へ改名（2026-08-11）
        /// - `pendingDay14Warning`: 14日時限開放の撤回で廃止（2026-08-11）
        /// - `reverseTrial*`: リバーストライアル全廃で廃止（2026-08-11・docs/11 §18）
        static let legacyResettable = [
            "day14ClampKeptCatalogID",
            "pendingDay14Warning",
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

    public var pendingMidSessionCheckIn: PendingMidSessionCheckIn? {
        get {
            guard let data = userDefaults.data(forKey: Key.pendingMidSessionCheckIn) else {
                return nil
            }
            return try? JSONDecoder().decode(PendingMidSessionCheckIn.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                userDefaults.removeObject(forKey: Key.pendingMidSessionCheckIn)
                return
            }
            userDefaults.set(data, forKey: Key.pendingMidSessionCheckIn)
        }
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
        get { lockThemeRawValue.flatMap(LockTheme.init(rawValue:)) ?? .e1 }
        set { lockThemeRawValue = newValue == .e1 ? nil : newValue.rawValue }
    }

    public var usageWatchEnabled: Bool {
        get { userDefaults.bool(forKey: Key.usageWatchEnabled) }
        set { userDefaults.set(newValue, forKey: Key.usageWatchEnabled) }
    }

    public var usageWatchQuestionIntervalMinutes: Int {
        get {
            let stored = userDefaults.integer(forKey: Key.usageWatchQuestionIntervalMinutes)
            return UsageWatchConfiguration.allowedQuestionIntervals.contains(stored) ? stored : 15
        }
        set {
            let normalized = UsageWatchConfiguration.allowedQuestionIntervals.contains(newValue)
                ? newValue
                : 15
            userDefaults.set(normalized, forKey: Key.usageWatchQuestionIntervalMinutes)
        }
    }

    public var usageWatchNightModeEnabled: Bool {
        get { userDefaults.bool(forKey: Key.usageWatchNightModeEnabled) }
        set { userDefaults.set(newValue, forKey: Key.usageWatchNightModeEnabled) }
    }

    /// 書き込み時刻つきで持つ。`PendingMidSessionCheckIn` と同じく、消費されないまま
    /// 残ったものを後から実行しないための有効期限を呼び出し側が判定できるようにする。
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

    private static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }
}
