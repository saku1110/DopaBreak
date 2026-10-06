import Foundation

public enum InterventionTargetResolution: Equatable, Sendable {
    case target(catalogID: String)
    case none
}

public enum InterventionTargetResolutionPolicy {
    /// Resolves an optional shortcut parameter against the targets selected in the app.
    /// An explicit valid request always wins. Unknown explicit IDs are ignored instead of
    /// silently opening a different app.
    public static func resolve(
        requested: String?,
        selected: [String]
    ) -> InterventionTargetResolution {
        if let requested {
            guard SNSAppCatalog.contains(catalogID: requested) else {
                return .none
            }
            return .target(catalogID: requested)
        }

        // A shortcut does not tell us which app triggered it when its parameter is empty.
        // Never attribute an ambiguous request to whichever app happens to be first.
        let validSelected = Set(selected.filter { SNSAppCatalog.contains(catalogID: $0) })
        guard validSelected.count == 1, let onlyTarget = validSelected.first else {
            return .none
        }
        return .target(catalogID: onlyTarget)
    }
}
