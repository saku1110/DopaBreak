import DeviceActivity
import FamilyControls
import ManagedSettings
import StoreKitTest
import SwiftUI
import UIKit
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

/// 1日に開ける回数の画面を実ウィンドウで描き、`output/verify/open-limit-2026-10-05/` へ書き出す。
/// 文字の潰れ・はみ出し・並びは数値では判定できないため、画像で確かめる。
/// `TEST_RUNNER_DOPABREAK_CAPTURE_OPEN_LIMIT=1` のときだけ動く。
@MainActor
final class DailyOpenLimitSnapshotCapture: XCTestCase {
    private var cleanups: [() -> Void] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard ProcessInfo.processInfo.environment["DOPABREAK_CAPTURE_OPEN_LIMIT"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_DOPABREAK_CAPTURE_OPEN_LIMIT=1 to capture verification images")
        }
    }

    override func tearDownWithError() throws {
        cleanups.forEach { $0() }
        cleanups = []
        try super.tearDownWithError()
    }

    func testCaptureSettings() async throws {
        let on = try makeFixture(limit: 12, opensToday: 9)
        on.model.setDailyOpenLimit(15)
        try await capture(SettingsView(snapshotModel: on.model, settingsStore: on.settingsStore,
                                       screenTimeAuthorized: true, onResetOnboarding: {}),
                          filename: "settings-on-pending.png")

        let off = try makeFixture(limit: nil, opensToday: 3, averagePerDay: 14)
        try await capture(SettingsView(snapshotModel: off.model, settingsStore: off.settingsStore,
                                       screenTimeAuthorized: true, onResetOnboarding: {}),
                          filename: "settings-off-average.png")
    }

    func testCaptureInterventionScreens() async throws {
        let breath = try makeFixture(limit: 12, opensToday: 9)
        let breathFlow = InterventionFlowModel(target: .catalog(try instagram()), model: breath.model, settingsStore: breath.settingsStore)
        breathFlow.start()
        try await capture(InterventionFlowView(snapshotFlow: breathFlow, model: breath.model,
                                               settingsStore: breath.settingsStore, onFinished: {}),
                          filename: "breath-remaining.png")
        breathFlow.stop()

        let last = try makeFixture(limit: 12, opensToday: 11)
        let lastFlow = InterventionFlowModel(target: .catalog(try instagram()), model: last.model, settingsStore: last.settingsStore)
        lastFlow.start()
        lastFlow.completeBreathingForTesting()
        lastFlow.selectReason(.boredom)
        lastFlow.chooseOpen()
        XCTAssertEqual(lastFlow.stage, .durationSelection)
        try await capture(InterventionFlowView(snapshotFlow: lastFlow, model: last.model,
                                               settingsStore: last.settingsStore, onFinished: {}),
                          filename: "duration-last-open.png")

        let reached = try makeFixture(limit: 12, opensToday: 12)
        let reachedFlow = InterventionFlowModel(target: .catalog(try instagram()), model: reached.model, settingsStore: reached.settingsStore)
        reachedFlow.start()
        XCTAssertEqual(reachedFlow.stage, .limitReached)
        try await capture(InterventionFlowView(snapshotFlow: reachedFlow, model: reached.model,
                                               settingsStore: reached.settingsStore, onFinished: {}),
                          filename: "limit-reached.png")

        reachedFlow.requestEmergencyOpen()
        XCTAssertEqual(reachedFlow.stage, .emergencyWaiting)
        try await capture(InterventionFlowView(snapshotFlow: reachedFlow, model: reached.model,
                                               settingsStore: reached.settingsStore, onFinished: {}),
                          filename: "emergency-waiting.png")
    }

    func testCaptureHomeAndEmergencySheet() async throws {
        let home = try makeFixture(limit: 12, opensToday: 12, cancelledToday: 4)
        home.settingsStore.setAutomationConfirmed(catalogID: "instagram", confirmed: true)
        home.settingsStore.setAutomationConfirmed(catalogID: "tiktok", confirmed: true)
        // 実機では権利の確認後に控えが書かれる。撮影では権利を確認できないため、止まっている控えを直接置く。
        let status = home.model.dailyOpenLimitStatus
        try DailyOpenLimitStore(snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: home.containerURL)))
            .transaction {
                $0 = DailyOpenLimitShieldSnapshot(
                    selectionDataList: [Data([1])],
                    openedCount: status.openedCount,
                    blockStartsAt: Date().addingTimeInterval(-600),
                    blockEndsAt: status.dayEndsAt,
                    updatedAt: Date()
                )
            }
        home.model.refresh()
        try await capture(HomeView(model: home.model, settingsStore: home.settingsStore),
                          filename: "home-exhausted.png")

        var settings = home.settingsStore.dailyOpenLimitSettings
        settings.emergencyRequestedAt = Date().addingTimeInterval(-31)
        home.settingsStore.dailyOpenLimitSettings = settings
        try await capture(DailyOpenLimitEmergencySheet(model: home.model), filename: "emergency-sheet-ready.png")
    }

    /// ペイウォールの機能一覧に「1日に開ける回数」の行が並ぶか。実寸と、全体が収まる縦長の2枚を撮る。
    func testCapturePaywallFeatureList() async throws {
        let config = projectRootURL.appendingPathComponent("ios/DopaBreak/DopaBreak.storekit")
        let storeSession = try SKTestSession(contentsOf: config)
        storeSession.disableDialogs = true
        storeSession.storefront = "JPN"
        storeSession.locale = Locale(identifier: "ja")
        defer { storeSession.resetToDefaultState() }
        let fixture = try makeFixture(limit: nil, opensToday: 0)
        fixture.settingsStore.entitlementCachedIsPro = false
        await fixture.model.storeService.loadProducts()
        for (filename, height) in [("paywall-top.png", 852.0), ("paywall-full.png", 1_900.0)] {
            try await capture(
                PaywallView(
                    storeService: fixture.model.storeService,
                    placement: .onboardingPrepaywallSummary,
                    settingsStore: fixture.settingsStore,
                    model: fixture.model
                ),
                filename: filename,
                size: CGSize(width: 393, height: height)
            )
        }
    }

    // MARK: - 補助

    private func capture<Content: View>(
        _ content: Content,
        filename: String,
        size: CGSize = CGSize(width: 393, height: 852)
    ) async throws {
        let controller = UIHostingController(rootView: content
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .preferredColorScheme(.dark))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(700))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        let directory = projectRootURL.appendingPathComponent("output/verify/open-limit-2026-10-05", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(filename), options: .atomic)
    }

    private func makeFixture(
        limit: Int?,
        opensToday: Int,
        cancelledToday: Int = 0,
        averagePerDay: Int? = nil
    ) throws -> (model: AppModel, settingsStore: SettingsStore, containerURL: URL) {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyOpenLimitSnapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let suiteName = "DailyOpenLimitSnapshot-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        cleanups.append {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: containerURL)
        }

        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.entitlementCachedIsPro = true
        settingsStore.onboardingCompleted = true
        settingsStore.lockScreenCheckCompleted = true
        settingsStore.wakeTimeMinutes = 420
        settingsStore.bedTimeMinutes = 1_380
        settingsStore.blockConfiguration = BlockConfiguration(blockEnabled: true, blockTriggers: [.night])
        settingsStore.firstLaunchDate = Date().addingTimeInterval(-10 * 86_400)
        if let limit {
            settingsStore.dailyOpenLimitSettings = DailyOpenLimitSettings(limit: limit)
        }

        let container = FixedContainer(url: containerURL)
        let model = AppModel(
            containerProvider: container,
            settingsStore: settingsStore,
            catalogAllowanceStore: CatalogAllowanceStore(userDefaults: defaults),
            dailyOpenLimitMonitoringCenter: CaptureOpenLimitMonitoring(),
            dailyOpenLimitShieldWriter: CaptureOpenLimitShieldWriter(),
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false,
            screenTimeCenter: ScreenTimeCenter(authorizationStatusProvider: { .approved })
        )
        try model.targetStore.setTargets(["instagram", "tiktok"])
        // テストでは本物のアプリを選べないため、仮のトークンを1つ入れて「完全ブロックを設定済み」にする。
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [try JSONDecoder().decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8)
        )]
        _ = try model.ruleStore.saveFamilyActivitySelection(
            JSONEncoder().encode(selection),
            name: "完全ブロック",
            mode: .deepFocus
        )
        // 開いた回は一呼吸の対象アプリの記録として入れ、ホームの集計とそろえる。
        let ruleID = try model.ruleStore.catalogTargetRule(for: try instagram()).id
        let log = try SQLiteLogStore(containerProvider: container)
        let now = Date()
        for index in 0..<opensToday {
            try insertOpen(log, ruleID: ruleID, at: now.addingTimeInterval(TimeInterval(-60 * (index + 1))))
        }
        for index in 0..<cancelledToday {
            let time = now.addingTimeInterval(TimeInterval(-90 * (index + 1)))
            try log.insertCancelledAttempt(AttemptLog(
                id: UUID(), ruleId: ruleID, startedAt: time, completedAt: time,
                decision: .cancelled, intent: .boredom, selectedDurationSeconds: nil, attemptCount24h: 1, opened: false
            ), reclaimedSeconds: 480)
        }
        if let averagePerDay {
            for day in 1...7 {
                for index in 0..<averagePerDay {
                    try insertOpen(log, ruleID: ruleID, at: now.addingTimeInterval(TimeInterval(-86_400 * day - 60 * index)))
                }
            }
        }
        _ = model.addGoal(title: "週3回ジムに行く", category: .other, lockScreenTitle: nil)
        _ = model.addGoal(title: "英語で日常会話ができるようになる", category: .other, lockScreenTitle: nil)
        model.refresh()
        return (model, settingsStore, containerURL)
    }

    private func insertOpen(_ log: SQLiteLogStore, ruleID: UUID, at time: Date) throws {
        try log.insert(AttemptLog(
            id: UUID(), ruleId: ruleID, startedAt: time, completedAt: time,
            decision: .opened, intent: .boredom, selectedDurationSeconds: 300, attemptCount24h: 1, opened: true
        ))
    }

    private func instagram() throws -> SNSAppCatalogItem {
        try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
    }

    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private final class CaptureOpenLimitMonitoring: DailyOpenLimitMonitoring {
    func schedule(for activity: DeviceActivityName) -> DeviceActivitySchedule? { nil }

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {}

    func stopMonitoring(_ activities: [DeviceActivityName]) {}
}

private final class CaptureOpenLimitShieldWriter: ShieldSettingsWriting {
    func setShield(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>) {}
}
