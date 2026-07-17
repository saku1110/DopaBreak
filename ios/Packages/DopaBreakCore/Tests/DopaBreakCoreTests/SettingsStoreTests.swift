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

    func testPendingMidSessionCheckInCatalogIDRoundTripsAndClears() {
        XCTAssertNil(store.pendingMidSessionCheckInCatalogID)

        store.pendingMidSessionCheckInCatalogID = "instagram"

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.pendingMidSessionCheckInCatalogID, "instagram")

        reloaded.pendingMidSessionCheckInCatalogID = nil

        XCTAssertNil(store.pendingMidSessionCheckInCatalogID)
        XCTAssertNil(defaults.object(forKey: "pendingMidSessionCheckInCatalogID"))
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
}
