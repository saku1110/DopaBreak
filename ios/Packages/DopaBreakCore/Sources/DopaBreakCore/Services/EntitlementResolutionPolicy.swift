public enum EntitlementResolutionPolicy {
    public enum CurrentEntitlementEvidence: Equatable, Sendable {
        case verifiedEntitlement
        case noVerifiedEntitlement
    }

    public enum StoreReachabilityEvidence: Equatable, Sendable {
        case productsAvailable
        case unavailable
    }

    public enum ProDowngradeConfirmation: Equatable, Sendable {
        case confirmedNoEntitlement
        case notConfirmed
    }

    /// Evidence sources stay separate so an unverified transaction cannot erase either a
    /// verified entitlement or an independently corroborated cached-Pro downgrade.
    public struct Evidence: Equatable, Sendable {
        public let currentEntitlements: CurrentEntitlementEvidence
        public let storeReachability: StoreReachabilityEvidence
        public let encounteredUnverifiedEntitlement: Bool
        public let proDowngradeConfirmation: ProDowngradeConfirmation

        public init(
            currentEntitlements: CurrentEntitlementEvidence,
            storeReachability: StoreReachabilityEvidence,
            encounteredUnverifiedEntitlement: Bool,
            proDowngradeConfirmation: ProDowngradeConfirmation
        ) {
            self.currentEntitlements = currentEntitlements
            self.storeReachability = storeReachability
            self.encounteredUnverifiedEntitlement = encounteredUnverifiedEntitlement
            self.proDowngradeConfirmation = proDowngradeConfirmation
        }
    }

    public struct Resolution: Equatable, Sendable {
        public let isPro: Bool
        public let hasConfirmedEntitlement: Bool

        public init(isPro: Bool, hasConfirmedEntitlement: Bool) {
            self.isPro = isPro
            self.hasConfirmedEntitlement = hasConfirmedEntitlement
        }
    }

    public static func storeReachability(
        loadedProductCount: Int
    ) -> StoreReachabilityEvidence {
        loadedProductCount > 0 ? .productsAvailable : .unavailable
    }

    public static func resolve(
        previousIsPro: Bool,
        evidence: Evidence
    ) -> Resolution {
        if evidence.currentEntitlements == .verifiedEntitlement {
            return Resolution(isPro: true, hasConfirmedEntitlement: true)
        }

        guard evidence.storeReachability == .productsAvailable else {
            return unresolved(previousIsPro: previousIsPro)
        }

        let hasCorroboratedDowngrade = evidence.proDowngradeConfirmation == .confirmedNoEntitlement

        if previousIsPro, !hasCorroboratedDowngrade {
            return unresolved(previousIsPro: true)
        }

        if evidence.encounteredUnverifiedEntitlement, !hasCorroboratedDowngrade {
            return unresolved(previousIsPro: previousIsPro)
        }

        return Resolution(isPro: false, hasConfirmedEntitlement: true)
    }

    private static func unresolved(previousIsPro: Bool) -> Resolution {
        Resolution(
            isPro: previousIsPro,
            hasConfirmedEntitlement: false
        )
    }
}
