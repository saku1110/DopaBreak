import Foundation

public enum FunnelEventName: String, Codable, Equatable, Sendable {
    case onboardingCompleted
    case onboardingStepCompleted
    case automationVerified
    case automationNonTargetShown = "automation_non_target_shown"
    case automationRequestDiscarded = "automation_request_discarded"
    case interventionPassThrough = "intervention_pass_through"
    case paywallShown
    case paywallDismissed
    case prePaywallSkipped
    case trialOrPurchaseStarted
    case appOpened
    case reviewPromptShown = "review_prompt_shown"
    case reflectionNotificationScheduled = "reflection_notification_scheduled"
    case reflectionNotificationTapped = "reflection_notification_tapped"
    case reflectionAnswered = "reflection_answered"
    case reflectionSkipped = "reflection_skipped"
}

public struct FunnelEvent: Codable, Equatable, Sendable {
    public let name: String
    public let detail: String?
    public let occurredAt: Date

    public init(name: String, detail: String? = nil, occurredAt: Date) {
        self.name = name
        self.detail = detail
        self.occurredAt = occurredAt
    }
}

public struct FunnelEventStore: Sendable {
    private static let maximumEventCount = 5_000
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore) {
        self.snapshotStore = snapshotStore
    }

    public func record(
        name: FunnelEventName,
        detail: String? = nil,
        at occurredAt: Date
    ) throws {
        var events = try allEvents()
        events.append(FunnelEvent(name: name.rawValue, detail: detail, occurredAt: occurredAt))

        if events.count > Self.maximumEventCount {
            events.removeFirst(events.count / 2)
        }

        try snapshotStore.write(events, to: .funnelEvents)
    }

    public func allEvents() throws -> [FunnelEvent] {
        try snapshotStore.read([FunnelEvent].self, from: .funnelEvents) ?? []
    }

    public func deleteAll() throws {
        try snapshotStore.write([FunnelEvent](), to: .funnelEvents)
    }
}
