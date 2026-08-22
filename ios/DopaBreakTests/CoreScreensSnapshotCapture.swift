import DopaBreakCore
import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit
import UserNotifications
import XCTest

@testable import DopaBreak

enum CoreScreensSnapshotCapturePolicy {
    static let environmentKey = "DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS"
    static let expectedPixelSize = CGSize(width: 1320, height: 2868)

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentKey] == "1"
    }

    static func supports(pixelSize: CGSize) -> Bool {
        pixelSize == expectedPixelSize
    }

    static func hasVisibleContent(in image: CGImage) -> Bool {
        let sampleWidth = 32
        let sampleHeight = 64
        let bytesPerPixel = 4
        var pixels = [UInt8](
            repeating: 0,
            count: sampleWidth * sampleHeight * bytesPerPixel
        )
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.interpolationQuality = .low
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        )

        var minimumBrightness = UInt8.max
        var maximumBrightness = UInt8.min
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let brightness = max(
                pixels[index],
                max(pixels[index + 1], pixels[index + 2])
            )
            minimumBrightness = min(minimumBrightness, brightness)
            maximumBrightness = max(maximumBrightness, brightness)
        }
        return maximumBrightness >= 12 && maximumBrightness - minimumBrightness >= 8
    }
}

private enum CoreScreensSnapshotCaptureError: LocalizedError {
    case blankImage(String)
    case unsupportedLocale(String)

    var errorDescription: String? {
        switch self {
        case .blankImage(let name):
            return "\(name) の描画結果が空のため保存しません"
        case .unsupportedLocale(let identifier):
            return "スクリーンショット撮影で未対応のロケールです: \(identifier)"
        }
    }
}

private struct CoreScreensSnapshotLocale {
    let outputLocale: String
    let localeIdentifier: String

    var swiftUILocale: Locale {
        Locale(identifier: localeIdentifier)
    }

    var goalSeeds: [(title: String, category: GoalCategory, lockScreenTitle: String?)] {
        switch outputLocale {
        case "ja":
            return [
                ("英語で商談できる自分になる", .other, nil),
                ("朝のランニングを続ける", .health, nil),
                ("読書を30分する", .study, nil)
            ]
        case "en-US":
            return [
                ("Hold my own in English meetings", .other, nil),
                ("Keep up my morning run", .health, nil),
                ("Read for 30 minutes", .study, nil)
            ]
        case "ko":
            return [
                ("영어로 상담할 수 있는 나 되기", .other, nil),
                ("아침 러닝 계속하기", .health, nil),
                ("30분 독서하기", .study, nil)
            ]
        default:
            preconditionFailure("Unsupported capture locale: \(outputLocale)")
        }
    }

    static func resolve(
        preferredLanguages: [String] = Locale.preferredLanguages,
        currentIdentifier: String = Locale.current.identifier
    ) throws -> Self {
        let requestedIdentifier = preferredLanguages.first ?? currentIdentifier
        let normalized = requestedIdentifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        if normalized == "ja" || normalized.hasPrefix("ja-") {
            return Self(outputLocale: "ja", localeIdentifier: "ja_JP")
        }
        if normalized == "en" || normalized.hasPrefix("en-") {
            return Self(outputLocale: "en-US", localeIdentifier: "en_US")
        }
        if normalized == "ko" || normalized.hasPrefix("ko-") {
            return Self(outputLocale: "ko", localeIdentifier: "ko_KR")
        }
        throw CoreScreensSnapshotCaptureError.unsupportedLocale(requestedIdentifier)
    }
}

/// App Storeスクリーンショットへ埋め込むコア体験を、テストホストの実ウィンドウから撮る。
///
/// `ImageRenderer` ではNavigationStack、シート、システムステータスバーを再現できないため、
/// `NativeChromeSnapshotCapture` と同じく実ウィンドウへ載せ、`drawHierarchy` で取り込む。
/// 出力は `-testLanguage` / `-testRegion` に応じて
/// `output/app-store-screenshots/raw-core/{ja,en-US,ko}/`。
final class CoreScreensSnapshotCapture: XCTestCase {
    /// 8秒呼吸の中間。リングは50%減、表示は残り4秒で全ロケール共通。
    private static let breathSnapshotElapsed: TimeInterval = 4
    private var captureLocale: CoreScreensSnapshotLocale!

