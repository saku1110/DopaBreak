import DopaBreakCore
import UserNotifications
import XCTest
@testable import DopaBreak

@MainActor
final class ReflectionNotificationSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_318_000)

    func testWorkCheckInUsesSeparateIdentifierAndDoesNotRouteToReflection() throws {
        let center = RecordingReflectionNotifying()
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)
        scheduler.scheduleWorkCheckIn(catalogID: "instagram", minutes: 10, isEnabled: true, now: now)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(request.identifier, NotificationIdentifier.workCheckIn("instagram"))
        XCTAssertNil(NotificationRouting.destination(forIdentifier: request.identifier))
        XCTAssertNotNil(request.trigger as? UNCalendarNotificationTrigger)
        scheduler.scheduleWorkCheckIn(catalogID: "instagram", minutes: 5, isEnabled: false, now: now)
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertTrue(center.removedDelivered.contains([NotificationIdentifier.workCheckIn("instagram")]))
    }

    func testSchedulesReflectionAtPromptedAt() throws {
        let center = RecordingReflectionNotifying()
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)
        let reflection = makeReflection(promptedAt: now.addingTimeInterval(10 * 60))
        var didSchedule: Bool?

        scheduler.schedule(
            reflection: reflection,
            appDisplayName: "Instagram",
            declaredMinutes: 10,
            isEnabled: true,
            now: now,
            completion: { didSchedule = $0 }
        )

        XCTAssertEqual(didSchedule, true)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(request.identifier, NotificationIdentifier.reflectionPrompt)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        let expectedComponents = Calendar(identifier: .gregorian).dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: reflection.promptedAt
        )
        XCTAssertEqual(trigger.dateComponents.era, expectedComponents.era)
        XCTAssertEqual(trigger.dateComponents.year, expectedComponents.year)
        XCTAssertEqual(trigger.dateComponents.month, expectedComponents.month)
        XCTAssertEqual(trigger.dateComponents.day, expectedComponents.day)
        XCTAssertEqual(trigger.dateComponents.hour, expectedComponents.hour)
        XCTAssertEqual(trigger.dateComponents.minute, expectedComponents.minute)
        XCTAssertEqual(trigger.dateComponents.second, expectedComponents.second)
    }

    func testSecondScheduleUsesSameIdentifierAndUpdatesFireDateForReplacement() throws {
        let center = RecordingReflectionNotifying()
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)
        let firstFireDate = now.addingTimeInterval(5 * 60)
        let secondFireDate = now.addingTimeInterval(10 * 60)

        scheduler.schedule(
            reflection: makeReflection(promptedAt: firstFireDate),
            appDisplayName: "Instagram",
            declaredMinutes: 5,
            isEnabled: true,
            now: now,
            completion: { _ in }
        )
        scheduler.schedule(
            reflection: makeReflection(promptedAt: secondFireDate),
            appDisplayName: "Instagram",
            declaredMinutes: 10,
            isEnabled: true,
            now: now,
            completion: { _ in }
        )

        XCTAssertEqual(
            center.addedRequests.map(\.identifier),
            [NotificationIdentifier.reflectionPrompt, NotificationIdentifier.reflectionPrompt]
        )
        let firstTrigger = try XCTUnwrap(
            center.addedRequests[0].trigger as? UNCalendarNotificationTrigger
        )
        let secondTrigger = try XCTUnwrap(
            center.addedRequests[1].trigger as? UNCalendarNotificationTrigger
        )
        let expectedSecondComponents = Calendar(identifier: .gregorian).dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: secondFireDate
        )
        XCTAssertNotEqual(firstTrigger.dateComponents, secondTrigger.dateComponents)
        XCTAssertEqual(secondTrigger.dateComponents.era, expectedSecondComponents.era)
        XCTAssertEqual(secondTrigger.dateComponents.year, expectedSecondComponents.year)
        XCTAssertEqual(secondTrigger.dateComponents.month, expectedSecondComponents.month)
        XCTAssertEqual(secondTrigger.dateComponents.day, expectedSecondComponents.day)
        XCTAssertEqual(secondTrigger.dateComponents.hour, expectedSecondComponents.hour)
        XCTAssertEqual(secondTrigger.dateComponents.minute, expectedSecondComponents.minute)
        XCTAssertEqual(secondTrigger.dateComponents.second, expectedSecondComponents.second)
        XCTAssertEqual(
            center.removedDelivered,
            [
                [NotificationIdentifier.reflectionPrompt],
                [NotificationIdentifier.reflectionPrompt]
            ]
        )
    }

    func testAddSucceedsWhenNotificationsAreUnauthorized() {
        let center = RecordingReflectionNotifying(
            authorizationStatus: .denied
        )
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)
        var didSchedule: Bool?

        scheduler.schedule(
            reflection: makeReflection(promptedAt: now.addingTimeInterval(10 * 60)),
            appDisplayName: "Instagram",
            declaredMinutes: 10,
            isEnabled: true,
            now: now,
            completion: { didSchedule = $0 }
        )

        XCTAssertEqual(didSchedule, true)
        XCTAssertEqual(center.addedRequests.count, 1)
    }

    func testReadsAuthorizationStatusThroughInjectedNotificationCenter() {
        let center = RecordingReflectionNotifying(authorizationStatus: .provisional)
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)
        var status: UNAuthorizationStatus?

        scheduler.getNotificationAuthorizationStatus { status = $0 }

        XCTAssertEqual(status, .provisional)
        XCTAssertEqual(center.authorizationStatusReadCount, 1)
    }

    func testDisabledDoesNotScheduleAndRemovesExistingNotification() {
        let center = RecordingReflectionNotifying()
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)
        var didSchedule: Bool?

        scheduler.schedule(
            reflection: makeReflection(promptedAt: now.addingTimeInterval(10 * 60)),
            appDisplayName: "Instagram",
            declaredMinutes: 10,
            isEnabled: false,
            now: now,
            completion: { didSchedule = $0 }
        )

        XCTAssertEqual(didSchedule, false)
        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.removedPending, [[NotificationIdentifier.reflectionPrompt]])
        XCTAssertEqual(center.removedDelivered, [[NotificationIdentifier.reflectionPrompt]])
    }

    func testCancelRemovesPendingAndDeliveredNotification() {
        let center = RecordingReflectionNotifying()
        let scheduler = ReflectionNotificationScheduler(notificationCenter: center)

        scheduler.cancel()

        XCTAssertEqual(center.removedPending, [[NotificationIdentifier.reflectionPrompt]])
        XCTAssertEqual(center.removedDelivered, [[NotificationIdentifier.reflectionPrompt]])
    }

    private func makeReflection(promptedAt: Date) -> ReflectionLog {
        ReflectionLog(
            id: UUID(),
            attemptLogId: UUID(),
            ruleId: UUID(),
            promptedAt: promptedAt,
            answeredAt: nil,
            trigger: .timedSessionEnded,
            satisfaction: nil,
            happinessDelta: nil,
            skipped: false,
            createdAt: now
        )
    }
}

private final class RecordingReflectionNotifying: ReflectionNotificationNotifying {
    let addError: Error?
    let authorizationStatus: UNAuthorizationStatus
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedPending: [[String]] = []
    private(set) var removedDelivered: [[String]] = []
    private(set) var authorizationStatusReadCount = 0

    init(
        addError: Error? = nil,
        authorizationStatus: UNAuthorizationStatus = .authorized
    ) {
        self.addError = addError
        self.authorizationStatus = authorizationStatus
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: ((Error?) -> Void)?
    ) {
        if addError == nil {
            addedRequests.append(request)
        }
        completionHandler?(addError)
    }

    func getNotificationAuthorizationStatus(
        withCompletionHandler completionHandler: @escaping (UNAuthorizationStatus) -> Void
    ) {
        authorizationStatusReadCount += 1
        completionHandler(authorizationStatus)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPending.append(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDelivered.append(identifiers)
    }
}
