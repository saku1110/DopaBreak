import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

final class WinScreenReclaimedTimeTests: XCTestCase {
    @MainActor
    func testDirectCancelFromReasonSelectionRecordsExactlyOneWinWithoutIntent() throws {
        let fixture = try FlowFixture()
        defer { fixture.cleanup() }
        let flow = try fixture.makeFlow()
        flow.start()
        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .reasonSelection)
        XCTAssertNil(flow.selectedReason)
        flow.chooseCancel()
        XCTAssertEqual(flow.stage, .win)
        let reclaimed = try fixture.logStore.reclaimedSeconds()
        flow.chooseCancel()
        XCTAssertEqual(try fixture.logStore.reclaimedSeconds(), reclaimed)
        XCTAssertGreaterThan(reclaimed, 0)
        let attempts = try fixture.logStore.fetchAttempts()
        XCTAssertEqual(attempts.count, 1)
        XCTAssertNil(attempts.first?.intent)
        XCTAssertNil(flow.selectedReason)
    }

    @MainActor
    func testStrictSessionBlocksModelModeAndTargetChanges() throws {
        let fixture = try FlowFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.deepFocusSession = .init(startedAt: Date(), endsAt: Date().addingTimeInterval(3600), isStrict: true)
        XCTAssertThrowsError(try fixture.model.applyInterventionMode(.standard))
        fixture.model.endDeepFocusSession()
        XCTAssertNotNil(fixture.model.deepFocusSession)
    }

    @MainActor
    func testRenderDirectCancelAndEmergencyExit() throws {
        let fixture = try FlowFixture()
        defer { fixture.cleanup() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        defer { window.isHidden = true }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/verify/competitive-improvements")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
        let reason = InterventionFlowView(snapshotTarget: target, model: fixture.model, settingsStore: fixture.settingsStore,
            selectedReason: nil, completesBreathing: true, onFinished: {})
        fixture.settingsStore.deepFocusSession = .init(startedAt: Date(), endsAt: Date().addingTimeInterval(3600), isStrict: true)
        for (name, view) in [("direct-cancel", AnyView(reason)), ("emergency-exit", AnyView(StrictSessionExitView(model: fixture.model)))] {
            let host = UIHostingController(rootView: view.environment(\.locale, Locale(identifier: "ja_JP")).preferredColorScheme(.dark))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertEqual(image.size, window.bounds.size)
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("\(name).png"))
        }
    }

    @MainActor
    func testRenderReinterventionReviewAndFinishOptions() throws {
        let fixture = try FlowFixture()
        defer { fixture.cleanup() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        defer { window.isHidden = true }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/verify/reintervention")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let engine = try XCTUnwrap(fixture.model.interventionEngine)
        let now = Date()
        var reflection = ReflectionLog(id: UUID(), attemptLogId: nil, ruleId: UUID(), promptedAt: now, answeredAt: nil,
            trigger: .timedSessionEnded, satisfaction: nil, happinessDelta: nil, skipped: false, createdAt: now.addingTimeInterval(-600))
        var session = ReinterventionSession(catalogID: "instagram", selectionData: Data(), minutes: 10, now: now.addingTimeInterval(-600))
        session.reachedAt = now
        session.reflectionID = reflection.id
        try fixture.model.reinterventionScheduler.store.transaction { $0.sessions["instagram"] = session }
        for name in ["satisfaction", "finish-or-extend", "work-time-checkin"] {
            if name == "finish-or-extend" { reflection.answeredAt = now; reflection.satisfaction = .fun }
            let sheet = PostUseReflectionSheet(model: fixture.model, engine: engine, reflection: reflection, onFinished: {})
            let content: AnyView
            if name == "work-time-checkin" {
                content = AnyView(InterventionFlowView(snapshotTarget: SNSAppCatalog.app(catalogID: "instagram")!,
                    model: fixture.model, settingsStore: fixture.settingsStore, selectedReason: .work, completesBreathing: true, onFinished: {}))
            } else { content = AnyView(sheet) }
            let host = UIHostingController(rootView: content.environment(\.locale, Locale(identifier: "ja_JP")).preferredColorScheme(.dark))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: try XCTUnwrap(image.cgImage)))
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("\(name).png"))
        }
    }

    @MainActor
    func testCancelUsesPersistedReclaimedSecondsAndSharedLifetimeFormat() throws {
        let fixture = try FlowFixture()
        defer { fixture.cleanup() }

        let flow = try fixture.makeFlow()
        flow.start()
        flow.completeBreathingForTesting()
        flow.selectReason(.unconscious)
        XCTAssertEqual(flow.stage, .usageSummary)

        flow.chooseCancel()

        XCTAssertEqual(flow.stage, .win)
        let persisted = try fixture.logStore.reclaimedSeconds()
        XCTAssertEqual(flow.winReclaimedSeconds, persisted)
        XCTAssertEqual(flow.winLifetimeReclaimedSeconds, persisted)
        XCTAssertEqual(flow.winConsecutiveDays, 1)
        XCTAssertEqual(
            ReclaimedTimeFormatter.detailedString(seconds: flow.winLifetimeReclaimedSeconds),
            ReclaimedTimeFormatter.detailedString(seconds: persisted)
        )
    }

    @MainActor
    func testOneThroughFiveGoalsAreAllRenderedWithinIPhone16ProBodyHeight() throws {
        for count in 1...5 {
            let goals = makeGoals(count: count)
            XCTAssertEqual(
                WinScreenPresentationPolicy.displayedGoals(goals).map(\.id),
                goals.map(\.id)
            )

            let content = WinScreenContent(
                reclaimedSeconds: 480,
                lifetimeReclaimedSeconds: 172_800 + 8_040,
                todayCancelledCount: 4,
                consecutiveDays: 3,
                estimatedMinutesPerCancellation: 8,
                goals: goals,
                milestone: ReclaimedTimeMilestone(thresholdSeconds: 86_400)
            )
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(width: 402)

            let host = UIHostingController(rootView: content)
            let fitted = host.sizeThatFits(
                in: CGSize(width: 402, height: CGFloat.greatestFiniteMagnitude)
            )
            XCTAssertLessThanOrEqual(fitted.height, 720, "goal count \(count)")

            let renderer = ImageRenderer(content: content.fixedSize(horizontal: false, vertical: true))
            renderer.scale = 1
            XCTAssertNotNil(renderer.cgImage, "goal count \(count) must render")
        }
    }

    @MainActor
    func testMilestoneIsClaimedOnlyOnceAndAdvancesAtEveryWholeDay() throws {
        let suiteName = "WinScreenReclaimedTimeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertNil(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 3_000,
                totalSeconds: 3_599,
                settingsStore: store
            )
        )
        XCTAssertEqual(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 3_599,
                totalSeconds: 3_600,
                settingsStore: store
            ),
            ReclaimedTimeMilestone(thresholdSeconds: 3_600)
        )
        XCTAssertNil(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 3_600,
                totalSeconds: 21_599,
                settingsStore: store
            )
        )
        XCTAssertEqual(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 21_599,
                totalSeconds: 21_600,
                settingsStore: store
            ),
            ReclaimedTimeMilestone(thresholdSeconds: 21_600)
        )
        XCTAssertNil(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 21_599,
                totalSeconds: 21_600,
                settingsStore: store
            )
        )
        XCTAssertEqual(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 3 * 86_400 - 1,
                totalSeconds: 3 * 86_400 + 10,
                settingsStore: store
            ),
            ReclaimedTimeMilestone(thresholdSeconds: 3 * 86_400)
        )
        XCTAssertNil(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 3 * 86_400 + 10,
                totalSeconds: 4 * 86_400 - 1,
                settingsStore: store
            )
        )
        XCTAssertEqual(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 4 * 86_400 - 1,
                totalSeconds: 4 * 86_400,
                settingsStore: store
            ),
            ReclaimedTimeMilestone(thresholdSeconds: 4 * 86_400)
        )

        let migratedStore = SettingsStore(
            userDefaults: try XCTUnwrap(UserDefaults(suiteName: "\(suiteName).migrated"))
        )
        defer { UserDefaults.standard.removePersistentDomain(forName: "\(suiteName).migrated") }
        XCTAssertNil(
            ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: 2 * 86_400,
                totalSeconds: 2 * 86_400 + 300,
                settingsStore: migratedStore
            ),
            "an already-crossed milestone must not celebrate late after an app update"
        )
        XCTAssertEqual(migratedStore.lastCelebratedReclaimedMilestoneSeconds, 2 * 86_400)
    }

    func testReduceMotionUsesStaticCelebrationInsteadOfConfetti() {
        let milestone = ReclaimedTimeMilestone(thresholdSeconds: 86_400)

        XCTAssertTrue(
            WinScreenPresentationPolicy.showsConfetti(
                milestone: milestone,
                reduceMotion: false
            )
        )
        XCTAssertFalse(
            WinScreenPresentationPolicy.showsConfetti(
                milestone: milestone,
                reduceMotion: true
            )
        )
        XCTAssertFalse(
            WinScreenPresentationPolicy.showsConfetti(
                milestone: nil,
                reduceMotion: false
            )
        )
    }

    func testMilestoneThresholdsUseOneSixTwelveHoursThenWholeDays() {
        XCTAssertNil(ReclaimedTimeMilestone.highestReached(seconds: 3_599))
        XCTAssertEqual(
            ReclaimedTimeMilestone.highestReached(seconds: 3_600),
            ReclaimedTimeMilestone(thresholdSeconds: 3_600)
        )
        XCTAssertEqual(
            ReclaimedTimeMilestone.highestReached(seconds: 21_600),
            ReclaimedTimeMilestone(thresholdSeconds: 21_600)
        )
        XCTAssertEqual(
            ReclaimedTimeMilestone.highestReached(seconds: 43_200),
            ReclaimedTimeMilestone(thresholdSeconds: 43_200)
        )
        XCTAssertEqual(
            ReclaimedTimeMilestone.highestReached(seconds: 2 * 86_400 + 86_399),
            ReclaimedTimeMilestone(thresholdSeconds: 2 * 86_400)
        )
    }

    func testNextMilestoneThresholdUsesTheExistingThresholdSequence() {
        let cases: [(seconds: Int, expected: Int)] = [
            (-1, 3_600),
            (0, 3_600),
            (3_599, 3_600),
            (3_600, 21_600),
            (21_599, 21_600),
            (21_600, 43_200),
            (43_199, 43_200),
            (43_200, 86_400),
            (86_399, 86_400),
            (86_400, 172_800),
            (2 * 86_400 + 1, 3 * 86_400)
        ]

        for entry in cases {
            XCTAssertEqual(
                ReclaimedTimeMilestone.nextThreshold(after: entry.seconds),
                ReclaimedTimeMilestone(thresholdSeconds: entry.expected),
                "seconds: \(entry.seconds)"
            )
        }
    }

    func testMilestoneProgressStartsAtThePreviousMilestone() throws {
        let firstInterval = try XCTUnwrap(ReclaimedTimeMilestoneProgress(seconds: 1_800))
        XCTAssertEqual(firstInterval.previousThresholdSeconds, 0)
        XCTAssertEqual(firstInterval.nextMilestone.thresholdSeconds, 3_600)
        XCTAssertEqual(firstInterval.fraction, 0.5, accuracy: 0.000_001)

        let sixHourInterval = try XCTUnwrap(ReclaimedTimeMilestoneProgress(seconds: 10_800))
        XCTAssertEqual(sixHourInterval.previousThresholdSeconds, 3_600)
        XCTAssertEqual(sixHourInterval.nextMilestone.thresholdSeconds, 21_600)
        XCTAssertEqual(sixHourInterval.fraction, 0.4, accuracy: 0.000_001)
        XCTAssertNotEqual(sixHourInterval.fraction, Double(10_800) / Double(21_600))

        let dayInterval = try XCTUnwrap(ReclaimedTimeMilestoneProgress(seconds: 129_600))
        XCTAssertEqual(dayInterval.previousThresholdSeconds, 86_400)
        XCTAssertEqual(dayInterval.nextMilestone.thresholdSeconds, 172_800)
        XCTAssertEqual(dayInterval.fraction, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(dayInterval.remainingSeconds, 43_200)
    }

    func testProgressIsHiddenForMilestoneCelebrationAndStreakForZeroDays() {
        XCTAssertTrue(WinScreenPresentationPolicy.showsProgress(milestone: nil))
        XCTAssertFalse(
            WinScreenPresentationPolicy.showsProgress(
                milestone: ReclaimedTimeMilestone(thresholdSeconds: 3_600)
            )
        )
        XCTAssertNil(WinScreenPresentationPolicy.streakText(days: 0))
        XCTAssertNil(WinScreenPresentationPolicy.streakText(days: -1))
        XCTAssertEqual(WinScreenPresentationPolicy.streakText(days: 1), "1日連続")
        XCTAssertEqual(WinScreenPresentationPolicy.streakText(days: 8), "8日連続")
    }

    func testWinCopyHasThreeLanguagesAndRemovedShameCopy() throws {
        let catalog = try localizableStrings()
        let requiredKeys = [
            "intervention.success.daily_cancelled",
            "intervention.success.goals.title",
            "intervention.success.milestone.days",
            "intervention.success.milestone.hours",
            "intervention.success.progress.days",
            "intervention.success.progress.hours",
            "intervention.success.progress.remaining",
            "intervention.success.reclaimed.increment",
            "intervention.success.reclaimed.label",
            "intervention.success.reclaimed.total",
            "intervention.success.streak"
        ]

        for key in requiredKeys {
            let entry = try XCTUnwrap(catalog[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            XCTAssertEqual(Set(localizations.keys), Set(["ja", "en", "ko"]), key)
        }

        XCTAssertNil(catalog["intervention.success.title"])
        XCTAssertNil(catalog["intervention.success.daily_attempt"])
        XCTAssertNil(catalog["intervention.success.metric.attempted"])
        XCTAssertNil(catalog["intervention.goal.eyebrow"])
    }

    private func makeGoals(count: Int) -> [Goal] {
        (0..<count).map { index in
            Goal(
                id: UUID(),
                title: "取り戻した時間で続けたい目標その\(index + 1)",
                lockScreenTitle: nil,
                category: .other,
                displayImagePath: nil,
                createdAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(index)),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(index))
            )
        }
    }

    private func localizableStrings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DopaBreak/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(object["strings"] as? [String: Any])
    }
}

@MainActor
private final class FlowFixture {
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
        suiteName = "WinScreenReclaimedTimeTests.Flow.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WinScreenReclaimedTimeTests-\(UUID().uuidString)", isDirectory: true)
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