    private enum VerticalScrollTarget {
        case offset(CGFloat)
        case bottom
        case bottomInset(CGFloat)

        var isBottom: Bool {
            switch self {
            case .bottom, .bottomInset:
                return true
            case .offset:
                return false
            }
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard CoreScreensSnapshotCapturePolicy.isEnabled() else {
            throw XCTSkip(
                "手動撮影専用です。\(CoreScreensSnapshotCapturePolicy.environmentKey)=1 を指定してください"
            )
        }
        captureLocale = try CoreScreensSnapshotLocale.resolve()
    }

    @MainActor
    func testCaptureCoreScreens() throws {
        try runCapture(
            goalsOnly: false,
            additionalOnly: false,
            breathOnly: false,
            reflectionOnly: false
        )
    }

    /// 一呼吸画面だけを更新し、他のrawを上書きしない。
    @MainActor
    func testCaptureBreathScreen() throws {
        try runCapture(
            goalsOnly: false,
            additionalOnly: false,
            breathOnly: true,
            reflectionOnly: false
        )
    }

    /// 振り返り画面だけを更新し、他のrawを上書きしない。
    @MainActor
    func testCaptureReflectionScreen() throws {
        try runCapture(
            goalsOnly: false,
            additionalOnly: false,
            breathOnly: false,
            reflectionOnly: true
        )
    }

    /// 目標画面だけを更新するとき、既存の他rawを上書きせずに撮影する。
    @MainActor
    func testCaptureGoalsScreen() throws {
        try runCapture(
            goalsOnly: true,
            additionalOnly: false,
            breathOnly: false,
            reflectionOnly: false
        )
    }

    /// 追加パネル08〜10用。既存rawを上書きせず、設定2画面と白黒ガイドだけを撮る。
    @MainActor
    func testCaptureAdditionalSettingsScreens() throws {
        try runCapture(
            goalsOnly: false,
            additionalOnly: true,
            breathOnly: false,
            reflectionOnly: false
        )
    }

    @MainActor
    private func runCapture(
        goalsOnly: Bool,
        additionalOnly: Bool,
        breathOnly: Bool,
        reflectionOnly: Bool
    ) throws {
        let window = try XCTUnwrap(activeKeyWindow(), "テストホストのキーウィンドウが取得できない")
        try requireSupportedPixelSize(in: window)

        let suiteName = "CoreScreensSnapshotCapture.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreScreensSnapshotCapture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        try captureCoreScreens(
            containerURL: containerURL,
            defaults: defaults,
            goalsOnly: goalsOnly,
            additionalOnly: additionalOnly,
            breathOnly: breathOnly,
            reflectionOnly: reflectionOnly,
            window: window
        )
        // AppModelの非同期StoreKit更新がSQLite接続を短時間保持し得るため、実行中にunlinkしない。
        // 保存先はテストホストのtmp配下で、アプリ用コンテナの破棄時にOSが回収する。
    }

    @MainActor
    private func captureCoreScreens(
        containerURL: URL,
        defaults: UserDefaults,
        goalsOnly: Bool,
        additionalOnly: Bool,
        breathOnly: Bool,
        reflectionOnly: Bool,
        window: UIWindow
    ) throws {
        let container = FixedContainer(url: containerURL)
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.onboardingCompleted = true
        settingsStore.breathDurationSeconds = 8
        settingsStore.verifiedAutomationCatalogIDs = ["instagram"]
        if additionalOnly {
            settingsStore.entitlementCachedIsPro = true
            settingsStore.pendingInterventionMode = InterventionMode.deepFocus.rawValue
            settingsStore.wakeTimeMinutes = 7 * 60
            settingsStore.bedTimeMinutes = 23 * 60
            settingsStore.usageWatchEnabled = true
            settingsStore.usageWatchQuestionIntervalMinutes = 15
            settingsStore.usageWatchNightModeEnabled = true
            settingsStore.deepFocusSchedule = DeepFocusSchedule(
                isEnabled: true,
                weekdays: [2, 3, 4, 5, 6],
                startMinutes: 20 * 60,
                endMinutes: 22 * 60
            )
        }

        let snapshotToken = try JSONDecoder().decode(
            ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8)
        )
        let usageWatchStore = UsageWatchStore(userDefaults: defaults)
        let usageWatchSelectionStore = UsageWatchSelectionStore(userDefaults: defaults)
        let monitoringCenter = SnapshotDeviceActivityMonitoringCenter()
        let notificationCenter = SnapshotDeepFocusNotificationCenter()
        if additionalOnly {
            var usageWatchSelection = FamilyActivitySelection()
            usageWatchSelection.applicationTokens = [snapshotToken]
            usageWatchSelectionStore.save(usageWatchSelection)
        }

