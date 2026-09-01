import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

final class WinScreenReclaimedTimeTests: XCTestCase {
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

    func testWinCopyHasThreeLanguagesAndRemovedShameCopy() throws {
        let catalog = try localizableStrings()
        let requiredKeys = [
            "intervention.success.daily_cancelled",
            "intervention.success.goals.title",
            "intervention.success.milestone.days",
            "intervention.success.milestone.hours",
            "intervention.success.reclaimed.increment",
            "intervention.success.reclaimed.label",
            "intervention.success.reclaimed.total"
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
