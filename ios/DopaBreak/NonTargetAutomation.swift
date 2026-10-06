import Foundation

enum NonTargetAutomationReason: String, Equatable {
    case removed
    case clampedByEntitlement = "clamped_by_entitlement"
}

struct NonTargetAutomation: Identifiable, Equatable {
    let catalogID: String
    let reason: NonTargetAutomationReason

    var id: String { catalogID }
}
