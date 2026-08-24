import Foundation
import XCTest
@testable import DopaBreakCore

final class GatePolicyTests: XCTestCase {
    private let tokenData = Data("app-token".utf8)

    /// すべての条件が同時に真でも、正本の順序どおり1つだけを返す。
    func testShieldStatePriorityIsHardWaitingLimitCooldownThenCanUnlock() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let pending = GateUnlockRequest(id: UUID(), tokenData: tokenData, requestedAt: now)
        let ledger = makeLedger(
            opensToday: 3,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            lastGrantEndedAt: now,
            updatedAt: now
        )
        let restrictive = makeSetting(limit: 3, cooldownMinutes: 60, updatedAt: now)

        XCTAssertEqual(
            state(
                now: now,
                setting: restrictive,
                ledger: ledger,
                pending: pending,
                deepFocus: true,
                night: true
            ),
            .hardWindow(kind: .deepFocus)
        )
        XCTAssertEqual(
            state(
                now: now,
                setting: restrictive,
                ledger: ledger,
                pending: pending,
                deepFocus: false,
                night: true
            ),
            .hardWindow(kind: .night)
        )
        XCTAssertEqual(
            state(now: now, setting: restrictive, ledger: ledger, pending: pending),
            .waitingForApp(requestedAt: now)
        )

        let afterRequestTTL = now.addingTimeInterval(GateConstants.pendingRequestTTL)
        XCTAssertEqual(
            state(
                now: afterRequestTTL,
                setting: restrictive,
                ledger: ledger,
                pending: pending
            ),
            .limitReached(limit: 3)
        )

        let cooldownSetting = makeSetting(limit: 10, cooldownMinutes: 60, updatedAt: now)
        XCTAssertEqual(
            state(
                now: afterRequestTTL,
                setting: cooldownSetting,
                ledger: ledger,
                pending: pending
            ),
            .cooldown(until: now.addingTimeInterval(3_600))
        )

