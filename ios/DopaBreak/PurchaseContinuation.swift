import DopaBreakCore
import Foundation

struct PurchaseContinuation: Equatable {
    enum Action: Equatable {
        case addTarget(catalogID: String)
        case applyMode(InterventionMode)
    }

    let action: Action
    let createdAt: Date

    static func addTarget(
        catalogID: String,
        createdAt: Date = Date()
    ) -> PurchaseContinuation {
        PurchaseContinuation(action: .addTarget(catalogID: catalogID), createdAt: createdAt)
    }

    static func applyMode(
        _ mode: InterventionMode,
        createdAt: Date = Date()
    ) -> PurchaseContinuation {
        PurchaseContinuation(action: .applyMode(mode), createdAt: createdAt)
    }
}

enum PurchaseContinuationAction: Equatable {
    case addTargets([String])
    case applyMode(InterventionMode)
}

enum PurchaseContinuationPolicy {
    static let validityDuration: TimeInterval = 30 * 60

    static func action(
        for continuation: PurchaseContinuation?,
        isPro: Bool,
        canAddTarget: Bool,
        selectedCatalogIDs: [String],
        now: Date = Date()
    ) -> PurchaseContinuationAction? {
        guard isPro,
              let continuation,
              now.timeIntervalSince(continuation.createdAt) <= validityDuration else {
            return nil
        }

        switch continuation.action {
        case .addTarget(let catalogID):
            guard canAddTarget else { return nil }
            if selectedCatalogIDs.contains(catalogID) {
                return .addTargets(selectedCatalogIDs)
            }
            return .addTargets(selectedCatalogIDs + [catalogID])
        case .applyMode(let mode):
            return .applyMode(mode)
        }
    }
}
