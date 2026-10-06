import DopaBreakCore
import Foundation
import SwiftUI
import UIKit
import Vision
import XCTest
@testable import DopaBreak

final class MeasurementFoundationTests: XCTestCase {
    func testSummaryCTANeverShowsTheTrialPrice() {
        // 無料トライアル（◯日間 ¥0）はペイウォールだけで伝える。まとめ画面のボタンは選択に関係なく同じ（2026-09-27 オーナー指示）。
        let title = OnboardingSummaryPresentation.actionTitle
        XCTAssertFalse(title.isEmpty)
        for priceMark in ["0", "¥", "$", "₩"] {
            XCTAssertFalse(title.contains(priceMark), title)
        }
    }

    func testSummaryPlanReviewFollowsTheTwoWayChoice() {
        // 無料を選んだ人にもペイウォールを1回出す（閉じれば無料で続く）
        XCTAssertTrue(OnboardingSummaryPresentation.needsPlanReview(mode: .standard, isPro: false))
        XCTAssertTrue(OnboardingSummaryPresentation.needsPlanReview(mode: .deepFocus, isPro: false))
        XCTAssertFalse(OnboardingSummaryPresentation.needsPlanReview(mode: .deepFocus, isPro: true))
        XCTAssertTrue(OnboardingSummaryPresentation.needsPlanReview(mode: .standard, isPro: false, hasPendingProTheme: true))
    }

    func testSummaryGoalsPreserveOrderLimitAndUncommittedInput() {
        let titles = ["毎日運動する", "英語を勉強する", "本を読む", "早く寝る", "貯金する", "料理する"]
        let drafts = titles.map { OnboardingGoalDraft(id: UUID(), persistedID: nil, title: $0) }
        for count in 0...6 {
            let summary = OnboardingSummaryPresentation(drafts: Array(drafts.prefix(count)), typedGoal: "")
            XCTAssertEqual(summary.titles, Array(titles.prefix(min(count, 5))))
            XCTAssertEqual(summary.additionalCount, max(0, count - 5))
        }
        let typed = OnboardingSummaryPresentation(drafts: Array(drafts.prefix(4)), typedGoal: "  貯金する  ")
        XCTAssertEqual(typed.titles, Array(titles.prefix(5)))
        XCTAssertEqual(OnboardingSummaryPresentation(drafts: [], typedGoal: " 本を読む ").titles, ["本を読む"])
        XCTAssertEqual(OnboardingSummaryPresentation(drafts: drafts, typedGoal: "旅行する").additionalCount, 2)
        XCTAssertEqual(OnboardingSummaryPresentation(drafts: drafts, typedGoal: "本を読む").additionalCount, 1)
    }

