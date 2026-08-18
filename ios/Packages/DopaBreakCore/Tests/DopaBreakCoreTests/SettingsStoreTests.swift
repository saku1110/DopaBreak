import XCTest
@testable import DopaBreakCore

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLockSurfaceDefaultsUseWakeTimeAndE1() {
        store.wakeTimeMinutes = 480

        XCTAssertTrue(store.morningNotificationEnabled)
        XCTAssertEqual(store.morningNotificationMinutes, 480)
        XCTAssertTrue(store.weeklyReportNotificationEnabled)
        XCTAssertTrue(store.retentionSupportNotificationsEnabled)
        XCTAssertTrue(store.planNotificationsEnabled)
        XCTAssertTrue(store.liveActivityEnabled)
        XCTAssertEqual(store.reviewPromptEventDates, [])
        XCTAssertFalse(store.lockScreenCheckCompleted)
        XCTAssertNil(store.lockThemeRawValue)
        XCTAssertEqual(store.lockTheme, .e1)
        XCTAssertFalse(store.usageWatchEnabled)
        XCTAssertEqual(store.usageWatchQuestionIntervalMinutes, 15)
        XCTAssertFalse(store.usageWatchNightModeEnabled)
        XCTAssertNil(store.pendingNotificationDestination)
    }

    func testLockScreenCheckCompletionPersists() {
        store.lockScreenCheckCompleted = true

        XCTAssertTrue(SettingsStore(userDefaults: defaults).lockScreenCheckCompleted)
    }

    func testLockSurfaceValuesPersistAndNormalizeMinutes() {
        store.morningNotificationEnabled = false
        store.morningNotificationMinutes = 1_500
        store.weeklyReportNotificationEnabled = false
        store.retentionSupportNotificationsEnabled = false
        store.planNotificationsEnabled = false
        store.liveActivityEnabled = false
        store.lockTheme = .yozora

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertFalse(reloaded.morningNotificationEnabled)
        XCTAssertEqual(reloaded.morningNotificationMinutes, 60)
        XCTAssertFalse(reloaded.weeklyReportNotificationEnabled)
        XCTAssertFalse(reloaded.retentionSupportNotificationsEnabled)
        XCTAssertFalse(reloaded.planNotificationsEnabled)
        XCTAssertFalse(reloaded.liveActivityEnabled)
        XCTAssertEqual(reloaded.lockThemeRawValue, LockTheme.yozora.rawValue)
        XCTAssertEqual(reloaded.lockTheme, .yozora)
    }

    func testSelectingE1RemovesStoredThemeOverride() {
        store.lockTheme = .kpop
        store.lockTheme = .e1

        XCTAssertNil(store.lockThemeRawValue)
        XCTAssertEqual(store.lockTheme, .e1)
    }

    func testLockSurfaceStateReflectsSettings() {
        store.morningNotificationMinutes = 7 * 60 + 35
        store.weeklyReportNotificationEnabled = false
        store.retentionSupportNotificationsEnabled = false
        store.planNotificationsEnabled = false
        store.lockTheme = .shinrin

        let state = store.lockSurfaceState
        XCTAssertEqual(state.morningNotificationTime.hour, 7)
        XCTAssertEqual(state.morningNotificationTime.minute, 35)
        XCTAssertFalse(state.weeklyReportEnabled)
        XCTAssertFalse(state.retentionSupportNotificationsEnabled)
        XCTAssertFalse(state.planNotificationsEnabled)
        XCTAssertEqual(state.theme, .shinrin)
    }

    func testReviewPromptEventDatesPersistAsTimestampArray() {
        let dates = [
            Date(timeIntervalSince1970: 1_700_000_000.25),
            Date(timeIntervalSince1970: 1_710_000_000.5)
        ]

        store.reviewPromptEventDates = dates

        XCTAssertEqual(SettingsStore(userDefaults: defaults).reviewPromptEventDates, dates)
        XCTAssertEqual(
            defaults.array(forKey: "reviewPromptEventDates") as? [Double],
            dates.map(\.timeIntervalSince1970)
        )
    }

    func testResetPreservesReviewEventsAndRestoresNewNotificationDefaults() {
        let eventDate = Date(timeIntervalSince1970: 1_800_000_000)
        store.reviewPromptEventDates = [eventDate]
        store.retentionSupportNotificationsEnabled = false
        store.planNotificationsEnabled = false
        store.usageWatchEnabled = true
        store.usageWatchQuestionIntervalMinutes = 60
        store.usageWatchNightModeEnabled = true
        store.pendingNotificationDestination = PendingNotificationDestination(
            destination: .stats,
            writtenAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        store.resetToDefaults()

        XCTAssertEqual(store.reviewPromptEventDates, [eventDate])
        XCTAssertTrue(store.retentionSupportNotificationsEnabled)
        XCTAssertTrue(store.planNotificationsEnabled)
        XCTAssertFalse(store.usageWatchEnabled)
        XCTAssertEqual(store.usageWatchQuestionIntervalMinutes, 15)
        XCTAssertFalse(store.usageWatchNightModeEnabled)
        XCTAssertNil(store.pendingNotificationDestination)
        XCTAssertNotNil(defaults.object(forKey: "reviewPromptEventDates"))
    }

    func testOneShotNotificationMarkersPersistAndSurviveReset() {
        let fireDate = Date(timeIntervalSince1970: 1_800_000_000)
        let expirationDate = Date(timeIntervalSince1970: 1_800_600_000)
        store.annualUpgradeOfferNotificationFireDate = fireDate
        store.cancelSaveNotificationExpirationDate = expirationDate
        store.cancelSaveNotificationFireDate = fireDate

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.annualUpgradeOfferNotificationFireDate, fireDate)
        XCTAssertEqual(reloaded.cancelSaveNotificationExpirationDate, expirationDate)
        XCTAssertEqual(reloaded.cancelSaveNotificationFireDate, fireDate)

        // データ削除で「一生に1回」の通知が復活しないよう、マーカーはリセット対象外。
        store.resetToDefaults()

        XCTAssertEqual(store.annualUpgradeOfferNotificationFireDate, fireDate)
        XCTAssertEqual(store.cancelSaveNotificationExpirationDate, expirationDate)
        XCTAssertEqual(store.cancelSaveNotificationFireDate, fireDate)

        store.annualUpgradeOfferNotificationFireDate = nil
        store.cancelSaveNotificationExpirationDate = nil
        store.cancelSaveNotificationFireDate = nil

        XCTAssertNil(defaults.object(forKey: "annualUpgradeOfferNotificationFireDate"))
        XCTAssertNil(defaults.object(forKey: "cancelSaveNotificationExpirationDate"))
        XCTAssertNil(defaults.object(forKey: "cancelSaveNotificationFireDate"))
    }

    func testUsageWatchSettingsPersistAndRejectUnsupportedInterval() {
        store.usageWatchEnabled = true
        store.usageWatchQuestionIntervalMinutes = 60
        store.usageWatchNightModeEnabled = true
        store.pendingNotificationDestination = PendingNotificationDestination(
            destination: .stats,
            writtenAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertTrue(reloaded.usageWatchEnabled)
        XCTAssertEqual(reloaded.usageWatchQuestionIntervalMinutes, 60)
        XCTAssertTrue(reloaded.usageWatchNightModeEnabled)
        XCTAssertEqual(
            reloaded.pendingNotificationDestination,
            PendingNotificationDestination(
                destination: .stats,
                writtenAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )

        reloaded.usageWatchQuestionIntervalMinutes = 10
        XCTAssertEqual(store.usageWatchQuestionIntervalMinutes, 15)
    }

    func testPendingMidSessionCheckInRoundTripsAndClears() {
        XCTAssertNil(store.pendingMidSessionCheckIn)

        let pending = PendingMidSessionCheckIn(
            catalogID: "instagram",
            writtenAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        store.pendingMidSessionCheckIn = pending

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.pendingMidSessionCheckIn, pending)

        reloaded.pendingMidSessionCheckIn = nil

        XCTAssertNil(store.pendingMidSessionCheckIn)
        XCTAssertNil(defaults.object(forKey: "pendingMidSessionCheckIn"))
    }

    func testTargetAppClampKeptCatalogIDRoundTripsAndClears() {
        store.targetAppClampKeptCatalogID = "instagram"

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.targetAppClampKeptCatalogID, "instagram")

        reloaded.targetAppClampKeptCatalogID = nil

        XCTAssertNil(store.targetAppClampKeptCatalogID)
        XCTAssertNil(defaults.object(forKey: "targetAppClampKeptCatalogID"))
    }

    func testLastAppOpenedDateKeyRoundTripsAndClears() {
        XCTAssertNil(store.lastAppOpenedDateKey)

        store.lastAppOpenedDateKey = "2026-07-17"

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.lastAppOpenedDateKey, "2026-07-17")

        reloaded.lastAppOpenedDateKey = nil

        XCTAssertNil(store.lastAppOpenedDateKey)
        XCTAssertNil(defaults.object(forKey: "lastAppOpenedDateKey"))
    }

    func testOnboardingSavedGoalIDRoundTripsAndClears() {
        let goalID = UUID().uuidString
        XCTAssertNil(store.onboardingSavedGoalID)

        store.onboardingSavedGoalID = goalID

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.onboardingSavedGoalID, goalID)

        reloaded.onboardingSavedGoalID = nil

        XCTAssertNil(store.onboardingSavedGoalID)
        XCTAssertNil(defaults.object(forKey: "onboardingSavedGoalID"))
    }

    func testResetToDefaultsClearsOnboardingSavedGoalID() {
        store.onboardingSavedGoalID = UUID().uuidString

        store.resetToDefaults()

        XCTAssertNil(store.onboardingSavedGoalID)
    }

    func testWeeklyPaywallDatesRoundTripAndClear() {
        let onboardingDate = Date(timeIntervalSince1970: 1_800_000_000)
        let shownDate = onboardingDate.addingTimeInterval(7 * 24 * 60 * 60)
        let anyShownDate = shownDate.addingTimeInterval(60)

        store.onboardingCompletedAt = onboardingDate
        store.lastWeeklyPaywallShownAt = shownDate
        store.lastAnyPaywallShownAt = anyShownDate

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.onboardingCompletedAt, onboardingDate)
        XCTAssertEqual(reloaded.lastWeeklyPaywallShownAt, shownDate)
        XCTAssertEqual(reloaded.lastAnyPaywallShownAt, anyShownDate)

        reloaded.onboardingCompletedAt = nil
        reloaded.lastWeeklyPaywallShownAt = nil
        reloaded.lastAnyPaywallShownAt = nil

        XCTAssertNil(store.onboardingCompletedAt)
        XCTAssertNil(store.lastWeeklyPaywallShownAt)
        XCTAssertNil(store.lastAnyPaywallShownAt)
        XCTAssertNil(defaults.object(forKey: "onboardingCompletedAt"))
        XCTAssertNil(defaults.object(forKey: "lastWeeklyPaywallShownAt"))
        XCTAssertNil(defaults.object(forKey: "lastAnyPaywallShownAt"))
    }

    func testResetToDefaultsClearsWeeklyPaywallDates() {
        store.onboardingCompletedAt = Date()
        store.lastWeeklyPaywallShownAt = Date()
        store.lastAnyPaywallShownAt = Date()

        store.resetToDefaults()

        XCTAssertNil(store.onboardingCompletedAt)
        XCTAssertNil(store.lastWeeklyPaywallShownAt)
        XCTAssertNil(store.lastAnyPaywallShownAt)
    }

    func testPendingNotificationDestinationRoundTripsWithItsWriteTime() {
        let writtenAt = Date(timeIntervalSince1970: 1_800_000_000)
        store.pendingNotificationDestination = PendingNotificationDestination(
            destination: .automationGuide,
            writtenAt: writtenAt
        )

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(
            reloaded.pendingNotificationDestination,
            PendingNotificationDestination(destination: .automationGuide, writtenAt: writtenAt)
        )

        reloaded.pendingNotificationDestination = nil

        XCTAssertNil(store.pendingNotificationDestination)
        XCTAssertNil(defaults.object(forKey: "pendingNotificationDestination"))
    }

    /// オンボーディング途中でD1通知をタップすると本体が消費できないまま残るため、
    /// 有効期限を持たせて後日オンボーディングを終えた瞬間に飛ばされないようにする。
    func testPendingNotificationDestinationExpiresLikeTheMidSessionCheckIn() {
        let writtenAt = Date(timeIntervalSince1970: 1_800_000_000)
        let pending = PendingNotificationDestination(
            destination: .automationGuide,
            writtenAt: writtenAt
        )

        XCTAssertTrue(pending.isValid(at: writtenAt))
        XCTAssertTrue(
            pending.isValid(at: writtenAt.addingTimeInterval(PendingNotificationDestination.validityInterval))
        )
        XCTAssertFalse(
            pending.isValid(
                at: writtenAt.addingTimeInterval(PendingNotificationDestination.validityInterval + 1)
            )
        )
        // 端末時計が巻き戻ったときも実行しない。
        XCTAssertFalse(pending.isValid(at: writtenAt.addingTimeInterval(-1)))
    }

    func testResetToDefaultsClearsPendingNotificationDestination() {
        store.pendingNotificationDestination = PendingNotificationDestination(
            destination: .planSettings,
            writtenAt: Date()
        )

        store.resetToDefaults()

        XCTAssertNil(store.pendingNotificationDestination)
    }

    /// `Key` から取り除いた旧キーは既存インストールに残り続けるため、削除対象に含める。
    func testResetToDefaultsClearsKeysRemovedFromTheCurrentSchema() {
        let legacyKeys = [
            "day14ClampKeptCatalogID",
            "pendingDay14Warning",
            "reverseTrialStartedAt",
            "reverseTrialEndPaywallShown"
        ]
        for key in legacyKeys {
            defaults.set("stale", forKey: key)
        }

        store.resetToDefaults()

        for key in legacyKeys {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
    }

    // MARK: - 完全ブロックの窓

    func testDeepFocusSessionRoundTripsAndClears() {
        let startedAt = Date(timeIntervalSince1970: 1_755_100_000)
        let endsAt = Date(timeIntervalSince1970: 1_755_103_600)
        store.deepFocusSession = DeepFocusSession(startedAt: startedAt, endsAt: endsAt)

        XCTAssertEqual(store.deepFocusSession?.startedAt.timeIntervalSince1970, 1_755_100_000)
        XCTAssertEqual(store.deepFocusSession?.endsAt?.timeIntervalSince1970, 1_755_103_600)

        store.deepFocusSession = nil
        XCTAssertNil(store.deepFocusSession)
    }

    /// 「自分で戻すまで」は終わる時刻を持たない。`nil` が「回そのものが無い」と混ざらないこと。
    func testOpenEndedDeepFocusSessionKeepsItsNilEndDate() {
        store.deepFocusSession = DeepFocusSession(
            startedAt: Date(timeIntervalSince1970: 1_755_100_000),
            endsAt: nil
        )

        XCTAssertNotNil(store.deepFocusSession)
        XCTAssertNil(store.deepFocusSession?.endsAt)
    }

    func testDeepFocusScheduleDefaultsToDisabledWithoutWeekdays() {
        let schedule = store.deepFocusSchedule

        XCTAssertFalse(schedule.isEnabled)
        XCTAssertEqual(schedule.weekdays, [])
        XCTAssertEqual(schedule.startMinutes, DeepFocusConstants.defaultScheduleStartMinutes)
        XCTAssertEqual(schedule.endMinutes, DeepFocusConstants.defaultScheduleEndMinutes)
        XCTAssertFalse(DeepFocusWindowPolicy.isScheduleUsable(schedule))
    }

    func testDeepFocusSchedulePersistsAndNormalizes() {
        store.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [6, 2, 2, 9],
            startMinutes: 1_500,
            endMinutes: -60
        )

        let restored = store.deepFocusSchedule
        XCTAssertTrue(restored.isEnabled)
        XCTAssertEqual(restored.weekdays, [2, 6])
        XCTAssertEqual(restored.startMinutes, 60)
        XCTAssertEqual(restored.endMinutes, 1_380)
    }

    /// 0時ちょうどを保存した人の値が、未保存と同じ扱いで既定へ戻されないこと。
    func testDeepFocusScheduleKeepsMidnightAsAStoredValue() {
        store.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [1],
            startMinutes: 0,
            endMinutes: 60
        )

        XCTAssertEqual(store.deepFocusSchedule.startMinutes, 0)
        XCTAssertEqual(store.deepFocusSchedule.endMinutes, 60)
    }

    func testResetToDefaultsClearsDeepFocusWindowSettings() {
        store.deepFocusSession = DeepFocusSession(
            startedAt: Date(timeIntervalSince1970: 0),
            endsAt: nil
        )
        store.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [2],
            startMinutes: 60,
            endMinutes: 300
        )

        store.resetToDefaults()

        XCTAssertNil(store.deepFocusSession)
        XCTAssertFalse(store.deepFocusSchedule.isEnabled)
        XCTAssertEqual(store.deepFocusSchedule.weekdays, [])
        XCTAssertEqual(
            store.deepFocusSchedule.startMinutes,
            DeepFocusConstants.defaultScheduleStartMinutes
        )
    }

    func testTrialReminderLeadDaysDefaultsToTwoDaysBefore() {
        XCTAssertEqual(store.trialReminderLeadDays, TrialReminderLeadDays.standard)
        XCTAssertEqual(store.trialReminderLeadDays, 2)
    }

    func testTrialReminderLeadDaysPersistsAcrossStores() {
        store.trialReminderLeadDays = 3

        XCTAssertEqual(SettingsStore(userDefaults: defaults).trialReminderLeadDays, 3)
    }

    func testTrialReminderLeadDaysFallsBackToDefaultForUnsupportedValues() {
        for unsupported in [0, 1, 4, 7, -2] {
            store.trialReminderLeadDays = unsupported
            XCTAssertEqual(store.trialReminderLeadDays, 2, "\(unsupported) は既定へ丸める")
        }
    }

    func testResetToDefaultsClearsTrialReminderLeadDays() {
        store.trialReminderLeadDays = 3

        store.resetToDefaults()

        XCTAssertEqual(store.trialReminderLeadDays, 2)
    }

}
