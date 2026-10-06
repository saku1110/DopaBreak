import Foundation
import XCTest
@testable import DopaBreakCore

final class InterventionEngineTests: XCTestCase {
    // MARK: - Happy paths

    func testFullHappyPathCancel() throws {
        var clock = date(0)
        let ctx = try makeContext(now: { clock })
        let rule = uuid(900)

        try ctx.engine.beginIntervention(ruleId: rule)
        XCTAssertEqual(try ctx.engine.currentStep(), .shieldPresented)
        XCTAssertEqual(try ctx.engine.advanceStep(), .breathing)
        XCTAssertEqual(try ctx.engine.advanceStep(), .usageSummary)
        XCTAssertEqual(try ctx.engine.advanceStep(), .intentSelection)
        XCTAssertEqual(try ctx.engine.advanceStep(), .decision)
        try ctx.engine.recordIntent(.boredom)

        clock = date(30)
        let reclaimedSeconds = try ctx.engine.recordCancel()

        XCTAssertEqual(try ctx.engine.currentStep(), .idle)
        let attempts = try ctx.log.fetchAttempts()
        XCTAssertEqual(attempts.count, 1)
        let attempt = try XCTUnwrap(attempts.first)
        XCTAssertEqual(attempt.decision, .cancelled)
        XCTAssertFalse(attempt.opened)
        XCTAssertEqual(attempt.intent, .boredom)
        XCTAssertEqual(attempt.ruleId, rule)
        XCTAssertEqual(attempt.startedAt, date(0))
        XCTAssertEqual(attempt.completedAt, date(30))
        XCTAssertNil(attempt.selectedDurationSeconds)
        XCTAssertEqual(attempt.attemptCount24h, 1)
        XCTAssertEqual(try ctx.log.fetchReflections(), [], "cancel does not create a reflection")
        XCTAssertEqual(try ctx.log.reclaimedLedgerEntryCount(), 1)
        XCTAssertEqual(try StatsService(logStore: ctx.log).reclaimedSecondsAllTime(), 300)
        XCTAssertEqual(reclaimedSeconds, 300, "the UI must receive the exact persisted ledger value")
    }

    func testFullHappyPathOpenExpireReshieldReflectionAnswer() throws {
        var clock = date(0)
        let ctx = try makeContext(now: { clock })
        let rule = uuid(901)

        try ctx.engine.beginIntervention(ruleId: rule)
        for _ in 0..<4 { _ = try ctx.engine.advanceStep() }
        XCTAssertEqual(try ctx.engine.currentStep(), .decision)
        try ctx.engine.recordIntent(.unconscious)

        try ctx.engine.recordOpen(durationSeconds: 300)
        XCTAssertEqual(try ctx.engine.currentStep(), .temporarilyAllowed)
        XCTAssertEqual(try ctx.engine.currentState().allowedUntil, date(300))

        clock = date(100)
        XCTAssertFalse(try ctx.engine.reshieldIfExpired())
        XCTAssertEqual(try ctx.engine.currentStep(), .temporarilyAllowed)

        clock = date(300)
        XCTAssertTrue(try ctx.engine.reshieldIfExpired())
        XCTAssertEqual(try ctx.engine.currentStep(), .reShieldScheduled)

        let pending = try XCTUnwrap(ctx.engine.pendingReflection())
        XCTAssertEqual(pending.trigger, .timedSessionEnded)
        XCTAssertEqual(pending.promptedAt, date(300))
        XCTAssertNil(pending.answeredAt)

        try ctx.engine.recordPostUseReflection(id: pending.id, satisfaction: .lostTime, happinessDelta: .decreased)
        XCTAssertEqual(try ctx.engine.currentStep(), .idle)

        let reflections = try ctx.log.fetchReflections()
        XCTAssertEqual(reflections.count, 1)
        let answered = try XCTUnwrap(reflections.first)
        XCTAssertEqual(answered.satisfaction, .lostTime)
        XCTAssertEqual(answered.happinessDelta, .decreased)
        XCTAssertEqual(answered.answeredAt, date(300))

        let attempt = try XCTUnwrap(ctx.log.fetchAttempts().first)
        XCTAssertTrue(attempt.opened)
        XCTAssertEqual(attempt.decision, .opened)
        XCTAssertEqual(attempt.selectedDurationSeconds, 300)
        XCTAssertEqual(attempt.intent, .unconscious)
        XCTAssertEqual(attempt.id, answered.attemptLogId, "reflection links back to its attempt")
        XCTAssertEqual(try ctx.log.reclaimedLedgerEntryCount(), 0, "opened attempts do not enter the ledger")
    }

