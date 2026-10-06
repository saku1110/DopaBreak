import Foundation

public enum AutomationRequestDecision: Equatable, Sendable {
    case consume
    case discardStale
    case discardSelfOpen
}

public enum AutomationRequestPolicy {
    public static let freshnessInterval: TimeInterval = 20
    public static let selfOpenSuppressionInterval: TimeInterval = 8

    public static func decision(
        requestedCatalogID: String,
        requestedAt: Date?,
        now: Date,
        lastSelfOpenedCatalogID: String?,
        lastSelfOpenedAt: Date?
    ) -> AutomationRequestDecision {
        guard let requestedAt,
              now.timeIntervalSince(requestedAt) <= freshnessInterval else {
            return .discardStale
        }

        if lastSelfOpenedCatalogID == requestedCatalogID,
           let lastSelfOpenedAt,
           requestedAt >= lastSelfOpenedAt,
           requestedAt.timeIntervalSince(lastSelfOpenedAt) < selfOpenSuppressionInterval {
            return .discardSelfOpen
        }

        return .consume
    }
}
