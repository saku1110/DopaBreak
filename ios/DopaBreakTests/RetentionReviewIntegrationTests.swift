import DopaBreakCore
import Foundation
import XCTest
@testable import DopaBreak

final class RetentionReviewIntegrationTests: XCTestCase {
    @MainActor
    func testEligibleReviewRequestPersistsDateAndAnalyticsEvent() throws {
        let context = try makeEligibleContext()

        let requestDate = try XCTUnwrap(
            context.model.reviewPromptRequestDateIfEligible(sessionBlocked: false)
        )
        context.model.recordReviewPromptShown(at: requestDate)

        XCTAssertEqual(context.settingsStore.reviewPromptEventDates, [context.now])
        XCTAssertEqual(
            try context.model.funnelEventStore.allEvents().last,
            FunnelEvent(
                name: "review_prompt_shown",
                occurredAt: context.now
            )
        )
        XCTAssertNil(
            context.model.reviewPromptRequestDateIfEligible(sessionBlocked: false)
        )
    }

    @MainActor
    func testStoreFailureCallbackBlocksReviewForFiveMinutes() throws {
        let context = try makeEligibleContext()
        XCTAssertNotNil(
            context.model.reviewPromptRequestDateIfEligible(sessionBlocked: false)
        )

        context.model.storeService.onPurchaseOrRestoreFailure?()

        XCTAssertEqual(context.model.purchaseOrRestoreFailedAt, context.now)
        XCTAssertTrue(context.model.purchaseOrRestoreFailedThisSession)
        XCTAssertNil(
            context.model.reviewPromptRequestDateIfEligible(
                sessionBlocked: context.model.purchaseOrRestoreFailedThisSession
            )
        )

        context.clock.now = context.now.addingTimeInterval(5 * 60 - 1)
        XCTAssertTrue(context.model.purchaseOrRestoreFailedThisSession)

        context.clock.now = context.now.addingTimeInterval(5 * 60)
        XCTAssertFalse(context.model.purchaseOrRestoreFailedThisSession)
        XCTAssertNotNil(
            context.model.reviewPromptRequestDateIfEligible(
                sessionBlocked: context.model.purchaseOrRestoreFailedThisSession
            )
        )
    }

    /// 「復元できる購入がありませんでした」も失敗体験として扱う。
    /// アラートを出すだけだと、直後の勝ち画面でレビュー依頼が出て星1につながる
    /// （docs/18 §1・release-monetization-check B-1「課金直後の失敗体験後は出さない」）。
    @MainActor
    func testNothingToRestoreBlocksTheReviewPrompt() throws {
        let context = try makeEligibleContext()
        XCTAssertNotNil(
            context.model.reviewPromptRequestDateIfEligible(sessionBlocked: false)
        )

        context.model.storeService.reportNoRestorablePurchase()

        XCTAssertNotNil(context.model.storeService.alertMessage)
        XCTAssertEqual(context.model.purchaseOrRestoreFailedAt, context.now)
        XCTAssertTrue(context.model.purchaseOrRestoreFailedThisSession)
        XCTAssertNil(
            context.model.reviewPromptRequestDateIfEligible(
                sessionBlocked: context.model.purchaseOrRestoreFailedThisSession
            )
        )
    }

    /// 自動更新オフはiOS設定側で起きるためTransactionが流れない。
    /// 復帰のたびに権利を取り直さないと、プロセスが生きている限り解約を検知できず、
    /// 解約セーブ通知（docs/18 §4）が一度も予約されないまま期限を過ぎる。
    @MainActor
    func testForegroundRefreshReResolvesEntitlement() async throws {
        let context = try makeEligibleContext()

        await context.model.refreshEntitlementOnForeground().value
        XCTAssertTrue(context.model.storeService.hasResolvedEntitlement)

        let revisionBeforeResume = context.model.storeService.entitlementRevision
        await context.model.refreshEntitlementOnForeground().value

        XCTAssertGreaterThan(
            context.model.storeService.entitlementRevision,
            revisionBeforeResume
        )
    }

    func testFeedbackEmailContainsEncodedVersionedSubject() throws {
        let url = try XCTUnwrap(AppURLs.feedbackEmail(appVersion: "1.2.3"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, AppURLs.supportEmail)
        XCTAssertEqual(
            components.queryItems,
            [URLQueryItem(name: "subject", value: "DopaBreak フィードバック (v1.2.3)")]
        )
        XCTAssertTrue(url.absoluteString.contains("%E3%83%95%E3%82%A3%E3%83%BC%E3%83%89%E3%83%90%E3%83%83%E3%82%AF"))
    }

    @MainActor
    private func makeEligibleContext() throws -> ReviewTestContext {
        let clock = ReviewTestClock(now: Date(timeIntervalSince1970: 1_800_000_000))
        let now = clock.now
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetentionReviewIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        let suiteName = "RetentionReviewIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: containerURL)
        }

        let provider = ReviewTestContainer(url: containerURL)
        let logStore = try SQLiteLogStore(containerProvider: provider)
        let ruleID = UUID()
        for index in 0..<5 {
            let timestamp = now.addingTimeInterval(TimeInterval(-3_600 - index))
            try logStore.insert(
                AttemptLog(
                    id: UUID(),
                    ruleId: ruleID,
                    startedAt: timestamp,
                    completedAt: timestamp,
                    decision: .cancelled,
                    intent: .unconscious,
                    selectedDurationSeconds: nil,
                    attemptCount24h: index + 1,
                    opened: false
                )
            )
        }

        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.firstLaunchDate = now.addingTimeInterval(-3 * 24 * 60 * 60)
        let model = AppModel(
            containerProvider: provider,
            settingsStore: settingsStore,
            now: { clock.now }
        )
        return ReviewTestContext(
            model: model,
            settingsStore: settingsStore,
            now: now,
            clock: clock
        )
    }
}

private struct ReviewTestContext {
    let model: AppModel
    let settingsStore: SettingsStore
    let now: Date
    let clock: ReviewTestClock
}

private final class ReviewTestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private struct ReviewTestContainer: ContainerProviding {
    let url: URL

    func containerURL() throws -> URL {
        url
    }
}
