import DopaBreakCore
import SwiftUI
import UIKit
import StoreKitTest
import Vision
import XCTest
@testable import DopaBreak

@MainActor
final class SettingsDeviceFixesSnapshotCapture: XCTestCase {
    func testCaptureUnifiedOnboardingChoice() async throws {
        let config = projectRootURL.appendingPathComponent("ios/DopaBreak/DopaBreak.storekit")
        let storeSession = try SKTestSession(contentsOf: config)
        storeSession.disableDialogs = true
        let language = Locale.current.language.languageCode?.identifier ?? "ja"
        storeSession.storefront = language == "ko" ? "KOR" : language == "en" ? "USA" : "JPN"
        storeSession.locale = Locale(identifier: language)
        defer { storeSession.resetToDefaultState() }
        let fixture = try makeFixture(isPro: false)
        defer { fixture.cleanup() }
        fixture.settingsStore.blockConfiguration = BlockConfiguration()
        await fixture.model.storeService.loadProducts()
        XCTAssertNotNil(fixture.model.storeService.activeAnnualProduct)
        XCTAssertNotNil(fixture.model.storeService.annualIntroOfferDurationText)
        XCTAssertEqual(OnboardingProgress.preferredMode(from: fixture.settingsStore), .standard)
        try await captureAutomationSurface(OnboardingFlow(model: fixture.model, settingsStore: fixture.settingsStore,
            initialStep: .chooseMode, onComplete: {}), filename: "onboarding-choice-\(language).png", directoryName: "block-model-2026-09-21")
    }

