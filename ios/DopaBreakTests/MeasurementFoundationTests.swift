import DopaBreakCore
import Foundation
import SwiftUI
import UIKit
import Vision
import XCTest
@testable import DopaBreak

final class MeasurementFoundationTests: XCTestCase {
    func testOnboardingStepIdentifiersAreStableAndCoverAllSeventeenSteps() {
        XCTAssertEqual(
            OnboardingStep.allCases.map(\.identifier),
            [
                "welcome",
                "self_check",
                "quiz_aimless",
                "quiz_regret",
                "quiz_result",
                "recovery_estimate",
                "choose_apps",
                "goal_setup",
                "choose_mode",
                "preview",
                "why_science",
                "permission",
                "notification_guide",
                "lock_screen_check",
                "lock_theme_pick",
                "pre_paywall_summary",
                "ready"
            ]
        )
    }

    func testLockThemePickFollowsLockScreenCheckAndPrecedesPrePaywallSummary() {
        XCTAssertEqual(OnboardingStep.lockScreenCheck.next, .lockThemePick)
        XCTAssertEqual(OnboardingStep.lockThemePick.previous, .lockScreenCheck)
        XCTAssertEqual(OnboardingStep.lockThemePick.next, .prePaywallSummary)
        XCTAssertEqual(OnboardingStep.prePaywallSummary.previous, .lockThemePick)
    }

    @MainActor
    func testSavedProThemeStaysGuardedForFreeAndReturnsForPro() throws {
        let suiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.lockTheme = .kpop
        settingsStore.entitlementCachedIsPro = false
        let container = TemporaryContainer(url: containerURL)
        let freeModel = AppModel(
            containerProvider: container,
            settingsStore: settingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )

        XCTAssertEqual(freeModel.savedLockTheme, .kpop)
        XCTAssertEqual(freeModel.liveLockTheme, .e1)

        settingsStore.entitlementCachedIsPro = true
        let proModel = AppModel(
            containerProvider: container,
            settingsStore: settingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )

        XCTAssertEqual(proModel.savedLockTheme, .kpop)
        XCTAssertEqual(proModel.liveLockTheme, .kpop)
    }