    func testRecordCancelAllowedFromIntentSelection() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(900))
        for _ in 0..<3 { _ = try ctx.engine.advanceStep() }
        XCTAssertEqual(try ctx.engine.currentStep(), .intentSelection)

        try ctx.engine.recordCancel()

        XCTAssertEqual(try ctx.engine.currentStep(), .idle)
        XCTAssertEqual(try ctx.log.fetchAttempts().count, 1)
    }

    func testIntentFirstFlowCanMoveDirectlyToIntentSelection() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(902))

        try ctx.engine.beginIntentSelection()
        XCTAssertEqual(try ctx.engine.currentStep(), .intentSelection)

        try ctx.engine.recordIntent(.workRequired)
        XCTAssertEqual(try ctx.engine.advanceStep(), .decision)
        try ctx.engine.recordOpen(durationSeconds: 600)

        let attempt = try XCTUnwrap(ctx.log.fetchAttempts().first)
        XCTAssertEqual(attempt.intent, .workRequired)
        XCTAssertEqual(attempt.selectedDurationSeconds, 600)
    }

    func testUntimedOpenRecordsNoDurationOrReflectionAndReturnsToIdle() throws {
        let ctx = try makeContext(now: { self.date(0) })
        let rule = uuid(903)

        try ctx.engine.beginIntervention(ruleId: rule)
        try ctx.engine.beginIntentSelection()
        try ctx.engine.recordIntent(.communication)
        _ = try ctx.engine.advanceStep()

        try ctx.engine.recordUntimedOpen()

        XCTAssertEqual(try ctx.engine.currentStep(), .idle)
        let attempt = try XCTUnwrap(ctx.log.fetchAttempts().first)
        XCTAssertEqual(attempt.ruleId, rule)
        XCTAssertEqual(attempt.decision, .opened)
        XCTAssertEqual(attempt.intent, .communication)
        XCTAssertTrue(attempt.opened)
        XCTAssertNil(attempt.selectedDurationSeconds)
        XCTAssertTrue(try ctx.log.fetchReflections().isEmpty)
    }

    func testCatalogOpenRecordsDeclaredDurationAndReflectionWithoutTemporaryAllowance() throws {
        let ctx = try makeContext(now: { self.date(100) })
        let rule = uuid(904)

        try ctx.engine.beginIntervention(ruleId: rule)
        try ctx.engine.beginIntentSelection()
        try ctx.engine.recordIntent(.communication)
        _ = try ctx.engine.advanceStep()

        let recordedReflection = try ctx.engine.recordCatalogOpen(durationSeconds: 600)

        XCTAssertEqual(try ctx.engine.currentStep(), .idle)
        let attempt = try XCTUnwrap(ctx.log.fetchAttempts().first)
        XCTAssertEqual(attempt.ruleId, rule)
        XCTAssertEqual(attempt.selectedDurationSeconds, 600)
        XCTAssertTrue(attempt.opened)
        let reflection = try XCTUnwrap(ctx.log.fetchReflections().first)
        XCTAssertEqual(recordedReflection.id, reflection.id)
        XCTAssertEqual(recordedReflection.promptedAt, date(700))
        XCTAssertEqual(reflection.attemptLogId, attempt.id)
        XCTAssertEqual(reflection.promptedAt, date(700))
        XCTAssertEqual(reflection.createdAt, date(100))
        XCTAssertEqual(reflection.trigger, .timedSessionEnded)
        XCTAssertNil(reflection.satisfaction)
    }

    func testBeginIntentSelectionRejectsNonStartStep() throws {
        let ctx = try makeContext(now: { self.date(0) })

        XCTAssertThrowsError(try ctx.engine.beginIntentSelection()) { error in
            self.assertInvalidTransition(error, from: .idle, action: "beginIntentSelection")
        }
    }

    // MARK: - Invalid transitions

    func testAdvanceStepFromIdleThrows() throws {
        let ctx = try makeContext(now: { self.date(0) })
        XCTAssertThrowsError(try ctx.engine.advanceStep()) { error in
            self.assertInvalidTransition(error, from: .idle, action: "advanceStep")
        }
    }

    func testRecordOpenBeforeDecisionThrows() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(1))
        XCTAssertThrowsError(try ctx.engine.recordOpen(durationSeconds: 300)) { error in
            self.assertInvalidTransition(error, from: .shieldPresented, action: "recordOpen")
        }
    }

    func testRecordUntimedOpenBeforeDecisionThrows() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(1))

        XCTAssertThrowsError(try ctx.engine.recordUntimedOpen()) { error in
            self.assertInvalidTransition(error, from: .shieldPresented, action: "recordUntimedOpen")
        }
    }

    func testRecordIntentFromBreathingThrows() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(1))
        _ = try ctx.engine.advanceStep() // breathing
        XCTAssertThrowsError(try ctx.engine.recordIntent(.research)) { error in
            self.assertInvalidTransition(error, from: .breathing, action: "recordIntent")
        }
    }

    func testBeginInterventionFromActiveStepThrows() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(1))
        _ = try ctx.engine.advanceStep() // breathing
        XCTAssertThrowsError(try ctx.engine.beginIntervention(ruleId: uuid(2))) { error in
            self.assertInvalidTransition(error, from: .breathing, action: "beginIntervention")
        }
    }

    func testRecordOpenWithNonPositiveDurationThrows() throws {
        let ctx = try makeContext(now: { self.date(0) })
        try ctx.engine.beginIntervention(ruleId: uuid(1))
        for _ in 0..<4 { _ = try ctx.engine.advanceStep() }
        XCTAssertThrowsError(try ctx.engine.recordOpen(durationSeconds: 0)) { error in
            guard case CoreError.validation = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
        }
    }

    // MARK: - Persistence & begin-allowed set

    func testStatePersistsAcrossEngineInstances() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)
        let rule = uuid(5)

        let first = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(0) })
        try first.beginIntervention(ruleId: rule)
        _ = try first.advanceStep() // breathing
        _ = try first.advanceStep() // usageSummary

        let second = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(0) })
        let state = try second.currentState()
        XCTAssertEqual(state.currentStep, .usageSummary)
        XCTAssertEqual(state.ruleId, rule)
        XCTAssertEqual(state.startedAt, date(0))
    }

    // MARK: - Cross-process intent persistence

    /// エンジンA（本体アプリ想定）が intent を記録し、別インスタンスのエンジンB
    /// （ShieldAction 拡張想定・同一 App Group コンテナ）がキャンセルを記録しても
    /// AttemptLog.intent が保持されること。跨プロセスで intent が失われた旧制約の回帰テスト。
    func testIntentPersistsAcrossEngineInstancesForCancel() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)
        let rule = uuid(910)

        let engineA = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(0) })
        try engineA.beginIntervention(ruleId: rule)
        for _ in 0..<3 { _ = try engineA.advanceStep() } // intentSelection
        try engineA.recordIntent(.research)

        // 新しいプロセスの新しいエンジンインスタンスは永続スナップショットから intent を復元する。
        let engineB = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(30) })
        XCTAssertEqual(try engineB.currentStep(), .intentSelection)
        XCTAssertEqual(try engineB.currentState().intent, .research, "intent is persisted, not in-memory")
        try engineB.recordCancel()

        let attempt = try XCTUnwrap(log.fetchAttempts().first)
        XCTAssertEqual(attempt.decision, .cancelled)
        XCTAssertEqual(attempt.intent, .research, "intent survives the app/extension process split")
        XCTAssertEqual(try engineB.currentStep(), .idle)
    }

    /// intentSelection で記録した intent が advanceStep（→ decision）を跨いでも保持され、
    /// 別インスタンスのエンジンBが recordOpen したときに AttemptLog.intent へ引き継がれること。
    func testIntentPersistsAcrossEngineInstancesForOpen() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)
        let rule = uuid(911)

        let engineA = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(0) })
        try engineA.beginIntervention(ruleId: rule)
        for _ in 0..<3 { _ = try engineA.advanceStep() } // intentSelection
        try engineA.recordIntent(.posting)
        _ = try engineA.advanceStep() // decision — advanceStep must preserve intent

        let engineB = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(0) })
        XCTAssertEqual(try engineB.currentStep(), .decision)
        try engineB.recordOpen(durationSeconds: 300)

        let attempt = try XCTUnwrap(log.fetchAttempts().first)
        XCTAssertEqual(attempt.decision, .opened)
        XCTAssertEqual(attempt.intent, .posting, "intent survives advanceStep and the process split")
    }

    /// intent 欄を持たない旧フォーマットの intervention_state.json が nil として後方互換にデコードされ、
    /// 既存フィールドはそのまま読めること。
    func testDecodesLegacyStateWithoutIntentField() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)

        // "intent" 欄が無い旧フォーマットを手書きで配置する。
        let legacyJSON = """
        {"currentStep":"decision","ruleId":"00000000-0000-0000-0000-000000000042",\
        "startedAt":"2027-01-01T00:00:00Z","updatedAt":"2027-01-01T00:00:05Z","allowedUntil":null}
        """
        let url = try snapshot.url(for: .interventionState)
        try Data(legacyJSON.utf8).write(to: url)

        let engine = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(10) })
        let state = try engine.currentState()
        XCTAssertEqual(state.currentStep, .decision)
        XCTAssertEqual(state.ruleId, uuid(42))
        XCTAssertNil(state.allowedUntil)
        XCTAssertNil(state.intent, "legacy state without an intent field decodes to nil")
    }

    func testDecodesRemovedGoalReminderStepAsMergedUsageSummary() throws {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)
        let legacyJSON = """
        {"currentStep":"goalReminder","ruleId":"00000000-0000-0000-0000-000000000042",\
        "startedAt":"2027-01-01T00:00:00Z","updatedAt":"2027-01-01T00:00:05Z","allowedUntil":null}
        """
        let url = try snapshot.url(for: .interventionState)
        try Data(legacyJSON.utf8).write(to: url)

        let engine = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(10) })
        XCTAssertEqual(try engine.currentStep(), .usageSummary)
    }

    func testBeginInterventionAllowedFromResolvedSteps() throws {
        for step in [InterventionStep.cancelled, .postUseReflection, .idle] {
            let container = FixedContainer(url: try makeTemporaryDirectory())
            let snapshot = JSONSnapshotStore(containerProvider: container)
            let log = try SQLiteLogStore(containerProvider: container)
            try snapshot.write(
                InterventionState(currentStep: step, ruleId: nil, startedAt: nil, updatedAt: date(0), allowedUntil: nil),
                to: .interventionState
            )
            let engine = InterventionEngine(snapshotStore: snapshot, logStore: log, now: { self.date(1) })
            XCTAssertNoThrow(try engine.beginIntervention(ruleId: self.uuid(7)), "should begin from \(step)")
            XCTAssertEqual(try engine.currentStep(), .shieldPresented)
        }
    }

    func testResetToIdleClearsContext() throws {
        let ctx = try makeContext(now: { self.date(5) })
        try ctx.engine.beginIntervention(ruleId: uuid(1))
        _ = try ctx.engine.advanceStep()

        try ctx.engine.resetToIdle()

        let state = try ctx.engine.currentState()
        XCTAssertEqual(state.currentStep, .idle)
        XCTAssertNil(state.ruleId)
        XCTAssertNil(state.startedAt)
        XCTAssertNil(state.allowedUntil)
    }

    // MARK: - Pending reflection window

    func testPendingReflectionWindowBoundary() throws {
        var clock = date(10_000)
        let ctx = try makeContext(now: { clock })
        let promptedAt = date(10_000)
        try ctx.log.insert(
            ReflectionLog(
                id: uuid(50),
                attemptLogId: nil,
                ruleId: uuid(900),
                promptedAt: promptedAt,
                answeredAt: nil,
                trigger: .timedSessionEnded,
                satisfaction: nil,
                happinessDelta: nil,
                skipped: false,
                createdAt: promptedAt
            )
        )

        clock = promptedAt.addingTimeInterval(InterventionEngine.reflectionPromptWindow) // age == window -> inside
        XCTAssertEqual(try ctx.engine.pendingReflection()?.id, uuid(50))

        clock = promptedAt.addingTimeInterval(InterventionEngine.reflectionPromptWindow + 1) // age > window -> outside
        XCTAssertNil(try ctx.engine.pendingReflection())

        clock = promptedAt.addingTimeInterval(-10) // future prompt -> not due
        XCTAssertNil(try ctx.engine.pendingReflection())

        clock = promptedAt.addingTimeInterval(50) // custom window boundaries
        XCTAssertNil(try ctx.engine.pendingReflection(within: 30))
        XCTAssertEqual(try ctx.engine.pendingReflection(within: 60)?.id, uuid(50))
    }

    func testPendingReflectionNotHiddenByManyOldUnanswered() throws {
        let reference = date(500_000)
        let ctx = try makeContext(now: { reference })
        // 120 old unanswered reflections far outside the 1800s window must not hide the newer one.
        for index in 0..<120 {
            try ctx.log.insert(unansweredReflection(id: 1_000 + index, promptedAt: date(500_000 - 100_000 + index)))
        }
        try ctx.log.insert(unansweredReflection(id: 2_000, promptedAt: date(500_000 - 60)))

        XCTAssertEqual(try ctx.engine.pendingReflection()?.id, uuid(2_000))
    }

    func testPendingReflectionUsesThreeHourNotificationTapWindow() throws {
        var clock = date(20_000)
        let ctx = try makeContext(now: { clock })
        let reflection = unansweredReflection(id: 2_100, promptedAt: date(10_000))
        try ctx.log.insert(reflection)

        clock = reflection.promptedAt.addingTimeInterval(
            InterventionEngine.reflectionPromptWindow + 1
        )
        XCTAssertNil(try ctx.engine.pendingReflection())
        XCTAssertEqual(
            try ctx.engine.pendingReflection(
                within: InterventionEngine.reflectionNotificationTapWindow
            )?.id,
            reflection.id
        )

        clock = reflection.promptedAt.addingTimeInterval(
            InterventionEngine.reflectionNotificationTapWindow + 1
        )
        XCTAssertNil(
            try ctx.engine.pendingReflection(
                within: InterventionEngine.reflectionNotificationTapWindow
            )
        )
    }

    func testTwoHourOldReflectionSurvivesThreeHourExpiryAndRemainsTappable() throws {
        let now = date(30_000)
        let ctx = try makeContext(now: { now })
        let reflection = unansweredReflection(
            id: 2_101,
            promptedAt: now.addingTimeInterval(-2 * 60 * 60)
        )
        try ctx.log.insert(reflection)

        XCTAssertEqual(
            try ctx.engine.expireStaleReflections(
                olderThan: InterventionEngine.reflectionNotificationTapWindow
            ),
            0
        )
        XCTAssertEqual(
            try ctx.engine.pendingReflection(
                within: InterventionEngine.reflectionNotificationTapWindow
            )?.id,
            reflection.id
        )
    }

    func testReflectionOlderThanThreeHoursIsExpired() throws {
        let now = date(50_000)
        let ctx = try makeContext(now: { now })
        let reflection = unansweredReflection(
            id: 2_102,
            promptedAt: now.addingTimeInterval(
                -InterventionEngine.reflectionNotificationTapWindow - 1
            )
        )
        try ctx.log.insert(reflection)

        XCTAssertEqual(
            try ctx.engine.expireStaleReflections(
                olderThan: InterventionEngine.reflectionNotificationTapWindow
            ),
            1
        )
        XCTAssertNil(
            try ctx.engine.pendingReflection(
                within: InterventionEngine.reflectionNotificationTapWindow
            )
        )
        let stored = try XCTUnwrap(
            ctx.log.fetchReflections().first { $0.id == reflection.id }
        )
        XCTAssertTrue(stored.skipped)
    }

    // MARK: - attemptCount24h

    func testAttemptCount24hCountsPriorSameRuleAttempts() throws {
        let reference = date(1_000_000)
        let ctx = try makeContext(now: { reference })
        let ruleA = uuid(900)
        let ruleB = uuid(901)
        try ctx.log.insert(sampleAttempt(id: 1, ruleId: ruleA, startedAt: reference.addingTimeInterval(-3_600)))
        try ctx.log.insert(sampleAttempt(id: 2, ruleId: ruleA, startedAt: reference.addingTimeInterval(-7_200)))
        try ctx.log.insert(sampleAttempt(id: 3, ruleId: ruleA, startedAt: reference.addingTimeInterval(-90_000))) // > 24h
        try ctx.log.insert(sampleAttempt(id: 4, ruleId: ruleB, startedAt: reference.addingTimeInterval(-1_800))) // other rule

        try ctx.engine.beginIntervention(ruleId: ruleA)
        for _ in 0..<4 { _ = try ctx.engine.advanceStep() }
        try ctx.engine.recordCancel()

        let seeded: Set<UUID> = [uuid(1), uuid(2), uuid(3), uuid(4)]
        let newAttempt = try XCTUnwrap(ctx.log.fetchAttempts().first { !seeded.contains($0.id) })
        XCTAssertEqual(newAttempt.attemptCount24h, 3, "2 prior in-window same-rule attempts + 1")
    }

    // MARK: - Skip

    func testSkipReflectionExcludesItFromPending() throws {
        var clock = date(0)
        let ctx = try makeContext(now: { clock })
        try ctx.engine.beginIntervention(ruleId: uuid(900))
        for _ in 0..<4 { _ = try ctx.engine.advanceStep() }
        try ctx.engine.recordOpen(durationSeconds: 300)

        clock = date(300)
        let pending = try XCTUnwrap(ctx.engine.pendingReflection())

        try ctx.engine.skipReflection(id: pending.id)

        XCTAssertNil(try ctx.engine.pendingReflection(), "skipped reflection no longer pending")
        XCTAssertEqual(try ctx.engine.currentStep(), .idle, "skip resolves the reflection flow")
        let reflections = try ctx.log.fetchReflections()
        XCTAssertEqual(reflections.count, 1)
        XCTAssertTrue(reflections.first?.skipped ?? false, "skip persisted to the shared DB")
        XCTAssertNil(reflections.first?.answeredAt)
    }

    func testSkipDoesNotAffectAlreadyAnsweredReflectionOrThrowOnUnknownId() throws {
        let ctx = try makeContext(now: { self.date(0) })
        let answered = ReflectionLog(
            id: uuid(70),
            attemptLogId: nil,
            ruleId: uuid(900),
            promptedAt: date(10),
            answeredAt: date(20),
            trigger: .timedSessionEnded,
            satisfaction: .satisfied,
            happinessDelta: .increased,
            skipped: false,
            createdAt: date(10)
        )
        try ctx.log.insert(answered)

        XCTAssertNoThrow(try ctx.engine.skipReflection(id: uuid(70)), "already answered -> no-op")
        XCTAssertNoThrow(try ctx.engine.skipReflection(id: uuid(9_999)), "unknown id -> no-op")

        let stored = try XCTUnwrap(ctx.log.fetchReflections().first)
        XCTAssertFalse(stored.skipped, "answered reflection must not be marked skipped")
        XCTAssertEqual(stored.answeredAt, date(20))
        XCTAssertEqual(stored.satisfaction, .satisfied)
    }

    // MARK: - Error type & skip writer

    func testInterventionEngineErrorDescriptions() {
        let invalid = InterventionEngineError.invalidTransition(from: .decision, action: "advanceStep")
        XCTAssertEqual(invalid, .invalidTransition(from: .decision, action: "advanceStep"))
        XCTAssertTrue(invalid.errorDescription?.contains("advanceStep") ?? false)
        XCTAssertTrue(invalid.errorDescription?.contains("decision") ?? false)

        let missing = InterventionEngineError.missingRule(action: "recordOpen")
        XCTAssertTrue(missing.errorDescription?.contains("recordOpen") ?? false)
        XCTAssertNotEqual(invalid, missing)
    }

    func testReflectionSkipWriterThrowsOnMissingDatabase() throws {
        let badURL = try makeTemporaryDirectory().appendingPathComponent("does_not_exist.sqlite")
        XCTAssertThrowsError(try ReflectionSkipWriter.markSkipped(reflectionID: uuid(1), databaseURL: badURL)) { error in
            guard case CoreError.sqliteOpen = error else {
                return XCTFail("Expected sqliteOpen, got \(error)")
            }
        }
    }

    func testMonitoredReflectionWaitsForUsageCallbackAndCannotBeAskedTwice() throws {
        var clock = date(0)
        let ctx = try makeContext(now: { clock })
        try ctx.engine.beginIntervention(ruleId: uuid(900))
        for _ in 0..<4 { _ = try ctx.engine.advanceStep() }
        let reflection = try ctx.engine.recordCatalogOpen(durationSeconds: 300, deferReflection: true)
        clock = date(900)
        XCTAssertNil(try ctx.engine.pendingReflection(), "Elapsed wall time must not prompt a monitored session")
        try ctx.log.makeReflectionReady(id: reflection.id, at: clock)
        XCTAssertEqual(try ctx.engine.pendingReflection()?.id, reflection.id)
        try ctx.engine.recordPostUseReflection(id: reflection.id, satisfaction: .fun, happinessDelta: .increased)
        try ctx.log.makeReflectionReady(id: reflection.id, at: date(1000))
        try ctx.engine.skipReflection(id: reflection.id)
        XCTAssertNil(try ctx.engine.pendingReflection())
        let saved = try XCTUnwrap(ctx.log.reflection(id: reflection.id))
        XCTAssertEqual(saved.promptedAt, date(900))
        XCTAssertEqual(saved.satisfaction, .fun)
        XCTAssertFalse(saved.skipped)
    }

    // MARK: - Helpers

    private func unansweredReflection(id: Int, promptedAt: Date) -> ReflectionLog {
        ReflectionLog(
            id: uuid(id),
            attemptLogId: nil,
            ruleId: uuid(900),
            promptedAt: promptedAt,
            answeredAt: nil,
            trigger: .timedSessionEnded,
            satisfaction: nil,
            happinessDelta: nil,
            skipped: false,
            createdAt: promptedAt
        )
    }

    private func makeContext(
        now: @escaping () -> Date
    ) throws -> (engine: InterventionEngine, snapshot: JSONSnapshotStore, log: SQLiteLogStore) {
        let container = FixedContainer(url: try makeTemporaryDirectory())
        let snapshot = JSONSnapshotStore(containerProvider: container)
        let log = try SQLiteLogStore(containerProvider: container)
        let engine = InterventionEngine(snapshotStore: snapshot, logStore: log, now: now)
        return (engine, snapshot, log)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("InterventionEngineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func sampleAttempt(id: Int, ruleId: UUID, startedAt: Date) -> AttemptLog {
        AttemptLog(
            id: uuid(id),
            ruleId: ruleId,
            startedAt: startedAt,
            completedAt: startedAt,
            decision: .cancelled,
            intent: nil,
            selectedDurationSeconds: nil,
            attemptCount24h: 1,
            opened: false
        )
    }

    private func assertInvalidTransition(
        _ error: Error,
        from: InterventionStep,
        action: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let InterventionEngineError.invalidTransition(actualFrom, actualAction) = error else {
            return XCTFail("Expected invalidTransition, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(actualFrom, from, file: file, line: line)
        XCTAssertEqual(actualAction, action, file: file, line: line)
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + offset))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