    /// 審査3.1.2: 年額カードは請求額（¥4,980/年）を大きく、月あたりの額を小さく出す（2026-09-26 オーナー承認）。
    /// 実際の課金画面をStoreKitの価格で描き、文字認識の高さで大小を確かめる。
    func testPaywallShowsBilledAnnualAmountLargerThanMonthlyEquivalent() async throws {
        let config = projectRootURL.appendingPathComponent("ios/DopaBreak/DopaBreak.storekit")
        let storeSession = try SKTestSession(contentsOf: config)
        storeSession.disableDialogs = true
        storeSession.storefront = "JPN"
        storeSession.locale = Locale(identifier: "ja")
        defer { storeSession.resetToDefaultState() }
        let fixture = try makeFixture(isPro: false)
        defer { fixture.cleanup() }
        await fixture.model.storeService.loadProducts()
        let annualProduct = try XCTUnwrap(fixture.model.storeService.activeAnnualProduct)
        // テスト環境のストアフロントで通貨が変わる（円・ドル）ため、価格は商品情報から組み立てて探す。
        let billedPrice = annualProduct.displayPrice.precomposedStringWithCompatibilityMapping.filter { !$0.isWhitespace }
        let monthlyEquivalentPrice = annualProduct.priceFormatStyle.format(annualProduct.price / Decimal(12))
            .precomposedStringWithCompatibilityMapping.filter { !$0.isWhitespace }

        let size = CGSize(width: 393, height: 852)
        let controller = UIHostingController(rootView: PaywallView(
            storeService: fixture.model.storeService,
            placement: .onboardingPrepaywallSummary,
            settingsStore: fixture.settingsStore,
            model: fixture.model
        )
            .preferredColorScheme(.dark))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(1200))
        // プランのカードは画面の下にあるため、内容の末尾までスクロールしてから撮る。
        let scrollView = try XCTUnwrap(firstScrollView(in: controller.view))
        scrollView.setContentOffset(
            CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)),
            animated: false
        )
        try await Task.sleep(for: .milliseconds(300))
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        let directory = projectRootURL.appendingPathComponent("output/verify/paywall-billed-amount-2026-09-26", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // 画面の文言はテストホストの言語で出るため、文字認識もその言語に合わせる。
        let language = Locale.current.language.languageCode?.identifier ?? "ja"
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("paywall-\(language).png"))

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [language == "ko" ? "ko-KR" : language == "en" ? "en-US" : "ja-JP"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let observations = (request.results ?? []).compactMap { observation -> (text: String, height: CGFloat)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let normalized = text.precomposedStringWithCompatibilityMapping.filter { !$0.isWhitespace }
            return (normalized, observation.boundingBox.height)
        }
        // 請求額は法務文言にも出るため、いちばん大きく読めた行を年額カードの価格とみなす。
        let billed = try XCTUnwrap(
            observations.filter { $0.text.contains(billedPrice) }.max { $0.height < $1.height },
            "年額の請求額（\(billedPrice)）が見つからない: \(observations.map(\.text))"
        )
        // 月あたりの額がどこかで大きく出ていれば、いちばん大きく読めた行がそれになる。
        let monthly = try XCTUnwrap(
            observations.filter { $0.text.contains(monthlyEquivalentPrice) }.max { $0.height < $1.height },
            "月あたりの額（\(monthlyEquivalentPrice)）が見つからない: \(observations.map(\.text))"
        )
        XCTAssertGreaterThan(billed.height, monthly.height * 1.5, "請求額は月あたりの額より明確に大きく出す")
    }

    func testBlockSwitchesPreserveOtherChoicesAndRejectFreeChanges() throws {
        for pro in [false, true] {
            let fixture = try makeFixture(isPro: pro)
            defer { fixture.cleanup() }
            fixture.settingsStore.blockConfiguration = BlockConfiguration(blockEnabled: pro, blockTriggers: [.manual, .night])
            try fixture.model.updateBlockTrigger(.weeklySchedule, enabled: true)
            XCTAssertEqual(fixture.settingsStore.blockTriggers, pro ? Set(BlockTrigger.allCases) : [.manual, .night])
            try fixture.model.updateBlockTrigger(.night, enabled: false)
            XCTAssertEqual(fixture.settingsStore.blockTriggers, pro ? [.manual, .weeklySchedule] : [.manual, .night])
        }
    }

    func testCachedProOfflineSwitchReflectsAllowsAndPreservesExistingBlock() throws {
        let fixture = try makeFixture(isPro: true)
        defer { fixture.cleanup() }
        XCTAssertTrue(fixture.model.entitlementGate.strictModeAllowed)
        XCTAssertFalse(fixture.model.storeService.hasConfirmedEntitlement)
        fixture.settingsStore.blockConfiguration = BlockConfiguration()
        try fixture.model.updateBlockTrigger(.night, enabled: true)
        XCTAssertTrue(fixture.model.blockConfiguration.blockTriggers.contains(.night))
        XCTAssertFalse(fixture.model.blockConfiguration.allows(.night), "The switch reads allows, not the stored intent")
        fixture.settingsStore.blockConfiguration = BlockConfiguration(blockEnabled: true, blockTriggers: [.manual])
        try fixture.model.updateBlockTrigger(.night, enabled: true)
        XCTAssertTrue(fixture.model.blockConfiguration.allows(.night))
        XCTAssertTrue(fixture.model.blockConfiguration.allows(.manual), "Offline edits must not downgrade a paying user")
    }

    func testPurchaseFromFreeOrLegacyStandardEnablesEveryTriggerAndContinues() throws {
        for continuation: PurchaseContinuation? in [nil, .addTarget(catalogID: "instagram"), .applyMode(.deepFocus)] {
            let fixture = try makeFixture(isPro: false)
            defer { fixture.cleanup() }
            fixture.settingsStore.blockConfiguration = .migrating(.standard)
            XCTAssertTrue(fixture.settingsStore.blockTriggers.isEmpty)
            XCTAssertFalse(fixture.model.storeService.isPro)
            fixture.model.purchaseContinuation = continuation
            // Feed the same verified resolution as a purchase; Simulator rejects transaction
            // creation with notEntitled. Exercise the real StoreService application path.
            let resolution = EntitlementResolutionPolicy.resolve(previousIsPro: false, evidence: .init(
                currentEntitlements: .verifiedEntitlement, storeReachability: .productsAvailable,
                encounteredUnverifiedEntitlement: false, proDowngradeConfirmation: .notConfirmed))
            fixture.model.storeService.applyEntitlement(.init(resolution: resolution, subscriptionEntitlements: []))
            XCTAssertTrue(fixture.model.storeService.hasConfirmedEntitlement)
            XCTAssertTrue(fixture.model.storeService.isPro)
            XCTAssertTrue(fixture.settingsStore.blockEnabled)
            _ = fixture.model.applyPurchaseContinuationIfNeeded()
            XCTAssertEqual(fixture.settingsStore.blockTriggers, Set(BlockTrigger.allCases))
            for trigger in BlockTrigger.allCases { XCTAssertTrue(fixture.model.blockConfiguration.allows(trigger)) }
            XCTAssertNil(fixture.model.purchaseContinuation)
            if case .addTarget = continuation?.action {
                XCTAssertTrue(try fixture.model.targetStore.selectedCatalogIDs().contains("instagram"))
            }
        }
    }

    func testCaptureUnifiedBlockSettingsAndHome() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.blockConfiguration = BlockConfiguration(blockEnabled: true, blockTriggers: Set(BlockTrigger.allCases))
        try fixture.model.targetStore.setTargets(["instagram"])
        try await captureAutomationSurface(
            SettingsView(snapshotModel: fixture.model, settingsStore: fixture.settingsStore,
                         screenTimeAuthorized: true, onResetOnboarding: {}),
            filename: "settings-block-ja.png", directoryName: "block-model-2026-09-21")
        fixture.settingsStore.setAutomationConfirmed(catalogID: "instagram", confirmed: true)
        try await captureAutomationSurface(HomeView(model: fixture.model, settingsStore: fixture.settingsStore),
            filename: "home-ja.png", directoryName: "block-model-2026-09-21")
        XCTAssertEqual(fixture.settingsStore.blockTriggers, Set(BlockTrigger.allCases))
    }

    func testCaptureManualAutomationStatusAndGuideEntry() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.pendingInterventionMode = InterventionMode.standard.rawValue
        try fixture.model.targetStore.setTargets(["instagram", "x"])

        // Execution history must not hide the prompt when the user's checklist is empty.
        fixture.settingsStore.verifiedAutomationCatalogIDs = ["instagram", "x"]
        try await captureAutomationSurface(
            HomeView(model: fixture.model, settingsStore: fixture.settingsStore),
            filename: "home-unchecked.png"
        )

        // Conversely, a manual confirmation must work without any execution history.
        fixture.settingsStore.verifiedAutomationCatalogIDs = []
        for id in ["instagram", "x"] {
            fixture.settingsStore.setAutomationConfirmed(catalogID: id, confirmed: true)
        }
        try await captureAutomationSurface(
            HomeView(model: fixture.model, settingsStore: fixture.settingsStore),
            filename: "home-checked.png"
        )
        fixture.settingsStore.setAutomationConfirmed(catalogID: "x", confirmed: false)
        try await captureAutomationSurface(
            AutomationGuideView(model: fixture.model, settingsStore: fixture.settingsStore),
            filename: "guide-checklist-first.png"
        )
        try await captureAutomationSurface(
            AutomationGuideView(model: fixture.model, settingsStore: fixture.settingsStore)
                .dynamicTypeSize(.xxxLarge),
            filename: "guide-large-text.png"
        )
    }

    private func captureAutomationSurface<Content: View>(_ content: Content, filename: String, directoryName: String = "manual-automation") async throws {
        let size = CGSize(width: 393, height: 852)
        let controller = UIHostingController(rootView: content
            .environment(\.locale, Locale(identifier: filename.hasPrefix("onboarding-choice-") ? (Locale.current.language.languageCode?.identifier ?? "ja") : "ja"))
            .preferredColorScheme(.dark))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(filename.hasPrefix("onboarding-choice-") ? 1800 : 600))
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        if directoryName == "block-model-2026-09-21" {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            let language = filename.hasPrefix("onboarding-choice-") ? (Locale.current.language.languageCode?.identifier ?? "ja") : "ja"
            request.recognitionLanguages = [language == "ko" ? "ko-KR" : language == "en" ? "en-US" : "ja-JP"]
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined().precomposedStringWithCompatibilityMapping.filter { !$0.isWhitespace }
            let choiceLabels = language == "ko" ? ["멈추는 방법 선택", "무심코 여는 손을 멈춰요", "완전 차단", "매주 예정대로 자동 차단", "잠자는 동안 자동 차단", "Pro"]
                : language == "en" ? ["Choose how to stop", "Breaks the reflex to open", "Pause plus full block", "Block now for 30 min to 2 hours", "Blocks on your weekly schedule", "Blocks automatically while you sleep", "Pro"]
                : ["止め方を選ぶ", "反射で開く手が止まる", "一呼吸＋完全ブロック", "いま30分〜2時間だけ開けなくする", "毎週の予定で自動ブロック", "就寝中は自動ブロック", "無料", "おすすめ", "Pro"]
            let expected = filename.hasPrefix("onboarding-choice-") ? choiceLabels
                : filename == "settings-block-ja.png" ? ["手動セッション", "毎週の予定", "就寝中は自動"]
                : ["ブロック", "手動", "予定", "就寝中"]
            for label in expected { XCTAssertTrue(text.contains(label.precomposedStringWithCompatibilityMapping.filter { !$0.isWhitespace }), "Missing \(label) in \(filename): \(text)") }
        }
        let directory = projectRootURL.appendingPathComponent("output/verify/" + directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(filename))
    }

    func testHoldTimelineForPausedDragVerification() throws {
        guard ProcessInfo.processInfo.environment["DOPABREAK_HOLD_TIMELINE_DRAG"] == "1" else {
            throw XCTSkip("Set DOPABREAK_HOLD_TIMELINE_DRAG=1 for interactive drag verification")
        }

        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.wakeTimeMinutes = 420
        fixture.settingsStore.bedTimeMinutes = 60

        let size = CGSize(width: 393, height: 852)
        let view = SettingsView(
            snapshotModel: fixture.model,
            settingsStore: fixture.settingsStore,
            screenTimeAuthorized: true,
            onResetOnboarding: {}
        )
        .frame(width: size.width, height: size.height)

        let controller = UIHostingController(rootView: view)
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        let appeared = expectation(description: "Settings timeline appeared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { appeared.fulfill() }
        wait(for: [appeared], timeout: 1)

        let scrollView = try XCTUnwrap(firstScrollView(in: controller.view))
        let maximumOffset = max(
            0,
            scrollView.contentSize.height - scrollView.adjustedContentInset.top
                - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        scrollView.setContentOffset(
            CGPoint(x: 0, y: maximumOffset * 0.72),
            animated: false
        )
        window.layoutIfNeeded()
        print("TIMELINE_PAUSED_DRAG_READY")

        let hold = expectation(description: "External Simulator drag verification completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { hold.fulfill() }
        wait(for: [hold], timeout: 65)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testCaptureHomeBlockSettingsLanding() throws {
        guard ProcessInfo.processInfo.environment["DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES"] == "1" else {
            throw XCTSkip("Set DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES=1 to capture verification images")
        }

        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let actionReady = expectation(description: "Home block settings action is available")
        var openBlockSettings: (() -> Void)?
        let size = CGSize(width: 393, height: 852)
        let view = HomeBlockSettingsLandingHarness(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            onBlockSettingsActionReady: { action in
                openBlockSettings = action
                actionReady.fulfill()
            }
        )
        .frame(width: size.width, height: size.height)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        wait(for: [actionReady], timeout: 2)

        try XCTUnwrap(openBlockSettings)()
        let landed = expectation(description: "Settings consumed the Full Block focus request")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if !fixture.model.pendingDeepFocusSettingsFocus {
                landed.fulfill()
            }
        }
        wait(for: [landed], timeout: 2)
        window.layoutIfNeeded()
        XCTAssertNil(fixture.model.deepFocusSession)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }
        let outputURL = projectRootURL
            .appendingPathComponent("output/verify", isDirectory: true)
            .appendingPathComponent("home-block-settings-landing-warm.png")
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try XCTUnwrap(image.pngData()).write(to: outputURL, options: .atomic)
        XCTAssertEqual(image.cgImage?.width, 1_179)
        XCTAssertEqual(image.cgImage?.height, 2_556)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        window.isHidden = true
        window.rootViewController = nil
    }

    func testCaptureSettingsDeviceFixes() throws {
        guard ProcessInfo.processInfo.environment["DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES"] == "1" else {
            throw XCTSkip("Set DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES=1 to capture verification images")
        }

        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try capture(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            timelineDragPreview: false,
            scrollFraction: 0.30,
            filename: "settings-deep-focus-choose-apps.png"
        )
        fixture.settingsStore.wakeTimeMinutes = 420
        fixture.settingsStore.bedTimeMinutes = 60
        try capture(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            timelineDragPreview: true,
            scrollFraction: 0.72,
            filename: "settings-timeline-drag-live-time.png"
        )
    }

    func testCaptureTimelinePrecisionControls() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.pendingInterventionMode = InterventionMode.nightOnly.rawValue
        fixture.settingsStore.wakeTimeMinutes = 427
        fixture.settingsStore.bedTimeMinutes = 1383
        try capture(model: fixture.model, settingsStore: fixture.settingsStore,
                    timelineDragPreview: true, scrollFraction: 1,
                    filename: "settings-timeline-precision.png")
    }

    func testCaptureCompactNightStatus() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.pendingInterventionMode = InterventionMode.nightOnly.rawValue
        try fixture.model.targetStore.setTargets(["instagram", "youtube"])
        try capture(model: fixture.model, settingsStore: fixture.settingsStore,
                    timelineDragPreview: false, scrollFraction: 0,
                    filename: "settings-compact-night-status.png")
    }

    private func capture(
        model: AppModel,
        settingsStore: SettingsStore,
        timelineDragPreview: Bool,
        scrollFraction: CGFloat,
        filename: String
    ) throws {
        let size = CGSize(width: 393, height: 852)
        let view = SettingsView(
            snapshotModel: model,
            settingsStore: settingsStore,
            screenTimeAuthorized: true,
            timelineDragPreview: timelineDragPreview,
            onResetOnboarding: {}
        )
        .frame(width: size.width, height: size.height)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        let appeared = expectation(description: "Settings appeared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            appeared.fulfill()
        }
        wait(for: [appeared], timeout: 1)
        window.layoutIfNeeded()

        let scrollView = try XCTUnwrap(firstScrollView(in: controller.view))
        let maximumOffset = max(
            0,
            scrollView.contentSize.height - scrollView.adjustedContentInset.top
                - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        scrollView.setContentOffset(
            CGPoint(x: 0, y: scrollFraction == 0
                ? -scrollView.adjustedContentInset.top
                : maximumOffset * scrollFraction),
            animated: false
        )
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }

        let outputDirectory = projectRootURL.appendingPathComponent("output/verify", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let outputURL = outputDirectory.appendingPathComponent(filename)
        try XCTUnwrap(image.pngData()).write(to: outputURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        window.isHidden = true
        window.rootViewController = nil
    }

    private func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }

    private func makeFixture(isPro: Bool = true) throws -> (
        model: AppModel,
        settingsStore: SettingsStore,
        cleanup: () -> Void
    ) {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsDeviceFixesSnapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        let suiteName = "SettingsDeviceFixesSnapshot-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.entitlementCachedIsPro = isPro
        settingsStore.pendingInterventionMode = InterventionMode.deepFocus.rawValue
        settingsStore.wakeTimeMinutes = 420
        settingsStore.bedTimeMinutes = 1_380

        let model = AppModel(
            containerProvider: SettingsDeviceFixesSnapshotContainer(url: containerURL),
            settingsStore: settingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )
        return (
            model,
            settingsStore,
            {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: containerURL)
            }
        )
    }

    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct HomeBlockSettingsLandingHarness: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onBlockSettingsActionReady: ((@escaping () -> Void) -> Void)
    @State private var selectedTab: AppTab = .settings
    @State private var hasWarmedSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                model: model,
                settingsStore: settingsStore,
                onOpenBlockSettings: {
                    selectedTab = .settings
                    model.pendingDeepFocusSettingsFocus = true
                },
                onBlockSettingsActionReady: onBlockSettingsActionReady
            )
            .tag(AppTab.home)
            .tabItem { Label("ホーム", systemImage: "house") }

            SettingsView(
                snapshotModel: model,
                settingsStore: settingsStore,
                screenTimeAuthorized: true,
                onResetOnboarding: {}
            )
            .tag(AppTab.settings)
            .tabItem { Label("設定", systemImage: "gearshape") }
            .onAppear {
                guard !hasWarmedSettings else { return }
                hasWarmedSettings = true
                Task { @MainActor in
                    await Task.yield()
                    selectedTab = .home
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .preferredColorScheme(.dark)
    }
}

private struct SettingsDeviceFixesSnapshotContainer: ContainerProviding {
    let url: URL

    func containerURL() throws -> URL {
        url
    }
}
