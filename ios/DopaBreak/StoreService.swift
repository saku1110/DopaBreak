import DopaBreakCore
import Foundation
import Observation
import StoreKit

enum PaywallDismissalPolicy {
    static func shouldRecord(isPro: Bool, hasPendingPurchase: Bool) -> Bool {
        !isPro && !hasPendingPurchase
    }
}

@MainActor
@Observable
final class StoreService {
    private enum StoreServiceError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return String(localized: "store.error.verification", defaultValue: "購入を確認できませんでした")
            }
        }
    }

    private static let annualProductIDs = [
        ProProductID.annual.rawValue,
        ProProductID.annualLaunch.rawValue
    ]

    private let funnelEventStore: FunnelEventStore
    private let now: () -> Date
    private let onProEntitlementActivated: (() -> Void)?

    // Remote config can swap this between dopabreak.pro.annual and dopabreak.pro.annual.launch.
    var activeAnnualProductID: String {
        didSet {
            if !Self.annualProductIDs.contains(activeAnnualProductID) {
                activeAnnualProductID = oldValue
            }
            refreshPaywallProducts()
            Task {
                await updateAnnualIntroOfferInfo()
            }
        }
    }

    private(set) var monthlyProduct: Product?
    private(set) var annualDefaultProduct: Product?
    private(set) var annualLaunchProduct: Product?
    private(set) var lifetimeProduct: Product?
    private(set) var paywallProducts: [Product] = []
    private(set) var annualIntroOfferText: String?
    private(set) var annualIntroOfferDurationText: String?
    private(set) var isEligibleForAnnualIntroOffer = false
    private(set) var isPro = false
    private(set) var hasResolvedEntitlement = false
    private(set) var activeSubscriptionEntitlement: SubscriptionEntitlementSnapshot?
    private(set) var annualTrialEntitlement: SubscriptionEntitlementSnapshot?
    private(set) var entitlementRevision = 0
    private(set) var hasPendingPurchase = false
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var alertMessage: String?

    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?

    init(
        activeAnnualProductID: String = ProProductID.annual.rawValue,
        funnelEventStore: FunnelEventStore = FunnelEventStore(snapshotStore: JSONSnapshotStore()),
        now: @escaping () -> Date = { .now },
        onProEntitlementActivated: (() -> Void)? = nil
    ) {
        self.activeAnnualProductID = Self.annualProductIDs.contains(activeAnnualProductID)
            ? activeAnnualProductID
            : ProProductID.annual.rawValue
        self.funnelEventStore = funnelEventStore
        self.now = now
        self.onProEntitlementActivated = onProEntitlementActivated

        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        guard !isLoadingProducts else {
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await Product.products(for: ProProductID.allIDs)
            monthlyProduct = loadedProducts.first { $0.id == ProProductID.monthly.rawValue }
            annualDefaultProduct = loadedProducts.first { $0.id == ProProductID.annual.rawValue }
            annualLaunchProduct = loadedProducts.first { $0.id == ProProductID.annualLaunch.rawValue }
            lifetimeProduct = loadedProducts.first { $0.id == ProProductID.lifetime.rawValue }
            refreshPaywallProducts()
            await updateAnnualIntroOfferInfo()
        } catch {
            alertMessage = String(localized: "store.error.product_load", defaultValue: "商品情報を読み込めませんでした")
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else {
            return false
        }

        isPurchasing = true
        alertMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                hasPendingPurchase = false
                await transaction.finish()
                await refreshEntitlement()
                try? funnelEventStore.record(name: .trialOrPurchaseStarted, detail: transaction.productID, at: now())
                return isPro
            case .userCancelled:
                return false
            case .pending:
                hasPendingPurchase = true
                alertMessage = String(localized: "store.status.purchase_pending", defaultValue: "購入の確認が保留中です")
                return false
            @unknown default:
                alertMessage = String(localized: "store.error.purchase", defaultValue: "購入を完了できませんでした")
                return false
            }
        } catch {
            alertMessage = String(localized: "store.error.purchase", defaultValue: "購入を完了できませんでした")
            return false
        }
    }

    func recordPaywallShown(placement: String) {
        try? funnelEventStore.record(name: .paywallShown, detail: placement, at: now())
    }

    @discardableResult
    func recordPaywallDismissedIfNeeded(placement: String) -> Bool {
        guard PaywallDismissalPolicy.shouldRecord(
            isPro: isPro,
            hasPendingPurchase: hasPendingPurchase
        ) else {
            return false
        }
        try? funnelEventStore.record(name: .paywallDismissed, detail: placement, at: now())
        return true
    }

    @discardableResult
    func restore() async -> Bool {
        guard !isRestoring else {
            return false
        }

        isRestoring = true
        alertMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPro {
                alertMessage = String(
                    localized: "store.status.no_restorable_purchase",
                    defaultValue: "復元できる購入がありませんでした"
                )
            }
            return isPro
        } catch {
            alertMessage = String(localized: "store.error.restore", defaultValue: "購入を復元できませんでした")
            return false
        }
    }

    func refreshEntitlement() async {
        var entitledProductIDs = Set<String>()
        var subscriptionEntitlements: [SubscriptionEntitlementSnapshot] = []
        let now = Date()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard ProProductID.productKind(for: transaction.productID) != nil else {
                    continue
                }
                guard transaction.revocationDate == nil else {
                    continue
                }
                if let expirationDate = transaction.expirationDate, expirationDate <= now {
                    continue
                }
                entitledProductIDs.insert(transaction.productID)
                if ProProductID.productKind(for: transaction.productID) == .subscription {
                    subscriptionEntitlements.append(
                        await subscriptionEntitlementSnapshot(from: transaction)
                    )
                }
            } catch {
                continue
            }
        }

        isPro = !entitledProductIDs.isEmpty
        activeSubscriptionEntitlement = subscriptionEntitlements.max { lhs, rhs in
            lhs.purchaseDate < rhs.purchaseDate
        }
        annualTrialEntitlement = subscriptionEntitlements
            .filter(\.isAnnualIntroductoryTrial)
            .max { lhs, rhs in lhs.purchaseDate < rhs.purchaseDate }
        entitlementRevision &+= 1
        if isPro {
            hasPendingPurchase = false
            onProEntitlementActivated?()
        }
        hasResolvedEntitlement = true
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreServiceError.failedVerification
        }
    }

    var activeAnnualProduct: Product? {
        if activeAnnualProductID == ProProductID.annualLaunch.rawValue {
            return annualLaunchProduct ?? annualDefaultProduct
        }
        return annualDefaultProduct ?? annualLaunchProduct
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else {
                    return
                }

                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlement()
                } catch {
                    self.alertMessage = String(
                        localized: "store.error.verification",
                        defaultValue: "購入を確認できませんでした"
                    )
                }
            }
        }
    }

    private func refreshPaywallProducts() {
        paywallProducts = [
            lifetimeProduct,
            activeAnnualProduct,
            monthlyProduct
        ].compactMap(\.self)
    }

    private func subscriptionEntitlementSnapshot(
        from transaction: Transaction
    ) async -> SubscriptionEntitlementSnapshot {
        let offerType: SubscriptionEntitlementSnapshot.OfferType?
        if let transactionOfferType = transaction.offerType {
            offerType = transactionOfferType == .introductory ? .introductory : .other
        } else {
            offerType = nil
        }
        return SubscriptionEntitlementSnapshot(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            originalPurchaseDate: transaction.originalPurchaseDate,
            offerType: offerType,
            willAutoRenew: await transaction.subscriptionStatus
                .flatMap { status in
                    guard case .verified(let renewalInfo) = status.renewalInfo else {
                        return nil
                    }
                    return renewalInfo.willAutoRenew
                }
        )
    }

    private func updateAnnualIntroOfferInfo() async {
        guard let subscription = activeAnnualProduct?.subscription,
              let introductoryOffer = subscription.introductoryOffer,
              introductoryOffer.paymentMode == .freeTrial else {
            annualIntroOfferText = nil
            annualIntroOfferDurationText = nil
            isEligibleForAnnualIntroOffer = false
            return
        }

        annualIntroOfferText = freeTrialText(for: introductoryOffer)
        annualIntroOfferDurationText = freeTrialDurationText(for: introductoryOffer)
        isEligibleForAnnualIntroOffer = await subscription.isEligibleForIntroOffer
    }

    private func freeTrialText(for offer: Product.SubscriptionOffer) -> String {
        guard let durationText = freeTrialDurationText(for: offer) else {
            return String(localized: "store.intro_offer.available", defaultValue: "無料期間あり")
        }
        return String(localized: "store.intro_offer.free", defaultValue: "\(durationText)無料")
    }

    private func freeTrialDurationText(for offer: Product.SubscriptionOffer) -> String? {
        let period = offer.period
        let totalValue = period.value * offer.periodCount
        switch period.unit {
        case .day:
            return String(localized: "store.intro_offer.duration.days", defaultValue: "\(totalValue)日間")
        case .week:
            // Appleは7日トライアルをP1W（1週間）で表す。表示はdoc06正本の「7日間無料」に合わせて日数へ換算する。
            return String(localized: "store.intro_offer.duration.days", defaultValue: "\(totalValue * 7)日間")
        case .month:
            return String(localized: "store.intro_offer.duration.months", defaultValue: "\(totalValue)か月")
        case .year:
            return String(localized: "store.intro_offer.duration.years", defaultValue: "\(totalValue)年間")
        @unknown default:
            return nil
        }
    }
}
