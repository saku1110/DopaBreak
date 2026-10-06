import XCTest
@testable import DopaBreakCore

final class ReinterventionStoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private func session() -> ReinterventionSession {
        .init(catalogID: "instagram", selectionData: Data([1]), minutes: 5, now: start)
    }

    func testOnlyCurrentEventCanReachThresholdOnceWithinLifetime() {
        var value = session()
        XCTAssertFalse(value.acceptsThreshold(eventID: UUID().uuidString, now: start.addingTimeInterval(600)))
        XCTAssertFalse(value.acceptsThreshold(eventID: value.id.uuidString, now: start.addingTimeInterval(299)))
        XCTAssertTrue(value.acceptsThreshold(eventID: value.id.uuidString, now: start.addingTimeInterval(300)))
        XCTAssertFalse(value.acceptsThreshold(eventID: value.id.uuidString, now: value.expiresAt))
        value.reachedAt = start.addingTimeInterval(300)
        XCTAssertFalse(value.acceptsThreshold(eventID: value.id.uuidString, now: start.addingTimeInterval(600)))
    }

    func testShieldRequiresReachedBudgetAndExpiresEvenWhenAppDoesNotReturn() {
        var value = session()
        XCTAssertFalse(value.shouldShield(at: start.addingTimeInterval(300)))
        value.reachedAt = start.addingTimeInterval(300)
        XCTAssertTrue(value.shouldShield(at: start.addingTimeInterval(300)))
        value.resumeRequested = true
        XCTAssertTrue(value.shouldShield(at: start.addingTimeInterval(400)), "Requesting more time alone must not unlock")
        XCTAssertFalse(value.shouldShield(at: value.expiresAt))
        value.endedEarly = true
        XCTAssertFalse(value.shouldShield(at: start.addingTimeInterval(400)))
    }

    func testExpiryMatchesMinutePrecisionMonitorBoundary() {
        var value = ReinterventionSession(catalogID: "instagram", selectionData: Data(), minutes: 5, now: start.addingTimeInterval(25.75))
        value.reachedAt = start.addingTimeInterval(600)
        XCTAssertEqual(value.expiresAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 60), 0)
        XCTAssertFalse(value.shouldShield(at: value.expiresAt))
        XCTAssertLessThanOrEqual(value.expiresAt.timeIntervalSince(value.startedAt), ReinterventionConstants.maximumSessionAge)
    }

    func testTransactionsPersistReviewAndRollbackFailedEdits() throws {
        let store = makeStore()
        var value = session()
        value.reflectionID = UUID()
        value.reachedAt = start.addingTimeInterval(300)
        value.notificationsEnabled = false
        try store.transaction { $0.sessions[value.catalogID] = value }
        XCTAssertEqual(try store.read().sessions[value.catalogID], value)
        enum Failure: Error { case expected }
        XCTAssertThrowsError(try store.transaction({ state in
            state.sessions.removeAll()
            throw Failure.expected
        }, afterCommit: { _ in XCTFail("Failed transactions must not apply shields") }))
        XCTAssertEqual(try store.read().sessions[value.catalogID], value)
        var committed: ReinterventionState?
        try store.transaction({ $0.sessions.removeAll() }, afterCommit: { committed = $0 })
        XCTAssertEqual(committed?.sessions.count, 0)
        XCTAssertTrue(try store.read().sessions.isEmpty)
    }

    func testLegacySessionsStillBlockWhenModeIsMissing() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session())) as? [String: Any])
        json.removeValue(forKey: "blocksAtLimit")
        let restored = try JSONDecoder().decode(ReinterventionSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.isBlocking)
    }

    func testConcurrentWritersPreserveOtherApps() throws {
        let store = makeStore()
        DispatchQueue.concurrentPerform(iterations: 24) { index in
            do { try store.transaction { $0.selections[String(index)] = Data([UInt8(index)]) } }
            catch { XCTFail("Transaction failed: \(error)") }
        }
        XCTAssertEqual(try store.read().selections.count, 24)
    }

    private func makeStore() -> ReinterventionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return .init(snapshotStore: .init(containerProvider: FixedContainer(url: url)))
    }
}
