import DopaBreakCore
import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreService {
    private enum StoreServiceError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "購入を確認できませんでした"
            }
        }
    }

    private static let annualProductIDs = [
        ProProductID.annual.rawValue,
        ProProductID.annualLaunch.rawValue
    ]

    private let funnelEventStore: FunnelEventStore
    private let now: () -> Date

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
    private(set) var isEligibleForAnnualIntroOffer = false
    private(set) var isPro = false
    private(set) var hasResolvedEntitlement = false
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var alertMessage: String?

    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?

    init(
        activeAnnualProductID: String = ProProductID.annual.rawValue,
        funnelEventStore: FunnelEventStore = FunnelEventStore(snapshotStore: JSONSnapshotStore()),
        now: @escaping () -> Date = { .now }
    ) {
        self.activeAnnualProductID = Self.annualProductIDs.contains(activeAnnualProductID)
            ? activeAnnualProductID
            : ProProductID.annual.rawValue
        self.funnelEventStore = funnelEventStore
        self.now = now

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
            alertMessage = "商品情報を読み込めませんでした"
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
                await transaction.finish()
                await refreshEntitlement()
                try? funnelEventStore.record(name: .trialOrPurchaseStarted, detail: transaction.productID, at: now())
                return isPro
            case .userCancelled:
                return false
            case .pending:
                alertMessage = "購入の確認が保留中です"
                return false
            @unknown default:
                alertMessage = "購入を完了できませんでした"
                return false
            }
        } catch {
            alertMessage = "購入を完了できませんでした"
            return false
        }
    }

    func recordPaywallShown() {
        try? funnelEventStore.record(name: .paywallShown, at: now())
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
                alertMessage = "復元できる購入がありませんでした"
            }
            return isPro
        } catch {
            alertMessage = "購入を復元できませんでした"
            return false
        }
    }

    func refreshEntitlement() async {
        var entitledProductIDs = Set<String>()
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
            } catch {
                continue
            }
        }

        isPro = !entitledProductIDs.isEmpty
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
                    self.alertMessage = "購入を確認できませんでした"
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

    private func updateAnnualIntroOfferInfo() async {
        guard let subscription = activeAnnualProduct?.subscription,
              let introductoryOffer = subscription.introductoryOffer,
              introductoryOffer.paymentMode == .freeTrial else {
            annualIntroOfferText = nil
            isEligibleForAnnualIntroOffer = false
            return
        }

        annualIntroOfferText = freeTrialText(for: introductoryOffer)
        isEligibleForAnnualIntroOffer = await subscription.isEligibleForIntroOffer
    }

    private func freeTrialText(for offer: Product.SubscriptionOffer) -> String {
        let period = offer.period
        let totalValue = period.value * offer.periodCount
        switch period.unit {
        case .day:
            return "\(totalValue)日間無料"
        case .week:
            // Appleは7日トライアルをP1W（1週間）で表す。表示はdoc06正本の「7日間無料」に合わせて日数へ換算する。
            return "\(totalValue * 7)日間無料"
        case .month:
            return "\(totalValue)か月無料"
        case .year:
            return "\(totalValue)年間無料"
        @unknown default:
            return "無料期間あり"
        }
    }
}
