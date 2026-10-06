import DeviceActivity
import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

/// 廃止した常時ゲートが残したDeviceActivityの監視を、更新後の最初の同期で止める。
///
/// `ManagedSettingsStore`（"dopabreak.gate"）の掃除だけが残っていて、
/// `dopabreak.gate.reshield.<uuid>` の予定を止める経路は持ち主のコントローラごと消えていた。
/// 旧ビルドから上げた端末では枠を食い続け、`MonitorExtension` を無駄に起こす（2026-09-04の修正2）。
@MainActor
final class ShieldControllerRetiredGateTests: XCTestCase {
    private var containerURL: URL!
    private var ruleStore: RuleStore!
    private var activityCenter: RecordingRetiredActivityMonitoring!
    private let currentDate = Date(timeIntervalSince1970: 1_755_100_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ShieldControllerRetiredGateTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        ruleStore = RuleStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        )
        activityCenter = RecordingRetiredActivityMonitoring()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: containerURL)
        activityCenter = nil
        ruleStore = nil
        containerURL = nil
        try super.tearDownWithError()
    }

    /// 権利が未確定でも掃除は通す。ここで止めないと、更新直後の起動でしか通らない機会を落とす。
    func testRetiredGateActivitiesAreStoppedEvenWhileTheEntitlementIsUnconfirmed() {
        let retired = "dopabreak.gate.reshield.\(UUID().uuidString)"
        activityCenter.activities = [
            DeviceActivityName(retired),
            DeviceActivityName(NightShieldConstants.activityName),
            DeviceActivityName(DeepFocusConstants.sessionActivityName)
        ]
        let controller = makeController()

        controller.syncShield(
            entitlementGate: EntitlementGate(isPro: true, now: currentDate),
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(
            activityCenter.stoppedActivities.map { $0.map(\.rawValue) },
            [[retired]]
        )
    }

    /// 生きている夜だけ強化・完全ブロックの予定は巻き添えにしない。
    func testLiveWindowActivitiesAreNeverStopped() {
        activityCenter.activities = [
            DeviceActivityName(NightShieldConstants.activityName),
            DeviceActivityName(DeepFocusConstants.sessionActivityName),
            DeviceActivityName(DeepFocusConstants.scheduleActivityName(weekday: 2))
        ]
        let controller = makeController()

        controller.syncShield(
            entitlementGate: EntitlementGate(isPro: true, now: currentDate),
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertTrue(activityCenter.stoppedActivities.isEmpty)
    }

    /// 何度通しても壊れない。実際に走るのは1回だけで、2回目以降は問い合わせもしない。
    /// 同期は前面復帰のたびに通るため、毎回スクリーンタイムへ聞きに行かせない。
    func testTheCleanupRunsOnlyOnceAndStaysSafeToRepeat() {
        let retired = "dopabreak.gate.reshield.\(UUID().uuidString)"
        activityCenter.activities = [DeviceActivityName(retired)]
        let controller = makeController()

        for _ in 0..<3 {
            controller.syncShield(
                entitlementGate: EntitlementGate(isPro: true, now: currentDate),
                hasConfirmedEntitlement: false,
                isNightWindow: false,
                isDeepFocusWindowActive: false
            )
        }

        XCTAssertEqual(activityCenter.stoppedActivities.count, 1)
        XCTAssertEqual(activityCenter.queryCount, 1)
        XCTAssertTrue(activityCenter.activities.isEmpty)
    }

    /// 一覧が空で返った回は「済んだ」ことにしない。
    ///
    /// スクリーンタイムの認可が未解決の端末では `monitoredActivityNames` が空を返す。
    /// そこで済んだ印を立てると、そのプロセスでは二度と見に行かず、旧ビルドから上げた端末の
    /// `dopabreak.gate.reshield.<uuid>` がアプリを起動し直すまで枠を食い続ける（2026-09-04のR1）。
    func testAnEmptyScanIsRetriedOnTheNextSync() {
        activityCenter.activities = []
        let controller = makeController()

        controller.syncShield(
            entitlementGate: EntitlementGate(isPro: true, now: currentDate),
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(activityCenter.queryCount, 1)
        XCTAssertTrue(activityCenter.stoppedActivities.isEmpty)

        let retired = "dopabreak.gate.reshield.\(UUID().uuidString)"
        activityCenter.activities = [DeviceActivityName(retired)]

        controller.syncShield(
            entitlementGate: EntitlementGate(isPro: true, now: currentDate),
            hasConfirmedEntitlement: false,
            isNightWindow: false,
            isDeepFocusWindowActive: false
        )

        XCTAssertEqual(activityCenter.queryCount, 2)
        XCTAssertEqual(
            activityCenter.stoppedActivities.map { $0.map(\.rawValue) },
            [[retired]]
        )
    }

    func testManualAndNightUseSeparateStoresAndEndingManualPreservesNight() throws {
        var stores: [String: RecordingShieldStore] = [:]
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8))
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [token]
        try ruleStore.saveFamilyActivitySelection(try JSONEncoder().encode(selection), name: "Both windows", mode: .standard)
        let controller = ShieldController(ruleStore: ruleStore, activityCenter: activityCenter, storeFactory: { name in
            XCTAssertNil(stores[name], "Each shield must have a separate named store")
            let store = RecordingShieldStore()
            stores[name] = store
            return store
        })
        let manual = try XCTUnwrap(stores[DeepFocusConstants.shieldStoreName])
        let night = try XCTUnwrap(stores[NightShieldConstants.shieldStoreName])
        XCTAssertFalse(manual === night)
        let configuration = BlockConfiguration(blockEnabled: true, blockTriggers: Set(BlockTrigger.allCases))
        controller.syncShield(entitlementGate: EntitlementGate(isPro: true, now: currentDate),
                              hasConfirmedEntitlement: true, isNightWindow: true,
                              isDeepFocusWindowActive: false, isManualDeepFocusSessionActive: true,
                              blockConfiguration: configuration)
        XCTAssertEqual(manual.applications, [token])
        XCTAssertEqual(night.applications, [token])
        controller.syncShield(entitlementGate: EntitlementGate(isPro: true, now: currentDate),
                              hasConfirmedEntitlement: true, isNightWindow: true,
                              isDeepFocusWindowActive: false, isManualDeepFocusSessionActive: false,
                              blockConfiguration: configuration)
        XCTAssertTrue(manual.applications.isEmpty)
        XCTAssertEqual(night.applications, [token])
    }

    private func makeController() -> ShieldController {
        ShieldController(ruleStore: ruleStore, activityCenter: activityCenter)
    }
}

// MARK: - Test double

private final class RecordingRetiredActivityMonitoring: RetiredActivityMonitoring {
    var activities: [DeviceActivityName] = []
    private(set) var queryCount = 0
    private(set) var stoppedActivities: [[DeviceActivityName]] = []

    var monitoredActivityNames: [DeviceActivityName] {
        queryCount += 1
        return activities
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stoppedActivities.append(activities)
        self.activities.removeAll { activities.contains($0) }
    }
}

private final class RecordingShieldStore: ShieldSettingsWriting {
    private(set) var applications = Set<ApplicationToken>()
    private(set) var categories = Set<ActivityCategoryToken>()
    private(set) var webDomains = Set<WebDomainToken>()

    func setShield(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>) {
        self.applications = applications
        self.categories = categories
        self.webDomains = webDomains
    }
}