        let model = AppModel(
            containerProvider: container,
            settingsStore: settingsStore,
            usageWatchStore: usageWatchStore,
            usageWatchSelectionStore: usageWatchSelectionStore,
            usageWatchMonitoringCenter: monitoringCenter,
            nightShieldMonitoringCenter: monitoringCenter,
            deepFocusMonitoringCenter: monitoringCenter,
            deepFocusNotificationCenter: notificationCenter,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let rule = try model.ruleStore.catalogTargetRule(for: target)
        let logStore = try SQLiteLogStore(containerProvider: container)
        try seedAttemptLogs(in: logStore, ruleID: rule.id, now: Date())

        let goalSeeds = captureLocale.goalSeeds
        for goal in goalSeeds {
            XCTAssertTrue(
                model.addGoal(
                    title: goal.title,
                    category: goal.category,
                    lockScreenTitle: goal.lockScreenTitle
                )
            )
        }
        model.refresh(scheduleNotifications: false)
        XCTAssertEqual(model.goals.map(\.title), goalSeeds.map(\.title))
        XCTAssertEqual(model.goals.count, 3)
        XCTAssertEqual(model.todayCancelledCount, 12)
        XCTAssertEqual(model.todayAttemptCount, 15)

        let statsService = StatsService(logStore: logStore)
        let reflection = ReflectionLog(
            id: UUID(),
            attemptLogId: nil,
            ruleId: rule.id,
            promptedAt: Date(),
            answeredAt: nil,
            trigger: .appReturned,
            satisfaction: nil,
            happinessDelta: nil,
            skipped: false,
            createdAt: Date()
        )
        let engine = try XCTUnwrap(model.interventionEngine)

        let outputDirectory = Self.outputDirectory(for: captureLocale.outputLocale)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        print(
            "CORE_SCREEN_LOCALE \(captureLocale.outputLocale) "
                + "\(captureLocale.localeIdentifier) \(outputDirectory.path)"
        )
        fflush(stdout)

        let originalRoot = window.rootViewController
        defer {
            window.rootViewController?.dismiss(animated: false)
            window.rootViewController = originalRoot
        }

        if additionalOnly {
            try captureAdditionalSettingsScreens(
                model: model,
                settingsStore: settingsStore,
                applicationToken: snapshotToken,
                in: window,
                outputDirectory: outputDirectory
            )
            return
        }

        if goalsOnly {
            try capture(
                AnyView(GoalsView(model: model)),
                named: "goals",
                in: window,
                outputDirectory: outputDirectory
            )
            return
        }

        if reflectionOnly {
            try captureReflectionScreen(
                model: model,
                statsService: statsService,
                engine: engine,
                reflection: reflection,
                in: window,
                outputDirectory: outputDirectory
            )
            return
        }

        try captureBreathScreen(
            target: target,
            model: model,
            settingsStore: settingsStore,
            in: window,
            outputDirectory: outputDirectory
        )

        if breathOnly {
            return
        }

        try capture(
            AnyView(
                InterventionFlowView(
                    snapshotTarget: target,
                    model: model,
                    settingsStore: settingsStore,
                    selectedReason: nil,
                    onFinished: {}
                )
            ),
            named: "intent",
            in: window,
            outputDirectory: outputDirectory
        )

        try capture(
            AnyView(HomeView(model: model, settingsStore: settingsStore)),
            named: "home",
            in: window,
            outputDirectory: outputDirectory
        )

        try capture(
            AnyView(StatsView(model: model, statsService: statsService)),
            named: "stats",
            in: window,
            outputDirectory: outputDirectory
        )

        try capture(
            AnyView(GoalsView(model: model)),
            named: "goals",
            in: window,
            outputDirectory: outputDirectory
        )

        try captureReflectionScreen(
            model: model,
            statsService: statsService,
            engine: engine,
            reflection: reflection,
            in: window,
            outputDirectory: outputDirectory
        )
    }

