import DeviceActivity
import UserNotifications
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

/// 「画面では有効なのに 実際のブロックが始まっていない」を黙らせないための回帰テスト。
///
/// 画面の解放はキャッシュ済みのProで通し、実体はStoreKitで権利を確かめられたときにしか
/// 置かない。この差は意図してそうしてある（取得に失敗しただけの課金者を締め出さないため）。
/// 差が開いているあいだ、以前は何の合図も残らず無言で失敗していた（2026-09-04の修正1）。
@MainActor
final class ShieldArmingStateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var containerURL: URL!
    private var settingsStore: SettingsStore!
    private var snapshotStore: JSONSnapshotStore!
    private var ruleStore: RuleStore!
    private var nightMonitoringCenter: RecordingShieldArmingMonitoring!
    private var deepFocusMonitoringCenter: RecordingShieldArmingMonitoring!
    private var notificationCenter: SilentDeepFocusNotifying!
    private var clearedShieldCount = 0
    private let currentDate = Date(timeIntervalSince1970: 1_755_100_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "ShieldArmingStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShieldArmingStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        settingsStore = SettingsStore(userDefaults: defaults)
        snapshotStore = JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        ruleStore = RuleStore(snapshotStore: snapshotStore)
        nightMonitoringCenter = RecordingShieldArmingMonitoring()
        deepFocusMonitoringCenter = RecordingShieldArmingMonitoring()
        notificationCenter = SilentDeepFocusNotifying()
        clearedShieldCount = 0
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
        notificationCenter = nil
        deepFocusMonitoringCenter = nil
        nightMonitoringCenter = nil
        ruleStore = nil
        snapshotStore = nil
        settingsStore = nil
        containerURL = nil
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // MARK: - 夜だけ強化

    /// StoreKitへ届いていないあいだは監視も控えも置かない。
    /// それ自体は正しいが、未武装であることは残す。
    func testNightRebuildReportsUnarmedWhileTheEntitlementIsUnconfirmed() throws {
        try makeNightRule()
        let scheduler = makeNightScheduler()

        XCTAssertFalse(
            scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: false)
        )

        XCTAssertEqual(scheduler.lastRebuildOutcome, .entitlementUnconfirmed)
        XCTAssertTrue(scheduler.didLastRebuildFail)
        // 解放条件は何も変えていない。触らないままであることを併せて確かめる。
        XCTAssertTrue(nightMonitoringCenter.startedActivities.isEmpty)
        XCTAssertTrue(nightMonitoringCenter.stoppedActivities.isEmpty)
        XCTAssertEqual(clearedShieldCount, 0)
        XCTAssertFalse(snapshotStore.exists(.nightShieldSnapshot))
    }

    /// 接続が戻って権利が確定したら、同じ経路で張り直り未武装は解ける。
    func testNightRebuildBecomesReadyOnceTheEntitlementResolves() throws {
        try makeNightRule()
        let scheduler = makeNightScheduler()

        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: false)
        XCTAssertEqual(scheduler.lastRebuildOutcome, .entitlementUnconfirmed)

        XCTAssertTrue(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertEqual(scheduler.lastRebuildOutcome, .ready)
        XCTAssertFalse(scheduler.didLastRebuildFail)
        XCTAssertEqual(
            nightMonitoringCenter.startedActivities.map(\.rawValue),
            [NightShieldConstants.activityName]
        )
    }

    /// Freeだと確定した人は「張らないことが正しい」側。注意行の対象にしない。
    func testNightRebuildForConfirmedFreeIsReadyNotUnarmed() throws {
        try makeNightRule()
        let scheduler = makeNightScheduler()

        XCTAssertFalse(scheduler.rebuild(entitlementGate: freeGate, hasConfirmedEntitlement: true))

        XCTAssertEqual(scheduler.lastRebuildOutcome, .ready)
        XCTAssertFalse(scheduler.didLastRebuildFail)
    }

    // MARK: - ディープフォーカス

    func testDeepFocusRebuildReportsUnarmedWhileTheEntitlementIsUnconfirmed() throws {
        try makeDeepFocusRule()
        let scheduler = makeDeepFocusScheduler()
        scheduler.startSession(durationMinutes: 60)

        XCTAssertFalse(
            scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: false)
        )

        XCTAssertEqual(scheduler.lastRebuildOutcome, .entitlementUnconfirmed)
        XCTAssertTrue(scheduler.didLastRebuildFail)
        // 残り時間は出るのに、控えも予定も置かれていない状態そのもの。
        XCTAssertNotNil(scheduler.activeSession)
        XCTAssertTrue(deepFocusMonitoringCenter.startedActivities.isEmpty)
        XCTAssertFalse(snapshotStore.exists(.deepFocusShieldSnapshot))
    }

    func testDeepFocusRebuildBecomesReadyOnceTheEntitlementResolves() throws {
        try makeDeepFocusRule()
        let scheduler = makeDeepFocusScheduler()
        scheduler.startSession(durationMinutes: 60)

        scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: false)
        XCTAssertEqual(scheduler.lastRebuildOutcome, .entitlementUnconfirmed)

        XCTAssertTrue(scheduler.rebuild(entitlementGate: proGate, hasConfirmedEntitlement: true))

        XCTAssertEqual(scheduler.lastRebuildOutcome, .ready)
        XCTAssertFalse(scheduler.didLastRebuildFail)
        XCTAssertTrue(snapshotStore.exists(.deepFocusShieldSnapshot))
    }

    // MARK: - 注意行を出す条件

    /// 起動直後の数秒で光らせない。取得を一度も試していないうちは黙っている。
    func testNoticeWaitsForTheFirstEntitlementResolutionAttempt() {
        XCTAssertFalse(
            ShieldArmingNoticePolicy.shouldShowUnarmedNotice(
                outcome: .entitlementUnconfirmed,
                hasAttemptedEntitlementResolution: false
            )
        )
        XCTAssertTrue(
            ShieldArmingNoticePolicy.shouldShowUnarmedNotice(
                outcome: .entitlementUnconfirmed,
                hasAttemptedEntitlementResolution: true
            )
        )
    }

    /// 出すのは「App Storeへ届いていない」ときだけ。
    /// 予定の登録に落ちたときは別の後始末（剥がす側へ倒す）が走るため、この文言は当たらない。
    func testNoticeIsNotShownForTheOtherOutcomes() {
        for outcome: ShieldArmingOutcome in [.ready] {
            XCTAssertFalse(
                ShieldArmingNoticePolicy.shouldShowUnarmedNotice(
                    outcome: outcome,
                    hasAttemptedEntitlementResolution: true
                ),
                "\(outcome) では出さない"
            )
        }
    }

    func testMonitoringFailureShowsNoticeEvenBeforeStoreKitAttempt() {
        XCTAssertTrue(ShieldArmingNoticePolicy.shouldShowUnarmedNotice(outcome: .failed, hasAttemptedEntitlementResolution: false))
    }

    // MARK: - Helpers

    private var proGate: EntitlementGate {
        EntitlementGate(isPro: true, now: currentDate)
    }

    private var freeGate: EntitlementGate {
        EntitlementGate(isPro: false, now: currentDate)
    }

    private func makeNightScheduler() -> NightShieldScheduler {
        NightShieldScheduler(
            ruleStore: ruleStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            monitoringCenter: nightMonitoringCenter,
            clearNightShield: { [weak self] in
                self?.clearedShieldCount += 1
            },
            now: { [weak self] in
                self?.currentDate ?? Date(timeIntervalSince1970: 0)
            }
        )
    }

    private func makeDeepFocusScheduler() -> DeepFocusScheduler {
        DeepFocusScheduler(
            ruleStore: ruleStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            monitoringCenter: deepFocusMonitoringCenter,
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
    private func makeNightRule() throws -> TargetRule {
        try ruleStore.saveFamilyActivitySelection(
            Data([0x01, 0x02]),
            name: "テスト対象",
            mode: .nightOnly
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
}

// MARK: - Test doubles

/// 夜だけ強化とディープフォーカスの両方へ差せる記録用の登録先。
private final class RecordingShieldArmingMonitoring: NightShieldMonitoring, DeepFocusMonitoring {
    private(set) var startedActivities: [DeviceActivityName] = []
    private(set) var stoppedActivities: [[DeviceActivityName]] = []

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        startedActivities.append(activity)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stoppedActivities.append(activities)
        startedActivities.removeAll { activities.contains($0) }
    }
}

private final class SilentDeepFocusNotifying: DeepFocusSessionNotifying {
    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?) {
        withCompletionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}