        let openSetting = makeSetting(limit: 10, cooldownMinutes: 0, updatedAt: now)
        XCTAssertEqual(
            state(
                now: afterRequestTTL,
                setting: openSetting,
                ledger: ledger,
                pending: pending
            ),
            .canUnlock(opensToday: 3, limit: 10)
        )
    }

    /// 23:59の回数は0:00でリセットし、日をまたぐ待ち時間の起点だけは残す。
    func testNormalizedEntryResetsOpensAtDayBoundary() throws {
        let beforeMidnight = try date(year: 2026, month: 8, day: 22, hour: 23, minute: 59)
        let midnight = try date(year: 2026, month: 8, day: 23, hour: 0)
        let entry = GateLedgerEntry(
            tokenData: tokenData,
            dayKey: GatePolicy.dayKey(for: beforeMidnight, calendar: calendar),
            opensToday: 5,
            lastGrantEndedAt: beforeMidnight
        )

        let normalized = GatePolicy.normalized(entry, now: midnight, calendar: calendar)

        XCTAssertEqual(normalized.dayKey, "2026-08-23")
        XCTAssertEqual(normalized.opensToday, 0)
        XCTAssertEqual(normalized.lastGrantEndedAt, beforeMidnight)
    }

    func testCooldownZeroAlwaysAllows() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let ledger = makeLedger(
            opensToday: 1,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            lastGrantEndedAt: now.addingTimeInterval(60),
            updatedAt: now
        )

        assertAllowed(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: makeSetting(limit: 3, cooldownMinutes: 0, updatedAt: now),
                ledger: ledger,
                calendar: calendar
            )
        )
    }

    func testNilLimitNeverDeniesByCount() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let ledger = makeLedger(
            opensToday: 999,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            updatedAt: now
        )

        assertAllowed(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: makeSetting(limit: nil, cooldownMinutes: 0, updatedAt: now),
                ledger: ledger,
                calendar: calendar
            )
        )
    }

    /// 期限切れだけを落とし、同じトークンの最も遅い終了時刻を待ち時間の起点にする。
    func testExpiringGrantsUpdatesLastGrantEndedAtAndPreservesActiveGrant() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let first = makeGrant(
            tokenData: tokenData,
            startedAt: now.addingTimeInterval(-1_200),
            endsAt: now.addingTimeInterval(-600)
        )
        let second = makeGrant(
            tokenData: tokenData,
            startedAt: now.addingTimeInterval(-600),
            endsAt: now
        )
        let active = makeGrant(
            tokenData: Data("other".utf8),
            startedAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(60)
        )
        var ledger = makeLedger(
            opensToday: 2,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            updatedAt: now.addingTimeInterval(-1_200)
        )
        ledger.activeGrants = [first, second, active]

        let result = GatePolicy.expiringGrants(ledger: ledger, now: now)

        XCTAssertEqual(Set(result.expired.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(result.ledger.activeGrants, [active])
        XCTAssertEqual(result.ledger.entries.first?.lastGrantEndedAt, now)
        XCTAssertEqual(result.ledger.updatedAt, now)
    }

    func testTokensToShieldExcludesOnlyCurrentlyActiveGrants() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let selected: Set<String> = ["active", "expired", "future", "untouched"]
        var ledger = GateLedger.empty
        ledger.activeGrants = [
            makeGrant(
                tokenData: try GateTokenCoding.encode("active"),
                startedAt: now.addingTimeInterval(-60),
                endsAt: now.addingTimeInterval(60)
            ),
            makeGrant(
                tokenData: try GateTokenCoding.encode("expired"),
                startedAt: now.addingTimeInterval(-120),
                endsAt: now
            ),
            makeGrant(
                tokenData: try GateTokenCoding.encode("future"),
                startedAt: now.addingTimeInterval(60),
                endsAt: now.addingTimeInterval(120)
            )
        ]

        XCTAssertEqual(
            GatePolicy.tokensToShield(selectionTokens: selected, ledger: ledger, now: now),
            ["expired", "untouched"]
        )
    }

    func testPendingRequestExpiresAtExactlySixHundredSeconds() throws {
        let requestedAt = try date(year: 2026, month: 8, day: 22, hour: 12)
        let request = GateUnlockRequest(
            id: UUID(),
            tokenData: tokenData,
            requestedAt: requestedAt
        )
        let ledger = makeLedger(updatedAt: requestedAt)
        let setting = makeSetting(updatedAt: requestedAt)

        XCTAssertEqual(
            state(
                now: requestedAt.addingTimeInterval(599),
                setting: setting,
                ledger: ledger,
                pending: request
            ),
            .waitingForApp(requestedAt: requestedAt)
        )
        XCTAssertEqual(
            state(
                now: requestedAt.addingTimeInterval(600),
                setting: setting,
                ledger: ledger,
                pending: request
            ),
            .canUnlock(opensToday: 0, limit: nil)
        )
    }

    func testPendingRequestForAnotherTokenDoesNotBlock() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let ledger = makeLedger(
            updatedAt: now
        )
        let request = GateUnlockRequest(
            id: UUID(),
            tokenData: Data("another-token".utf8),
            requestedAt: now
        )

        XCTAssertEqual(
            state(
                now: now,
                setting: makeSetting(updatedAt: now),
                ledger: ledger,
                pending: request
            ),
            .canUnlock(opensToday: 0, limit: nil)
        )
    }

    func testApplyingGrantResetsOldDayCountAndAddsActiveGrant() throws {
        let startedAt = try date(year: 2026, month: 8, day: 23, hour: 8)
        let oldDay = try date(year: 2026, month: 8, day: 22, hour: 23)
        let grant = makeGrant(
            tokenData: tokenData,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(600)
        )
        let ledger = makeLedger(
            opensToday: 5,
            dayKey: GatePolicy.dayKey(for: oldDay, calendar: calendar),
            lastGrantEndedAt: oldDay,
            updatedAt: oldDay
        )

        let application = GatePolicy.applyingGrant(
            ledger: ledger,
            grant: grant,
            calendar: calendar
        )
        let updated = application.ledger

        XCTAssertEqual(application.expired, [])
        XCTAssertEqual(updated.entries.first?.dayKey, "2026-08-23")
        XCTAssertEqual(updated.entries.first?.opensToday, 1)
        XCTAssertEqual(updated.entries.first?.lastGrantEndedAt, oldDay)
        XCTAssertEqual(updated.activeGrants, [grant])
        XCTAssertEqual(updated.updatedAt, startedAt)
    }

    func testCanGrantAndShieldStateResetYesterdayLimitAtRollover() throws {
        let yesterday = try date(year: 2026, month: 8, day: 22, hour: 23, minute: 59)
        let now = try date(year: 2026, month: 8, day: 23, hour: 0)
        let ledger = makeLedger(
            opensToday: 3,
            dayKey: GatePolicy.dayKey(for: yesterday, calendar: calendar),
            updatedAt: yesterday
        )
        let setting = makeSetting(limit: 3, updatedAt: yesterday)

        assertAllowed(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: setting,
                ledger: ledger,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            state(now: now, setting: setting, ledger: ledger),
            .canUnlock(opensToday: 0, limit: 3)
        )
    }

    func testCooldownSurvivesMidnight() throws {
        let endedAt = try date(year: 2026, month: 8, day: 22, hour: 23, minute: 58)
        let now = try date(year: 2026, month: 8, day: 23, hour: 0, minute: 3)
        let until = try date(year: 2026, month: 8, day: 23, hour: 0, minute: 8)
        let ledger = makeLedger(
            opensToday: 7,
            dayKey: GatePolicy.dayKey(for: endedAt, calendar: calendar),
            lastGrantEndedAt: endedAt,
            updatedAt: endedAt
        )
        let setting = makeSetting(cooldownMinutes: 10, updatedAt: endedAt)

        assertDenied(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: setting,
                ledger: ledger,
                calendar: calendar
            ),
            equals: .cooldown(until: until)
        )
        XCTAssertEqual(
            state(now: now, setting: setting, ledger: ledger),
            .cooldown(until: until)
        )
    }

    func testCooldownAllowsAtExactBoundary() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let endedAt = now.addingTimeInterval(-600)
        let ledger = makeLedger(
            opensToday: 1,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            lastGrantEndedAt: endedAt,
            updatedAt: endedAt
        )

        assertAllowed(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: makeSetting(cooldownMinutes: 10, updatedAt: endedAt),
                ledger: ledger,
                calendar: calendar
            )
        )
    }

    func testExpiringGrantCreatesMissingEntryForCooldown() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let grant = makeGrant(
            tokenData: tokenData,
            startedAt: now.addingTimeInterval(-600),
            endsAt: now.addingTimeInterval(-60)
        )
        var ledger = GateLedger.empty
        ledger.activeGrants = [grant]

        let result = GatePolicy.expiringGrants(
            ledger: ledger,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.expired, [grant])
        XCTAssertEqual(result.ledger.entries.count, 1)
        XCTAssertEqual(result.ledger.entries[0].tokenData, tokenData)
        XCTAssertEqual(result.ledger.entries[0].opensToday, 0)
        XCTAssertEqual(result.ledger.entries[0].lastGrantEndedAt, grant.endsAt)
        XCTAssertEqual(result.ledger.entries[0].dayKey, "2026-08-22")
    }

    func testExpiringGrantNeverRegressesLastGrantEndedAt() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let laterEnd = now.addingTimeInterval(-30)
        let grant = makeGrant(
            tokenData: tokenData,
            startedAt: now.addingTimeInterval(-600),
            endsAt: now.addingTimeInterval(-60)
        )
        var ledger = makeLedger(
            opensToday: 2,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            lastGrantEndedAt: laterEnd,
            updatedAt: laterEnd
        )
        ledger.activeGrants = [grant]

        let result = GatePolicy.expiringGrants(
            ledger: ledger,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.ledger.entries[0].lastGrantEndedAt, laterEnd)
    }

    func testToleranceExpiresOnlyNamedGrantAndPreservesOtherFutureGrant() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let callbackGrant = makeGrant(
            tokenData: tokenData,
            startedAt: now.addingTimeInterval(-600),
            endsAt: now.addingTimeInterval(20)
        )
        let otherGrant = makeGrant(
            tokenData: Data("other-token".utf8),
            startedAt: now.addingTimeInterval(-600),
            endsAt: now.addingTimeInterval(10)
        )
        var ledger = GateLedger.empty
        ledger.activeGrants = [callbackGrant, otherGrant]

        let result = GatePolicy.expiringGrants(
            ledger: ledger,
            now: now,
            additionallyExpiring: [callbackGrant.id],
            calendar: calendar
        )

        XCTAssertEqual(result.expired, [callbackGrant])
        XCTAssertEqual(result.ledger.activeGrants, [otherGrant])
        XCTAssertEqual(result.ledger.entries.first?.lastGrantEndedAt, callbackGrant.endsAt)
    }

    func testActiveGrantReturnsAlreadyOpenAndShieldStateDoesNotOfferAnotherGrant() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let grant = makeGrant(
            tokenData: tokenData,
            startedAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(540)
        )
        var ledger = makeLedger(
            opensToday: 1,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            updatedAt: now.addingTimeInterval(-60)
        )
        ledger.activeGrants = [grant]
        let setting = makeSetting(limit: 1, cooldownMinutes: 60, updatedAt: now)

        assertDenied(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: setting,
                ledger: ledger,
                calendar: calendar
            ),
            equals: .alreadyOpen(until: grant.endsAt)
        )
        XCTAssertEqual(
            state(now: now, setting: setting, ledger: ledger),
            .alreadyOpen(until: grant.endsAt)
        )
    }

    func testApplyingSixthGrantExpiresOldestAndKeepsFive() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let oldestToken = Data("oldest-token".utf8)
        let existing = (0..<GateConstants.maximumConcurrentGrants).map { index in
            makeGrant(
                tokenData: index == 0 ? oldestToken : Data("token-\(index)".utf8),
                startedAt: now.addingTimeInterval(TimeInterval(-600 + index)),
                endsAt: now.addingTimeInterval(600)
            )
        }
        var ledger = GateLedger.empty
        ledger.activeGrants = existing
        let newGrant = makeGrant(
            tokenData: tokenData,
            startedAt: now,
            endsAt: now.addingTimeInterval(600)
        )

        let application = GatePolicy.applyingGrant(
            ledger: ledger,
            grant: newGrant,
            calendar: calendar
        )

        XCTAssertEqual(application.expired, [existing[0]])
        XCTAssertEqual(application.ledger.activeGrants.count, 5)
        XCTAssertFalse(application.ledger.activeGrants.contains { $0.id == existing[0].id })
        XCTAssertTrue(application.ledger.activeGrants.contains { $0.id == newGrant.id })
        XCTAssertEqual(
            application.ledger.entries.first { $0.tokenData == oldestToken }?.lastGrantEndedAt,
            now
        )
    }

    func testRequestOlderThanLatestGrantIsIgnored() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let request = GateUnlockRequest(
            id: UUID(),
            tokenData: tokenData,
            requestedAt: now.addingTimeInterval(-300)
        )
        let ledger = makeLedger(
            opensToday: 1,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            lastGrantEndedAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60)
        )

        XCTAssertEqual(
            state(
                now: now,
                setting: makeSetting(updatedAt: now),
                ledger: ledger,
                pending: request
            ),
            .canUnlock(opensToday: 1, limit: nil)
        )
    }

    func testSuppliedSettingTokenMismatchFallsBackToUnrestrictedDefaults() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let ledger = makeLedger(
            opensToday: 999,
            dayKey: GatePolicy.dayKey(for: now, calendar: calendar),
            lastGrantEndedAt: now,
            updatedAt: now
        )
        let mismatched = GateAppSetting(
            tokenData: Data("different-token".utf8),
            dailyOpenLimit: 1,
            sessionMinutes: 30,
            cooldownMinutes: 60,
            updatedAt: now
        )

        assertAllowed(
            GatePolicy.canGrant(
                tokenData: tokenData,
                now: now,
                settings: mismatched,
                ledger: ledger,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            state(now: now, setting: mismatched, ledger: ledger),
            .canUnlock(opensToday: 999, limit: nil)
        )
    }

    func testTokensToShieldKeepsUnencodableTokenShielded() throws {
        let now = try date(year: 2026, month: 8, day: 22, hour: 12)
        let token = UnencodableGateToken(rawValue: "keep-shielded")
        var ledger = GateLedger.empty
        ledger.activeGrants = [
            makeGrant(
                tokenData: Data("some-active-grant".utf8),
                startedAt: now.addingTimeInterval(-60),
                endsAt: now.addingTimeInterval(60)
            )
        ]

        XCTAssertEqual(
            GatePolicy.tokensToShield(selectionTokens: [token], ledger: ledger, now: now),
            [token]
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    private func makeSetting(
        limit: Int? = nil,
        cooldownMinutes: Int = 0,
        updatedAt: Date
    ) -> GateAppSetting {
        GateAppSetting(
            tokenData: tokenData,
            dailyOpenLimit: limit,
            sessionMinutes: 10,
            cooldownMinutes: cooldownMinutes,
            updatedAt: updatedAt
        )
    }

    private func makeLedger(
        opensToday: Int = 0,
        dayKey: String? = nil,
        lastGrantEndedAt: Date? = nil,
        updatedAt: Date
    ) -> GateLedger {
        let entries: [GateLedgerEntry]
        if let dayKey {
            entries = [
                GateLedgerEntry(
                    tokenData: tokenData,
                    dayKey: dayKey,
                    opensToday: opensToday,
                    lastGrantEndedAt: lastGrantEndedAt
                )
            ]
        } else {
            entries = []
        }
        return GateLedger(
            entries: entries,
            activeGrants: [],
            updatedAt: updatedAt
        )
    }

    private func makeGrant(
        tokenData: Data,
        startedAt: Date,
        endsAt: Date
    ) -> GateGrant {
        let id = UUID()
        return GateGrant(
            id: id,
            tokenData: tokenData,
            ruleId: UUID(),
            startedAt: startedAt,
            endsAt: endsAt,
            activityName: GateConstants.reshieldActivityName(for: id)
        )
    }

    private func state(
        now: Date,
        setting: GateAppSetting,
        ledger: GateLedger,
        pending: GateUnlockRequest? = nil,
        deepFocus: Bool = false,
        night: Bool = false
    ) -> GateShieldState {
        GatePolicy.shieldState(
            tokenData: tokenData,
            now: now,
            settings: setting,
            ledger: ledger,
            pendingUnlockRequest: pending,
            isDeepFocusWindowActive: deepFocus,
            isNightWindow: night,
            calendar: calendar
        )
    }

    private func assertAllowed(
        _ result: Result<Void, GateDenial>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case .failure(let denial) = result {
            XCTFail("Expected grant, got \(denial)", file: file, line: line)
        }
    }

    private func assertDenied(
        _ result: Result<Void, GateDenial>,
        equals expected: GateDenial,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let denial) = result else {
            XCTFail("Expected denial \(expected), got success", file: file, line: line)
            return
        }
        XCTAssertEqual(denial, expected, file: file, line: line)
    }
}