    @MainActor
    func testFreeSettingsProThemeSelectionSavesThemeAndPresentsSettingsPaywall() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())
        var settingsPlacement: PaywallPlacement?
        var callbackOrder: [String] = []

        SettingsLockThemeSelectionHandler.select(
            for: .gaming,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: {
                settingsPlacement = $0
                callbackOrder.append("paywall")
            },
            onSelect: { theme in
                fixture.settingsStore.lockTheme = theme
                fixture.model.refreshLockSurfaces(scheduleNotifications: false)
                callbackOrder.append("save")
            }
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .gaming)
        XCTAssertEqual(settingsPlacement, .settingsThemeGate)
        XCTAssertEqual(callbackOrder, ["save", "paywall"])
    }

    @MainActor
    func testFreeHomeProThemeSelectionSavesThemeAndPresentsHomePaywall() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())
        var homePlacement: PaywallPlacement?
        var callbackOrder: [String] = []

        HomeLockThemeSelectionHandler.select(
            for: .kpop,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: {
                homePlacement = $0
                callbackOrder.append("paywall")
            },
            onSelect: { theme in
                fixture.settingsStore.lockTheme = theme
                fixture.model.refreshLockSurfaces(scheduleNotifications: false)
                callbackOrder.append("save")
            }
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .kpop)
        XCTAssertEqual(homePlacement, .homeThemeGate)
        XCTAssertEqual(callbackOrder, ["save", "paywall"])
    }

    @MainActor
    func testFreeModelKeepsE1SurfaceAfterLockedThemeHandlerSelection() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        SettingsLockThemeSelectionHandler.select(
            for: .blueprint,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { _ in },
            onSelect: { theme in
                fixture.settingsStore.lockTheme = theme
                fixture.model.refreshLockSurfaces(scheduleNotifications: false)
            }
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .blueprint)
        XCTAssertEqual(fixture.model.lockSurfaceState.theme, .e1)
    }

    @MainActor
    func testPurchasedProUsesThemeSavedByLockedThemeHandlerWithoutReselection() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        HomeLockThemeSelectionHandler.select(
            for: .asagiri,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { _ in },
            onSelect: { theme in
                fixture.settingsStore.lockTheme = theme
                fixture.model.refreshLockSurfaces(scheduleNotifications: false)
            }
        )
        XCTAssertEqual(fixture.model.lockSurfaceState.theme, .e1)

        fixture.settingsStore.entitlementCachedIsPro = true
        let proModel = AppModel(
            containerProvider: TemporaryContainer(url: fixture.containerURL),
            settingsStore: fixture.settingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .asagiri)
        XCTAssertEqual(proModel.lockSurfaceState.theme, .asagiri)
    }

    @MainActor
    func testFreeSettingsPickerSelectionKeepsRowGuardedWhileSavingAndRenderingProTheme() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let actionReady = expectation(description: "Rendered settings picker action is available")
        let proThemeRendered = expectation(description: "Selected Pro theme is rendered")
        var selectTheme: ((LockTheme) -> Void)?
        var rowTheme = LockTheme.e1
        var paywallPlacement: PaywallPlacement?
        var savedThemeWhenPaywallPresented: LockTheme?
        let root = SettingsLockSurfaceView(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            liveLockTheme: Binding(
                get: { rowTheme },
                set: { rowTheme = $0 }
            ),
            liveActivityEnabled: .constant(true),
            isLockScreenCheckPresented: .constant(false),
            paywallPlacement: Binding(
                get: { paywallPlacement },
                set: {
                    paywallPlacement = $0
                    if $0 == .settingsThemeGate {
                        savedThemeWhenPaywallPresented = fixture.settingsStore.lockTheme
                    }
                }
            ),
            onPickerActionReady: { action in
                selectTheme = action
                actionReady.fulfill()
            },
            onPickerSelectionRendered: { theme in
                if theme == .gaming {
                    proThemeRendered.fulfill()
                }
            }
        )
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 2_400))

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)
        defer { window.isHidden = true }

        wait(for: [actionReady], timeout: 2)
        try XCTUnwrap(selectTheme)(.gaming)
        render(host)

        wait(for: [proThemeRendered], timeout: 2)
        XCTAssertEqual(rowTheme, .e1)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .gaming)
        XCTAssertEqual(paywallPlacement, .settingsThemeGate)
        XCTAssertEqual(savedThemeWhenPaywallPresented, .gaming)
    }

    @MainActor
    func testFreeSettingsPickerSelectionRendersProNoteForSavedTheme() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let actionReady = expectation(description: "Rendered settings picker action is available")
        let proNoteRendered = expectation(description: "Pro note is rendered for the saved theme")
        actionReady.assertForOverFulfill = false
        proNoteRendered.assertForOverFulfill = false
        var selectTheme: ((LockTheme) -> Void)?
        var liveTheme = LockTheme.e1
        var paywallPlacement: PaywallPlacement?
        let root = SettingsLockSurfaceView(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            liveLockTheme: Binding(
                get: { liveTheme },
                set: { liveTheme = $0 }
            ),
            liveActivityEnabled: .constant(true),
            isLockScreenCheckPresented: .constant(false),
            paywallPlacement: Binding(
                get: { paywallPlacement },
                set: { paywallPlacement = $0 }
            ),
            onPickerActionReady: { action in
                selectTheme = action
                actionReady.fulfill()
            },
            onProNoteRendered: {
                proNoteRendered.fulfill()
            }
        )
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 2_400))

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)
        defer { window.isHidden = true }

        wait(for: [actionReady], timeout: 2)
        try XCTUnwrap(selectTheme)(.note)
        render(host)

        wait(for: [proNoteRendered], timeout: 2)
        XCTAssertEqual(liveTheme, .e1)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .note)
        XCTAssertEqual(paywallPlacement, .settingsThemeGate)

        paywallPlacement = nil
        render(host)

        XCTAssertNil(paywallPlacement)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .note)
    }

    @MainActor
    func testFreeHomePickerKeepsSavedSelectionAndLivePreviewWhilePresentingHomePaywall() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        fixture.settingsStore.liveActivityEnabled = true
        let entryReady = expectation(description: "Home theme picker entry is rendered")
        let pickerReady = expectation(description: "Home theme picker is rendered")
        let proThemeRendered = expectation(description: "Selected Pro theme is rendered in the picker")
        let livePreviewRendered = expectation(description: "Guarded live theme preview is rendered")
        let paywallPresented = expectation(description: "Home theme paywall is presented")
        entryReady.assertForOverFulfill = false
        pickerReady.assertForOverFulfill = false
        proThemeRendered.assertForOverFulfill = false
        livePreviewRendered.assertForOverFulfill = false
        paywallPresented.assertForOverFulfill = false
        var openPicker: (() -> Void)?
        var selectTheme: ((LockTheme) -> Void)?
        var pickerTheme: LockTheme?
        var previewTheme: LockTheme?
        var presentedPlacement: PaywallPlacement?
        let root = HomeView(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            statsService: nil,
            onThemePickerEntryActionReady: { action in
                openPicker = action
                entryReady.fulfill()
            },
            onThemePickerActionReady: { action in
                selectTheme = action
                pickerReady.fulfill()
            },
            onThemePickerSelectionChanged: { theme in
                pickerTheme = theme
                if theme == .gaming {
                    proThemeRendered.fulfill()
                }
            },
            onLockScreenPreviewRendered: { theme in
                previewTheme = theme
                if theme == .e1 {
                    livePreviewRendered.fulfill()
                }
            },
            onPaywallPresented: { placement in
                presentedPlacement = placement
                if placement == .homeThemeGate {
                    paywallPresented.fulfill()
                }
            }
        )
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 2_400))

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)
        defer { window.isHidden = true }

        wait(for: [entryReady, livePreviewRendered], timeout: 2)
        try XCTUnwrap(openPicker)()
        render(host)
        wait(for: [pickerReady], timeout: 2)

        try XCTUnwrap(selectTheme)(.gaming)
        render(host)

        wait(for: [proThemeRendered, paywallPresented], timeout: 3)
        XCTAssertEqual(pickerTheme, .gaming)
        XCTAssertEqual(previewTheme, .e1)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .gaming)
        XCTAssertEqual(presentedPlacement, .homeThemeGate)
    }

    @MainActor
    func testProSettingsPickerSelectionUpdatesRowPickerAndSavedThemeTogether() throws {
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        let actionReady = expectation(description: "Rendered settings picker action is available")
        let proThemeRendered = expectation(description: "Selected Pro theme is rendered")
        var selectTheme: ((LockTheme) -> Void)?
        var rowTheme = LockTheme.e1
        var paywallPlacement: PaywallPlacement?
        let root = SettingsLockSurfaceView(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            liveLockTheme: Binding(
                get: { rowTheme },
                set: { rowTheme = $0 }
            ),
            liveActivityEnabled: .constant(true),
            isLockScreenCheckPresented: .constant(false),
            paywallPlacement: Binding(
                get: { paywallPlacement },
                set: { paywallPlacement = $0 }
            ),
            onPickerActionReady: { action in
                selectTheme = action
                actionReady.fulfill()
            },
            onPickerSelectionRendered: { theme in
                if theme == .blueprint {
                    proThemeRendered.fulfill()
                }
            }
        )
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 2_400))

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)
        defer { window.isHidden = true }

        wait(for: [actionReady], timeout: 2)
        try XCTUnwrap(selectTheme)(.blueprint)
        render(host)

        wait(for: [proThemeRendered], timeout: 2)
        XCTAssertEqual(rowTheme, .blueprint)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .blueprint)
        XCTAssertNil(paywallPlacement)
    }

    func testProOnboardingSelectionHidesBothThemeNotes() {
        let proGate = EntitlementGate(tier: .pro, now: Date())

        XCTAssertFalse(
            OnboardingThemeSummaryPolicy.showsPickerProNote(
                for: .kpop,
                isThemeAllowed: proGate.lockThemeAllowed
            )
        )
        XCTAssertFalse(
            OnboardingThemeSummaryPolicy.showsSummaryProNote(
                for: .kpop,
                isThemeAllowed: proGate.lockThemeAllowed
            )
        )
    }

    @MainActor
    func testLockThemePreviewCardAtWideWidthHasNoLetterboxedRowHeight() {
        let rendered = expectation(description: "Wide lock theme card rendered")
        var renderedSize = CGSize.zero
        let card = LockThemePreviewCard(
            theme: .e1,
            goalTitles: ["Read"],
            cancelledCount: 1,
            attemptCount: 2,
            onLayout: { size in
                renderedSize = size
                if abs(size.width - 393) < 0.5, abs(size.height - 160) < 0.5 {
                    rendered.fulfill()
                }
            }
        )
        let root = card
            .frame(width: 700, alignment: .top)
            .frame(width: 700, height: 300, alignment: .top)
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 700, height: 300))

        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        defer { window.isHidden = true }

        wait(for: [rendered], timeout: 2)
        XCTAssertEqual(renderedSize.width, 393, accuracy: 0.5)
        XCTAssertEqual(renderedSize.height, 160, accuracy: 0.5)
    }

    func testLockThemePickerRendersTenThemes() {
        XCTAssertEqual(LockThemePickerView.renderedThemes.count, 10)
    }

    func testPrePaywallSummaryOnlyShowsCardForProThemeSelection() {
        XCTAssertFalse(OnboardingThemeSummaryPolicy.showsThemeCard(for: .e1))
        for theme in LockTheme.allCases where theme != .e1 {
            XCTAssertTrue(OnboardingThemeSummaryPolicy.showsThemeCard(for: theme))
        }
    }

    @MainActor
    func testSettingsModeCardsRenderAllJapaneseCopyWithoutTruncation() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        fixture.settingsStore.onboardingCompleted = true
        fixture.settingsStore.pendingInterventionMode = InterventionMode.standard.rawValue

        let root = SettingsView(
            snapshotModel: fixture.model,
            settingsStore: fixture.settingsStore,
            screenTimeAuthorized: true,
            onResetOnboarding: {}
        )
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.dynamicTypeSize, .large)
        .preferredColorScheme(.dark)
        let host = UIHostingController(rootView: root)
        host.overrideUserInterfaceStyle = .dark
        let window = try XCTUnwrap(activeKeyWindow(), "No active simulator window for settings regression")
        let originalRootViewController = window.rootViewController
        defer {
            window.rootViewController = originalRootViewController
            window.makeKeyAndVisible()
        }

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)

        try XCTSkipUnless(InterventionMode.nightOnly.detailText == "就寝時刻から起床時刻までアプリを開けなくする", "ja環境でのみ日本語切り詰め回帰を検証する")

        let image = try XCTUnwrap(renderedImage(in: window).cgImage, "Settings mode cards image could not be rendered")
        let recognizedText = try recognizeJapaneseText(in: image)
        let compactRecognizedText = recognizedText.joined().filter { !$0.isWhitespace }
        for mode in InterventionMode.selectable {
            XCTAssertTrue(
                compactRecognizedText.contains(mode.displayTitle.filter { !$0.isWhitespace }),
                "Missing rendered mode title: \(mode.displayTitle)"
            )
            XCTAssertTrue(
                compactRecognizedText.contains(mode.detailText.filter { !$0.isWhitespace }),
                "Rendered mode detail is truncated or missing: \(mode.detailText)"
            )
        }
    }

    @MainActor
    func testCaptureSettingsModeCardsPNG() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        fixture.settingsStore.onboardingCompleted = true
        fixture.settingsStore.pendingInterventionMode = InterventionMode.standard.rawValue

        let root = SettingsView(
            snapshotModel: fixture.model,
            settingsStore: fixture.settingsStore,
            screenTimeAuthorized: true,
            onResetOnboarding: {}
        )
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.dynamicTypeSize, .large)
        .preferredColorScheme(.dark)
        let host = UIHostingController(rootView: root)
        host.overrideUserInterfaceStyle = .dark

        let window = try XCTUnwrap(activeKeyWindow(), "No active simulator window for settings capture")
        let originalRootViewController = window.rootViewController
        defer {
            window.rootViewController = originalRootViewController
            window.makeKeyAndVisible()
        }

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let cgImage = image.cgImage,
              cgImage.width == 1_320,
              cgImage.height == 2_868 else {
            throw XCTSkip(
                "Settings verification capture requires 1320x2868 pixels; got \(image.size) at scale \(format.scale)"
            )
        }

        let outputURL = settingsModeCardsVerificationURL()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try XCTUnwrap(image.pngData(), "Settings mode cards image could not be encoded as PNG")
        try data.write(to: outputURL, options: .atomic)
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
                "settings_target_app_limit",
                "settings_family_activity_limit",
                "settings_pro_status_row",
                "settings_theme_gate",
                "home_theme_gate",
                "settings_mode_gate",
                "settings_gate_gate",
                "onboarding_prepaywall_summary",
                "onboarding_mode_gate",
                "onboarding_target_app_gate",
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
        let rootView = BackgroundSnapshotShieldHost(onAppActive: {
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

    /// 目標の件数制限は撤廃済み（2026-08-17オーナー決定）。Freeでもまとめ置き換えで増減できる。
    @MainActor
    func testReplaceGoalsAllowsGrowthOnTheFreeTier() throws {
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

        // 既存2件のまま書き換えるのは通す
        var kept = model.goals
        kept[0].title = "英語で話し切る"
        XCTAssertTrue(model.replaceGoals(kept))
        XCTAssertEqual(model.goals.map(\.title), ["英語で話し切る", "読書を30分"])

        // 減らすのも通す
        XCTAssertTrue(model.replaceGoals(Array(model.goals.prefix(1))))
        XCTAssertEqual(model.goals.count, 1)

        // Freeでも増やせる（件数制限の撤廃）
        let extra = Goal(
            id: UUID(),
            title: "資格の勉強",
            lockScreenTitle: nil,
            category: .other,
            displayImagePath: nil,
            createdAt: currentDate,
            updatedAt: currentDate
        )
        XCTAssertTrue(model.replaceGoals(model.goals + [extra]))
        XCTAssertEqual(model.goals.map(\.title), ["英語で話し切る", "資格の勉強"])

        // Freeでも3件目・4件目まで足せる
        let more = (1...2).map { index in
            Goal(
                id: UUID(),
                title: "追加の目標\(index)",
                lockScreenTitle: nil,
                category: .other,
                displayImagePath: nil,
                createdAt: currentDate,
                updatedAt: currentDate
            )
        }
        XCTAssertTrue(model.replaceGoals(model.goals + more))
        XCTAssertEqual(model.goals.count, 4)
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
    func testConfiguredBreathDurationIsAvailableBeforeAndAfterStart() throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }

        for duration in [5, 8] {
            context.settingsStore.breathDurationSeconds = duration
            let flow = try context.makeFlow()

            XCTAssertEqual(flow.breathTotalSeconds, duration)
            XCTAssertEqual(flow.breathRemainingSeconds, duration)

            flow.start()
            XCTAssertEqual(flow.breathTotalSeconds, duration)
            XCTAssertEqual(flow.breathRemainingSeconds, duration)
            flow.stop()
        }
    }

    @MainActor
    func testResumeWhileBreathingIsNoOpWithoutStartingSecondTimerOrChangingGeneration() async throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }
        context.settingsStore.breathDurationSeconds = 8
        let flow = try context.makeFlow()
        defer { flow.stop() }

        flow.start()
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 1_300_000_000)
        XCTAssertLessThan(flow.breathRemainingSeconds, flow.breathTotalSeconds)
        let remainingBeforeResume = flow.breathRemainingSeconds
        let generationBeforeResume = try XCTUnwrap(
            Mirror(reflecting: flow).descendant("_startGeneration") as? Int
        )

        flow.resumeBreathingIfNeeded()

        let generationAfterResume = try XCTUnwrap(
            Mirror(reflecting: flow).descendant("_startGeneration") as? Int
        )
        XCTAssertEqual(flow.breathRemainingSeconds, remainingBeforeResume)
        XCTAssertEqual(generationAfterResume, generationBeforeResume)
        XCTAssertLessThan(flow.breathRemainingSeconds, flow.breathTotalSeconds)
    }

    @MainActor
    func testStoppedBreathingCanResumeWithoutRestartingFlowGeneration() async throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }
        let flow = try context.makeFlow()
        defer { flow.stop() }

        flow.start()
        flow.stop()
        XCTAssertEqual(flow.stage, .breathing)

        flow.resumeBreathingIfNeeded()
        try await Task.sleep(nanoseconds: 3_300_000_000)

        XCTAssertEqual(flow.stage, .reasonSelection)
        XCTAssertEqual(try context.model.interventionEngine?.currentStep(), .intentSelection)
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
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertLessThan(flow.breathRemainingSeconds, flow.breathTotalSeconds)

        flow.start()
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .shieldPresented)
    }

    @MainActor
    func testBreathingCompletesCountdownBeforeReasonSelection() async throws {
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
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(flow.stage, .breathing)

        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(flow.stage, .reasonSelection)
        XCTAssertEqual(flow.breathRemainingSeconds, 0)
        XCTAssertEqual(try model.interventionEngine?.currentStep(), .intentSelection)
    }

    @MainActor
    func testDirectReasonCannotBeSelectedBeforeBreathingCompletes() throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }
        let flow = try context.makeFlow()
        defer { flow.stop() }

        flow.start()
        XCTAssertEqual(flow.stage, .breathing)
        flow.selectReason(.work)
        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertNil(flow.selectedReason)

        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .reasonSelection)
        flow.selectReason(.work)
        guard case .opening = flow.stage else {
            return XCTFail("Direct reason should open the catalog target after breathing")
        }
    }

    @MainActor
    func testReflectiveReasonAdvancesDirectlyToUsageSummaryAfterBreathing() throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }
        let flow = try context.makeFlow()
        defer { flow.stop() }

        flow.start()
        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .reasonSelection)

        flow.selectReason(.unconscious)
        XCTAssertEqual(flow.stage, .usageSummary)
        XCTAssertEqual(try context.model.interventionEngine?.currentStep(), .decision)
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

