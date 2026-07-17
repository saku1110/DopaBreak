import Foundation

public enum FunnelEventName: String, Codable, Equatable, Sendable {
    case onboardingCompleted
    case automationVerified
    case paywallShown
    case trialOrPurchaseStarted
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
}