final class GateReshieldPolicyTests: XCTestCase {
    func testDecisionStopsWhenGrantIsAbsent() {
        let decision = GateReshieldPolicy.decision(
            grant: nil,
            now: Date(timeIntervalSince1970: 1_000),
            tolerance: 30
        )

        XCTAssertFalse(decision.shouldReshield)
        XCTAssertTrue(decision.shouldStopMonitoring)
    }

    func testDecisionKeepsMonitoringWhenCallbackIsEarlierThanTolerance() {
        let grant = makeGrant(endsAt: Date(timeIntervalSince1970: 1_000))
        let decision = GateReshieldPolicy.decision(
            grant: grant,
            now: grant.endsAt.addingTimeInterval(-30.001),
            tolerance: 30
        )

        XCTAssertFalse(decision.shouldReshield)
        XCTAssertFalse(decision.shouldStopMonitoring)
    }

    func testDecisionReshieldsAndStopsAtToleranceBoundary() {
        let grant = makeGrant(endsAt: Date(timeIntervalSince1970: 1_000))
        let decision = GateReshieldPolicy.decision(
            grant: grant,
            now: grant.endsAt.addingTimeInterval(-30),
            tolerance: 30
        )

        XCTAssertTrue(decision.shouldReshield)
        XCTAssertTrue(decision.shouldStopMonitoring)
    }

    private func makeGrant(endsAt: Date) -> GateGrant {
        let id = UUID()
        return GateGrant(
            id: id,
            tokenData: Data("reshield-policy".utf8),
            ruleId: UUID(),
            startedAt: endsAt.addingTimeInterval(-600),
            endsAt: endsAt,
            activityName: GateConstants.reshieldActivityName(for: id)
        )
    }
}

private struct UnencodableGateToken: Codable, Hashable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        throw EncodingError.invalidValue(
            rawValue,
            EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "intentional gate-token encoding failure"
            )
        )
    }
}
