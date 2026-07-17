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

    func testPaywallPlacementIdentifiersCoverAllNinePresentationSites() {
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
                "onboarding_target_app_gate"
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
