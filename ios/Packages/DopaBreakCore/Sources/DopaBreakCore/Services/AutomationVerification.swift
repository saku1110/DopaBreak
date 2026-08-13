import Foundation

public enum AutomationVerification {
    public struct Progress: Equatable, Sendable {
        public let verifiedCount: Int
        public let totalCount: Int

        public init(verifiedCount: Int, totalCount: Int) {
            self.verifiedCount = verifiedCount
            self.totalCount = totalCount
        }
    }

    /// Returns selected targets that have not yet been verified, preserving selection order.
    public static func unverifiedCatalogIDs(
        selectedCatalogIDs: [String],
        verifiedCatalogIDs: [String]
    ) -> [String] {
        let verified = Set(verifiedCatalogIDs)
        return selectedCatalogIDs.filter { !verified.contains($0) }
    }

    /// Returns setup progress for the selected targets only.
    /// Duplicate IDs are counted once so persisted legacy data cannot inflate either value.
    public static func progress(
        selectedCatalogIDs: [String],
        verifiedCatalogIDs: [String]
    ) -> Progress {
        let selected = Set(selectedCatalogIDs)
        let verified = Set(verifiedCatalogIDs)
        return Progress(
            verifiedCount: selected.intersection(verified).count,
            totalCount: selected.count
        )
    }
}
