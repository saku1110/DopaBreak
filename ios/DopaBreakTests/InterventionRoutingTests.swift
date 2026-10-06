import DopaBreakCore
import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak

@MainActor
final class InterventionRoutingTests: XCTestCase {
    private func hardBlockSelection() throws -> Data {
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [try JSONDecoder().decode(ApplicationToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8))]
        return try JSONEncoder().encode(selection)
    }

    func testHardBlockDiscardsShortcutAndDirectRequestsIncludingAllowance() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        var now = Date(timeIntervalSince1970: 10_000)
        let model = context.makeModel(now: { now })
        try model.setTargetCatalogIDs(["instagram"])
        model.requestStartIntervention(catalogID: "instagram")
        XCTAssertNotNil(model.pendingInterventionTarget)
        try context.snapshotStore.write(DeepFocusShieldSnapshot(
            selectionDataList: [], sessionSelectionDataList: [try hardBlockSelection()],
            schedule: .disabled,
            session: DeepFocusSession(startedAt: now, endsAt: now.addingTimeInterval(60)),
            updatedAt: now), to: .deepFocusShieldSnapshot)
        model.catalogAllowanceStore.grant(catalogID: "instagram", until: now.addingTimeInterval(300))
        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingStartInterventionRequestedAt = now
        model.consumePendingInterventionRequest(from: context.settingsStore)
        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertNil(context.settingsStore.pendingStartInterventionRequestedAt)
        model.requestStartIntervention(catalogID: "instagram")
        XCTAssertNil(model.pendingInterventionTarget)
        model.requestPassThrough(catalogID: "instagram", until: now.addingTimeInterval(300))
        XCTAssertNil(model.pendingInterventionTarget)
        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)
        XCTAssertNil(model.pendingInterventionTarget)
        now = now.addingTimeInterval(60)
        model.consumePendingInterventionRequest(from: context.settingsStore)
        XCTAssertNil(model.pendingInterventionTarget, "Discarded requests must not replay when the block ends")
        model.requestStartIntervention(catalogID: "instagram")
        XCTAssertNotNil(model.pendingInterventionTarget)
    }

    func testNightBlockSuppressesOnlyInsideWindowAndRespectsRemoval() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = Date(timeIntervalSince1970: 0)
        try context.snapshotStore.write(NightShieldSnapshot(
            selectionDataList: [try hardBlockSelection()], bedTimeMinutes: 23 * 60,
            wakeTimeMinutes: 7 * 60, updatedAt: midnight), to: .nightShieldSnapshot)
        XCTAssertTrue(ReinterventionShield.suppressesIntervention(
            snapshotStore: context.snapshotStore, now: midnight, calendar: calendar))
        XCTAssertFalse(ReinterventionShield.suppressesIntervention(
            snapshotStore: context.snapshotStore, now: midnight.addingTimeInterval(7 * 3600), calendar: calendar))
        try FileManager.default.removeItem(at: context.snapshotStore.url(for: .nightShieldSnapshot))
        XCTAssertFalse(ReinterventionShield.suppressesIntervention(
            snapshotStore: context.snapshotStore, now: midnight, calendar: calendar))
    }

    func testHardBlockScheduleCategoryAndNonApplicationSelections() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 3600)
        var selection = FamilyActivitySelection()
        selection.categoryTokens = [try JSONDecoder().decode(ActivityCategoryToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8))]
        var snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [try JSONEncoder().encode(selection)],
            schedule: DeepFocusSchedule(isEnabled: true, weekdays: [1, 2, 3, 4, 5, 6, 7],
                                       startMinutes: 60, endMinutes: 120),
            session: nil, updatedAt: now)
        try context.snapshotStore.write(snapshot, to: .deepFocusShieldSnapshot)
        XCTAssertTrue(ReinterventionShield.suppressesIntervention(
            snapshotStore: context.snapshotStore, now: now, calendar: calendar))
        XCTAssertFalse(ReinterventionShield.suppressesIntervention(
            snapshotStore: context.snapshotStore, now: now.addingTimeInterval(-1), calendar: calendar))
        XCTAssertFalse(ReinterventionShield.suppressesIntervention(
            snapshotStore: context.snapshotStore, now: now.addingTimeInterval(3600), calendar: calendar))
        selection.categoryTokens = []
        selection.webDomainTokens = [try JSONDecoder().decode(WebDomainToken.self,
            from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8))]
        for data in [try JSONEncoder().encode(selection), try JSONEncoder().encode(FamilyActivitySelection()), Data([0xff])] {
            snapshot.selectionDataList = [data]
            try context.snapshotStore.write(snapshot, to: .deepFocusShieldSnapshot)
            XCTAssertFalse(ReinterventionShield.suppressesIntervention(
                snapshotStore: context.snapshotStore, now: now, calendar: calendar))
        }
    }

    func testAmbiguousShortcutDoesNotVerifyTikTokAndExplicitXVerifiesOnlyX() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        context.settingsStore.entitlementCachedIsPro = true
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["tiktok", "x"])
        XCTAssertEqual(try model.targetStore.selectedCatalogIDs(), ["tiktok", "x"])
        context.settingsStore.pendingStartInterventionAutoResolve = true
        context.settingsStore.pendingStartInterventionRequestedAt = Date()
        model.consumePendingInterventionRequest(from: context.settingsStore)
        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertTrue(context.settingsStore.verifiedAutomationCatalogIDs.isEmpty)
        XCTAssertNotNil(model.alertMessage)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)

        context.settingsStore.pendingStartInterventionCatalogID = "x"
        context.settingsStore.pendingStartInterventionRequestedAt = Date()
        model.consumePendingInterventionRequest(from: context.settingsStore)
        XCTAssertEqual(model.pendingInterventionTarget, SNSAppCatalog.app(catalogID: "x").map(InterventionTarget.catalog))
        XCTAssertEqual(context.settingsStore.verifiedAutomationCatalogIDs, ["x"])
    }

    func testOnboardingDoesNotVerifyAmbiguousShortcut() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        context.settingsStore.entitlementCachedIsPro = true
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["tiktok", "x"])
        context.settingsStore.pendingStartInterventionAutoResolve = true
        context.settingsStore.pendingStartInterventionRequestedAt = Date()
        XCTAssertNil(model.consumeAutomationVerificationOnly(from: context.settingsStore))
        XCTAssertTrue(context.settingsStore.verifiedAutomationCatalogIDs.isEmpty)
        XCTAssertNotNil(model.alertMessage)
    }

    func testExplicitShortcutTargetWinsOverAutoResolve() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        try model.setTargetCatalogIDs(["instagram", "youtube"])
        context.settingsStore.pendingStartInterventionCatalogID = "youtube"
        context.settingsStore.pendingStartInterventionAutoResolve = true
        context.settingsStore.pendingStartInterventionRequestedAt = Date()

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "youtube").map(InterventionTarget.catalog)
        )
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testAutoResolveWithoutSelectionClearsRequestWithoutPresentation() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()
        context.settingsStore.pendingStartInterventionAutoResolve = true
        context.settingsStore.pendingStartInterventionRequestedAt = Date()

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testModelInitializationVerifiesPendingRequestBeforeOnboardingCompletion() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        try InterventionTargetStore(snapshotStore: context.snapshotStore)
            .setTargets(["instagram"])
        context.settingsStore.pendingStartInterventionAutoResolve = true
        context.settingsStore.pendingStartInterventionRequestedAt = Date()

        let model = context.makeModel()

        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertEqual(context.settingsStore.verifiedAutomationCatalogIDs, ["instagram"])
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testModelInitializationStartsPendingInterventionAfterOnboardingCompletion() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        context.settingsStore.onboardingCompleted = true
        try InterventionTargetStore(snapshotStore: context.snapshotStore)
            .setTargets(["instagram"])
        context.settingsStore.pendingStartInterventionAutoResolve = true
        context.settingsStore.pendingStartInterventionRequestedAt = Date()

        let model = context.makeModel()

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "instagram").map(InterventionTarget.catalog)
        )
        XCTAssertNil(context.settingsStore.pendingStartInterventionCatalogID)
        XCTAssertFalse(context.settingsStore.pendingStartInterventionAutoResolve)
    }

    func testActiveCatalogAllowanceRequestsPassThrough() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })
        try model.setTargetCatalogIDs(["instagram"])
        model.catalogAllowanceStore.grant(
            catalogID: "instagram",
            until: now.addingTimeInterval(600)
        )

        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "instagram").map {
                .catalogPassThrough($0, until: now.addingTimeInterval(600))
            }
        )
    }

    func testExpiredPassThroughFallsBackToIntervention() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })

        model.requestPassThrough(
            catalogID: "instagram",
            until: now.addingTimeInterval(-0.001)
        )

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "instagram").map(InterventionTarget.catalog)
        )
    }

    func testNonTargetAutomationDistinguishesRemovedTarget() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()

        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)

        XCTAssertEqual(
            model.pendingNonTargetAutomation,
            NonTargetAutomation(catalogID: "instagram", reason: .removed)
        )
        XCTAssertNil(model.pendingInterventionTarget)
    }

    func testNonTargetAutomationDistinguishesEntitlementClamp() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        context.clampBackupStore.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )
        context.clampBackupStore.commitClamp(appliedCatalogIDs: ["instagram"])
        let model = context.makeModel()
        try InterventionTargetStore(snapshotStore: context.snapshotStore).setTargets(["instagram"])

        model.consumeInterventionRequest(catalogID: "youtube", settingsStore: context.settingsStore)

        XCTAssertEqual(
            model.pendingNonTargetAutomation,
            NonTargetAutomation(catalogID: "youtube", reason: .clampedByEntitlement)
        )
    }

    /// 「そのまま開く」で戻った先の再発火は自己起動として捨てる。
    /// 記録しないと同じ説明シートが返り続ける（自動化は本体からは消せない）。
    func testNonTargetAutomationSelfOpenSuppressesRepeatedSheet() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })

        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)
        XCTAssertEqual(
            model.pendingNonTargetAutomation,
            NonTargetAutomation(catalogID: "instagram", reason: .removed)
        )

        // RootTabViewの「そのまま開く」と同じ順序で、自己起動を記録してからシートを閉じる。
        model.markSelfOpened(catalogID: "instagram")
        model.pendingNonTargetAutomation = nil
        XCTAssertEqual(context.settingsStore.lastSelfOpenedCatalogID, "instagram")
        XCTAssertEqual(context.settingsStore.lastSelfOpenedAt, now)

        // 対象アプリが前面に戻ると、残った自動化がもう一度要求を書く。
        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingStartInterventionRequestedAt = now
        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertNil(model.pendingNonTargetAutomation)
        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertEqual(
            try model.funnelEventStore.allEvents().last,
            FunnelEvent(
                name: FunnelEventName.automationRequestDiscarded.rawValue,
                detail: "self_open",
                occurredAt: now
            )
        )
    }

    func testNonTargetAutomationWithoutSelfOpenRecordShowsSheetAgain() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })

        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)
        model.pendingNonTargetAutomation = nil

        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingStartInterventionRequestedAt = now
        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertEqual(
            model.pendingNonTargetAutomation,
            NonTargetAutomation(catalogID: "instagram", reason: .removed)
        )
    }

    func testPassThroughFlowDoesNotCreateAttemptOrReflection() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })
        let target = try XCTUnwrap(SNSAppCatalog.app(catalogID: "safari"))
        let flow = InterventionFlowModel(
            target: .catalogPassThrough(target, until: now.addingTimeInterval(600)),
            model: model,
            settingsStore: context.settingsStore
        )

        flow.start()
        XCTAssertEqual(flow.stage, .passingThrough(remainingMinutes: 10))
        try await Task.sleep(for: .milliseconds(650))

        let logStore = try SQLiteLogStore(containerProvider: FixedContainer(url: context.containerURL))
        XCTAssertTrue(try logStore.fetchAttempts(from: .distantPast, to: .distantFuture).isEmpty)
        XCTAssertNil(try model.interventionEngine?.pendingReflection())
    }

    func testPassThroughOpenCompletionDiscardsMatchingPendingTarget() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })
        let catalogTarget = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let target = InterventionTarget.catalogPassThrough(
            catalogTarget,
            until: now.addingTimeInterval(600)
        )
        model.pendingInterventionTarget = target
        var openCompletion: (@MainActor @Sendable (Bool) -> Void)?
        let flow = InterventionFlowModel(
            target: target,
            model: model,
            settingsStore: context.settingsStore,
            openURL: { _, completion in openCompletion = completion }
        )

        flow.start()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertNotNil(openCompletion)
        XCTAssertEqual(context.settingsStore.lastSelfOpenedCatalogID, "instagram")
        XCTAssertEqual(context.settingsStore.lastSelfOpenedAt, now)

        openCompletion?(true)

        XCTAssertNil(model.pendingInterventionTarget)
    }

    func testExpiredPassThroughIsNotEligibleForPresentation() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let catalogTarget = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let target = InterventionTarget.catalogPassThrough(catalogTarget, until: now)

        XCTAssertNil(
            InterventionTargetPresentationPolicy.validatedTarget(target, now: now)
        )
    }

    func testRootInitializationLeavesExpiredPassThroughForActivePresentationValidation() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })
        let catalogTarget = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let target = InterventionTarget.catalogPassThrough(catalogTarget, until: now)
        model.pendingInterventionTarget = target

        _ = RootTabView(
            model: model,
            settingsStore: context.settingsStore,
            onResetOnboarding: {}
        )

        XCTAssertEqual(model.pendingInterventionTarget, target)
    }

    func testReflectionDestinationSuppressesActivePassThroughCandidate() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })
        try model.setTargetCatalogIDs(["instagram"])
        model.catalogAllowanceStore.grant(
            catalogID: "instagram",
            until: now.addingTimeInterval(600)
        )
        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingStartInterventionRequestedAt = now
        context.settingsStore.pendingNotificationDestination = PendingNotificationDestination(
            destination: .reflection,
            writtenAt: now
        )

        let suppressPassThrough = ReflectionInterventionPriority.shouldSuppressPassThrough(
            for: context.settingsStore.pendingNotificationDestination,
            now: now
        )

        model.consumePendingInterventionRequest(
            from: context.settingsStore,
            suppressPassThrough: suppressPassThrough
        )

        XCTAssertTrue(suppressPassThrough)
        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertTrue(context.settingsStore.isAutomationVerified(catalogID: "instagram"))
    }

    func testSelfOpenedAutomationRequestIsVerifiedThenDiscarded() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel(now: { now })
        try model.setTargetCatalogIDs(["instagram"])
        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingStartInterventionRequestedAt = now
        context.settingsStore.lastSelfOpenedCatalogID = "instagram"
        context.settingsStore.lastSelfOpenedAt = now.addingTimeInterval(-1)

        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertNil(model.pendingInterventionTarget)
        XCTAssertTrue(context.settingsStore.isAutomationVerified(catalogID: "instagram"))
        XCTAssertNil(context.settingsStore.lastSelfOpenedCatalogID)
        XCTAssertNil(context.settingsStore.lastSelfOpenedAt)
        XCTAssertEqual(
            try model.funnelEventStore.allEvents().last,
            FunnelEvent(
                name: FunnelEventName.automationRequestDiscarded.rawValue,
                detail: "self_open",
                occurredAt: now
            )
        )

        context.settingsStore.pendingStartInterventionCatalogID = "instagram"
        context.settingsStore.pendingStartInterventionRequestedAt = now
        model.consumePendingInterventionRequest(from: context.settingsStore)

        XCTAssertEqual(
            model.pendingInterventionTarget,
            SNSAppCatalog.app(catalogID: "instagram").map(InterventionTarget.catalog)
        )
    }

    func testDeferredReflectionRestoresOnlyUnansweredReflectionWithoutTimeWindow() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let deferred = ReflectionLog(
            id: UUID(),
            attemptLogId: nil,
            ruleId: UUID(),
            promptedAt: now.addingTimeInterval(-3 * 60 * 60),
            answeredAt: nil,
            trigger: .notification,
            satisfaction: nil,
            happinessDelta: nil,
            skipped: false,
            createdAt: now.addingTimeInterval(-4 * 60 * 60)
        )

        XCTAssertTrue(
            ReflectionDeferralPolicy.shouldRestore(
                pendingReflection: nil,
                deferredReflection: deferred
            )
        )
        XCTAssertFalse(
            ReflectionDeferralPolicy.shouldRestore(
                pendingReflection: deferred,
                deferredReflection: deferred
            )
        )
        XCTAssertFalse(
            ReflectionDeferralPolicy.shouldRestore(
                pendingReflection: nil,
                deferredReflection: ReflectionLog(
                    id: deferred.id,
                    attemptLogId: deferred.attemptLogId,
                    ruleId: deferred.ruleId,
                    promptedAt: deferred.promptedAt,
                    answeredAt: now,
                    trigger: deferred.trigger,
                    satisfaction: .satisfied,
                    happinessDelta: .increased,
                    skipped: false,
                    createdAt: deferred.createdAt
                )
            )
        )
        XCTAssertFalse(
            ReflectionDeferralPolicy.shouldRestore(
                pendingReflection: nil,
                deferredReflection: ReflectionLog(
                    id: deferred.id,
                    attemptLogId: deferred.attemptLogId,
                    ruleId: deferred.ruleId,
                    promptedAt: deferred.promptedAt,
                    answeredAt: nil,
                    trigger: deferred.trigger,
                    satisfaction: nil,
                    happinessDelta: nil,
                    skipped: true,
                    createdAt: deferred.createdAt
                )
            )
        )
    }

    func testPurchaseContinuationPolicyResolvesTargetAndMode() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(
            PurchaseContinuationPolicy.action(
                for: .addTarget(catalogID: "youtube", createdAt: now),
                isPro: true,
                canAddTarget: true,
                selectedCatalogIDs: ["instagram"],
                now: now
            ),
            .addTargets(["instagram", "youtube"])
        )
        XCTAssertEqual(
            PurchaseContinuationPolicy.action(
                for: .applyMode(.deepFocus, createdAt: now),
                isPro: true,
                canAddTarget: true,
                selectedCatalogIDs: [],
                now: now
            ),
            .applyMode(.deepFocus)
        )
        XCTAssertNil(
            PurchaseContinuationPolicy.action(
                for: .addTarget(catalogID: "youtube", createdAt: now),
                isPro: false,
                canAddTarget: true,
                selectedCatalogIDs: [],
                now: now
            )
        )
    }

    func testPurchaseContinuationKeepsRestoredClampSelectionWithoutDuplicates() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertEqual(
            PurchaseContinuationPolicy.action(
                for: .addTarget(catalogID: "youtube", createdAt: now),
                isPro: true,
                canAddTarget: true,
                selectedCatalogIDs: ["instagram", "youtube", "x"],
                now: now
            ),
            .addTargets(["instagram", "youtube", "x"])
        )
    }

    func testPurchaseContinuationExpiresAfterThirtyMinutes() {
        let createdAt = Date(timeIntervalSince1970: 10_000)

        XCTAssertNil(
            PurchaseContinuationPolicy.action(
                for: .addTarget(catalogID: "youtube", createdAt: createdAt),
                isPro: true,
                canAddTarget: true,
                selectedCatalogIDs: ["instagram"],
                now: createdAt.addingTimeInterval(30 * 60 + 0.001)
            )
        )
    }

    func testAppModelExposesBlockConfigurationAndSeedsWakeSleepDefaults() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let screenTime = ScreenTimeCenter(authorizationStatusProvider: { .approved })
        let selectionData = try JSONEncoder().encode(FamilyActivitySelection())
        try RuleStore(snapshotStore: context.snapshotStore).saveFamilyActivitySelection(
            selectionData,
            name: "SNS",
            mode: .nightOnly
        )
        let model = context.makeModel(screenTimeCenter: screenTime)

        model.ensureWakeSleepDefaults()
        model.refresh()

        XCTAssertEqual(model.screenTimeAuthorizationStatus, .approved)
        XCTAssertEqual(model.blockTargetRuleCount, 1)
        XCTAssertTrue(model.isBlockConfigured)
        XCTAssertEqual(context.settingsStore.wakeTimeMinutes, 420)
        XCTAssertEqual(context.settingsStore.bedTimeMinutes, 1_380)
    }

    func testBlockedAppSelectionRequiresPro() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let model = context.makeModel()

        XCTAssertFalse(model.saveBlockedAppSelection(FamilyActivitySelection(), mode: .standard))
        XCTAssertTrue(try model.ruleStore.allRules().isEmpty)
        XCTAssertNil(model.alertMessage)
    }

    func testOverlayStateRecreatesForChangedTargetAndDismisses() throws {
        let instagram = try XCTUnwrap(SNSAppCatalog.app(catalogID: "instagram"))
        let youtube = try XCTUnwrap(SNSAppCatalog.app(catalogID: "youtube"))
        var state = InterventionOverlayPresentationState()

        state.present(.catalog(instagram))
        let firstFlowID = try XCTUnwrap(state.flowID)
        state.present(.catalog(youtube))

        XCTAssertEqual(state.target, .catalog(youtube))
        XCTAssertNotEqual(state.flowID, firstFlowID)

        state.dismiss()
        XCTAssertNil(state.target)
        XCTAssertNil(state.flowID)
    }

    func testInterventionPresentationPrioritizesExistingModals() {
        XCTAssertEqual(
            InterventionPresentationPolicy.directive(
                awaitingModalDismissal: nil,
                isLockScreenCheckPresented: true,
                isPaywallPresented: false,
                isReflectionPresented: false
            ),
            .dismissLockScreenCheck
        )
        XCTAssertEqual(
            InterventionPresentationPolicy.directive(
                awaitingModalDismissal: nil,
                isLockScreenCheckPresented: false,
                isPaywallPresented: true,
                isReflectionPresented: false
            ),
            .dismissPaywall
        )
        XCTAssertEqual(
            InterventionPresentationPolicy.directive(
                awaitingModalDismissal: nil,
                isLockScreenCheckPresented: false,
                isPaywallPresented: false,
                isReflectionPresented: true
            ),
            .dismissReflection
        )
        XCTAssertEqual(
            InterventionPresentationPolicy.directive(
                awaitingModalDismissal: .reflection,
                isLockScreenCheckPresented: false,
                isPaywallPresented: false,
                isReflectionPresented: false
            ),
            .waitForModalDismissal
        )
        XCTAssertEqual(
            InterventionPresentationPolicy.directive(
                awaitingModalDismissal: nil,
                isLockScreenCheckPresented: false,
                isPaywallPresented: false,
                isReflectionPresented: false
            ),
            .present
        )
    }

    func testBackgroundSnapshotShieldStaysVisibleUntilActiveConsumption() {
        let coordinator = BackgroundSnapshotShieldCoordinator()
        coordinator.handle(scenePhase: .background) {}
        XCTAssertTrue(coordinator.isShieldVisible)

        coordinator.handle(scenePhase: .inactive) {
            XCTFail("inactive must not consume an intervention request")
        }
        XCTAssertTrue(coordinator.isShieldVisible)

        var wasVisibleWhileConsuming = false
        coordinator.handle(scenePhase: .active) {
            wasVisibleWhileConsuming = coordinator.isShieldVisible
        }
        XCTAssertTrue(wasVisibleWhileConsuming)
        XCTAssertFalse(coordinator.isShieldVisible)
    }

    /// 振り返りの着地は3時間まで受ける（`InterventionEngine.reflectionNotificationTapWindow`）。
    ///
    /// 宣言時間の終わりに届く通知は、手が空いてからタップされることが多い。
    /// 既定の30分へ戻すと、素通りの候補が先に通って振り返りが一度も出ないまま畳まれる。
    /// 窓の内と外の両側を固定する（2026-09-04のR3）。
    func testReflectionSuppressionHoldsForTheFullThreeHourTapWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let window = InterventionEngine.reflectionNotificationTapWindow
        XCTAssertEqual(window, 3 * 60 * 60)
        XCTAssertGreaterThan(window, PendingNotificationDestination.validityInterval)

        let justInsideWindow = PendingNotificationDestination(
            destination: .reflection,
            writtenAt: now.addingTimeInterval(-(window - 1))
        )
        XCTAssertTrue(
            ReflectionInterventionPriority.shouldSuppressPassThrough(
                for: justInsideWindow,
                now: now
            )
        )

        // 30分の既定を超えても振り返りだけは受ける。ここが落ちると3時間の窓が効いていない。
        let pastDefaultValidity = PendingNotificationDestination(
            destination: .reflection,
            writtenAt: now.addingTimeInterval(-(PendingNotificationDestination.validityInterval + 1))
        )
        XCTAssertTrue(
            ReflectionInterventionPriority.shouldSuppressPassThrough(
                for: pastDefaultValidity,
                now: now
            )
        )

        let justOutsideWindow = PendingNotificationDestination(
            destination: .reflection,
            writtenAt: now.addingTimeInterval(-(window + 1))
        )
        XCTAssertFalse(
            ReflectionInterventionPriority.shouldSuppressPassThrough(
                for: justOutsideWindow,
                now: now
            )
        )

        // 伸ばしたのは振り返りだけ。他の着地は30分のままで、素通りを止める側にも回らない。
        let statsPastDefaultValidity = PendingNotificationDestination(
            destination: .stats,
            writtenAt: now.addingTimeInterval(-(PendingNotificationDestination.validityInterval + 1))
        )
        XCTAssertFalse(statsPastDefaultValidity.isValid(at: now))
        XCTAssertFalse(
            ReflectionInterventionPriority.shouldSuppressPassThrough(
                for: statsPastDefaultValidity,
                now: now
            )
        )
    }

    func testReinterventionReviewsBeforeExtensionAndDoesNotRepeatAnsweredQuestion() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = try makeContext()
        defer { context.cleanup() }
        let screenTime = ScreenTimeCenter(authorizationStatusProvider: { .approved })
        let model = context.makeModel(screenTimeCenter: screenTime, now: { now })
        try model.setTargetCatalogIDs(["instagram"])
        let engine = try XCTUnwrap(model.interventionEngine)
        try engine.beginIntervention(ruleId: UUID())
        for _ in 0..<4 { _ = try engine.advanceStep() }
        let reflection = try engine.recordCatalogOpen(durationSeconds: 300, deferReflection: true)
        var session = ReinterventionSession(catalogID: "instagram", selectionData: Data(), minutes: 5, now: now.addingTimeInterval(-600))
        session.reachedAt = now
        session.reflectionID = reflection.id
        try model.reinterventionScheduler.store.transaction { $0.sessions["instagram"] = session }
        context.settingsStore.reflectionNotificationEnabled = false
        model.syncReinterventionNotificationPreference()
        XCTAssertEqual(model.reinterventionSession(catalogID: "instagram")?.notificationsEnabled, false)
        model.catalogAllowanceStore.grant(catalogID: "instagram", until: now.addingTimeInterval(3600))
        model.consumeInterventionRequest(catalogID: "instagram", settingsStore: context.settingsStore)
        XCTAssertNil(model.pendingInterventionTarget, "A reached budget must show reflection instead of opening SNS")
        XCTAssertEqual(model.pendingReinterventionReflection()?.id, reflection.id)
        try engine.recordPostUseReflection(id: reflection.id, satisfaction: .fun, happinessDelta: .increased)
        XCTAssertNotNil(model.pendingReinterventionReflection()?.answeredAt, "After relaunch show finish/extend without repeating satisfaction")
        try model.resumeAfterReintervention(catalogID: "instagram")
        XCTAssertNil(model.pendingReinterventionReflection())
        XCTAssertEqual(model.pendingInterventionTarget, .catalog(SNSAppCatalog.app(catalogID: "instagram")!))
        let flow = InterventionFlowModel(target: .catalog(SNSAppCatalog.app(catalogID: "instagram")!), model: model, settingsStore: context.settingsStore)
        flow.start()
        flow.completeBreathingForTesting()
        XCTAssertEqual(flow.stage, .durationSelection, "Extension does not repeat the first-use reason question")
        try model.finishReintervention(catalogID: "instagram")
        XCTAssertNil(model.reinterventionSession(catalogID: "instagram"))
    }

    func testNecessaryTasksDefaultToUntimedWithoutReflectionOrPersistentBypass() throws {
        for reason: InterventionReason in [.work, .research, .communication, .posting] {
            let context = try makeContext()
            defer { context.cleanup() }
            let model = context.makeModel()
            try model.setTargetCatalogIDs(["instagram"])
            try model.reinterventionScheduler.store.transaction { $0.selections["instagram"] = Data([1]) }
            var opened = false
            let flow = InterventionFlowModel(target: .catalog(SNSAppCatalog.app(catalogID: "instagram")!), model: model, settingsStore: context.settingsStore,
                openURL: { _, completion in opened = true; completion(true) })
            flow.start(); flow.completeBreathingForTesting(); flow.selectReason(reason)
            XCTAssertTrue(flow.usesTimeLimit)
            flow.usesTimeLimit = false
            flow.confirmSelectedDuration()
            XCTAssertTrue(opened, "Untimed use must not require a monitoring registration")
            let log = try SQLiteLogStore(containerProvider: FixedContainer(url: context.containerURL))
            XCTAssertTrue(try log.fetchReflections().isEmpty)
            let attempt = try XCTUnwrap(log.fetchAttempts().first)
            XCTAssertEqual(attempt.intent, reason.intentCategory)
            XCTAssertNil(attempt.selectedDurationSeconds)
            XCTAssertNil(model.reinterventionSession(catalogID: "instagram"))
            XCTAssertTrue(model.isReinterventionConnected(catalogID: "instagram"))
            XCTAssertNil(model.catalogAllowanceStore.activeAllowance(catalogID: "instagram", at: Date()))
        }
    }

    func testNecessaryTaskCanOptIntoTimeAndCasualUseDefaultsToTime() throws {
        for reason: InterventionReason in [.work, .boredom, .unconscious] {
            let context = try makeContext()
            defer { context.cleanup() }
            let model = context.makeModel()
            try model.setTargetCatalogIDs(["instagram"])
            let flow = InterventionFlowModel(target: .catalog(SNSAppCatalog.app(catalogID: "instagram")!), model: model, settingsStore: context.settingsStore,
                openURL: { _, completion in completion(true) })
            flow.start(); flow.completeBreathingForTesting(); flow.selectReason(reason)
            if reason == .work { flow.usesTimeLimit = true }
            else { XCTAssertTrue(flow.usesTimeLimit); flow.chooseOpen() }
            flow.chooseDuration(.fiveMinutes); flow.confirmSelectedDuration()
            let log = try SQLiteLogStore(containerProvider: FixedContainer(url: context.containerURL))
            XCTAssertEqual(try log.fetchReflections().count, reason == .work ? 0 : 1)
            XCTAssertEqual(try log.fetchAttempts().first?.selectedDurationSeconds, 300)
        }
    }

    func testContinueNecessaryTaskSkipsQuestionAndPreservesConnectionAndHardSession() throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let now = Date()
        let model = context.makeModel(now: { now })
        try model.setTargetCatalogIDs(["instagram"])
        let engine = try XCTUnwrap(model.interventionEngine)
        try engine.beginIntervention(ruleId: UUID())
        for _ in 0..<4 { _ = try engine.advanceStep() }
        let reflection = try engine.recordCatalogOpen(durationSeconds: 300, deferReflection: true)
        var session = ReinterventionSession(catalogID: "instagram", selectionData: Data([1]), minutes: 5, now: now.addingTimeInterval(-600))
        session.reachedAt = now; session.reflectionID = reflection.id
        try model.reinterventionScheduler.store.transaction {
            $0.selections["instagram"] = Data([1]); $0.sessions["instagram"] = session
        }
        let hard = DeepFocusSession(startedAt: now, endsAt: now.addingTimeInterval(3600), isStrict: true)
        context.settingsStore.deepFocusSession = hard
        try model.continueWithoutReintervention(catalogID: "instagram")
        XCTAssertNil(model.pendingReinterventionReflection())
        XCTAssertNil(model.reinterventionSession(catalogID: "instagram"))
        XCTAssertTrue(model.isReinterventionConnected(catalogID: "instagram"))
        XCTAssertEqual(context.settingsStore.deepFocusSession, hard)
        XCTAssertNil(model.catalogAllowanceStore.activeAllowance(catalogID: "instagram", at: now))
        let log = try SQLiteLogStore(containerProvider: FixedContainer(url: context.containerURL))
        XCTAssertTrue(try XCTUnwrap(log.reflection(id: reflection.id)).skipped)
        let target = try XCTUnwrap(model.pendingInterventionTarget)
        let flow = InterventionFlowModel(target: target, model: model, settingsStore: context.settingsStore)
        XCTAssertTrue(flow.isUntimedPassThrough)
    }

    func testReleaseR11RemovalAndPermissionRevocationCleanReachedAndPendingSessions() throws {
        for removeTarget in [false, true] {
            for reached in [false, true] {
                let context = try makeContext()
                defer { context.cleanup() }
                var authorized = true
                let now = Date(timeIntervalSince1970: 1_800_000_000)
                let model = context.makeModel(screenTimeCenter: ScreenTimeCenter(authorizationStatusProvider: { authorized ? .approved : .denied }), now: { now })
                try model.setTargetCatalogIDs(["instagram"])
                var session = ReinterventionSession(catalogID: "instagram", selectionData: Data(), minutes: 5, now: now.addingTimeInterval(-600))
                if reached { session.reachedAt = now.addingTimeInterval(-1) }
                try model.reinterventionScheduler.store.transaction {
                    $0.selections["instagram"] = Data()
                    $0.sessions["instagram"] = session
                }
                model.catalogAllowanceStore.grant(catalogID: "instagram", until: session.expiresAt)
                if removeTarget { try model.setTargetCatalogIDs([]) }
                else { authorized = false }
                model.refresh(scheduleNotifications: false)
                XCTAssertNil(model.reinterventionSession(catalogID: "instagram"))
                XCTAssertNil(model.catalogAllowanceStore.activeAllowance(catalogID: "instagram", at: now))
                if removeTarget { XCTAssertFalse(model.isReinterventionConnected(catalogID: "instagram")) }
                authorized = true
                model.refresh(scheduleNotifications: false)
                XCTAssertNil(model.reinterventionSession(catalogID: "instagram"), "Old block must not resurrect after permission restoration")
            }
        }
    }

    func testReleaseR14ExpiryCleansUnreachedAndReachedSessionsAndPreservesConnection() throws {
        for reached in [false, true] {
            let context = try makeContext()
            defer { context.cleanup() }
            let start = Date(timeIntervalSince1970: 1_800_000_000)
            var clock = start
            let model = context.makeModel(screenTimeCenter: ScreenTimeCenter(authorizationStatusProvider: { .approved }), now: { clock })
            try model.setTargetCatalogIDs(["instagram"])
            var session = ReinterventionSession(catalogID: "instagram", selectionData: Data(), minutes: 5, now: start)
            if reached { session.reachedAt = start.addingTimeInterval(300) }
            try model.reinterventionScheduler.store.transaction {
                $0.selections["instagram"] = Data()
                $0.sessions["instagram"] = session
            }
            clock = session.expiresAt.addingTimeInterval(-1)
            model.refresh(scheduleNotifications: false)
            XCTAssertNotNil(model.reinterventionSession(catalogID: "instagram"))
            clock = session.expiresAt
            model.refresh(scheduleNotifications: false)
            XCTAssertNil(model.reinterventionSession(catalogID: "instagram"))
            XCTAssertTrue(model.isReinterventionConnected(catalogID: "instagram"))
            model.refresh(scheduleNotifications: false)
            XCTAssertNil(model.pendingReinterventionReflection())
            XCTAssertNil(model.reinterventionSession(catalogID: "instagram"))
        }
    }

    private func makeContext() throws -> InterventionRoutingTestContext {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InterventionRoutingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let suiteName = "InterventionRoutingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return InterventionRoutingTestContext(
            containerURL: containerURL,
            suiteName: suiteName,
            settingsStore: SettingsStore(userDefaults: defaults)
        )
    }
}

@MainActor
private struct InterventionRoutingTestContext {
    let containerURL: URL
    let suiteName: String
    let settingsStore: SettingsStore

    var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    var clampBackupStore: TargetClampBackupStore {
        TargetClampBackupStore(userDefaults: defaults)
    }

    var snapshotStore: JSONSnapshotStore {
        JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
    }

    func makeModel(
        screenTimeCenter: ScreenTimeCenter? = nil,
        now: @escaping () -> Date = { Date() }
    ) -> AppModel {
        AppModel(
            containerProvider: FixedContainer(url: containerURL),
            settingsStore: settingsStore,
            clampBackupStore: clampBackupStore,
            catalogAllowanceStore: CatalogAllowanceStore(userDefaults: defaults),
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false,
            screenTimeCenter: screenTimeCenter,
            now: now
        )
    }

    func cleanup() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: containerURL)
    }
}
