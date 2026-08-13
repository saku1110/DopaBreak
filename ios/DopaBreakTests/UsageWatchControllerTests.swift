import DeviceActivity
import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class UsageWatchControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: SettingsStore!
    private var usageWatchStore: UsageWatchStore!
    private var selectionStore: UsageWatchSelectionStore!
    private var monitoringCenter: RecordingUsageWatchMonitoring!

    override func setUp() {
        super.setUp()
        suiteName = "UsageWatchControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(userDefaults: defaults)
        usageWatchStore = UsageWatchStore(userDefaults: defaults)
        selectionStore = UsageWatchSelectionStore(userDefaults: defaults)
        monitoringCenter = RecordingUsageWatchMonitoring()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        monitoringCenter = nil
        selectionStore = nil
        usageWatchStore = nil
        settingsStore = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDailyScheduleUsesSpecifiedBoundsAndRepeats() {
        let schedule = UsageWatchController.schedule()

        XCTAssertEqual(schedule.intervalStart.hour, 0)
        XCTAssertEqual(schedule.intervalStart.minute, 0)
        XCTAssertEqual(schedule.intervalEnd.hour, 23)
        XCTAssertEqual(schedule.intervalEnd.minute, 59)
        XCTAssertTrue(schedule.repeats)
    }

    func testLadderContainsTwentyFourFifteenMinuteThresholdsThroughSixHours() {
        let events = UsageWatchController.ladderEvents(for: FamilyActivitySelection())

        XCTAssertEqual(events.count, 24)
        for stepIndex in 1...24 {
            let name = DeviceActivityEvent.Name(
                UsageWatchConstants.eventName(stepIndex: stepIndex)
            )
            let event = events[name]
            let expectedMinutes = stepIndex * 15
            XCTAssertEqual(event?.threshold.hour, expectedMinutes / 60)
            XCTAssertEqual(event?.threshold.minute, expectedMinutes % 60)
        }
    }

    func testStaleEnabledFlagWithoutSelectionIsRevertedAtInitialization() {
        settingsStore.usageWatchEnabled = true

        let controller = makeController()

        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(settingsStore.usageWatchEnabled)
    }

    func testConfigurationSnapshotUsesSettingsAndEntitlement() {
        settingsStore.usageWatchQuestionIntervalMinutes = 60
        settingsStore.usageWatchNightModeEnabled = true
        settingsStore.bedTimeMinutes = 1_410
        settingsStore.wakeTimeMinutes = 390
        let controller = makeController()

        controller.configurationDidChange(isPro: true)

        XCTAssertEqual(
            usageWatchStore.loadConfiguration(),
            UsageWatchConfiguration(
                isPro: true,
                questionIntervalMinutes: 60,
                nightModeEnabled: true,
                bedTimeMinutes: 1_410,
                wakeTimeMinutes: 390
            )
        )
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
    }

    func testEmptySelectionCannotEnableAndStopsExistingSchedule() {
        let controller = makeController()

        let enabled = controller.enable(
            with: FamilyActivitySelection(),
            isPro: false
        )

        XCTAssertFalse(enabled)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(monitoringCenter.stoppedActivities.last, [UsageWatchController.activityName])
    }

    func testStopAndClearAllDataClearsSelectionAndCoreSnapshots() {
        usageWatchStore.saveConfiguration(UsageWatchConfiguration(isPro: true))
        usageWatchStore.saveState(UsageWatchState(questionsSentToday: 4))
        let controller = makeController()

        controller.stopAndClearAllData()

        XCTAssertFalse(settingsStore.usageWatchEnabled)
        XCTAssertEqual(usageWatchStore.loadConfiguration(), UsageWatchConfiguration())
        XCTAssertEqual(usageWatchStore.loadState(), UsageWatchState())
        XCTAssertEqual(selectionStore.load(), FamilyActivitySelection())
    }

    func testConfigurationChangeKeepsExistingRegistrationToPreserveDailyThresholdProgress() throws {
        let selection = try nonEmptySelection()
        let controller = makeController()
        XCTAssertTrue(controller.enable(with: selection, isPro: false))
        XCTAssertEqual(monitoringCenter.startedActivities.count, 1)

        controller.configurationDidChange(isPro: true)
        controller.entitlementDidChange(isPro: true)
        controller.setNightModeEnabled(true, isPro: true)

        // 登録し直すと当日の累積カウントが0に戻るため、張り直してはいけない。
        XCTAssertEqual(monitoringCenter.startedActivities.count, 1)
        XCTAssertEqual(monitoringCenter.stoppedActivities.count, 1)
        XCTAssertTrue(usageWatchStore.loadConfiguration().isPro)
        XCTAssertTrue(usageWatchStore.loadConfiguration().nightModeEnabled)
    }

    func testConfigurationChangeRestartsMonitoringWhenRegistrationWasLost() throws {
        let selection = try nonEmptySelection()
        let controller = makeController()
        XCTAssertTrue(controller.enable(with: selection, isPro: false))
        monitoringCenter.simulateSystemDroppedRegistration()

        controller.configurationDidChange(isPro: false)

        XCTAssertEqual(monitoringCenter.startedActivities.count, 2)
    }

    func testUnchangedSelectionDoesNotRestartMonitoring() throws {
        let selection = try nonEmptySelection()
        let controller = makeController()
        XCTAssertTrue(controller.enable(with: selection, isPro: false))

        XCTAssertTrue(controller.updateSelection(selection, isPro: false))
        XCTAssertEqual(monitoringCenter.startedActivities.count, 1)

        // 対象アプリが変わったときは閾値イベントを作り直す必要がある。
        let changed = try nonEmptySelection(base64: "ZG9wYWJyZWFrLXRlc3QtdG9rZW4tMg==")
        XCTAssertTrue(controller.updateSelection(changed, isPro: false))
        XCTAssertEqual(monitoringCenter.startedActivities.count, 2)
    }

    /// FamilyActivitySelectionのトークンはピッカー経由でしか作れないため、
    /// Codable表現（{"data": base64}）からダミートークンを組み立てる。
    /// コントローラはトークンの中身を見ず本数だけを見るため、これで足りる。
    private func nonEmptySelection(
        base64: String = "ZG9wYWJyZWFrLXRlc3QtdG9rZW4="
    ) throws -> FamilyActivitySelection {
        var selection = FamilyActivitySelection()
        let token = try JSONDecoder().decode(
            ApplicationToken.self,
            from: Data(#"{"data":"\#(base64)"}"#.utf8)
        )
        selection.applicationTokens = [token]
        return selection
    }

    private func makeController() -> UsageWatchController {
        UsageWatchController(
            settingsStore: settingsStore,
            usageWatchStore: usageWatchStore,
            selectionStore: selectionStore,
            monitoringCenter: monitoringCenter
        )
    }
}

private final class RecordingUsageWatchMonitoring: UsageWatchMonitoring {
    private(set) var startedActivities: [DeviceActivityName] = []
    private(set) var stoppedActivities: [[DeviceActivityName]] = []
    private(set) var activities: [DeviceActivityName] = []

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        startedActivities.append(activity)
        if !activities.contains(activity) {
            activities.append(activity)
        }
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stoppedActivities.append(activities)
        self.activities.removeAll { activities.contains($0) }
    }

    /// 再起動やOS都合で登録が失われた状態を再現する。
    func simulateSystemDroppedRegistration() {
        activities.removeAll()
    }
}
