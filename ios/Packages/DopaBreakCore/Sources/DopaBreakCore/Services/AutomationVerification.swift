import Foundation

public enum AutomationVerification {
    /// Returns selected targets that have not yet been verified, preserving selection order.
    public static func unverifiedCatalogIDs(
        selectedCatalogIDs: [String],
        verifiedCatalogIDs: [String]
    ) -> [String] {
        let verified = Set(verifiedCatalogIDs)
        return selectedCatalogIDs.filter { !verified.contains($0) }
    }
}
