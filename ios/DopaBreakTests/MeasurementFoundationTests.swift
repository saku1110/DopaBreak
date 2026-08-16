import DopaBreakCore
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import DopaBreak

final class MeasurementFoundationTests: XCTestCase {
    func testOnboardingStepIdentifiersAreStableAndCoverAllFifteenSteps() {
        XCTAssertEqual(
            OnboardingStep.allCases.map(\.identifier),
            [
                "welcome",
                "self_check",
                "quiz_aimless",
                "quiz_regret",
                "quiz_result",
                "choose_apps",
                "goal_setup",
                "choose_mode",
                "preview",
                "why_science",
                "permission",
                "notification_guide",
                "lock_screen_check",
                "pre_paywall_summary",
                "ready"
            ]
        )
    }

    func testLockScreenCheckPhaseNeedsReturnFromLockScreenBeforeConfirming() {
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .visible,
                didReturnFromLockScreen: false,
                current: .starting
            ),
            .waiting
        )
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .visible,
                didReturnFromLockScreen: true,
                current: .waiting
            ),
            .confirmed
        )
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .visible,
                didReturnFromLockScreen: false,
                current: .confirmed
            ),
            .confirmed
        )
    }

    func testLockScreenCheckPhaseSeparatesSystemDenialFromRecoverableFailure() {
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .systemDisabled,
                didReturnFromLockScreen: true,
                current: .confirmed
            ),
            .blocked(.systemDisabled)
        )
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .failed,
                didReturnFromLockScreen: false,
                current: .waiting
            ),
            .blocked(.failed)
        )
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .noGoal,
                didReturnFromLockScreen: false,
                current: .starting
            ),
            .noGoal
        )
    }

    func testLockScreenCheckRecoversFromBlockedOnceActivityIsUpAgain() {
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .visible,
                didReturnFromLockScreen: false,
                current: .blocked(.systemDisabled)
            ),
            .waiting
        )
        XCTAssertEqual(
            LockScreenCheckContent.phase(
                for: .visible,
                didReturnFromLockScreen: true,
                current: .blocked(.failed)
            ),
            .confirmed
        )
    }

    func testLockScreenCheckPhaseIsPresentingOnlyWhileActivityIsUp() {
        XCTAssertTrue(LockScreenCheckPhase.waiting.isPresenting)
        XCTAssertTrue(LockScreenCheckPhase.confirmed.isPresenting)
        XCTAssertFalse(LockScreenCheckPhase.starting.isPresenting)
        XCTAssertFalse(LockScreenCheckPhase.blocked(.systemDisabled).isPresenting)
        XCTAssertFalse(LockScreenCheckPhase.blocked(.failed).isPresenting)
        XCTAssertFalse(LockScreenCheckPhase.noGoal.isPresenting)
        XCTAssertTrue(LockScreenCheckPhase.blocked(.systemDisabled).isBlocked)
        XCTAssertTrue(LockScreenCheckPhase.blocked(.failed).isBlocked)
        XCTAssertFalse(LockScreenCheckPhase.waiting.isBlocked)
    }

    func testPaywallPlacementIdentifiersCoverAllPresentationSites() {
        XCTAssertEqual(
            Set(PaywallPlacement.allCases.map(\.rawValue)),
            Set([
                "goals_limit",
                "settings_target_app_limit",
                "settings_family_activity_limit",
                "settings_pro_status_row",
                "settings_theme_gate",
                "settings_mode_gate",
                "settings_usage_watch_gate",
                "onboarding_prepaywall_summary",
                "onboarding_mode_gate",
                "onboarding_target_app_gate",
                "stats_history_gate",
                "weekly"
            ])
        )
    }

    @MainActor
    func testAppRootRecordsAppOpenedWhileOnboardingIsIncomplete() throws {
        let suiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let settingsStore = SettingsStore(userDefaults: defaults)
        XCTAssertFalse(settingsStore.onboardingCompleted)
        let eventStore = FunnelEventStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        )
        let timestamp = Date(timeIntervalSince1970: 1_721_174_400)
        let recorder = DailyAppOpenRecorder(
            settingsStore: settingsStore,
            funnelEventStore: eventStore
        )
        let rootView = AppLifecycleView(onAppActive: {
            try? recorder.recordIfNeeded(at: timestamp)
        }) {
            Text("onboarding")
        }
        let viewController = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: UIScreen.main.bounds)

        window.rootViewController = viewController
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        defer { window.isHidden = true }

        XCTAssertEqual(
            try eventStore.allEvents(),
            [FunnelEvent(name: FunnelEventName.appOpened.rawValue, occurredAt: timestamp)]
        )
    }

    func testPaywallDismissalPolicyExcludesProAndPendingPurchases() {
        XCTAssertTrue(
            PaywallDismissalPolicy.shouldRecord(isPro: false, hasPendingPurchase: false)
        )
        XCTAssertFalse(
            PaywallDismissalPolicy.shouldRecord(isPro: true, hasPendingPurchase: false)
        )
        XCTAssertFalse(
            PaywallDismissalPolicy.shouldRecord(isPro: false, hasPendingPurchase: true)
        )
    }

    /// まとめ置き換えでも上限は守る。ただし、すでに上限を超えている既存データは保てる。
    @MainActor
    func testReplaceGoalsBlocksGrowthBeyondTheFreeLimitButKeepsExistingGoals() throws {
        let suiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: containerURL) }

        let currentDate = Date(timeIntervalSince1970: 1_800_000_000)
        let settingsStore = SettingsStore(userDefaults: defaults)
        let containerProvider = TemporaryContainer(url: containerURL)
        try GoalStore(
            snapshotStore: JSONSnapshotStore(containerProvider: containerProvider)
        ).replace(goals: [
            Goal(
                id: UUID(),
                title: "英語で話す",
                lockScreenTitle: nil,
                category: .other,
                displayImagePath: nil,
                createdAt: currentDate,
                updatedAt: currentDate
            ),
            Goal(
                id: UUID(),
                title: "読書を30分",
                lockScreenTitle: nil,
                category: .other,
                displayImagePath: nil,
                createdAt: currentDate,
                updatedAt: currentDate
            )
        ])
        let model = AppModel(
            containerProvider: containerProvider,
            settingsStore: settingsStore,
            now: { currentDate }
        )

        XCTAssertEqual(model.entitlementGate.tier, .free)
        XCTAssertEqual(model.goals.map(\.title), ["英語で話す", "読書を30分"])

        // 既存2件のまま書き換えるのは通す（上限超過でも失わせない）
        var kept = model.goals
        kept[0].title = "英語で話し切る"
        XCTAssertTrue(model.replaceGoals(kept))
        XCTAssertEqual(model.goals.map(\.title), ["英語で話し切る", "読書を30分"])

        // 減らすのも通す
        XCTAssertTrue(model.replaceGoals(Array(model.goals.prefix(1))))
        XCTAssertEqual(model.goals.count, 1)

        // 上限を超えて増やすのは止める
        let extra = Goal(
            id: UUID(),
            title: "資格の勉強",
            lockScreenTitle: nil,
            category: .other,
            displayImagePath: nil,
            createdAt: currentDate,
            updatedAt: currentDate
        )
        XCTAssertFalse(model.replaceGoals(model.goals + [extra]))
        XCTAssertEqual(model.goals.count, 1)
    }

    func testPaywallResolvedYearlyDaysUsesSnapshotAndFallsBackToDefaultEstimate() {
        let snapshot = SelfCheckSnapshot(
            id: UUID(),
            usageBucket: "6時間以上",
            aimlessScrollBucket: "ほとんど毎日",
            regretBucket: "半分以上",
            estimatedDailyMinutes: 390,
            estimatedYearlyDays: 99,
            createdAt: Date()
        )

        XCTAssertEqual(PaywallView.resolvedYearlyDays(snapshot: snapshot), 99)
        XCTAssertEqual(PaywallView.resolvedYearlyDays(snapshot: nil), 38)
    }

    @MainActor
    func testRestartDuringBreathingDoesNotAllowStaleTaskToAdvance() async throws {
        let suiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.breathDurationSeconds = 3
        let model = AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore
        )
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let flow = InterventionFlowModel(
            target: target,
            model: model,
            settingsStore: settingsStore
        )
        defer { flow.stop() }

        flow.start()
        flow.selectReason(.boredom)
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertLessThan(flow.breathRemainingSeconds, flow.breathTotalSeconds)

        flow.start()
        XCTAssertEqual(flow.stage, .reasonSelection)

        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(flow.stage, .reasonSelection)
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .intentSelection)
    }

    @MainActor
    func testBreathingCompletesCountdownBeforeUsageSummary() async throws {
        let suiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.breathDurationSeconds = 3
        let model = AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore
        )
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let flow = InterventionFlowModel(
            target: target,
            model: model,
            settingsStore: settingsStore
        )
        defer { flow.stop() }

        flow.start()
        flow.selectReason(.unconscious)

        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(flow.stage, .usageSummary)
        XCTAssertEqual(flow.breathRemainingSeconds, 0)
    }

    @MainActor
    func testPaywallViewResolvesYearlyDaysFromPersistedSnapshotAndFallsBackOnCorruptData() throws {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let snapshotStore = JSONSnapshotStore(
            containerProvider: FixedContainer(url: containerURL)
        )
        try snapshotStore.write(
            SelfCheckSnapshot(
                id: UUID(),
                usageBucket: "6時間以上",
                aimlessScrollBucket: "ほとんど毎日",
                regretBucket: "半分以上",
                estimatedDailyMinutes: 390,
                estimatedYearlyDays: 99,
                createdAt: Date()
            ),
            to: .selfCheckSnapshot
        )
        let service = StoreService(
            funnelEventStore: FunnelEventStore(snapshotStore: snapshotStore)
        )

        let persistedView = PaywallView(
            storeService: service,
            placement: .settingsThemeGate,
            snapshotStore: snapshotStore
        )
        XCTAssertEqual(persistedView.yearlyDays, 99)

        try Data("not json".utf8).write(
            to: containerURL.appendingPathComponent("self_check_snapshot.json")
        )
        let fallbackView = PaywallView(
            storeService: service,
            placement: .settingsThemeGate,
            snapshotStore: snapshotStore
        )
        XCTAssertEqual(fallbackView.yearlyDays, 38)
    }

    @MainActor
    func testStoreServiceRecordsPaywallShownAndDismissedWithPlacement() throws {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let eventStore = FunnelEventStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        )
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let service = StoreService(funnelEventStore: eventStore, now: { timestamp })

        service.recordPaywallShown(placement: PaywallPlacement.settingsThemeGate.rawValue)
        service.recordPaywallDismissedIfNeeded(placement: PaywallPlacement.settingsThemeGate.rawValue)

        XCTAssertEqual(
            try eventStore.allEvents(),
            [
                FunnelEvent(
                    name: FunnelEventName.paywallShown.rawValue,
                    detail: "settings_theme_gate",
                    occurredAt: timestamp
                ),
                FunnelEvent(
                    name: FunnelEventName.paywallDismissed.rawValue,
                    detail: "settings_theme_gate",
                    occurredAt: timestamp
                )
            ]
        )
    }

}

/// 実データを書ける一時コンテナ。テストごとに捨てる。
private struct TemporaryContainer: ContainerProviding {
    let url: URL

    func containerURL() throws -> URL {
        url
    }
}
