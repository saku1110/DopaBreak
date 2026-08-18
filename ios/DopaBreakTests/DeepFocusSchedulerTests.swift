import DeviceActivity
import UserNotifications
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@MainActor
final class DeepFocusSchedulerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var containerURL: URL!
    private var settingsStore: SettingsStore!
    private var snapshotStore: JSONSnapshotStore!
    private var ruleStore: RuleStore!
    private var monitoringCenter: RecordingDeepFocusMonitoring!
    private var notificationCenter: RecordingDeepFocusNotifying!
    private var clearedShieldCount = 0
    private var currentDate = Date(timeIntervalSince1970: 1_755_100_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "DeepFocusSchedulerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepFocusSchedulerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        settingsStore = SettingsStore(userDefaults: defaults)
        snapshotStore = JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        ruleStore = RuleStore(snapshotStore: snapshotStore)
        monitoringCenter = RecordingDeepFocusMonitoring()
        notificationCenter = RecordingDeepFocusNotifying()
        clearedShieldCount = 0
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
        notificationCenter = nil
        monitoringCenter = nil
        ruleStore = nil
        snapshotStore = nil
        settingsStore = nil
        containerURL = nil
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // MARK: - 窓は本人の操作でしか開かない（P1-1の再発防止）

    /// 同期そのものが窓を作らないこと。
    /// 引き継ぎ処理が入っていた頃は、対象を選んだだけのProに、本人が始めていない
    /// 無期限ブロックが掛かった。同期は既にある窓を反映するだけに徹する。
    func testRebuildNeverCreatesASessionOnItsOwn() throws {
        try makeDeepFocusRule()

        let scheduler = makeScheduler()
        for _ in 0..<3 {
            scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)
        }

        XCTAssertNil(settingsStore.deepFocusSession)
        XCTAssertFalse(settingsStore.deepFocusSchedule.isEnabled)
        XCTAssertFalse(scheduler.isWindowActive)
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
    }

    /// 後からProになった人にも窓は生えない。権利の確定は窓を開く理由にならない。
    func testBecomingProLaterStillCreatesNoSession() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()

        scheduler.rebuild(entitlementGate: freeGate, hasConfirmedEntitlement: true)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        XCTAssertNil(settingsStore.deepFocusSession)
        XCTAssertFalse(scheduler.isWindowActive)
    }

    // MARK: - セッションの開始と終了

    func testStartSessionStoresTheRequestedDuration() {
        let scheduler = makeScheduler()

        scheduler.startSession(durationMinutes: 30)

        XCTAssertEqual(settingsStore.deepFocusSession?.startedAt, currentDate)
        XCTAssertEqual(
            settingsStore.deepFocusSession?.endsAt,
            currentDate.addingTimeInterval(30 * 60)
        )
        XCTAssertTrue(scheduler.isWindowActive)
    }

    /// 「自分で戻すまで」は終わる時刻を持たない。
    func testStartSessionWithoutDurationHasNoEndDate() {
        let scheduler = makeScheduler()

        scheduler.startSession(durationMinutes: nil)

        XCTAssertNotNil(settingsStore.deepFocusSession)
        XCTAssertNil(settingsStore.deepFocusSession?.endsAt)
        XCTAssertTrue(scheduler.isWindowActive)
    }

    func testEndSessionClearsTheSessionAndItsNotification() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)
        XCTAssertEqual(notificationCenter.addedIdentifiers, [NotificationIdentifier.deepFocusSessionEnd])

        scheduler.endSession()

        XCTAssertNil(settingsStore.deepFocusSession)
        XCTAssertFalse(scheduler.isWindowActive)
        XCTAssertTrue(
            notificationCenter.removedPendingIdentifiers.contains([
                NotificationIdentifier.deepFocusSessionEnd
            ])
        )
    }

    /// 終わった回は同期のたびに畳む。残ると画面が「実行中」と出し続ける。
    func testRebuildPrunesAnExpiredSession() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 30)

        currentDate = currentDate.addingTimeInterval(31 * 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        XCTAssertNil(settingsStore.deepFocusSession)
        XCTAssertFalse(scheduler.isWindowActive)
        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
    }

    /// 権利が未確定でも、終わった回を畳むところまでは通す（シールドには触らない）。
    func testRebuildPrunesExpiredSessionEvenWhenEntitlementIsUnconfirmed() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 30)

        currentDate = currentDate.addingTimeInterval(31 * 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: false)

        XCTAssertNil(settingsStore.deepFocusSession)
        XCTAssertEqual(clearedShieldCount, 0)
        XCTAssertTrue(monitoringCenter.stoppedActivities.isEmpty)
    }

    // MARK: - rebuildの順序規律

    /// 控え書込 → 成功時のみstop → start。
    /// 先に止める形にすると、書き込みに失敗した端末で窓の終わりの解除まで失う。
    func testRebuildWritesTheSnapshotBeforeStoppingMonitoring() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)

        XCTAssertTrue(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertTrue(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertEqual(monitoringCenter.stoppedActivities.count, 1)
        // 止める対象は登録しうる全部。要らなくなった曜日ぶんも一緒に落とす。
        XCTAssertEqual(
            Set(monitoringCenter.stoppedActivities[0].map(\.rawValue)),
            Set(DeepFocusConstants.allWindowActivityNames)
        )
        XCTAssertEqual(
            monitoringCenter.startedActivities.map(\.rawValue),
            [DeepFocusConstants.sessionActivityName]
        )
    }

    /// 控えを書けなければ既存の予定に触らない。
    func testRebuildLeavesMonitoringUntouchedWhenTheSnapshotCannotBeWritten() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler(snapshotStore: unwritableSnapshotStore())
        scheduler.startSession(durationMinutes: 60)

        XCTAssertFalse(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertTrue(monitoringCenter.stoppedActivities.isEmpty)
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
        XCTAssertTrue(notificationCenter.addedIdentifiers.isEmpty)
        XCTAssertTrue(scheduler.didLastRebuildFail)
    }

    /// 未確定のあいだは何も触らない（`ShieldSyncPolicy` の preserve と同じ）。
    func testRebuildDoesNothingWhileTheEntitlementIsUnconfirmed() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)

        XCTAssertFalse(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: false))

        XCTAssertTrue(monitoringCenter.stoppedActivities.isEmpty)
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
        XCTAssertEqual(clearedShieldCount, 0)
    }

    /// Freeだと確定したら、ルールを読む前に後始末を通す。
    func testRebuildStopsAndClearsForConfirmedFree() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        XCTAssertFalse(scheduler.rebuild(entitlementGate: freeGate, hasConfirmedEntitlement: true))

        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertTrue(
            notificationCenter.removedPendingIdentifiers.contains([
                NotificationIdentifier.deepFocusSessionEnd
            ])
        )
        // 降格は非破壊。窓の設定そのものは残す。
        XCTAssertNotNil(settingsStore.deepFocusSession)
    }

    /// 曜日の予定は選んだ曜日のぶんだけ張る。
    func testRebuildStartsOneActivityPerSelectedWeekday() throws {
        try makeDeepFocusRule()
        settingsStore.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [2, 5],
            startMinutes: 1_200,
            endMinutes: 1_320
        )
        let scheduler = makeScheduler()

        XCTAssertTrue(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertEqual(
            Set(monitoringCenter.startedActivities.map(\.rawValue)),
            [
                DeepFocusConstants.scheduleActivityName(weekday: 2),
                DeepFocusConstants.scheduleActivityName(weekday: 5)
            ]
        )
    }

    /// 曜日ゼロの予定は窓として成立しない。控えも予定も持たせない。
    func testRebuildKeepsNothingForAScheduleWithoutWeekdays() throws {
        try makeDeepFocusRule()
        settingsStore.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [],
            startMinutes: 1_200,
            endMinutes: 1_320
        )
        let scheduler = makeScheduler()

        XCTAssertFalse(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
    }

    // MARK: - 一部失敗の切り分け（P2-2）

    /// 曜日1本が張れなくても、成功したセッションの一回きりの予定は生かす。
    /// ここを巻き添えで落とすと、いま動いている回の終わりに解除を出す担い手が消える。
    func testASingleWeekdayFailureDoesNotCancelTheSessionActivity() throws {
        try makeDeepFocusRule()
        settingsStore.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [2, 5],
            startMinutes: 1_200,
            endMinutes: 1_320
        )
        monitoringCenter.failingActivityNames = [
            DeepFocusConstants.scheduleActivityName(weekday: 5)
        ]
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)

        XCTAssertFalse(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        // 成功したぶんは残る。剥がす側へは倒さない。
        XCTAssertEqual(clearedShieldCount, 0)
        XCTAssertTrue(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertEqual(
            notificationCenter.addedIdentifiers,
            [NotificationIdentifier.deepFocusSessionEnd]
        )
        XCTAssertTrue(
            monitoringCenter.startedActivities
                .map(\.rawValue)
                .contains(DeepFocusConstants.sessionActivityName)
        )
        // 張れなかった曜日だけを止め直す。
        XCTAssertTrue(
            monitoringCenter.stoppedActivities.contains([
                DeviceActivityName(DeepFocusConstants.scheduleActivityName(weekday: 5))
            ])
        )
        XCTAssertTrue(scheduler.didLastRebuildFail)
    }

    /// 1本も張れなかったときだけ剥がす側へ倒す。嘘の終了通知も残さない。
    func testACompleteMonitoringFailureClearsTheShieldAndTheNotification() throws {
        try makeDeepFocusRule()
        monitoringCenter.failsEverything = true
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)

        XCTAssertFalse(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertEqual(clearedShieldCount, 1)
        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertTrue(
            notificationCenter.removedPendingIdentifiers.contains([
                NotificationIdentifier.deepFocusSessionEnd
            ])
        )
        XCTAssertTrue(scheduler.didLastRebuildFail)
    }

    /// セッションの予定だけが落ちたら、終了通知は取り消す。
    /// 解除が伴わない「終わりました」は事実とずれる。
    func testAFailedSessionActivityCancelsTheEndNotification() throws {
        try makeDeepFocusRule()
        settingsStore.deepFocusSchedule = DeepFocusSchedule(
            isEnabled: true,
            weekdays: [2],
            startMinutes: 1_200,
            endMinutes: 1_320
        )
        monitoringCenter.failingActivityNames = [DeepFocusConstants.sessionActivityName]
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)

        XCTAssertFalse(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        // 曜日ぶんは生きているので、まるごと剥がす側へは倒さない。
        XCTAssertEqual(clearedShieldCount, 0)
        XCTAssertTrue(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertEqual(
            notificationCenter.removedPendingIdentifiers.last,
            [NotificationIdentifier.deepFocusSessionEnd]
        )
    }

    // MARK: - セッション終了の通知

    /// 「自分で戻すまで」は時間で終わらないので通知も予約しない。
    func testAnOpenEndedSessionSchedulesNoEndNotification() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: nil)

        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        XCTAssertTrue(notificationCenter.addedIdentifiers.isEmpty)
        // 時刻を持たない回に一回きりの予定は要らない。
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
    }

    /// 同期のたびに残り時間で取り直す。二重に積まない。
    func testTheEndNotificationIsRescheduledWithTheRemainingTime() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        currentDate = currentDate.addingTimeInterval(20 * 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        XCTAssertEqual(notificationCenter.addedIdentifiers.count, 2)
        XCTAssertEqual(notificationCenter.addedIntervals.count, 2)
        XCTAssertEqual(notificationCenter.addedIntervals[0], 3_600, accuracy: 1)
        XCTAssertEqual(notificationCenter.addedIntervals[1], 2_400, accuracy: 1)
        // 積み直しの前に必ず消してある。
        XCTAssertEqual(notificationCenter.removedPendingIdentifiers.count, 2)
    }

    func testStopAndClearRemovesTheSnapshotAndTheNotification() throws {
        try makeDeepFocusRule()
        let scheduler = makeScheduler()
        scheduler.startSession(durationMinutes: 60)
        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true)

        XCTAssertTrue(scheduler.stopAndClear())

        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
        XCTAssertEqual(
            Set(monitoringCenter.stoppedActivities.last?.map(\.rawValue) ?? []),
            Set(DeepFocusConstants.allWindowActivityNames)
        )
        XCTAssertTrue(
            notificationCenter.removedPendingIdentifiers.contains([
                NotificationIdentifier.deepFocusSessionEnd
            ])
        )
    }

    // MARK: - Helpers

    private var proGate: EntitlementGate {
        EntitlementGate(isPro: true, now: currentDate)
    }

    private var freeGate: EntitlementGate {
        EntitlementGate(isPro: false, now: currentDate)
    }

    private func makeScheduler(snapshotStore: JSONSnapshotStore? = nil) -> DeepFocusScheduler {
        DeepFocusScheduler(
            ruleStore: ruleStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore ?? self.snapshotStore,
            monitoringCenter: monitoringCenter,
            notificationCenter: notificationCenter,
            clearDeepFocusShield: { [weak self] in
                self?.clearedShieldCount += 1
            },
            now: { [weak self] in
                self?.currentDate ?? Date(timeIntervalSince1970: 0)
            }
        )
    }

    @discardableResult
    private func makeDeepFocusRule() throws -> TargetRule {
        try ruleStore.saveFamilyActivitySelection(
            Data([0x01, 0x02]),
            name: "テスト対象",
            mode: .deepFocus
        )
    }

    /// 書き込みが必ず失敗する控え置き場（存在しない親ディレクトリを指す）。
    private func unwritableSnapshotStore() -> JSONSnapshotStore {
        JSONSnapshotStore(
            containerProvider: FixedContainer(
                url: URL(fileURLWithPath: "/dev/null/deepfocus-unwritable")
            )
        )
    }
}

// MARK: - Test doubles

private final class RecordingDeepFocusMonitoring: DeepFocusMonitoring {
    enum MonitoringError: Error {
        case rejected
    }

    private(set) var startedActivities: [DeviceActivityName] = []
    private(set) var stoppedActivities: [[DeviceActivityName]] = []

    /// この名前の登録だけを失敗させる。一部失敗の切り分けを再現する。
    var failingActivityNames: Set<String> = []
    var failsEverything = false

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if failsEverything || failingActivityNames.contains(activity.rawValue) {
            throw MonitoringError.rejected
        }
        startedActivities.append(activity)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stoppedActivities.append(activities)
        startedActivities.removeAll { activities.contains($0) }
    }
}

private final class RecordingDeepFocusNotifying: DeepFocusSessionNotifying {
    private(set) var addedIdentifiers: [String] = []
    private(set) var addedIntervals: [TimeInterval] = []
    private(set) var removedPendingIdentifiers: [[String]] = []
    private(set) var removedDeliveredIdentifiers: [[String]] = []

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler: ((Error?) -> Void)?
    ) {
        addedIdentifiers.append(request.identifier)
        if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            addedIntervals.append(trigger.timeInterval)
        }
        withCompletionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
    }
}