    @MainActor
    func testSummaryModeNoticeIsOnceOnlyAndPreservesPreference() throws {
        for mode in InterventionMode.selectable {
            for isPro in [false, true] {
                let fixture = try makeThemeSelectionFixture(isPro: isPro)
                defer { fixture.cleanUp() }
                let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .prePaywallSummary)
                progress.saveModePreference(mode)
                progress.summaryPaywallDismissed(isPro: isPro, mode: mode)
                XCTAssertEqual(fixture.settingsStore.onboardingPendingModeNotice, !isPro && mode.usesShield ? mode.rawValue : nil)
                // Recreate after dismissal, before ready, to exercise persistent delivery.
                let resumed = OnboardingProgress(settings: fixture.settingsStore, initialStep: .ready)
                resumed.presentReadyModeNotice(isPro: isPro)
                XCTAssertEqual(resumed.readyModeNotice, !isPro && mode.usesShield ? mode : nil)
                resumed.presentReadyModeNotice(isPro: isPro)
                XCTAssertEqual(resumed.readyModeNotice, !isPro && mode.usesShield ? mode : nil)
                resumed.step = .prePaywallSummary
                resumed.summaryPaywallDismissed(isPro: isPro, mode: mode)
                resumed.step = .ready
                resumed.presentReadyModeNotice(isPro: isPro)
                XCTAssertNil(resumed.readyModeNotice)
                XCTAssertEqual(fixture.settingsStore.blockTriggers.isEmpty, mode == .standard)
                XCTAssertEqual(OnboardingSummaryPresentation.modeTitle(mode, isPro: isPro).contains("Pro"), !isPro && mode.usesShield)
                let recreated = OnboardingProgress(settings: fixture.settingsStore, initialStep: .ready)
                recreated.presentReadyModeNotice(isPro: isPro)
                XCTAssertNil(recreated.readyModeNotice)
            }
        }
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .chooseApps)
        progress.summaryPaywallDismissed(isPro: false, mode: .deepFocus)
        XCTAssertNil(fixture.settingsStore.onboardingPendingModeNotice, "Other paywalls do not trigger the notice")
        progress.step = .prePaywallSummary
        progress.summaryPaywallDismissed(isPro: false, mode: .deepFocus)
        progress.step = .ready
        progress.presentReadyModeNotice(isPro: true)
        XCTAssertNil(progress.readyModeNotice, "A purchase before ready cancels the pending explanation")
        XCTAssertNil(fixture.settingsStore.onboardingPendingModeNotice)
    }

    @MainActor
    func testPurchaseAfterReadyNoticeRestoresDeepFocus() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        try fixture.model.targetStore.setTargets(["safari"])
        let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .prePaywallSummary)
        progress.saveModePreference(.deepFocus)
        try fixture.model.applyBlockPreference(true)
        let savedRules = try fixture.model.ruleStore.allRules()
        XCTAssertFalse(savedRules.isEmpty)
        progress.summaryPaywallDismissed(isPro: false, mode: .deepFocus)
        progress.step = .ready
        progress.presentReadyModeNotice(isPro: false)
        XCTAssertEqual(progress.readyModeNotice, .deepFocus)
        XCTAssertEqual(InterventionModeResolver.resolve(
            OnboardingProgress.preferredMode(from: fixture.settingsStore),
            hasConfirmedEntitlement: true,
            strictModeAllowed: fixture.model.entitlementGate.strictModeAllowed), .standard)

        // Model the persisted entitlement produced by a successful purchase, then relaunch.
        // This exercises the real StoreService, EntitlementGate, saved rules and resolver
        // without relying on the simulator's StoreKit transaction service.
        fixture.settingsStore.entitlementCachedIsPro = true
        let purchasedModel = AppModel(containerProvider: TemporaryContainer(url: fixture.containerURL),
                                      settingsStore: fixture.settingsStore,
                                      automaticallyRefreshEntitlement: false,
                                      scheduleNotificationsOnInit: false)
        XCTAssertTrue(purchasedModel.storeService.isPro)
        XCTAssertTrue(purchasedModel.entitlementGate.strictModeAllowed)
        for confirmed in [false, true] {
            XCTAssertEqual(InterventionModeResolver.resolve(
                OnboardingProgress.preferredMode(from: fixture.settingsStore),
                hasConfirmedEntitlement: confirmed,
                strictModeAllowed: purchasedModel.entitlementGate.strictModeAllowed), .deepFocus)
        }
        XCTAssertEqual(fixture.settingsStore.blockTriggers, Set(BlockTrigger.allCases))
        XCTAssertEqual(try purchasedModel.ruleStore.allRules(), savedRules)
        XCTAssertTrue(savedRules.allSatisfy { $0.mode == .standard })
        progress.presentReadyModeNotice(isPro: purchasedModel.storeService.isPro)
        XCTAssertNil(progress.readyModeNotice)
        let resumed = OnboardingProgress(settings: fixture.settingsStore, initialStep: .ready)
        resumed.presentReadyModeNotice(isPro: purchasedModel.storeService.isPro)
        XCTAssertNil(resumed.readyModeNotice)
    }

    func testSummaryDisplayCopyInAllLanguages() throws {
        for (language, label, value) in [("ja", "1年でSNSに使う時間", "約38日"),
                                        ("en", "SNS time per year", "About 38 days"),
                                        ("ko", "1년간 SNS에 쓰는 시간", "약 38일")] {
            let bundle = try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))))
            let actual = bundle.localizedString(forKey: "onboarding.summary.time", value: nil, table: nil)
            XCTAssertEqual(actual, label)
            XCTAssertEqual(String(format: bundle.localizedString(forKey: "onboarding.summary.yearly_days", value: nil, table: nil), 38), value)
            XCTAssertFalse(actual.contains("\n"))
            XCTAssertLessThanOrEqual((actual as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 15, weight: .bold)]).width, 295)
        }
    }

    @MainActor
    func testSummaryAndReadyJapaneseCapture() async throws {
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        let titles = ["毎日運動する", "英語を勉強する", "本を読む", "早く寝る", "貯金する", "料理する"]
        for title in titles { XCTAssertTrue(fixture.model.addGoal(title: title, category: .other, lockScreenTitle: nil)) }
        let expected = Array(fixture.model.lockScreenDisplayTitles.prefix(5))
        XCTAssertEqual(OnboardingSummaryPresentation(drafts: OnboardingGoalList.restore(from: fixture.model.goals), typedGoal: "").titles, expected)
        // Recreate the model as Free while retaining the same on-device goals.
        fixture.settingsStore.entitlementCachedIsPro = false
        let model = AppModel(containerProvider: TemporaryContainer(url: fixture.containerURL), settingsStore: fixture.settingsStore,
                             automaticallyRefreshEntitlement: false, scheduleNotificationsOnInit: false)
        try model.targetStore.setTargets(["safari"])
        fixture.settingsStore.setAutomationConfirmed(catalogID: "safari", confirmed: true)
        fixture.settingsStore.selectBlockPreference(true)
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let output = URL(fileURLWithPath: "/tmp/dopabreak-summary-2026-09-21", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        defer { window.isHidden = true; window.rootViewController = nil }
        for step in [OnboardingStep.prePaywallSummary, .ready, .chooseMode] {
            if step == .ready {
                let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .prePaywallSummary)
                progress.summaryPaywallDismissed(isPro: false, mode: .deepFocus)
            }
            let host = UIHostingController(rootView:
                OnboardingFlow(model: model, settingsStore: fixture.settingsStore, initialStep: step, onComplete: {})
                    .environment(\.locale, Locale(identifier: "ja"))
                    .environment(\.dynamicTypeSize, .large).preferredColorScheme(.dark))
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(1600))
            render(host)
            let scroll = try XCTUnwrap(findScrollView(in: host.view))
            var allText = ""
            var offset: CGFloat = 0
            var index = 0
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            while true {
                scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                render(host)
                try await Task.sleep(for: .milliseconds(150))
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                XCTAssertEqual(image.size, CGSize(width: 375, height: 812))
                try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("\(step.identifier)-\(index).png"))
                allText += try recognizeJapaneseText(in: XCTUnwrap(image.cgImage)).joined().filter { !$0.isWhitespace }
                if offset >= bottom { break }
                offset = min(bottom, offset + scroll.bounds.height / 2)
                index += 1
            }
            if step == .prePaywallSummary {
                for text in expected + ["ほか1件", "1年でSNSに使う時間", "約38日", "止め方", "一呼吸＋完全ブロック"] {
                    XCTAssertTrue(allText.contains(text), "Missing \(text): \(allText)")
                }
                XCTAssertTrue(allText.contains("Pro"))
            } else if step == .ready {
                for text in ["いまは一呼吸で始めます", "ブロックはProで使えます", "設定でいつでも変えられます"] {
                    XCTAssertTrue(allText.contains(text), "Missing \(text): \(allText)")
                }
            } else {
                XCTAssertTrue(allText.contains("おすすめ"), allText)
                XCTAssertEqual(allText.components(separatedBy: "Pro").count - 1, 1, allText)
            }
        }
    }


    @MainActor
    func testGoalFieldClearsAfterReturn() async throws {
        try await verifyGoalFieldCommit(marked: false)
    }

    @MainActor
    func testGoalFieldClearsLeftoverMarkedTextAfterReturn() async throws {
        try await verifyGoalFieldCommit(marked: true)
    }

    @MainActor
    func testGoalFieldKeepsInputAndLatestOfFourGoalsVisible() async throws {
        try await verifyGoalFieldCommit(marked: false, existingDraftCount: 3)
    }

    /// Exercise the actual SwiftUI/UIKit field, including a still-active IME composition.
    @MainActor
    private func verifyGoalFieldCommit(marked: Bool, existingDraftCount: Int = 0) async throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        defer { window.isHidden = true; window.rootViewController = nil }
        let host = UIHostingController(rootView:
            OnboardingFlow(model: fixture.model, settingsStore: fixture.settingsStore,
                           initialStep: .goalSetup, onComplete: {})
                .environment(\.locale, Locale(identifier: "ja"))
                .preferredColorScheme(.dark))
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(350))
        func fields(_ view: UIView) -> [UITextField] {
            (view as? UITextField).map { [$0] } ?? view.subviews.flatMap { fields($0) }
        }
        for index in 0..<existingDraftCount {
            let field = try XCTUnwrap(fields(host.view).first)
            XCTAssertTrue(field.becomeFirstResponder())
            try await Task.sleep(for: .milliseconds(250))
            field.insertText("目標\(index + 1)")
            try await Task.sleep(for: .milliseconds(150))
            field.sendActions(for: .editingDidEndOnExit)
            try await Task.sleep(for: .milliseconds(550))
            XCTAssertEqual(fields(host.view).first?.text, "")
        }
        let original = try XCTUnwrap(fields(host.view).first)
        XCTAssertTrue(original.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(250))
        original.insertText("毎朝本を読む")
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(original.text, "毎朝本を読む")
        if marked {
            // Leave a composition after committed text. Replacing the whole selection can
            // legitimately make the binding empty before UIKit inserts the marked text.
            original.selectedTextRange = original.textRange(from: original.endOfDocument, to: original.endOfDocument)
            original.setMarkedText("習慣", selectedRange: NSRange(location: 2, length: 0))
            XCTAssertNotNil(original.markedTextRange)
            XCTAssertEqual(original.text, "毎朝本を読む習慣")
        }
        original.sendActions(for: .editingDidEndOnExit)
        try await Task.sleep(for: .milliseconds(550))
        render(host)
        let current = try XCTUnwrap(fields(host.view).first)
        let output = URL(fileURLWithPath: "/tmp/dopabreak-goal-field", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let captureName = existingDraftCount > 0 ? "four-goals" : marked ? "marked" : "return"
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(captureName + ".png"))
        XCTAssertFalse(current === original, "Discard the UIKit field holding IME composition")
        XCTAssertEqual(current.text, "")
        XCTAssertNil(current.markedTextRange)
        XCTAssertTrue(current.isFirstResponder, "Continue entering the next goal without another tap")
        let focusedOCR = VNRecognizeTextRequest()
        focusedOCR.recognitionLevel = .accurate
        focusedOCR.recognitionLanguages = ["ja-JP"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([focusedOCR])
        XCTAssertTrue((focusedOCR.results ?? []).contains {
            $0.topCandidates(1).first?.string.contains("毎朝本を読む") == true
        }, "The newly added row must remain visible while the field is focused")
        current.resignFirstResponder()
        try await Task.sleep(for: .milliseconds(350))
        // Return to the top to compare the actual rendered vertical order without keyboard occlusion.
        func scrolls(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrolls($0) }
        }
        scrolls(host.view).first?.setContentOffset(.zero, animated: false)
        render(host)
        let layoutImage = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(layoutImage.pngData()).write(to: output.appendingPathComponent(captureName + "-layout.png"))
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(layoutImage.cgImage)).perform([request])
        let results = request.results ?? []
        // 入力前の「0/16」は意味が伝わらないため、上限が近いときだけ出す（2026-09-21 オーナー指摘）
        XCTAssertFalse(results.contains { $0.topCandidates(1).first?.string == "0/16" })
        // 汎用の例文ボタンは撤去済み（2026-09-21 オーナー指示）
        XCTAssertFalse(results.contains {
            guard let text = $0.topCandidates(1).first?.string else { return false }
            return text.contains("英語で話せるようになる") && !text.contains("例")
        }, "Preset goal buttons must not return")
        let row = try XCTUnwrap(results.first { $0.topCandidates(1).first?.string.contains("毎朝本を読む") == true })
        let preview = try XCTUnwrap(results.first {
            $0.topCandidates(1).first?.string.contains("ロック画面の見え方") == true
        })
        let rowY = (1 - row.boundingBox.midY) * 812
        let previewY = (1 - preview.boundingBox.midY) * 812
        XCTAssertLessThan(current.convert(current.bounds, to: window).maxY, rowY)
        XCTAssertLessThan(rowY, previewY, "Input → added goals → lock screen preview")
        XCTAssertTrue(fixture.model.goals.isEmpty, "Editing drafts must not persist goals")
    }

    func testOnboardingStepIdentifiersAreStableAndCoverAllElevenSteps() {
        XCTAssertEqual(OnboardingStep.allCases.map(\.analyticsIdentifier), OnboardingStep.allCases.map(\.identifier))
        XCTAssertEqual(
            OnboardingStep.allCases.map(\.identifier),
            [
                "self_check",
                "scroll_regret",
                "loss_recovery",
                "goal_setup",
                "choose_apps",
                "choose_mode",
                "experience",
                "notification_guide",
                "pre_paywall_summary",
                "permission",
                "block_setup",
                "ready"
            ]
        )
    }

    /// Real SwiftUI screens, isolated stores and fixed point-sized windows. No purchases or authorization prompts.
    @MainActor
    func testOnboardingLinebreakCapture() async throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        try fixture.model.targetStore.setTargets(["safari"])
        fixture.settingsStore.onboardingQuizAnswers = ["usage": "2〜4時間", "aimless": "数日", "regret": "数日"]
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let language = Locale.current.language.languageCode?.identifier ?? "ja"
        let output = URL(fileURLWithPath: "/tmp/dopabreak-linebreaks/" + language, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var observations: [String: [[String: Any]]] = [:]
        for size in [CGSize(width: 375, height: 812), CGSize(width: 430, height: 932)] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            defer { window.isHidden = true; window.rootViewController = nil }
            for step in OnboardingStep.allCases {
                let view = OnboardingFlow(model: fixture.model, settingsStore: fixture.settingsStore,
                                          initialStep: step, onComplete: {})
                    .environment(\.locale, Locale(identifier: language))
                    .environment(\.dynamicTypeSize, .large)
                    .preferredColorScheme(.dark)
                let host = UIHostingController(rootView: view)
                window.rootViewController = host
                window.makeKeyAndVisible()
                render(host)
                try await Task.sleep(for: .milliseconds(1800))
                render(host)
                func capture(_ suffix: String) throws {
                    let name = "\(Int(size.width))x\(Int(size.height))-\(step.identifier)" + suffix
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    XCTAssertEqual(image.size, size)
                    try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(name + ".png"))
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = [language == "ja" ? "ja-JP" : language == "ko" ? "ko-KR" : "en-US"]
                    try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
                    observations[name] = (request.results ?? []).compactMap { item in
                        guard let text = item.topCandidates(1).first?.string else { return nil }
                        return ["text": text, "x": item.boundingBox.minX, "y": item.boundingBox.minY,
                                "width": item.boundingBox.width, "height": item.boundingBox.height]
                    }
                }
                try capture("")
                func scrolls(_ view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrolls($0) }
                }
                if let scroll = scrolls(host.view).first,
                   scroll.contentSize.height > scroll.bounds.height {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    render(host)
                    try await Task.sleep(for: .milliseconds(200))
                    try capture("-bottom")
                }
            }
        }
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("ocr.json"))
        XCTAssertFalse(fixture.model.storeService.isPro)
        XCTAssertTrue(try fixture.model.ruleStore.allRules().isEmpty)
    }

    @MainActor
    func testV3OnboardingScreensRenderAtCompactSize() async throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        try fixture.model.targetStore.setTargets(["safari"])
        fixture.settingsStore.onboardingQuizAnswers = ["usage": "2〜4時間", "aimless": "数日", "regret": "数日"]
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        defer { window.isHidden = true; window.rootViewController = nil }
        let output = URL(fileURLWithPath: "/tmp/dopabreak-v3-screens", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var screens: [(String, AnyView)] = [OnboardingStep.goalSetup, .scrollRegret, .lossRecovery, .chooseMode, .prePaywallSummary].map { step in
            (step.identifier, AnyView(OnboardingFlow(model: fixture.model, settingsStore: fixture.settingsStore,
                                                     initialStep: step, onComplete: {})))
        }
        screens.append(("mechanism", AnyView(NavigationStack { SettingsMechanismView() })))
        for (name, view) in screens {
            let host = UIHostingController(rootView: view.preferredColorScheme(.dark))
            window.rootViewController = host
            window.makeKeyAndVisible()
            render(host)
            try await Task.sleep(for: .milliseconds(1600))
            render(host)
            let image = renderedImage(in: window)
            XCTAssertTrue(CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: try XCTUnwrap(image.cgImage)))
            if name == "goal_setup" {
                let text = try recognizeJapaneseText(in: XCTUnwrap(image.cgImage)).joined()
                    .filter { !$0.isWhitespace && $0 != "\u{200B}" }
                XCTAssertTrue(text.contains("取り戻す38日で何をする"), text)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "v3-" + name
            attachment.lifetime = .keepAlways
            add(attachment)
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(name + ".png"))
            if name == "loss_recovery" {
                func scrollViews(in view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
                }
                let scrolls = scrollViews(in: host.view)
                XCTAssertEqual(scrolls.count, 1)
                let scroll = try XCTUnwrap(scrolls.first)
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                render(host)
                try await Task.sleep(for: .milliseconds(200))
                try XCTUnwrap(renderedImage(in: window).pngData()).write(to: output.appendingPathComponent("loss-recovery-bottom.png"))
            }
        }
        // Presenting the recommended mode must not purchase, apply rules, or lose the selected step.
        XCTAssertFalse(fixture.model.storeService.isPro)
        XCTAssertTrue(try fixture.model.ruleStore.allRules().isEmpty)
    }

    @MainActor
    func testBreathingGoalsAtAccessibility5RemainReachable() throws {
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        let titles = [
            "毎日運動して健康な体で家族と楽しい時間を過ごす",
            "英語を勉強して海外の友人と自信を持って会話する",
            "本を読んで新しい知識を身につけ仕事に活かす",
            "早く寝る習慣を続けて毎朝すっきりした気分で起きる",
            "貯金を続けて大切な家族と一緒に海外旅行へ行く"
        ]
        for title in titles {
            XCTAssertTrue(fixture.model.addGoal(title: title, category: .other, lockScreenTitle: nil))
        }
        for size in [CGSize(width: 375, height: 667), CGSize(width: 440, height: 956)] {
            let flow = InterventionFlowModel(
                target: try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari")),
                model: fixture.model, settingsStore: fixture.settingsStore
            )
            let host = UIHostingController(rootView: InterventionFlowView(
                snapshotFlow: flow, model: fixture.model, settingsStore: fixture.settingsStore,
                breathPreviewLoop: 0..<0, onFinished: {}
            ).environment(\.dynamicTypeSize, .accessibility5))
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { flow.stop(); window.isHidden = true; window.rootViewController = nil }
            render(host)
            flow.stop() // Freeze the countdown while inspecting every scroll position.
            XCTAssertEqual(window.bounds.size, size)
            let scroll = try XCTUnwrap(findScrollView(in: host.view))
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            var capturedText = ""
            var offset: CGFloat = -scroll.adjustedContentInset.top
            var index = 0
            while true {
                scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                render(host)
                let image = renderedImage(in: window)
                let attachment = XCTAttachment(image: image)
                attachment.name = "breathing-accessibility5-\(Int(size.width))-\(index)"
                attachment.lifetime = .keepAlways
                add(attachment)
                capturedText += try recognizeJapaneseText(in: XCTUnwrap(image.cgImage))
                    .joined().filter { !$0.isWhitespace }
                if offset >= bottom { break }
                offset = min(bottom, offset + scroll.bounds.height / 3)
                index += 1
            }
            // 「まずはひと呼吸」の見出しは撤去済み（オーナー指示 2026-09-21）
            for text in [
                String(localized: "intervention.breath.goals_title", defaultValue: "目標を思い出しましょう")
            ] + titles {
                XCTAssertTrue(capturedText.contains(text.filter { !$0.isWhitespace }), text)
            }
            XCTAssertEqual(scroll.contentOffset.y, bottom, accuracy: 1)
            XCTAssertEqual(flow.stage, .breathing)
        }
    }

    @MainActor
    func testBreathingGoalsSnapshotWithAndWithoutGoals() throws {
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let titles = ["毎日運動する", "英語を勉強する", "本を読む", "早く寝る", "貯金する"]
        let heading = String(localized: "intervention.breath.goals_title", defaultValue: "目標を思い出しましょう")
        for count in [0, 5] {
            let fixture = try makeThemeSelectionFixture(isPro: true)
            defer { fixture.cleanUp() }
            for title in titles.prefix(count) {
                XCTAssertTrue(fixture.model.addGoal(title: title, category: .other, lockScreenTitle: nil))
            }
            XCTAssertEqual(fixture.model.goals.count, count)
            for size in [CGSize(width: 375, height: 667), CGSize(width: 440, height: 956)] {
                let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
                let flow = InterventionFlowModel(target: target, model: fixture.model, settingsStore: fixture.settingsStore)
                let host = UIHostingController(rootView: InterventionFlowView(
                    snapshotFlow: flow, model: fixture.model, settingsStore: fixture.settingsStore,
                    breathPreviewLoop: 0..<0, onFinished: {}
                ))
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                window.rootViewController = host
                window.makeKeyAndVisible()
                defer { flow.stop(); window.isHidden = true; window.rootViewController = nil }
                render(host)
                let image = renderedImage(in: window)
                let attachment = XCTAttachment(image: image)
                attachment.name = "breathing-goals-\(count)-\(Int(size.width))"
                attachment.lifetime = .keepAlways
                add(attachment)
                try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(attachment.name! + ".png"))
                flow.stop()
                var text = try recognizeJapaneseText(in: XCTUnwrap(image.cgImage))
                    .joined().filter { !$0.isWhitespace }
                let scroll = try XCTUnwrap(findScrollView(in: host.view))
                scroll.setContentOffset(CGPoint(
                    x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                ), animated: false)
                render(host)
                let bottomImage = renderedImage(in: window)
                let bottomAttachment = XCTAttachment(image: bottomImage)
                bottomAttachment.name = "breathing-goals-\(count)-\(Int(size.width))-bottom"
                bottomAttachment.lifetime = .keepAlways
                add(bottomAttachment)
                text += try recognizeJapaneseText(in: XCTUnwrap(bottomImage.cgImage))
                    .joined().filter { !$0.isWhitespace }
                XCTAssertFalse(text.isEmpty, "Snapshot must contain rendered text")
                XCTAssertEqual(text.contains(heading.filter { !$0.isWhitespace }), count > 0, text)
                for title in titles {
                    XCTAssertEqual(text.contains(title), count > 0, text)
                }
                XCTAssertFalse(text.contains("開く目的を決める"))
                XCTAssertEqual(flow.stage, .breathing)
            }
        }
    }

    /// オーガニック動画の絵コンテ用に、実際の一呼吸画面を撮る（言語は -testLanguage で切り替える）。
    @MainActor
    func testCaptureBreathingScreenForOrganicVideo() throws {
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        let language = Locale.current.language.languageCode?.identifier ?? "ja"
        for goal in Self.organicVideoGoals(language) {
            XCTAssertTrue(fixture.model.addGoal(title: goal, category: .other, lockScreenTitle: nil))
        }
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let flow = InterventionFlowModel(target: target, model: fixture.model, settingsStore: fixture.settingsStore)
        let host = UIHostingController(rootView: InterventionFlowView(
            snapshotFlow: flow, model: fixture.model, settingsStore: fixture.settingsStore,
            breathPreviewLoop: 0..<0, onFinished: {}
        ).preferredColorScheme(.dark))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { flow.stop(); window.isHidden = true; window.rootViewController = nil }
        render(host)
        let image = renderedImage(in: window)
        let output = URL(fileURLWithPath: "/tmp/dopabreak-organic", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("breath-\(language).png"))
        XCTAssertEqual(flow.stage, .breathing)
    }

    /// 動画の絵コンテで画面に出す人生の目標（夢・人・仕事）。
    static func organicVideoGoals(_ language: String) -> [String] {
        language == "ja"
            ? ["1年スペインで暮らす", "大切な人との時間をちゃんと過ごす", "自分の事業を始める"]
            : ["Live in Spain for a year", "Be present with the people I love", "Start my own business"]
    }

    /// 一呼吸画面を本番と同じ動き（呼吸アニメーション・カウントダウン）のまま表示し続ける。
    /// 表示中に外部から `xcrun simctl io <UDID> recordVideo` で録画する。
    /// マーカー `ORG_BREATH_BEGIN <epoch>` を待ってから切り出すこと。
    @MainActor
    func testHoldBreathingScreenForOrganicVideo() async throws {
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        let language = Locale.current.language.languageCode?.identifier ?? "ja"
        for goal in Self.organicVideoGoals(language) {
            XCTAssertTrue(fixture.model.addGoal(title: goal, category: .other, lockScreenTitle: nil))
        }
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let window = try XCTUnwrap(activeKeyWindow())
        let originalRoot = window.rootViewController
        defer { window.rootViewController = originalRoot }
        let host = UIHostingController(rootView: InterventionFlowView(
            snapshotTarget: target, model: fixture.model, settingsStore: fixture.settingsStore,
            selectedReason: nil, onFinished: {}
        ).preferredColorScheme(.dark))
        window.rootViewController = host
        window.makeKeyAndVisible()
        print("ORG_BREATH_BEGIN \(Date().timeIntervalSince1970)")
        try await Task.sleep(for: .seconds(8))
        print("ORG_BREATH_END \(Date().timeIntervalSince1970)")
    }

    @MainActor
    func testDeferringBlockSetupRetainsBothShieldModesAndProEntitlement() throws {
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        try fixture.model.targetStore.setTargets(["safari"])
        for mode in [InterventionMode.deepFocus, .nightOnly] {
            try fixture.model.applyInterventionMode(mode)
            fixture.settingsStore.pendingInterventionMode = mode.rawValue
            let rules = try fixture.model.ruleStore.allRules()
            XCTAssertFalse(rules.isEmpty)
            XCTAssertTrue(rules.allSatisfy { $0.mode == mode })
            let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .blockSetup)
            progress.deferBlockSetup()
            XCTAssertEqual(progress.step, .ready)
            XCTAssertFalse(fixture.model.isBlockConfigured)
            let currentMode = InterventionModeResolver.resolve(
                try XCTUnwrap(fixture.settingsStore.pendingInterventionMode.flatMap(InterventionMode.init(rawValue:))),
                hasConfirmedEntitlement: fixture.model.storeService.hasConfirmedEntitlement,
                strictModeAllowed: fixture.model.entitlementGate.strictModeAllowed
            )
            XCTAssertTrue(currentMode.usesShield && !fixture.model.isBlockConfigured)
            XCTAssertEqual(fixture.settingsStore.pendingInterventionMode, mode.rawValue)
            XCTAssertEqual(try fixture.model.ruleStore.allRules(), rules)
            XCTAssertTrue(fixture.model.storeService.isPro)
            XCTAssertTrue(fixture.model.entitlementGate.strictModeAllowed)
        }
    }

    @MainActor
    func testOnboardingRestoresStepAndCompletionClearsProgress() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        fixture.settingsStore.selectBlockPreference(true)
        let progress = OnboardingProgress(settings: fixture.settingsStore)
        for step in OnboardingStep.allCases {
            progress.step = step
            let restored = OnboardingProgress(settings: fixture.settingsStore)
            XCTAssertEqual(restored.step, step)
        }
        // 不明な保存値と完了後（やり直し）は、先頭のSNS時間の質問から始める
        fixture.settingsStore.onboardingStepRaw = 999
        XCTAssertEqual(OnboardingProgress(settings: fixture.settingsStore).step, .selfCheck)
        fixture.settingsStore.onboardingCompleted = true
        XCTAssertNil(fixture.settingsStore.onboardingStepRaw)
        XCTAssertEqual(OnboardingProgress(settings: fixture.settingsStore).step, .selfCheck)
    }

    @MainActor
    func testOnboardingExperienceRunsOnceAndContinuesAfterWin() throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }
        try context.model.targetStore.setTargets(["safari"])
        context.settingsStore.pendingStartInterventionCatalogID = "safari"
        context.settingsStore.pendingStartInterventionRequestedAt = context.model.currentDate
        XCTAssertEqual(context.model.consumeAutomationVerificationOnly(from: context.settingsStore), "safari")
        let target = try XCTUnwrap(context.model.takeOnboardingExperience(from: context.settingsStore))
        XCTAssertNil(context.model.takeOnboardingExperience(from: context.settingsStore))
        let flow = InterventionFlowModel(target: .catalog(target), model: context.model,
                                         settingsStore: context.settingsStore, isOnboardingExperience: true,
                                         openURL: { _, _ in XCTFail("Experience must not open another app") })
        defer { flow.stop() }
        flow.start()
        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .reasonSelection)
        flow.selectReason(.work)
        XCTAssertEqual(flow.stage, .durationSelection)
        flow.chooseDuration(.fiveMinutes)
        flow.confirmSelectedDuration()
        XCTAssertEqual(flow.stage, .win)
        XCTAssertNil(flow.reviewPromptRequestDateIfEligible())
        let progress = OnboardingProgress(settings: context.settingsStore, initialStep: .experience)
        progress.completeExperience()
        context.model.finishOnboardingExperience()
        XCTAssertEqual(progress.step, .notificationGuide)
        XCTAssertEqual(OnboardingProgress(settings: context.settingsStore).step, .notificationGuide)
        context.model.pendingOnboardingExperienceCatalogID = "safari"
        XCTAssertNil(context.model.takeOnboardingExperience(from: context.settingsStore))
    }

    @MainActor
    func testCaptureASABreathingScreens() async throws {
        let window = try XCTUnwrap(activeKeyWindow())
        XCTAssertEqual(window.bounds.size, CGSize(width: 440, height: 956))
        let original = window.rootViewController
        defer { window.rootViewController = original; window.makeKeyAndVisible() }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/verify/asa-fix-2026-09-20")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let language = Locale.preferredLanguages.first ?? "en"
        let locale = language.hasPrefix("ja") ? "ja" : (language.hasPrefix("ko") ? "ko" : "en")
        let japanese = locale == "ja"
        // ロック画面・テーマ一覧のスクショと同じ目標（scripts/generate-appstore-screenshots-v2.py の LOCK_GOALS）。
        // 同じ利用者の画面として枚をまたいで目標を揃える。
        let titles = [
            "ja": ["1000万円貯める", "12月までにTOEIC800点を取る", "毎朝30分歩く", "今日は0時までに寝る"],
            "en": ["More time with family and friends", "Save $10,000 by December",
                   "Hit the gym three times a week", "In bed by 11 tonight"],
            "ko": ["종잣돈 1억 모으기", "12월까지 토익 900점 넘기기", "아침에 30분 걷기", "오늘은 12시 전에 자기"]
        ][locale]!
        for count in (japanese ? [titles.count, 0] : [titles.count]) {
            let fixture = try makeThemeSelectionFixture(isPro: true)
            defer { fixture.cleanUp() }
            for title in titles.prefix(count) {
                XCTAssertTrue(fixture.model.addGoal(title: title, category: .other, lockScreenTitle: nil))
            }
            XCTAssertEqual(fixture.model.goals.count, count)
            let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
            let flow = InterventionFlowModel(target: target, model: fixture.model, settingsStore: fixture.settingsStore)
            defer { flow.stop() }
            let host = UIHostingController(rootView: InterventionFlowView(
                snapshotFlow: flow, model: fixture.model, settingsStore: fixture.settingsStore,
                breathPreviewLoop: (Double(flow.breathTotalSeconds) / 2)..<(Double(flow.breathTotalSeconds) / 2), onFinished: {}
            ).preferredColorScheme(.dark))
            window.rootViewController = host
            window.makeKeyAndVisible()
            render(host)
            try await Task.sleep(for: .milliseconds(500))
            render(host)
            XCTAssertEqual(flow.stage, .breathing)
            let image = renderedImage(in: window)
            XCTAssertTrue(CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: try XCTUnwrap(image.cgImage)))
            let name = "breathing-\(count == 0 ? "no-goals" : "goals")-\(locale)"
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(name + ".png"))
            if japanese {
                let text = try recognizeJapaneseText(in: XCTUnwrap(image.cgImage)).joined().filter { !$0.isWhitespace }
                XCTAssertEqual(text.contains("目標を思い出しましょう"), count > 0, text)
            }
        }
    }

    @MainActor
    func testCaptureASAFixScreens() async throws {
        let fixture = try makeThemeSelectionFixture(isPro: true)
        defer { fixture.cleanUp() }
        let window = try XCTUnwrap(activeKeyWindow())
        let original = window.rootViewController
        defer { window.rootViewController = original; window.makeKeyAndVisible() }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/verify/asa-fix-2026-09-20")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        func capture(_ view: AnyView, name: String) async throws {
            let host = UIHostingController(rootView: view.preferredColorScheme(.dark))
            window.rootViewController = host
            window.makeKeyAndVisible()
            render(host)
            try await Task.sleep(for: .milliseconds(500))
            render(host)
            let image = renderedImage(in: window)
            XCTAssertTrue(CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: try XCTUnwrap(image.cgImage)))
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(name + ".png"))
            if name == "paywall-load-failed" {
                func firstScrollView(in view: UIView) -> UIScrollView? {
                    if let scroll = view as? UIScrollView { return scroll }
                    return view.subviews.lazy.compactMap { firstScrollView(in: $0) }.first
                }
                let scroll = try XCTUnwrap(firstScrollView(in: host.view))
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                render(host)
                try await Task.sleep(for: .milliseconds(200))
                try XCTUnwrap(renderedImage(in: window).pngData()).write(to: output.appendingPathComponent("paywall-load-failed-prices.png"))
            }
        }

        try fixture.model.targetStore.setTargets(["safari"])
        fixture.settingsStore.selectBlockPreference(true)
        try fixture.model.applyInterventionMode(.deepFocus)
        try await capture(AnyView(HomeView(model: fixture.model, settingsStore: fixture.settingsStore)), name: "home-block-setup")

        let freeSuite = "ASAVisualFree.\(UUID().uuidString)"
        let freeDefaults = try XCTUnwrap(UserDefaults(suiteName: freeSuite))
        defer { freeDefaults.removePersistentDomain(forName: freeSuite) }
        let store = StoreService(funnelEventStore: fixture.model.funnelEventStore,
                                 settingsStore: SettingsStore(userDefaults: freeDefaults),
                                 startsBackgroundTasks: false, productLoader: { throw URLError(.notConnectedToInternet) })
        try await capture(AnyView(PaywallView(storeService: store, placement: .onboardingPrepaywallSummary,
                                            snapshotStore: JSONSnapshotStore(containerProvider: TemporaryContainer(url: fixture.containerURL)),
                                            settingsStore: fixture.settingsStore)), name: "paywall-load-failed")
        XCTAssertEqual(store.productLoadingState, .failed)

        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
        let flow = InterventionFlowModel(target: .catalog(target), model: fixture.model,
                                         settingsStore: fixture.settingsStore, isOnboardingExperience: true)
        defer { flow.stop() }
        flow.start()
        flow.completeBreathingForTesting()
        flow.selectReason(.work)
        flow.confirmSelectedDuration()
        XCTAssertEqual(flow.stage, .win)
        try await capture(AnyView(InterventionFlowView(snapshotFlow: flow, model: fixture.model,
                                                      settingsStore: fixture.settingsStore, onFinished: {})), name: "onboarding-experience-win")
    }

    /// 課金画面は無料機能の説明ではなく、本人の目標を出す（2026-09-24 オーナー承認）。
    @MainActor
    func testPaywallShowsUserGoalsInsteadOfFreeFeatureBody() async throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        XCTAssertTrue(fixture.model.addGoal(title: "英語で話せるようになる", category: .other, lockScreenTitle: nil))
        XCTAssertTrue(fixture.model.addGoal(title: "寝る前に本を読む", category: .other, lockScreenTitle: nil))
        let suite = "PaywallGoals.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StoreService(funnelEventStore: fixture.model.funnelEventStore,
                                 settingsStore: SettingsStore(userDefaults: defaults),
                                 startsBackgroundTasks: false, productLoader: { throw URLError(.notConnectedToInternet) })
        let scene = try XCTUnwrap(activeKeyWindow()?.windowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        defer { window.isHidden = true; window.rootViewController = nil }
        let host = UIHostingController(rootView: PaywallView(storeService: store, placement: .onboardingPrepaywallSummary,
                                                             settingsStore: fixture.settingsStore, model: fixture.model)
            .environment(\.locale, Locale(identifier: "ja"))
            .preferredColorScheme(.dark))
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(1200))
        let image = renderedImage(in: window)
        let output = URL(fileURLWithPath: "/tmp/dopabreak-paywall", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("paywall-goals-375.png"))
        let text = try recognizeJapaneseText(in: XCTUnwrap(image.cgImage)).joined().filter { !$0.isWhitespace }
        XCTAssertTrue(text.contains("あなたの目標"))
        XCTAssertTrue(text.contains("英語で話せるようになる"))
        XCTAssertFalse(text.contains("ずっと我慢する"))
    }

    @MainActor
    func testOnlyCurrentSubscriptionsAreSoldWhileLegacyPurchasesRemainRecognized() {
        XCTAssertEqual(ProProductID.saleSubscriptionIDs, [ProProductID.monthly.rawValue, ProProductID.annual.rawValue])
        XCTAssertFalse(ProProductID.saleSubscriptionIDs.contains(ProProductID.annualLaunch.rawValue))
        XCTAssertEqual(ProProductID.productKind(for: ProProductID.annualLaunch.rawValue), .subscription)
        XCTAssertEqual(ProProductID.productKind(for: ProProductID.lifetime.rawValue), .nonConsumable)
        let service = StoreService(startsBackgroundTasks: false)
        XCTAssertNil(service.activeAnnualProduct)
    }

    @MainActor
    func testFreeTestingPreservesPurchasedEntitlementAndPersistsOnlyInEnabledBuild() {
        let suite = "FreeTesting.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(userDefaults: defaults)
        settings.entitlementCachedIsPro = true
        let service = StoreService(settingsStore: settings, startsBackgroundTasks: false, allowsFreeTesting: true)
        XCTAssertTrue(service.isPro)
        service.setFreeTesting(true)
        XCTAssertFalse(service.isPro)
        XCTAssertEqual(settings.entitlementCachedIsPro, true)
        let relaunched = StoreService(settingsStore: settings, startsBackgroundTasks: false, allowsFreeTesting: true)
        XCTAssertFalse(relaunched.isPro)
        let production = StoreService(settingsStore: settings, startsBackgroundTasks: false, allowsFreeTesting: false)
        XCTAssertTrue(production.isPro)
        production.setFreeTesting(true)
        XCTAssertTrue(production.isPro)
        service.setFreeTesting(false)
        XCTAssertTrue(service.isPro)
        XCTAssertFalse(settings.freeEntitlementTestingEnabled)
    }

    func testV3ForwardBackProgressAndBlockSkipping() {
        for (index, step) in OnboardingStep.allCases.enumerated() {
            XCTAssertEqual(step.previous, index == 0 ? nil : OnboardingStep.allCases[index - 1])
            let count = OnboardingStep.allCases.count
            XCTAssertEqual(count, 12, "アプリ内の体験を独立させて12画面（2026-09-24）")
            XCTAssertEqual(step.next, index == count - 1 ? nil : OnboardingStep.allCases[index + 1])
            XCTAssertEqual(step.progress, Double(index + 1) / Double(count))
            XCTAssertEqual(step.position, index + 1)

        }
    }

    @MainActor
    func testRestoredAndInitialBlockSetupRespectConcreteEntitlementAndModeCases() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let cases: [(Bool, Bool, InterventionMode, OnboardingStep)] = [
            (false, true, .standard, .ready),
            (true, true, .standard, .ready),
            (false, false, .standard, .ready),
            (true, false, .standard, .ready),
            (false, true, .deepFocus, .ready),
            (true, true, .deepFocus, .blockSetup),
            (false, false, .deepFocus, .blockSetup),
            (true, false, .deepFocus, .blockSetup),
            (false, true, .nightOnly, .ready),
            (true, true, .nightOnly, .blockSetup)
        ]
        for (isPro, confirmed, mode, expected) in cases {
            fixture.settingsStore.blockConfiguration = .migrating(mode)
            fixture.settingsStore.onboardingStepRaw = OnboardingStep.blockSetup.rawValue
            for initial: OnboardingStep? in [nil, .blockSetup] {
                let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: initial,
                    isPro: isPro, hasConfirmedEntitlement: confirmed)
                XCTAssertEqual(progress.step, expected, "Pro=\(isPro), confirmed=\(confirmed), mode=\(mode), initial=\(String(describing: initial))")
            }
        }
    }

    @MainActor
    func testBreathingIsDefaultAndBlockChoicePersistsWithoutApplyingRules() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .chooseMode)
        XCTAssertEqual(OnboardingProgress.preferredMode(from: fixture.settingsStore), .standard)
        for mode in InterventionMode.selectable {
            progress.saveModePreference(mode)
            XCTAssertEqual(OnboardingProgress.preferredMode(from: fixture.settingsStore), mode == .standard ? .standard : .deepFocus)
            XCTAssertFalse(fixture.model.storeService.isPro)
            XCTAssertTrue(try fixture.model.ruleStore.allRules().isEmpty)
            XCTAssertEqual(progress.step, .chooseMode)
        }
    }

    /// オンボーディングの一呼吸の体験はSNSで見せる。Safariを先に選んでいてもSNSを優先する（2026-09-26 オーナー指示）。
    func testOnboardingExperienceUsesSelectedSNSInsteadOfSafari() throws {
        let safari = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
        let x = try XCTUnwrap(SNSAppCatalog.app(catalogID: "x"))
        XCTAssertEqual(OnboardingExperienceAppPolicy.app(from: [safari, x])?.catalogID, "x")
        XCTAssertEqual(OnboardingExperienceAppPolicy.app(from: [x, safari])?.catalogID, "x")
        // Safariだけを選んだ人はSafariのまま。見本のアプリにすると、選んでいないアプリの記録が残る。
        XCTAssertEqual(OnboardingExperienceAppPolicy.app(from: [safari])?.catalogID, "safari")
        // 何も選んでいないときは従来どおり見本のInstagram。
        XCTAssertEqual(OnboardingExperienceAppPolicy.app(from: [])?.catalogID, "instagram")
    }

    /// 止め方の画面はおすすめのProを選んだ状態で始める。確定後の画面から再開する人には保存済みの選択を出す（2026-09-26 オーナー指示）。
    @MainActor
    func testChooseModeStartsWithRecommendedProUntilTheChoiceIsSaved() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let beforeChoice: [OnboardingStep] = [.selfCheck, .goalSetup, .chooseApps, .chooseMode]
        for step in beforeChoice {
            XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: step), .deepFocus, "\(step)")
        }

        let progress = OnboardingProgress(settings: fixture.settingsStore, initialStep: .chooseMode)
        progress.saveModePreference(.standard)
        XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: .experience), .standard)
        XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: .prePaywallSummary), .standard)
        // 無料を確定→戻るで止め方の画面へ→再起動。確定した無料を勝手にProへ戻さない。
        XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: .chooseMode), .standard)
        XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: .goalSetup), .standard)

        progress.saveModePreference(.deepFocus)
        XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: .experience), .deepFocus)
        XCTAssertEqual(OnboardingProgress.initialModeSelection(from: fixture.settingsStore, startingAt: .chooseMode), .deepFocus)
    }

    @MainActor
    func testLegacyOnboardingStepsMigrateWithoutChangingScreens() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let migrations: [Int: OnboardingStep] = [0: .selfCheck, 2: .scrollRegret, 5: .lossRecovery,
            9: .experience, 10: .experience, 11: .experience, 13: .prePaywallSummary, 14: .prePaywallSummary, 16: .ready]
        let beforeGoal: Set<OnboardingStep> = [.selfCheck, .scrollRegret, .lossRecovery]
        for (raw, expected) in migrations {
            fixture.settingsStore.onboardingStepRaw = raw
            XCTAssertEqual(OnboardingProgress(settings: fixture.settingsStore).step, expected)
            // 目標が無くても目標画面より前は保存位置から再開し、後ろなら目標画面へ戻す
            XCTAssertEqual(
                OnboardingStep.restored(from: fixture.settingsStore, hasGoals: false),
                beforeGoal.contains(expected) ? expected : .goalSetup
            )
        }
    }

    /// 新規ユーザーは先頭のSNS時間の質問から始まる（目標画面から始まって質問3画面を飛ばす不具合の回帰）。
    @MainActor
    func testFirstLaunchStartsAtSelfCheckNotGoalSetup() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        fixture.settingsStore.onboardingStepRaw = nil
        XCTAssertEqual(OnboardingStep.restored(from: fixture.settingsStore, hasGoals: false), .selfCheck)
        XCTAssertEqual(OnboardingProgress(settings: fixture.settingsStore, hasGoals: false).step, .selfCheck)
        XCTAssertEqual(OnboardingStep.allCases.first, .selfCheck)
        XCTAssertEqual(OnboardingStep.selfCheck.next, .scrollRegret)
        XCTAssertEqual(OnboardingStep.lossRecovery.next, .goalSetup)
    }

    func testOnboardingAutomationSetupStateMovesFromInitialToOpenedToVerified() {
        XCTAssertEqual(
            OnboardingAutomationSetupPolicy.state(
                hasOpenedShortcuts: false,
                selectedCatalogIDs: ["instagram"],
                verifiedCatalogIDs: []
            ),
            .initial
        )
        XCTAssertEqual(
            OnboardingAutomationSetupPolicy.state(
                hasOpenedShortcuts: true,
                selectedCatalogIDs: ["instagram"],
                verifiedCatalogIDs: []
            ),
            .awaitingVerification
        )
        XCTAssertEqual(
            OnboardingAutomationSetupPolicy.state(
                hasOpenedShortcuts: true,
                selectedCatalogIDs: ["instagram"],
                verifiedCatalogIDs: ["instagram"]
            ),
            .verified
        )
    }

    func testOnboardingAutomationVerificationMustMatchSelectedTarget() {
        XCTAssertEqual(
            OnboardingAutomationSetupPolicy.state(
                hasOpenedShortcuts: true,
                selectedCatalogIDs: ["instagram"],
                verifiedCatalogIDs: ["youtube"]
            ),
            .awaitingVerification
        )
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
    func testUpdateLockThemeSynchronizesSavedSelectionAndPersistentStore() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }

        fixture.model.updateLockTheme(.gaming)

        XCTAssertEqual(fixture.settingsStore.lockTheme, .gaming)
        XCTAssertEqual(fixture.model.savedLockTheme, .gaming)
        XCTAssertEqual(fixture.model.lockThemeSelection, .gaming)
        XCTAssertEqual(fixture.model.liveLockTheme, .e1)
    }

    @MainActor
    func testRefreshImportsLockThemeChangedOutsideAppModel() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }

        fixture.settingsStore.lockTheme = .note
        fixture.model.refresh(scheduleNotifications: false)

        XCTAssertEqual(fixture.model.savedLockTheme, .note)
        XCTAssertEqual(fixture.model.lockThemeSelection, .note)
        XCTAssertEqual(fixture.model.liveLockTheme, .e1)
    }

    @MainActor
    func testFreeSettingsProThemeSelectionStaysPendingAndPresentsSettingsPaywall() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())
        var settingsPlacement: PaywallPlacement?
        var callbackOrder: [String] = []

        SettingsLockThemeSelectionHandler.select(
            for: .gaming,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { theme, placement in
                fixture.model.pendingProThemeSelection = theme
                settingsPlacement = placement
                callbackOrder.append("paywall")
            },
            onSelect: { theme in
                fixture.model.updateLockTheme(theme)
                callbackOrder.append("save")
            }
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .gaming)
        XCTAssertEqual(fixture.model.displayedLockThemeSelection, .gaming)
        XCTAssertEqual(settingsPlacement, .settingsThemeGate)
        XCTAssertEqual(callbackOrder, ["paywall"])
    }

    @MainActor
    func testFreeHomeProThemeSelectionStaysPendingAndPresentsHomePaywall() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())
        var homePlacement: PaywallPlacement?
        var callbackOrder: [String] = []

        HomeLockThemeSelectionHandler.select(
            for: .kpop,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { theme, placement in
                fixture.model.pendingProThemeSelection = theme
                homePlacement = placement
                callbackOrder.append("paywall")
            },
            onSelect: { theme in
                fixture.model.updateLockTheme(theme)
                callbackOrder.append("save")
            }
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .kpop)
        XCTAssertEqual(homePlacement, .homeThemeGate)
        XCTAssertEqual(callbackOrder, ["paywall"])
    }

    @MainActor
    func testFreeModelKeepsE1SurfaceAfterLockedThemeHandlerSelection() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        SettingsLockThemeSelectionHandler.select(
            for: .blueprint,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { theme, _ in
                fixture.model.pendingProThemeSelection = theme
            },
            onSelect: { theme in
                fixture.model.updateLockTheme(theme)
            }
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .blueprint)
        XCTAssertEqual(fixture.model.lockSurfaceState.theme, .e1)
    }

    @MainActor
    func testPurchasedProCommitsThemePendingFromLockedThemeHandler() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        HomeLockThemeSelectionHandler.select(
            for: .asagiri,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { theme, _ in
                fixture.model.pendingProThemeSelection = theme
            },
            onSelect: { theme in
                fixture.model.updateLockTheme(theme)
            }
        )
        XCTAssertEqual(fixture.model.lockSurfaceState.theme, .e1)

        XCTAssertTrue(
            fixture.model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .asagiri)
        XCTAssertNil(fixture.model.pendingProThemeSelection)

        let proFixture = try makeThemeSelectionFixture(isPro: true)
        defer { proFixture.cleanUp() }
        XCTAssertEqual(proFixture.settingsStore.lockTheme, .e1)
        XCTAssertFalse(
            proFixture.model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)
        )
        XCTAssertEqual(proFixture.settingsStore.lockTheme, .e1)
    }

    @MainActor
    func testOnboardingProThemeSelectionCommitsOnlyAfterPurchase() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        OnboardingLockThemeSelectionHandler.select(
            for: .note,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { fixture.model.pendingProThemeSelection = $0 },
            onSelect: fixture.model.updateLockTheme
        )

        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.displayedLockThemeSelection, .note)
        XCTAssertTrue(
            fixture.model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)
        )
        XCTAssertEqual(fixture.settingsStore.lockTheme, .note)
        XCTAssertNil(fixture.model.pendingProThemeSelection)
    }

    /// 保留中のProテーマを持ち込んでよいペイウォールの真理値表。
    /// `PaywallPlacement.allCases` を突き合わせるので、placementが増えたらここで落ちる。
    func testPendingProThemePaywallPolicyKeepsSelectionOnlyForDesignSelectionPlacements() {
        let expected: [PaywallPlacement: Bool] = [
            .settingsThemeGate: true,
            .homeThemeGate: true,
            .onboardingPrepaywallSummary: true,
            .onboardingModeGate: true,
            .onboardingTargetAppGate: true,
            .onboardingLockThemeGate: true,
            .settingsTargetAppLimit: false,
            .settingsFamilyActivityLimit: false,
            .settingsProStatusRow: false,
            .settingsModeGate: false,
            .weekly: false
        ]

        XCTAssertEqual(expected.count, PaywallPlacement.allCases.count)
        for placement in PaywallPlacement.allCases {
            guard let keepsSelection = expected[placement] else {
                XCTFail("placement \(placement.rawValue) が真理値表にない")
                continue
            }
            XCTAssertEqual(
                PendingProThemePaywallPolicy.keepsPendingSelection(for: placement),
                keepsSelection,
                "placement \(placement.rawValue)"
            )
        }
    }

    /// この施策の本体。デザインを選ぶ導線ではないペイウォールを開いた時点で保留を捨て、
    /// そこでProになってもロック画面とLive Activityが既定の `.e1` のままであることを確かめる。
    @MainActor
    func testProStatusRowPaywallPresentationDropsPendingProThemeAndKeepsDefaultTheme() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        SettingsLockThemeSelectionHandler.select(
            for: .gaming,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { theme, _ in fixture.model.pendingProThemeSelection = theme },
            onSelect: { theme in fixture.model.updateLockTheme(theme) }
        )
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .gaming)
        XCTAssertEqual(fixture.model.displayedLockThemeSelection, .gaming)

        let presentation = presentPaywall(placement: .settingsProStatusRow, fixture: fixture)
        defer { presentation.tearDown() }
        XCTAssertNotNil(fixture.settingsStore.lastAnyPaywallShownAt)

        XCTAssertNil(fixture.model.pendingProThemeSelection)
        XCTAssertEqual(fixture.model.displayedLockThemeSelection, .e1)
        XCTAssertFalse(
            fixture.model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)
        )
        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.savedLockTheme, .e1)
        XCTAssertEqual(fixture.model.lockSurfaceState.theme, .e1)
    }

    @MainActor
    func testSettingsThemeGatePaywallPresentationKeepsPendingProThemeSelection() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        SettingsLockThemeSelectionHandler.select(
            for: .gaming,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { theme, _ in fixture.model.pendingProThemeSelection = theme },
            onSelect: { theme in fixture.model.updateLockTheme(theme) }
        )

        let presentation = presentPaywall(placement: .settingsThemeGate, fixture: fixture)
        defer { presentation.tearDown() }
        XCTAssertNotNil(fixture.settingsStore.lastAnyPaywallShownAt)

        XCTAssertEqual(fixture.model.pendingProThemeSelection, .gaming)
        XCTAssertTrue(
            fixture.model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)
        )
        XCTAssertEqual(fixture.settingsStore.lockTheme, .gaming)
        XCTAssertEqual(fixture.model.savedLockTheme, .gaming)
        XCTAssertNil(fixture.model.pendingProThemeSelection)
    }

    @MainActor
    func testOnboardingPrepaywallSummaryPaywallPresentationKeepsPendingProThemeSelection() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        let freeGate = EntitlementGate(tier: .free, now: Date())

        OnboardingLockThemeSelectionHandler.select(
            for: .note,
            isThemeAllowed: freeGate.lockThemeAllowed,
            onLocked: { fixture.model.pendingProThemeSelection = $0 },
            onSelect: fixture.model.updateLockTheme
        )

        let presentation = presentPaywall(
            placement: .onboardingPrepaywallSummary,
            fixture: fixture
        )
        defer { presentation.tearDown() }
        XCTAssertNotNil(fixture.settingsStore.lastAnyPaywallShownAt)

        XCTAssertEqual(fixture.model.pendingProThemeSelection, .note)
        XCTAssertTrue(
            fixture.model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)
        )
        XCTAssertEqual(fixture.settingsStore.lockTheme, .note)
        XCTAssertEqual(fixture.model.savedLockTheme, .note)
    }

    @MainActor
    func testFreeSettingsPickerSelectionKeepsRowGuardedWhileDeferringAndRenderingProTheme() throws {
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
        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .gaming)
        XCTAssertEqual(paywallPlacement, .settingsThemeGate)
        XCTAssertEqual(savedThemeWhenPaywallPresented, .e1)
    }

    @MainActor
    func testFreeSettingsPickerSelectionRendersProNoteForPendingTheme() throws {
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
        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .note)
        XCTAssertEqual(paywallPlacement, .settingsThemeGate)

        paywallPlacement = nil
        render(host)

        XCTAssertNil(paywallPlacement)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.displayedLockThemeSelection, .note)
    }

    @MainActor
    func testFreeHomePickerKeepsPendingSelectionAndLivePreviewWhilePresentingHomePaywall() throws {
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
        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .gaming)
        XCTAssertEqual(presentedPlacement, .homeThemeGate)
    }

    /// ホームでロック済みテーマを選んでからペイウォールが出るまでの受け渡し。
    /// ここで `isChildModalActive` が一瞬でも false に落ちると、`RootTabView` が
    /// 週次ペイウォールを割り込ませ、その提示で保留中のProテーマが捨てられる。
    @MainActor
    func testHomeLockedThemeHandoffKeepsChildModalActiveUntilPaywallPresents() throws {
        let fixture = try makeThemeSelectionFixture()
        defer { fixture.cleanUp() }
        fixture.settingsStore.liveActivityEnabled = true
        let entryReady = expectation(description: "Home theme picker entry is rendered")
        let pickerReady = expectation(description: "Home theme picker is rendered")
        entryReady.assertForOverFulfill = false
        pickerReady.assertForOverFulfill = false
        var openPicker: (() -> Void)?
        var selectTheme: ((LockTheme) -> Void)?
        var presentedPlacement: PaywallPlacement?
        var childModalActiveWhenPaywallPresented: Bool?
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
            onPaywallPresented: { placement in
                guard presentedPlacement == nil else { return }
                presentedPlacement = placement
                childModalActiveWhenPaywallPresented = fixture.model.isChildModalActive
            }
        )
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 2_400))

        window.rootViewController = host
        window.makeKeyAndVisible()
        render(host)
        defer { window.isHidden = true }

        wait(for: [entryReady], timeout: 2)
        try XCTUnwrap(openPicker)()
        render(host)
        wait(for: [pickerReady], timeout: 2)
        XCTAssertTrue(fixture.model.isChildModalActive)

        try XCTUnwrap(selectTheme)(.gaming)

        // シートが閉じてからペイウォールが出るまでを1msきざみで見張る。毎回レイアウトを進めないと
        // SwiftUIの再評価が追いつかず、落ちる窓を跨いで見逃す。
        // 見張りを外した状態での実測: 0.002〜0.015秒のあいだ false（ペイウォールは0.045秒に提示）。
        var observedInactive = false
        var didPresent = false
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            host.view.layoutIfNeeded()
            if !fixture.model.isChildModalActive {
                observedInactive = true
            }
            if presentedPlacement != nil {
                didPresent = true
                break
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.001))
        }

        XCTAssertTrue(didPresent, "ホームのペイウォールが出なかった")
        XCTAssertFalse(
            observedInactive,
            "ピッカーが閉じてからペイウォールが出るまでに isChildModalActive が false になった"
        )
        XCTAssertEqual(presentedPlacement, .homeThemeGate)
        XCTAssertEqual(childModalActiveWhenPaywallPresented, true)
        XCTAssertEqual(fixture.model.pendingProThemeSelection, .gaming)
        XCTAssertEqual(fixture.settingsStore.lockTheme, .e1)
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
    func testSettingsBlockSwitchesRenderAllJapaneseCopyWithoutTruncation() throws {
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

        try XCTSkipUnless(Locale.current.language.languageCode?.identifier == "ja", "ja環境でのみ日本語切り詰め回帰を検証する")

        let image = try XCTUnwrap(renderedImage(in: window).cgImage, "Settings mode cards image could not be rendered")
        let recognizedText = try recognizeJapaneseText(in: image)
        let compactRecognizedText = recognizedText.joined().filter { !$0.isWhitespace }
        for trigger in BlockTrigger.allCases {
            XCTAssertTrue(compactRecognizedText.contains(trigger.displayTitle.filter { !$0.isWhitespace }),
                "Missing rendered trigger: \(trigger.displayTitle)")
        }
        XCTAssertTrue(compactRecognizedText.contains("開く前の一呼吸はいつでも使えます"))

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
                "onboarding_prepaywall_summary",
                "onboarding_mode_gate",
                "onboarding_target_app_gate",
                "onboarding_lock_theme_gate",
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
        XCTAssertEqual(PaywallView.resolvedDailyMinutes(snapshot: snapshot), 390)
        XCTAssertEqual(PaywallView.resolvedDailyMinutes(snapshot: nil), 150)
    }

    /// 見出しの年数と注記の1日の時間は、オンボーディングの O-03r と同じ書式でなければならない。
    /// 切り捨て（四捨五入しない）と50年前提が景表法上の根拠なので、値を固定して守る。
    func testLossEstimatePresentationSharesOnboardingFormats() throws {
        // docs/07 O-03r のバケット対応表を全5件そのまま固定する（切り上げたら落ちる）。
        XCTAssertEqual(LossEstimatePresentation.lifetimeYearsText(yearlyDays: 11), "1.5")
        XCTAssertEqual(LossEstimatePresentation.lifetimeYearsText(yearlyDays: 23), "3.1")
        XCTAssertEqual(LossEstimatePresentation.lifetimeYearsText(yearlyDays: 38), "5.2")
        XCTAssertEqual(LossEstimatePresentation.lifetimeYearsText(yearlyDays: 76), "10.4")
        XCTAssertEqual(LossEstimatePresentation.lifetimeYearsText(yearlyDays: 99), "13.5")

        let japanese = try localizedAppBundle(language: "ja")

        XCTAssertEqual(LossEstimatePresentation.dailyTimeText(minutes: 150, bundle: japanese), "2.5時間")
        XCTAssertEqual(LossEstimatePresentation.dailyTimeText(minutes: 45, bundle: japanese), "45分")
        XCTAssertEqual(LossEstimatePresentation.dailyTimeText(minutes: 120, bundle: japanese), "2時間")
    }

    /// ペイウォールの新設・差し替えキーを、ビルド済みの各言語バンドルから実値で照合する。
    /// カタログのJSONではなく `.lproj` を見るのは、翻訳が製品に載っていることまで確かめるため。
    func testPaywallHeadlineAndFeatureCopyIsShippedInEverySupportedLanguage() throws {
        let expectedValues: [String: [String: String]] = [
            "paywall.header.line1.prefix": [
                "ja": "「あと5分」が人生の",
                "en": "“5 more min” = ",
                "ko": "'5분만 더'가 인생의 "
            ],
            "paywall.header.line1.suffix": [
                "ja": "年",
                "en": " years gone",
                "ko": "년"
            ],
            "paywall.header.estimate_note": [
                "ja": "1日約%@が50年続いた場合の推計",
                "en": "Estimate: %@ a day, over 50 years",
                "ko": "하루 약 %@이 50년 이어질 때의 추정치"
            ],
            "paywall.feature.strict_block": [
                "ja": "解除に30秒待つ強いブロック",
                "en": "Strict blocks with a 30-second exit delay",
                "ko": "해제 전 30초 기다리는 강력 차단"
            ],
            "paywall.feature.weekly_schedule": [
                "ja": "毎週のブロック予定を2つ設定",
                "en": "Set two weekly blocking schedules",
                "ko": "주간 차단 일정 2개 설정"
            ],
            "paywall.feature.daily_open_limit": [
                "ja": "1日の開く回数を制限してブロック",
                "en": "Block apps after your daily open limit",
                "ko": "하루에 여는 횟수를 제한해 차단"
            ],
            "paywall.feature.grayscale": [
                "ja": "刺激を軽減する白黒モード",
                "en": "Grayscale mode to reduce stimulation",
                "ko": "자극을 줄이는 흑백 모드"
            ]
        ]

        for language in ["ja", "en", "ko"] {
            let bundle = try localizedAppBundle(language: language)
            for (key, expectedByLanguage) in expectedValues {
                let expected = try XCTUnwrap(expectedByLanguage[language], "\(key) \(language)")
                XCTAssertEqual(
                    bundle.localizedString(forKey: key, value: "", table: nil),
                    expected,
                    "\(key) \(language)"
                )
            }
        }
    }

    private func localizedAppBundle(
        language: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Bundle {
        let appBundle = Bundle(for: AppDelegate.self)
        let path = try XCTUnwrap(
            appBundle.path(forResource: language, ofType: "lproj"),
            "\(language).lproj が見つからない",
            file: file,
            line: line
        )
        return try XCTUnwrap(Bundle(path: path), "\(language).lproj を読めない", file: file, line: line)
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
        XCTAssertEqual(flow.stage, .durationSelection)
    }

    @MainActor
    func testPendingReflectionDoesNotInterruptBreathingFlow() throws {
        let context = try InterventionFlowTestContext()
        defer { context.cleanup() }
        let flow = try context.makeFlow()
        defer { flow.stop() }
        let now = Date()
        let reflection = ReflectionLog(
            id: UUID(),
            attemptLogId: nil,
            ruleId: UUID(),
            promptedAt: now.addingTimeInterval(-5 * 60),
            answeredAt: nil,
            trigger: .timedSessionEnded,
            satisfaction: nil,
            happinessDelta: nil,
            skipped: false,
            createdAt: now.addingTimeInterval(-15 * 60)
        )
        try context.logStore.insert(reflection)

        flow.start()

        XCTAssertEqual(flow.stage, .breathing)
        XCTAssertFalse(try XCTUnwrap(context.logStore.fetchReflections().first).skipped)
    }

    func testReflectionTimingSummaryIncludesElapsedTimeAndDeclaredMinutes() {
        let promptedAt = Date(timeIntervalSince1970: 10_000)
        let reflection = ReflectionLog(
            id: UUID(),
            attemptLogId: nil,
            ruleId: UUID(),
            promptedAt: promptedAt,
            answeredAt: nil,
            trigger: .timedSessionEnded,
            satisfaction: nil,
            happinessDelta: nil,
            skipped: false,
            createdAt: promptedAt.addingTimeInterval(-10 * 60)
        )

        XCTAssertEqual(ReflectionTimingSummary.durationMinutes(for: reflection), 10)
        XCTAssertEqual(
            ReflectionTimingSummary.elapsedMinutes(
                for: reflection,
                now: promptedAt.addingTimeInterval(3 * 60 * 60)
            ),
            180
        )
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
        XCTAssertEqual(persistedView.dailyMinutes, 390)

        try Data("not json".utf8).write(
            to: containerURL.appendingPathComponent("self_check_snapshot.json")
        )
        let fallbackView = PaywallView(
            storeService: service,
            placement: .settingsThemeGate,
            snapshotStore: snapshotStore
        )
        XCTAssertEqual(fallbackView.yearlyDays, 38)
        XCTAssertEqual(fallbackView.dailyMinutes, 150)
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

    var logStore: SQLiteLogStore {
        get throws {
            try SQLiteLogStore(containerProvider: FixedContainer(url: containerURL))
        }
    }

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

/// ペイウォールを実際に窓へ載せて `.onAppear` を走らせる。保留テーマの破棄は提示時に行うため、
/// `PaywallView` を組み立てるだけでは検証にならない。
@MainActor
private struct PaywallPresentation {
    let window: UIWindow
    let host: UIViewController

    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
    }
}

@MainActor
private func presentPaywall(
    placement: PaywallPlacement,
    fixture: ThemeSelectionFixture
) -> PaywallPresentation {
    let root = PaywallView(
        storeService: fixture.model.storeService,
        placement: placement,
        snapshotStore: JSONSnapshotStore(
            containerProvider: TemporaryContainer(url: fixture.containerURL)
        ),
        settingsStore: fixture.settingsStore,
        model: fixture.model
    )
    let host = UIHostingController(rootView: root)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))

    window.rootViewController = host
    window.makeKeyAndVisible()
    render(host)
    // 提示の計測が書かれた時点で `.onAppear` のガード内を通過している。
    spinRunLoop(until: { fixture.settingsStore.lastAnyPaywallShownAt != nil })

    return PaywallPresentation(window: window, host: host)
}

@MainActor
@discardableResult
private func spinRunLoop(until condition: () -> Bool, timeout: TimeInterval = 2) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
    return condition()
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
        weeklyReportNotificationEnabled: Binding<Bool>,
        retentionSupportNotificationsEnabled: Binding<Bool>,
        planNotificationsEnabled: Binding<Bool>
    ) {
        self.init(
            model: model,
            settingsStore: settingsStore,
            weeklyReportNotificationMinutes: .constant(
                settingsStore.weeklyReportNotificationMinutes
            ),
            weeklyReportNotificationEnabled: weeklyReportNotificationEnabled,
            reflectionNotificationEnabled: .constant(
                settingsStore.reflectionNotificationEnabled
            ),
            retentionSupportNotificationsEnabled: retentionSupportNotificationsEnabled,
            planNotificationsEnabled: planNotificationsEnabled
        )
    }
}

@MainActor
private func findScrollView(in view: UIView) -> UIScrollView? {
    if let scroll = view as? UIScrollView { return scroll }
    return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
}