    @MainActor
    private func captureReflectionScreen(
        model: AppModel,
        statsService: StatsService,
        engine: InterventionEngine,
        reflection: ReflectionLog,
        in window: UIWindow,
        outputDirectory: URL
    ) throws {
        try capture(
            AnyView(
                ReflectionSnapshotHost(
                    model: model,
                    statsService: statsService,
                    engine: engine,
                    reflection: reflection
                )
            ),
            named: "reflection",
            in: window,
            outputDirectory: outputDirectory,
            settleTime: 1.2
        )
    }

    @MainActor
    private func captureBreathScreen(
        target: SNSAppCatalogItem,
        model: AppModel,
        settingsStore: SettingsStore,
        in window: UIWindow,
        outputDirectory: URL
    ) throws {
        try capture(
            AnyView(
                InterventionFlowView(
                    snapshotTarget: target,
                    model: model,
                    settingsStore: settingsStore,
                    selectedReason: .boredom,
                    // 空RangeはpreviewLoopの既存span==0経路で中間位相へ固定する。
                    breathPreviewLoop: Self.breathSnapshotElapsed..<Self.breathSnapshotElapsed,
                    onFinished: {}
                )
            ),
            named: "breath",
            in: window,
            outputDirectory: outputDirectory,
            settleTime: 0.8
        )
    }

    @MainActor
    private func captureAdditionalSettingsScreens(
        model: AppModel,
        settingsStore: SettingsStore,
        applicationToken: ApplicationToken,
        in window: UIWindow,
        outputDirectory: URL
    ) throws {
        var blockSelection = FamilyActivitySelection()
        blockSelection.applicationTokens = [applicationToken]
        let selectionData = try JSONEncoder().encode(blockSelection)
        _ = try model.ruleStore.saveFamilyActivitySelection(
            selectionData,
            name: "Instagram",
            mode: .deepFocus
        )
        try model.applyInterventionMode(.deepFocus)
        settingsStore.pendingInterventionMode = InterventionMode.deepFocus.rawValue
        model.refresh(scheduleNotifications: false)

        guard model.entitlementGate.strictModeAllowed else {
            XCTFail("追加パネル撮影用のPro権利を確立できなかった")
            return
        }
        XCTAssertTrue(model.usageWatch.isEnabled)
        XCTAssertEqual(model.usageWatch.selectedTokenCount, 1)
        XCTAssertEqual(model.usageWatch.questionIntervalMinutes, 15)

        try capture(
            AnyView(
                SettingsView(
                    snapshotModel: model,
                    settingsStore: settingsStore,
                    screenTimeAuthorized: true,
                    onResetOnboarding: {}
                )
            ),
            named: "deepfocus",
            in: window,
            outputDirectory: outputDirectory,
            settleTime: 1.0,
            verticalScrollTarget: .offset(60),
            validateBeforeRender: {
                _ = try XCTUnwrap(
                    model.entitlementGate.strictModeAllowed ? true : nil,
                    "deepfocusの描画前に撮影用Pro権利が失われた"
                )
            }
        )

        try model.applyInterventionMode(.nightOnly)
        settingsStore.pendingInterventionMode = InterventionMode.nightOnly.rawValue
        try capture(
            AnyView(
                SettingsView(
                    snapshotModel: model,
                    settingsStore: settingsStore,
                    screenTimeAuthorized: true,
                    onResetOnboarding: {}
                )
            ),
            named: "nightmode",
            in: window,
            outputDirectory: outputDirectory,
            settleTime: 1.0,
            verticalScrollTarget: .offset(280),
            validateBeforeRender: {
                _ = try XCTUnwrap(
                    model.entitlementGate.strictModeAllowed ? true : nil,
                    "nightmodeの描画前に撮影用Pro権利が失われた"
                )
            }
        )

        try model.applyInterventionMode(.deepFocus)
        settingsStore.pendingInterventionMode = InterventionMode.deepFocus.rawValue
        try capture(
            AnyView(AutomationGuideView(model: model, settingsStore: settingsStore)),
            named: "grayscale",
            in: window,
            outputDirectory: outputDirectory,
            settleTime: 1.0,
            verticalScrollTarget: .bottomInset(24)
        )
    }

