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
        static let pendingDay14Warning = "pendingDay14Warning"
        static let verifiedAutomationCatalogIDs = "verifiedAutomationCatalogIDs"
        static let day14ClampKeptCatalogID = "day14ClampKeptCatalogID"
        static let onboardingSavedGoalID = "onboardingSavedGoalID"
        static let onboardingCompletedAt = "onboardingCompletedAt"
        static let firstLaunchDate = "firstLaunchDate"
        static let lastAppOpenedDateKey = "lastAppOpenedDateKey"
        static let lastWeeklyPaywallShownAt = "lastWeeklyPaywallShownAt"
        static let lastAnyPaywallShownAt = "lastAnyPaywallShownAt"
        static let reverseTrialStartedAt = "reverseTrialStartedAt"
        static let reverseTrialEndPaywallShown = "reverseTrialEndPaywallShown"
        static let wakeTimeMinutes = "wakeTimeMinutes"
        static let bedTimeMinutes = "bedTimeMinutes"
        static let morningNotificationEnabled = "morningNotificationEnabled"
        static let morningNotificationMinutes = "morningNotificationMinutes"
        static let weeklyReportNotificationEnabled = "weeklyReportNotificationEnabled"
        static let liveActivityEnabled = "liveActivityEnabled"
        static let lockThemeRawValue = "lockThemeRawValue"

        // firstLaunchDate is intentionally excluded. It is an entitlement/anti-abuse
        // anchor rather than user-created content and must survive content erasure.
        static let resettable = [
            onboardingCompleted,
            lastAppVersion,
            pendingInterventionMode,
            selectedAppBrands,
            breathDurationSeconds,
            pendingStartInterventionCatalogID,
            pendingMidSessionCheckIn,
            pendingDay14Warning,
            verifiedAutomationCatalogIDs,
            day14ClampKeptCatalogID,
            onboardingSavedGoalID,
            onboardingCompletedAt,
            lastAppOpenedDateKey,
            lastWeeklyPaywallShownAt,
            lastAnyPaywallShownAt,
            reverseTrialStartedAt,
            reverseTrialEndPaywallShown,
            wakeTimeMinutes,
            bedTimeMinutes,
            morningNotificationEnabled,
            morningNotificationMinutes,
            weeklyReportNotificationEnabled,
            liveActivityEnabled,
            lockThemeRawValue
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

    public var pendingDay14Warning: PendingDay14Warning? {
        get {
            guard let data = userDefaults.data(forKey: Key.pendingDay14Warning) else {
                return nil
            }
            return try? JSONDecoder().decode(PendingDay14Warning.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                userDefaults.removeObject(forKey: Key.pendingDay14Warning)
                return
            }
            userDefaults.set(data, forKey: Key.pendingDay14Warning)
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

    public var day14ClampKeptCatalogID: String? {
        get { userDefaults.string(forKey: Key.day14ClampKeptCatalogID) }
        set { setOptional(newValue, forKey: Key.day14ClampKeptCatalogID) }
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

    public var reverseTrialStartedAt: Date? {
        get { userDefaults.object(forKey: Key.reverseTrialStartedAt) as? Date }
        set { setOptional(newValue, forKey: Key.reverseTrialStartedAt) }
    }

    public var reverseTrialEndPaywallShown: Bool {
        get { userDefaults.bool(forKey: Key.reverseTrialEndPaywallShown) }
        set { userDefaults.set(newValue, forKey: Key.reverseTrialEndPaywallShown) }
    }

    @discardableResult
    public func startReverseTrialIfNeeded(at date: Date) -> Bool {
        guard reverseTrialStartedAt == nil else {
            return false
        }
        reverseTrialStartedAt = date
        return true
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

    public var liveActivityEnabled: Bool {
        get { bool(forKey: Key.liveActivityEnabled, defaultValue: true) }
        set { userDefaults.set(newValue, forKey: Key.liveActivityEnabled) }
    }

    public var lockThemeRawValue: String? {
        get { userDefaults.string(forKey: Key.lockThemeRawValue) }
        set { setOptional(newValue, forKey: Key.lockThemeRawValue) }
    }

    public var lockTheme: LockTheme {
        get { lockThemeRawValue.flatMap(LockTheme.init(rawValue:)) ?? .e1 }
        set { lockThemeRawValue = newValue == .e1 ? nil : newValue.rawValue }
    }

    public var lockSurfaceState: LockSurfaceState {
        let minutes = morningNotificationMinutes
        return LockSurfaceState(
            morningNotificationEnabled: morningNotificationEnabled,
            morningNotificationTime: DateComponents(hour: minutes / 60, minute: minutes % 60),
            weeklyReportEnabled: weeklyReportNotificationEnabled,
            liveActivityEnabled: liveActivityEnabled,
            liveActivityStartedAt: nil,
            theme: lockTheme
        )
    }

    public func resetToDefaults() {
        Key.resettable.forEach(userDefaults.removeObject(forKey:))
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
