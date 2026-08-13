import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import Observation

protocol UsageWatchMonitoring {
    var activities: [DeviceActivityName] { get }
    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: UsageWatchMonitoring {}

final class UsageWatchSelectionStore: @unchecked Sendable {
    private static let key = "usageWatch.familyActivitySelection"

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    convenience init() throws {
        guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
            throw CoreError.appGroupUnavailable(AppGroup.identifier)
        }
        self.init(userDefaults: userDefaults)
    }

    func load() -> FamilyActivitySelection {
        guard let data = userDefaults.data(forKey: Self.key),
              let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    func save(_ selection: FamilyActivitySelection) {
        guard let data = try? encoder.encode(selection) else {
            return
        }
        userDefaults.set(data, forKey: Self.key)
    }

    func clear() {
        userDefaults.removeObject(forKey: Self.key)
    }
}

@MainActor
@Observable
final class UsageWatchController {
    static let activityName = DeviceActivityName(UsageWatchConstants.activityName)

    private let settingsStore: SettingsStore
    private let usageWatchStore: UsageWatchStore
    private let selectionStore: UsageWatchSelectionStore
    private let monitoringCenter: any UsageWatchMonitoring

    private(set) var selection: FamilyActivitySelection
    private(set) var isEnabled: Bool
    private(set) var didLastMonitoringStartFail = false

    init(
        settingsStore: SettingsStore,
        usageWatchStore: UsageWatchStore,
        selectionStore: UsageWatchSelectionStore,
        monitoringCenter: any UsageWatchMonitoring = DeviceActivityCenter()
    ) {
        self.settingsStore = settingsStore
        self.usageWatchStore = usageWatchStore
        self.selectionStore = selectionStore
        self.monitoringCenter = monitoringCenter
        self.selection = selectionStore.load()
        self.isEnabled = settingsStore.usageWatchEnabled

        if Self.isEmpty(selection) && isEnabled {
            isEnabled = false
            settingsStore.usageWatchEnabled = false
        }
    }

    var selectedTokenCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var questionIntervalMinutes: Int {
        settingsStore.usageWatchQuestionIntervalMinutes
    }

    var nightModeEnabled: Bool {
        settingsStore.usageWatchNightModeEnabled
    }

    func requestAuthorization(using screenTime: ScreenTimeCenter) async -> Bool {
        screenTime.refresh()
        let isAuthorized: Bool
        if screenTime.isAuthorized {
            isAuthorized = true
        } else {
            isAuthorized = await screenTime.requestAuthorization()
        }
        guard isAuthorized else {
            disable()
            return false
        }
        return true
    }

    @discardableResult
    func enable(with selection: FamilyActivitySelection, isPro: Bool) -> Bool {
        guard !Self.isEmpty(selection) else {
            disable()
            return false
        }

        self.selection = selection
        selectionStore.save(selection)
        isEnabled = true
        settingsStore.usageWatchEnabled = true
        return rebuildMonitoring(isPro: isPro)
    }

    func disable() {
        monitoringCenter.stopMonitoring([Self.activityName])
        isEnabled = false
        settingsStore.usageWatchEnabled = false
        didLastMonitoringStartFail = false
    }

    @discardableResult
    func updateSelection(_ selection: FamilyActivitySelection, isPro: Bool) -> Bool {
        let selectionDidChange = selection != self.selection
        self.selection = selection
        selectionStore.save(selection)

        guard !Self.isEmpty(selection) else {
            disable()
            return false
        }
        guard isEnabled else {
            synchronizeConfiguration(isPro: isPro)
            return true
        }
        // 選択が変わっていないのに張り直すと当日の閾値カウントが0に戻る。
        // ピッカーを開いて何も変えずに閉じただけのときは登録を維持する。
        guard selectionDidChange || !isMonitoringActive else {
            synchronizeConfiguration(isPro: isPro)
            return true
        }
        return rebuildMonitoring(isPro: isPro)
    }

    func setQuestionIntervalMinutes(_ minutes: Int, isPro: Bool) {
        settingsStore.usageWatchQuestionIntervalMinutes = minutes
        configurationDidChange(isPro: isPro)
    }

    func setNightModeEnabled(_ isEnabled: Bool, isPro: Bool) {
        settingsStore.usageWatchNightModeEnabled = isEnabled
        configurationDidChange(isPro: isPro)
    }

    func configurationDidChange(isPro: Bool) {
        synchronizeConfiguration(isPro: isPro)
        guard isEnabled, !Self.isEmpty(selection) else { return }
        // startMonitoringを張り直すと、その日に積み上がった閾値カウントが0に戻る。
        // Extensionは発火のたびにApp Groupから設定を読み直すため、
        // 設定スナップショットの更新だけでは登録し直さない。
        // 起動時に登録が失われていた場合だけここで張り直す。
        guard !isMonitoringActive else { return }
        _ = rebuildMonitoring(isPro: isPro)
    }

    func entitlementDidChange(isPro: Bool) {
        configurationDidChange(isPro: isPro)
    }

    func recordIntervention(at date: Date) {
        usageWatchStore.recordIntervention(at: date)
    }

    func stopAndClearAllData() {
        disable()
        selection = FamilyActivitySelection()
        selectionStore.clear()
        usageWatchStore.clear()
    }

    static func schedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }

    static func ladderEvents(
        for selection: FamilyActivitySelection
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        Dictionary(uniqueKeysWithValues: (1...UsageWatchConstants.maximumStepCount).map { stepIndex in
            let thresholdMinutes = stepIndex * UsageWatchConstants.stepMinutes
            let name = DeviceActivityEvent.Name(
                UsageWatchConstants.eventName(stepIndex: stepIndex)
            )
            let event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(
                    hour: thresholdMinutes / 60,
                    minute: thresholdMinutes % 60
                )
            )
            return (name, event)
        })
    }

    private var isMonitoringActive: Bool {
        monitoringCenter.activities.contains(Self.activityName)
    }

    private func synchronizeConfiguration(isPro: Bool) {
        usageWatchStore.saveConfiguration(
            UsageWatchConfiguration(
                isPro: isPro,
                questionIntervalMinutes: settingsStore.usageWatchQuestionIntervalMinutes,
                nightModeEnabled: settingsStore.usageWatchNightModeEnabled,
                bedTimeMinutes: settingsStore.bedTimeMinutes ?? 1_380,
                wakeTimeMinutes: settingsStore.wakeTimeMinutes ?? 420
            )
        )
    }

    @discardableResult
    private func rebuildMonitoring(isPro: Bool) -> Bool {
        synchronizeConfiguration(isPro: isPro)
        monitoringCenter.stopMonitoring([Self.activityName])

        guard isEnabled, !Self.isEmpty(selection) else {
            return false
        }

        do {
            try monitoringCenter.startMonitoring(
                Self.activityName,
                during: Self.schedule(),
                events: Self.ladderEvents(for: selection)
            )
            didLastMonitoringStartFail = false
            return true
        } catch {
            monitoringCenter.stopMonitoring([Self.activityName])
            isEnabled = false
            settingsStore.usageWatchEnabled = false
            didLastMonitoringStartFail = true
            return false
        }
    }

    private static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }
}