    private func seedAttemptLogs(
        in logStore: SQLiteLogStore,
        ruleID: UUID,
        now: Date
    ) throws {
        let calendar = Calendar.current
        let dailyCounts: [(dayOffset: Int, attempts: Int, cancelled: Int)] = [
            (-6, 3, 2),
            (-5, 5, 3),
            (-4, 4, 4),
            (-3, 7, 5),
            (-2, 6, 4),
            (-1, 8, 6),
            (0, 15, 12)
        ]

        for day in dailyCounts {
            let shifted = try XCTUnwrap(
                calendar.date(byAdding: .day, value: day.dayOffset, to: now)
            )
            let startOfDay = calendar.startOfDay(for: shifted)

            for index in 0..<day.attempts {
                let startedAt = try XCTUnwrap(
                    calendar.date(
                        byAdding: .minute,
                        value: 8 * 60 + index * 19,
                        to: startOfDay
                    )
                )
                let isCancelled = index < day.cancelled
                try logStore.insert(
                    AttemptLog(
                        id: UUID(),
                        ruleId: ruleID,
                        startedAt: startedAt,
                        completedAt: startedAt.addingTimeInterval(12),
                        decision: isCancelled ? .cancelled : .opened,
                        intent: isCancelled ? .unconscious : .communication,
                        selectedDurationSeconds: isCancelled ? nil : 600,
                        attemptCount24h: index + 1,
                        opened: !isCancelled
                    )
                )
            }
        }
    }

    @MainActor
    private func capture(
        _ view: AnyView,
        named name: String,
        in window: UIWindow,
        outputDirectory: URL,
        settleTime: TimeInterval = 0.7,
        verticalScrollTarget: VerticalScrollTarget? = nil,
        validateBeforeRender: (@MainActor () throws -> Void)? = nil
    ) throws {
        window.rootViewController?.dismiss(animated: false)

        let root = view
            .environment(\.locale, captureLocale.swiftUILocale)
            .environment(\.dynamicTypeSize, .large)
            .preferredColorScheme(.dark)
        let host = UIHostingController(rootView: root)
        host.overrideUserInterfaceStyle = .dark
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        settleRunLoop(for: settleTime)

        if let verticalScrollTarget {
            try positionVerticalScroll(
                in: host.view,
                target: verticalScrollTarget,
                screenName: name
            )
        }

        try validateBeforeRender?()

        let image = Self.render(window: window, fallbackView: host.view)
        let cgImage = try XCTUnwrap(image.cgImage, "\(name) のピクセル寸法を取得できなかった")
        let actualPixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard CoreScreensSnapshotCapturePolicy.supports(pixelSize: actualPixelSize) else {
            throw XCTSkip(
                "\(name) は \(Self.pixelSizeDescription(actualPixelSize))。"
                    + "6.9-inch用の \(Self.pixelSizeDescription(CoreScreensSnapshotCapturePolicy.expectedPixelSize)) "
                    + "ではないため保存しません"
            )
        }
        guard CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: cgImage) else {
            throw CoreScreensSnapshotCaptureError.blankImage(name)
        }

