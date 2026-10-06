import DeviceActivity
import FamilyControls
import ManagedSettings
import XCTest
@testable import DopaBreak
@testable import DopaBreakCore

@available(iOS 17.4, *)
@MainActor
final class ReinterventionSchedulerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testBudgetExcludesPastUsageAndUsesUniqueEventWithExpiry() throws {
        let (scheduler, monitor, store) = try context()
        XCTAssertNil(try scheduler.prepare(catalogID: "youtube", minutes: 5, authorized: true))
        let session = try XCTUnwrap(scheduler.prepare(catalogID: "instagram", minutes: 10, authorized: true, notificationsEnabled: false))
        XCTAssertEqual(monitor.activity?.rawValue, ReinterventionConstants.activityName("instagram"))
        let event = try XCTUnwrap(monitor.events[.init(session.id.uuidString)])
        XCTAssertEqual(event.threshold.minute, 10)
        XCTAssertFalse(event.includesPastActivity)
        XCTAssertEqual(event.applications.count, 1)
        XCTAssertEqual(session.expiresAt.timeIntervalSince(start), 12 * 3600)
        XCTAssertFalse(session.notificationsEnabled)
        let reflectionID = UUID()
        try scheduler.attach(reflectionID: reflectionID, to: session)
        XCTAssertEqual(try store.read().sessions["instagram"]?.reflectionID, reflectionID)
    }

    func testGentleBudgetPersistsWithoutShieldOrReflection() throws {
        let (scheduler, _, store) = try context()
        var session = try XCTUnwrap(scheduler.prepare(catalogID: "instagram", minutes: 5, authorized: true, blocksAtLimit: false))
        session.reachedAt = start.addingTimeInterval(300)
        try store.transaction { $0.sessions["instagram"] = session }
        let restored = try XCTUnwrap(store.read().sessions["instagram"])
        XCTAssertFalse(restored.isBlocking)
        XCTAssertFalse(restored.shouldShield(at: start.addingTimeInterval(300)))
        XCTAssertNil(restored.reflectionID)
    }

    func testAnotherOpenCannotResetActiveAccumulation() throws {
        let (scheduler, monitor, store) = try context()
        let original = try scheduler.prepare(catalogID: "instagram", minutes: 5, authorized: true)
        let stopCount = monitor.stops.count
        XCTAssertThrowsError(try scheduler.prepare(catalogID: "instagram", minutes: 30, authorized: true))
        XCTAssertEqual(try store.read().sessions["instagram"], original)
        XCTAssertEqual(monitor.stops.count, stopCount)
    }

    func testStartFailureRestoresReachedSessionWithoutUnlocking() throws {
        let (scheduler, monitor, store) = try context()
        var original = ReinterventionSession(catalogID: "instagram", selectionData: try XCTUnwrap(store.read().selections["instagram"]), minutes: 5, now: start.addingTimeInterval(-600))
        original.reachedAt = start.addingTimeInterval(-100)
        original.resumeRequested = true
        try store.transaction { $0.sessions["instagram"] = original }
        monitor.shouldFail = true
        XCTAssertThrowsError(try scheduler.prepare(catalogID: "instagram", minutes: 10, authorized: true))
        XCTAssertEqual(try store.read().sessions["instagram"], original)
        XCTAssertTrue(try XCTUnwrap(store.read().sessions["instagram"]).shouldShield(at: start))
        XCTAssertNil(monitor.activity)
    }

    func testPermissionOrInvalidDurationFailsBeforeMutation() throws {
        let (scheduler, monitor, store) = try context()
        XCTAssertThrowsError(try scheduler.prepare(catalogID: "instagram", minutes: 5, authorized: false))
        XCTAssertThrowsError(try scheduler.prepare(catalogID: "instagram", minutes: 6, authorized: true))
        XCTAssertTrue(try store.read().sessions.isEmpty)
        XCTAssertTrue(monitor.stops.isEmpty)
    }

    func testEarlyFinishCreatesReviewWithoutShieldAndDisconnectCleansUp() throws {
        let (scheduler, monitor, store) = try context()
        _ = try scheduler.prepare(catalogID: "instagram", minutes: 5, authorized: true)
        try scheduler.finishEarly(catalogID: "instagram")
        let session = try XCTUnwrap(store.read().sessions["instagram"])
        XCTAssertEqual(session.reachedAt, start)
        XCTAssertTrue(session.endedEarly)
        XCTAssertFalse(session.shouldShield(at: start))
        XCTAssertNil(monitor.activity)
        try scheduler.finish(catalogID: "instagram", disconnect: true)
        XCTAssertTrue(try store.read().sessions.isEmpty)
        XCTAssertTrue(try store.read().selections.isEmpty)
    }

    func testReleaseR13AllDurationsRegisterCorrectThresholdAndStopEarly() throws {
        for minutes in [5, 10, 15, 30] {
            for blocking in [false, true] {
                let (scheduler, monitor, store) = try context()
                let session = try XCTUnwrap(scheduler.prepare(catalogID: "instagram", minutes: minutes, authorized: true, blocksAtLimit: blocking))
                let event = try XCTUnwrap(monitor.events[.init(session.id.uuidString)])
                XCTAssertEqual(event.threshold.minute, minutes)
                XCTAssertFalse(event.includesPastActivity)
                XCTAssertFalse(session.acceptsThreshold(eventID: session.id.uuidString, now: start.addingTimeInterval(Double(minutes * 60 - 1))))
                XCTAssertTrue(session.acceptsThreshold(eventID: session.id.uuidString, now: start.addingTimeInterval(Double(minutes * 60))))
                try scheduler.finishEarly(catalogID: "instagram")
                let ended = try XCTUnwrap(store.read().sessions["instagram"])
                XCTAssertFalse(ended.shouldShield(at: start.addingTimeInterval(Double(minutes * 60))))
                XCTAssertFalse(ended.acceptsThreshold(eventID: ended.id.uuidString, now: start.addingTimeInterval(Double(minutes * 60))))
                XCTAssertNil(monitor.activity)
            }
        }
    }

    func testReleaseR11R12DisconnectAndExtendDoNotChangeOtherBudget() throws {
        let (scheduler, monitor, store) = try context()
        // A second opaque test token; no real user's Screen Time selection is used.
        let token = try JSONDecoder().decode(ApplicationToken.self, from: Data(#"{"data":"c2Vjb25kLXRlc3QtdG9rZW4="}"#.utf8))
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [token]
        try store.transaction { $0.selections["youtube"] = try JSONEncoder().encode(selection) }
        let instagram = try XCTUnwrap(scheduler.prepare(catalogID: "instagram", minutes: 5, authorized: true))
        let youtube = try XCTUnwrap(scheduler.prepare(catalogID: "youtube", minutes: 10, authorized: true))
        try store.transaction { $0.sessions["instagram"]?.reachedAt = start.addingTimeInterval(300) }
        let extended = try XCTUnwrap(scheduler.prepare(catalogID: "instagram", minutes: 15, authorized: true))
        XCTAssertNotEqual(extended.id, instagram.id)
        XCTAssertFalse(extended.acceptsThreshold(eventID: instagram.id.uuidString, now: start.addingTimeInterval(900)))
        XCTAssertEqual(try store.read().sessions["youtube"], youtube)
        try scheduler.finish(catalogID: "instagram", disconnect: true)
        XCTAssertNil(try store.read().sessions["instagram"])
        XCTAssertNil(try store.read().selections["instagram"])
        XCTAssertEqual(try store.read().sessions["youtube"], youtube)
        XCTAssertNotNil(try store.read().selections["youtube"])
        XCTAssertEqual(monitor.stops.last, [.init(ReinterventionConstants.activityName("instagram"))])
    }

    private func context() throws -> (ReinterventionScheduler, BudgetMonitor, ReinterventionStore) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let store = ReinterventionStore(snapshotStore: .init(containerProvider: FixedContainer(url: url)))
        let token = try JSONDecoder().decode(ApplicationToken.self, from: Data(#"{"data":"ZG9wYWJyZWFrLXRlc3QtdG9rZW4="}"#.utf8))
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [token]
        try store.transaction { $0.selections["instagram"] = try JSONEncoder().encode(selection) }
        let monitor = BudgetMonitor()
        return (ReinterventionScheduler(store: store, monitoring: monitor, now: { self.start }), monitor, store)
    }
}

private final class BudgetMonitor: DeepFocusMonitoring {
    var activity: DeviceActivityName?
    var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    var stops: [[DeviceActivityName]] = []
    var shouldFail = false
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule, events: [DeviceActivityEvent.Name: DeviceActivityEvent]) throws {
        if shouldFail { throw ReinterventionError.monitoring }
        self.activity = activity
        self.events = events
    }
    func stopMonitoring(_ activities: [DeviceActivityName]) {
        stops.append(activities)
        if let activity, activities.contains(activity) { self.activity = nil; events = [:] }
    }
}
