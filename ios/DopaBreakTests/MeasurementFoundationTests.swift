import DopaBreakCore
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import DopaBreak

final class MeasurementFoundationTests: XCTestCase {
    func testOnboardingStepIdentifiersAreStableAndCoverAllFourteenSteps() {
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
                "pre_paywall_summary",
                "ready"
            ]
        )
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
                "onboarding_prepaywall_summary",
                "onboarding_mode_gate",
                "onboarding_target_app_gate",
                "stats_history_gate",
                "day14_warning",
                "weekly",
                "reverse_trial_end"
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

    @MainActor
    func testAppModelEntitlementGateIncludesReverseTrialThenReturnsToFree() throws {
        let suiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var currentDate = startedAt
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.startReverseTrialIfNeeded(at: startedAt)
        do {
            var model: AppModel? = AppModel(
                containerProvider: UnavailableContainer(),
                settingsStore: settingsStore,
                now: { currentDate }
            )

            XCTAssertEqual(model!.entitlementGate.tier, .pro)
            XCTAssertNil(model!.entitlementGate.statsDays)
            XCTAssertNil(model!.entitlementGate.targetAppTokensLimit)

            currentDate = ReverseTrialPolicy.endDate(startedAt: startedAt)
            model!.refresh(scheduleNotifications: false)

            XCTAssertEqual(model!.entitlementGate.tier, .free)
            XCTAssertEqual(model!.entitlementGate.statsDays, 1)
            XCTAssertTrue(model!.shouldPresentReverseTrialEndPaywall)
            model = nil
        }
    }

    func testPaywallResolvedYearlyDaysUsesSnapshotAndFallsBackToDefaultEstimate() {
        let snapshot = SelfCheckSnapshot(
            id: UUID(),
            usageBucket: "4時間以上",
            aimlessScrollBucket: "ほとんど毎日",
            regretBucket: "半分以上",
            estimatedDailyMinutes: 270,
            estimatedYearlyDays: 68,
            createdAt: Date()
        )

        XCTAssertEqual(PaywallView.resolvedYearlyDays(snapshot: snapshot), 68)
        XCTAssertEqual(PaywallView.resolvedYearlyDays(snapshot: nil), 38)
    }

    func testDay14WarningScheduleUsesNominalTimeUntilItHasPassed() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let nominal = now.addingTimeInterval(6 * 60 * 60)
        let boundary = now.addingTimeInterval(2 * 86_400)

        XCTAssertEqual(
            Day14WarningSchedule.nextFireDate(
                nominalFireDate: nominal,
                now: now,
                day14Boundary: boundary
            ),
            nominal
        )
    }

    func testDay14WarningScheduleUsesEarlierFutureFallbackAfterNominalTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let nominal = now.addingTimeInterval(-60)
        let boundary = now.addingTimeInterval(20 * 60 * 60)

        XCTAssertEqual(
            Day14WarningSchedule.nextFireDate(
                nominalFireDate: nominal,
                now: now,
                day14Boundary: boundary
            ),
            now.addingTimeInterval(60 * 60)
        )
    }

    func testDay14WarningScheduleDoesNotUsePastBoundaryFallback() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let nominal = now.addingTimeInterval(-60)
        let boundary = now.addingTimeInterval(6 * 60 * 60)

        XCTAssertEqual(
            Day14WarningSchedule.nextFireDate(
                nominalFireDate: nominal,
                now: now,
                day14Boundary: boundary
            ),
            now.addingTimeInterval(60 * 60)
        )
        XCTAssertNil(
            Day14WarningSchedule.nextFireDate(
                nominalFireDate: nominal,
                now: boundary,
                day14Boundary: boundary
            )
        )
    }

    func testDay14WarningScheduleDoesNotFallbackAcrossDay14Boundary() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let nominal = now.addingTimeInterval(-60)
        let boundary = now.addingTimeInterval(30 * 60)

        XCTAssertNil(
            Day14WarningSchedule.nextFireDate(
                nominalFireDate: nominal,
                now: now,
                day14Boundary: boundary
            )
        )
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

        flow.start()
        XCTAssertEqual(flow.stage, .reasonSelection)

        try await Task.sleep(nanoseconds: 3_200_000_000)
        XCTAssertEqual(flow.stage, .reasonSelection)
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .intentSelection)
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
                usageBucket: "4時間以上",
                aimlessScrollBucket: "ほとんど毎日",
                regretBucket: "半分以上",
                estimatedDailyMinutes: 270,
                estimatedYearlyDays: 68,
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
        XCTAssertEqual(persistedView.yearlyDays, 68)

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

private struct UnavailableContainer: ContainerProviding {
    func containerURL() throws -> URL {
        throw NSError(domain: "MeasurementFoundationTests", code: 1)
    }
}