        let data = try XCTUnwrap(image.pngData(), "\(name) をPNG化できなかった")
        let outputURL = outputDirectory.appendingPathComponent("\(name).png")
        try data.write(to: outputURL, options: .atomic)
        print("CORE_SCREEN_CAPTURED \(name) \(cgImage.width)x\(cgImage.height) \(outputURL.path)")
        fflush(stdout)
    }

    @MainActor
    private func requireSupportedPixelSize(in window: UIWindow) throws {
        let image = Self.render(window: window)
        let cgImage = try XCTUnwrap(image.cgImage, "撮影端末のピクセル寸法を取得できない")
        let actualPixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard CoreScreensSnapshotCapturePolicy.supports(pixelSize: actualPixelSize) else {
            throw XCTSkip(
                "撮影端末は \(Self.pixelSizeDescription(actualPixelSize))。"
                    + "6.9-inch用の \(Self.pixelSizeDescription(CoreScreensSnapshotCapturePolicy.expectedPixelSize)) "
                    + "ではないため、モデル生成とファイル保存を行いません"
            )
        }
    }

    private static func pixelSizeDescription(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }

    @MainActor
    private func positionVerticalScroll(
        in rootView: UIView,
        target: VerticalScrollTarget,
        screenName: String
    ) throws {
        // 横チップのScrollViewも同じ階層にいるため、画面より縦に長いものだけを候補にし、
        // contentSizeが最大のSwiftUI本体ScrollViewを選ぶ。
        let scrollView = try XCTUnwrap(
            verticalScrollViews(in: rootView).max {
                $0.contentSize.height < $1.contentSize.height
            },
            "\(screenName) の縦UIScrollViewが取得できない"
        )

        // LazyVStackは最下部へ送った後にcontentSizeが段階的に確定し直すことがあるため、
        // bottomだけ十分な回数を合わせ直す。どちらもUIScrollView.contentOffsetを直接設定する。
        let adjustmentCount = target.isBottom ? 6 : 1
        for _ in 0..<adjustmentCount {
            rootView.setNeedsLayout()
            rootView.layoutIfNeeded()
            let minimumY = -scrollView.adjustedContentInset.top
            let maximumY = max(
                minimumY,
                scrollView.contentSize.height
                    - scrollView.bounds.height
                    + scrollView.adjustedContentInset.bottom
            )
            let requestedY: CGFloat
            switch target {
            case .offset(let y):
                requestedY = y
            case .bottom:
                requestedY = maximumY
            case .bottomInset(let inset):
                requestedY = maximumY - max(0, inset)
            }
            let resolvedY = min(max(requestedY, minimumY), maximumY)
            scrollView.setContentOffset(
                CGPoint(x: scrollView.contentOffset.x, y: resolvedY),
                animated: false
            )
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
            settleRunLoop(for: 0.35)
        }

        let offsetText = String(format: "%.2f", scrollView.contentOffset.y)
        let contentHeightText = String(format: "%.2f", scrollView.contentSize.height)
        let boundsHeightText = String(format: "%.2f", scrollView.bounds.height)
        let maximumY = max(
            -scrollView.adjustedContentInset.top,
            scrollView.contentSize.height
                - scrollView.bounds.height
                + scrollView.adjustedContentInset.bottom
        )
        let maximumText = String(format: "%.2f", maximumY)
        print(
            "CORE_SCREEN_SCROLL \(screenName) "
                + "offsetY=\(offsetText) maximumY=\(maximumText) "
                + "contentHeight=\(contentHeightText) boundsHeight=\(boundsHeightText)"
        )
        fflush(stdout)
    }

    @MainActor
    private func verticalScrollViews(in view: UIView) -> [UIScrollView] {
        var matches: [UIScrollView] = []
        if let scrollView = view as? UIScrollView,
           scrollView.contentSize.height > scrollView.bounds.height + 1 {
            matches.append(scrollView)
        }
        for subview in view.subviews {
            matches.append(contentsOf: verticalScrollViews(in: subview))
        }
        return matches
    }

    @MainActor
    private func settleRunLoop(for duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(
                mode: .default,
                before: min(deadline, Date().addingTimeInterval(0.05))
            )
        }
    }

    @MainActor
    private static func render(window: UIWindow, fallbackView: UIView? = nil) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let hierarchyImage = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        if let cgImage = hierarchyImage.cgImage,
           CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: cgImage) {
            return hierarchyImage
        }
        guard let fallbackView else {
            return hierarchyImage
        }
        return renderer.image { context in
            fallbackView.layer.render(in: context.cgContext)
        }
    }

    @MainActor
    private func activeKeyWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            if let first = windowScene.windows.first {
                return first
            }
        }
        return nil
    }

    private static func outputDirectory(for locale: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "output/app-store-screenshots/raw-core/\(locale)",
                isDirectory: true
            )
    }
}

private final class SnapshotDeviceActivityMonitoringCenter:
    UsageWatchMonitoring,
    NightShieldMonitoring,
    DeepFocusMonitoring
{
    private(set) var startedActivities: [DeviceActivityName] = []
    private(set) var stoppedActivities: [[DeviceActivityName]] = []
    var activities: [DeviceActivityName] { startedActivities }

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws {
        if !startedActivities.contains(activity) {
            startedActivities.append(activity)
        }
    }

    func stopMonitoring(_ activitiesToStop: [DeviceActivityName]) {
        stoppedActivities.append(activitiesToStop)
        startedActivities.removeAll { activitiesToStop.contains($0) }
    }
}