@MainActor
private struct InterventionFlowTestContext {
    let containerURL: URL
    let suiteName: String
    let defaults: UserDefaults
    let settingsStore: SettingsStore
    let model: AppModel

    init() throws {
        suiteName = "MeasurementFoundationTests.InterventionFlow.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-InterventionFlow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.breathDurationSeconds = 3
        model = AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )
    }

    func makeFlow() throws -> InterventionFlowModel {
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
        return InterventionFlowModel(target: target, model: model, settingsStore: settingsStore)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
    }
}

@MainActor
private final class ThemeSelectionFixture {
    let settingsStore: SettingsStore
    let model: AppModel
    let containerURL: URL

    private let suiteName: String
    private let defaults: UserDefaults

    init(isPro: Bool = false) throws {
        let resolvedSuiteName = "MeasurementFoundationTests.\(UUID().uuidString)"
        let resolvedDefaults = try XCTUnwrap(UserDefaults(suiteName: resolvedSuiteName))
        resolvedDefaults.removePersistentDomain(forName: resolvedSuiteName)
        let resolvedContainerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeasurementFoundationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: resolvedContainerURL, withIntermediateDirectories: true)

        let resolvedSettingsStore = SettingsStore(userDefaults: resolvedDefaults)
        resolvedSettingsStore.entitlementCachedIsPro = isPro
        let resolvedModel = AppModel(
            containerProvider: TemporaryContainer(url: resolvedContainerURL),
            settingsStore: resolvedSettingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )

