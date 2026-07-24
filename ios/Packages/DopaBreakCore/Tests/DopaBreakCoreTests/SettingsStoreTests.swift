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
        XCTAssertTrue(store.liveActivityEnabled)
        XCTAssertNil(store.lockThemeRawValue)
        XCTAssertEqual(store.lockTheme, .e1)
    }

    func testLockSurfaceValuesPersistAndNormalizeMinutes() {
        store.morningNotificationEnabled = false
        store.morningNotificationMinutes = 1_500
        store.weeklyReportNotificationEnabled = false
        store.liveActivityEnabled = false
        store.lockTheme = .yozora

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertFalse(reloaded.morningNotificationEnabled)
        XCTAssertEqual(reloaded.morningNotificationMinutes, 60)
        XCTAssertFalse(reloaded.weeklyReportNotificationEnabled)
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
        store.lockTheme = .shinrin

        let state = store.lockSurfaceState
        XCTAssertEqual(state.morningNotificationTime.hour, 7)
        XCTAssertEqual(state.morningNotificationTime.minute, 35)
        XCTAssertFalse(state.weeklyReportEnabled)
        XCTAssertEqual(state.theme, .shinrin)
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

    func testPendingDay14WarningRoundTripsAndExpiresAfter24Hours() {
        let writtenAt = Date(timeIntervalSince1970: 1_800_000_000)
        let pending = PendingDay14Warning(writtenAt: writtenAt)
        store.pendingDay14Warning = pending

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.pendingDay14Warning, pending)
        XCTAssertTrue(pending.isValid(at: writtenAt.addingTimeInterval(24 * 60 * 60)))
        XCTAssertFalse(pending.isValid(at: writtenAt.addingTimeInterval(24 * 60 * 60 + 1)))

        reloaded.pendingDay14Warning = nil

        XCTAssertNil(store.pendingDay14Warning)
        XCTAssertNil(defaults.object(forKey: "pendingDay14Warning"))
    }

    func testDay14ClampKeptCatalogIDRoundTripsAndClears() {
        store.day14ClampKeptCatalogID = "instagram"

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.day14ClampKeptCatalogID, "instagram")

        reloaded.day14ClampKeptCatalogID = nil

        XCTAssertNil(store.day14ClampKeptCatalogID)
        XCTAssertNil(defaults.object(forKey: "day14ClampKeptCatalogID"))
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

    func testReverseTrialValuesRoundTripAndStartIsNotOverwritten() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(store.startReverseTrialIfNeeded(at: startedAt))
        XCTAssertFalse(store.startReverseTrialIfNeeded(at: startedAt.addingTimeInterval(60)))
        store.reverseTrialEndPaywallShown = true

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.reverseTrialStartedAt, startedAt)
        XCTAssertTrue(reloaded.reverseTrialEndPaywallShown)
    }

    func testResetToDefaultsClearsReverseTrialState() {
        store.reverseTrialStartedAt = Date()
        store.reverseTrialEndPaywallShown = true

        store.resetToDefaults()

        XCTAssertNil(store.reverseTrialStartedAt)
        XCTAssertFalse(store.reverseTrialEndPaywallShown)
    }
}