private final class SnapshotDeepFocusNotificationCenter: DeepFocusSessionNotifying {
    private(set) var pendingRemovalCount = 0
    private(set) var deliveredRemovalCount = 0

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler: ((Error?) -> Void)?
    ) {
        withCompletionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRemovalCount += 1
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        deliveredRemovalCount += 1
    }
}

final class CoreScreensSnapshotCapturePolicyTests: XCTestCase {
    func testCaptureRequiresExplicitOptIn() {
        XCTAssertFalse(CoreScreensSnapshotCapturePolicy.isEnabled(environment: [:]))
        XCTAssertFalse(
            CoreScreensSnapshotCapturePolicy.isEnabled(
                environment: [CoreScreensSnapshotCapturePolicy.environmentKey: "0"]
            )
        )
        XCTAssertTrue(
            CoreScreensSnapshotCapturePolicy.isEnabled(
                environment: [CoreScreensSnapshotCapturePolicy.environmentKey: "1"]
            )
        )
    }

    func testCaptureAcceptsOnlyTheAppStoreSixPointNineInchPixelSize() {
        XCTAssertTrue(
            CoreScreensSnapshotCapturePolicy.supports(
                pixelSize: CGSize(width: 1320, height: 2868)
            )
        )
        XCTAssertFalse(
            CoreScreensSnapshotCapturePolicy.supports(
                pixelSize: CGSize(width: 1206, height: 2622)
            )
        )
    }

    func testHostedUnitTestsDisableAppStartupSideEffects() {
        XCTAssertFalse(
            AppLaunchPolicy.enablesStartupSideEffects(
                environment: ["XCTestConfigurationFilePath": "/tmp/DopaBreakTests.xctestconfiguration"]
            )
        )
        XCTAssertTrue(AppLaunchPolicy.enablesStartupSideEffects(environment: [:]))
    }

    func testCaptureRejectsBlankImages() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let blankImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let visibleImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            UIColor.white.setFill()
            context.fill(CGRect(x: 8, y: 8, width: 16, height: 16))
        }

        XCTAssertFalse(
            CoreScreensSnapshotCapturePolicy.hasVisibleContent(
                in: try XCTUnwrap(blankImage.cgImage)
            )
        )
        XCTAssertTrue(
            CoreScreensSnapshotCapturePolicy.hasVisibleContent(
                in: try XCTUnwrap(visibleImage.cgImage)
            )
        )
    }

    @MainActor
    func testSnapshotAppModelCanDisableStartupSideEffectsAndUseInjectedServices() throws {
        let suiteName = "CoreScreensSnapshotCapturePolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        // AppModelがSQLite接続を保持するため実行中にはunlinkしない。テストホストのtmpはOSが回収する。

        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.entitlementCachedIsPro = true
        let monitoringCenter = SnapshotDeviceActivityMonitoringCenter()
        let notificationCenter = SnapshotDeepFocusNotificationCenter()

        let model = AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore,
            usageWatchStore: UsageWatchStore(userDefaults: defaults),
            usageWatchSelectionStore: UsageWatchSelectionStore(userDefaults: defaults),
            usageWatchMonitoringCenter: monitoringCenter,
            nightShieldMonitoringCenter: monitoringCenter,
            deepFocusMonitoringCenter: monitoringCenter,
            deepFocusNotificationCenter: notificationCenter,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )

        XCTAssertTrue(model.entitlementGate.strictModeAllowed)
        model.deepFocusScheduler.endSession()
        XCTAssertEqual(notificationCenter.pendingRemovalCount, 1)
        XCTAssertEqual(notificationCenter.deliveredRemovalCount, 1)
        XCTAssertTrue(monitoringCenter.startedActivities.isEmpty)
        XCTAssertTrue(monitoringCenter.stoppedActivities.isEmpty)
    }
}

#if DEBUG
private struct ReflectionSnapshotHost: View {
    let model: AppModel
    let statsService: StatsService
    let engine: InterventionEngine
    let reflection: ReflectionLog

    @State private var isReflectionPresented = true

    var body: some View {
        StatsView(model: model, statsService: statsService)
            .sheet(isPresented: $isReflectionPresented) {
                PostUseReflectionSheet(
                    model: model,
                    engine: engine,
                    reflection: reflection,
                    onFinished: {}
                )
            }
    }
}
#endif