        suiteName = resolvedSuiteName
        defaults = resolvedDefaults
        containerURL = resolvedContainerURL
        settingsStore = resolvedSettingsStore
        model = resolvedModel
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
    }
}

@MainActor
private func makeThemeSelectionFixture(isPro: Bool = false) throws -> ThemeSelectionFixture {
    try ThemeSelectionFixture(isPro: isPro)
}

@MainActor
private func render(_ host: UIViewController) {
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    host.view.layoutIfNeeded()
}

@MainActor
private func renderedImage(in window: UIWindow) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = window.screen.scale
    return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
}

private func recognizeJapaneseText(in image: CGImage) throws -> [String] {
    var recognizedText: [String] = []
    let request = VNRecognizeTextRequest { request, error in
        guard error == nil,
              let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        recognizedText = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
    }
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ja-JP"]
    request.usesLanguageCorrection = true

    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return recognizedText
}

@MainActor
private func activeKeyWindow() -> UIWindow? {
    for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        if let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let firstWindow = windowScene.windows.first {
            return firstWindow
        }
    }
    return nil
}

private func settingsModeCardsVerificationURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("output/verify/settings-mode-cards.png")
}

/// 実データを書ける一時コンテナ。テストごとに捨てる。
private struct TemporaryContainer: ContainerProviding {
    let url: URL

    func containerURL() throws -> URL {
        url
    }
}

// Compatibility initializer used by the existing snapshot harness while the notification view
// supplies its notification-time binding explicitly.
@MainActor
extension SettingsNotificationsView {
    init(
        model: AppModel,
        settingsStore: SettingsStore,
        morningNotificationEnabled: Binding<Bool>,
        weeklyReportNotificationEnabled: Binding<Bool>,
        retentionSupportNotificationsEnabled: Binding<Bool>,
        planNotificationsEnabled: Binding<Bool>
    ) {
        self.init(
            model: model,
            settingsStore: settingsStore,
            morningNotificationEnabled: morningNotificationEnabled,
            morningNotificationMinutes: .constant(settingsStore.morningNotificationMinutes),
            weeklyReportNotificationEnabled: weeklyReportNotificationEnabled,
            retentionSupportNotificationsEnabled: retentionSupportNotificationsEnabled,
            planNotificationsEnabled: planNotificationsEnabled
        )
    }
}
