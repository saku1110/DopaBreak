import DopaBreakCore
import Foundation
import Observation
import OSLog
import StoreKit

enum PaywallDismissalPolicy {
    static func shouldRecord(isPro: Bool, hasPendingPurchase: Bool) -> Bool {
        !isPro && !hasPendingPurchase
    }
}

/// プランカードに出す導入オファー表記の組み立て。
/// 通貨記号は必ずStoreKitの価格書式が決める（¥0 / $0 / ₩0）。日本語UIでも米国ストアの利用者はUSDで
/// 請求されるため、記号をリテラルで書くと実際の請求通貨と食い違う。
enum IntroOfferDisplayPolicy {
    enum PlanCardStyle: Equatable {
        /// 「7日間 ¥0」。期間とゼロ価格が揃った正常系。
        case durationWithZeroPrice(duration: String, zeroPrice: String)
        /// 「7日間無料」。ゼロ価格を組み立てられなかったときの退避。
        case durationOnly(duration: String)
        /// 「無料期間あり」。期間すら取れなかったときの退避。
        case unspecified
    }

    static func planCardStyle(durationText: String?, zeroPriceText: String?) -> PlanCardStyle {
        guard let duration = normalizedText(durationText) else {
            return .unspecified
        }
        guard let zeroPrice = normalizedZeroPriceText(zeroPriceText) else {
            return .durationOnly(duration: duration)
        }
        return .durationWithZeroPrice(duration: duration, zeroPrice: zeroPrice)
    }

    static func planCardText(durationText: String?, zeroPriceText: String?) -> String {
        switch planCardStyle(durationText: durationText, zeroPriceText: zeroPriceText) {
        case .unspecified:
            return String(localized: "store.intro_offer.available", defaultValue: "無料期間あり")
        case .durationOnly(let duration):
            return String(localized: "store.intro_offer.free", defaultValue: "\(duration)無料")
        case .durationWithZeroPrice(let duration, let zeroPrice):
            return String(localized: "store.intro_offer.zero_price", defaultValue: "\(duration) \(zeroPrice)")
        }
    }

    /// 書式化が崩れて記号だけ・空文字になった値は使わない。金額として読めるものだけ通す。
    static func normalizedZeroPriceText(_ text: String?) -> String? {
        guard let trimmed = normalizedText(text),
              trimmed.rangeOfCharacter(from: .decimalDigits) != nil else {
            return nil
        }
        return trimmed
    }

    private static func normalizedText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

@MainActor
@Observable
final class StoreService {
    private final class EntitlementRefreshFlight {
        var task: Task<Void, Never>!
    }

    private struct EntitlementRefreshSnapshot {
        let resolution: EntitlementResolutionPolicy.Resolution
        let subscriptionEntitlements: [SubscriptionEntitlementSnapshot]
    }

    private static let annualProductIDs = [
        ProProductID.annual.rawValue,
        ProProductID.annualLaunch.rawValue
    ]
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DopaBreak",
        category: "StoreService"
    )
    private static let maxRefreshRoundsPerFlight = 2

    private let funnelEventStore: FunnelEventStore
    private let settingsStore: SettingsStore?
    private let now: () -> Date
    private let usageWatchStore: UsageWatchStore?

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
    /// StoreKitへの到達が裏付けられた状態でentitlementを解決できたか。
    /// true になる条件: verified currentEntitlements がある、または空だった場合に
    /// 非空の商品取得と、必要な降格確認まで成功したとき。商品取得の空配列・失敗や
    /// unverifiedだけのときは false のまま前回状態を維持する。
    private(set) var hasConfirmedEntitlement: Bool = false
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

    @ObservationIgnored
    private var entitlementRefreshTask: EntitlementRefreshFlight?

    @ObservationIgnored
    private var entitlementRefreshGeneration = 0

    @ObservationIgnored
    private var entitlementRefreshRequest = 0

    @ObservationIgnored
    private var completedEntitlementRefreshRequest = 0

    @ObservationIgnored
    private var pendingRefreshRequested = false

    @ObservationIgnored
    private var reportedPassiveUnverifiedProductIDs = Set<String>()

    @ObservationIgnored
    var onPurchaseOrRestoreFailure: (() -> Void)?

    init(
        activeAnnualProductID: String = ProProductID.annual.rawValue,
        funnelEventStore: FunnelEventStore = FunnelEventStore(snapshotStore: JSONSnapshotStore()),
        settingsStore: SettingsStore? = nil,
        usageWatchStore: UsageWatchStore? = nil,
        startsBackgroundTasks: Bool = true,
        now: @escaping () -> Date = { .now }
    ) {
        let resolvedSettingsStore = settingsStore ?? (try? SettingsStore())
        self.activeAnnualProductID = Self.annualProductIDs.contains(activeAnnualProductID)
            ? activeAnnualProductID
            : ProProductID.annual.rawValue
        self.funnelEventStore = funnelEventStore
        self.settingsStore = resolvedSettingsStore
        self.usageWatchStore = usageWatchStore
        self.now = now

        // Cached Pro intentionally has no TTL. A failed StoreKit lookup is not evidence of Free,
        // so access stays fail-open until StoreKit supplies affirmative downgrade evidence.
        // entitlementCachedAt is retained for future telemetry only; it is not an expiry date.
        if let cachedIsPro = resolvedSettingsStore?.entitlementCachedIsPro {
            isPro = cachedIsPro
            usageWatchStore?.updateConfiguration { configuration in
                configuration.isPro = cachedIsPro
            }
        }

        if startsBackgroundTasks {
            updatesTask = listenForTransactions()
            Task {
                await loadProducts()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        entitlementRefreshTask?.task.cancel()
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
                switch verification {
                case .verified(let transaction):
                    hasPendingPurchase = false
                    await transaction.finish()
                    await refreshEntitlement()
                    try? funnelEventStore.record(
                        name: .trialOrPurchaseStarted,
                        detail: transaction.productID,
                        at: now()
                    )
                    return isPro
                case .unverified(let transaction, let error):
                    reportUnverifiedTransaction(
                        transaction,
                        error: error,
                        isUserInitiated: true
                    )
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                hasPendingPurchase = true
                alertMessage = String(localized: "store.status.purchase_pending", defaultValue: "購入の確認が保留中です")
                return false
            @unknown default:
                alertMessage = String(localized: "store.error.purchase", defaultValue: "購入を完了できませんでした")
                onPurchaseOrRestoreFailure?()
                return false
            }
        } catch {
            alertMessage = String(localized: "store.error.purchase", defaultValue: "購入を完了できませんでした")
            onPurchaseOrRestoreFailure?()
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
            if hasConfirmedEntitlement, !isPro {
                reportNoRestorablePurchase()
            }
            return isPro
        } catch {
            await refreshEntitlement()
            if isPro {
                return true
            }
            alertMessage = String(localized: "store.error.restore", defaultValue: "購入を復元できませんでした")
            onPurchaseOrRestoreFailure?()
            return false
        }
    }

    /// 復元しても解放できるものが無かったとき。
    /// アラートを出すだけでなく失敗として通知する。ユーザーにとっては「復元できなかった」体験であり、
    /// 直後にレビュー依頼を出すと星1につながる（docs/18 §1・release-monetization-check B-1）。
    func reportNoRestorablePurchase() {
        alertMessage = String(
            localized: "store.status.no_restorable_purchase",
            defaultValue: "復元できる購入がありませんでした"
        )
        onPurchaseOrRestoreFailure?()
    }

    func refreshEntitlement() async {
        entitlementRefreshRequest &+= 1
        let request = entitlementRefreshRequest
        pendingRefreshRequested = true

        while completedEntitlementRefreshRequest < request {
            let flight = entitlementRefreshTask ?? startEntitlementRefreshFlight()
            await flight.task.value
        }
    }

    private func startEntitlementRefreshFlight() -> EntitlementRefreshFlight {
        let flight = EntitlementRefreshFlight()
        flight.task = Task { @MainActor [weak self, weak flight] in
            guard let self, let flight else {
                return
            }

            defer {
                // Cleanup is tied to flight identity, never to a mutable generation number.
                if self.entitlementRefreshTask === flight {
                    self.entitlementRefreshTask = nil
                }
            }

            await self.runEntitlementRefreshFlight()
        }
        entitlementRefreshTask = flight
        return flight
    }

    private func runEntitlementRefreshFlight() async {
        var remainingRounds = Self.maxRefreshRoundsPerFlight

        while remainingRounds > 0, !Task.isCancelled {
            pendingRefreshRequested = false
            let coveredRequest = entitlementRefreshRequest

            guard await performEntitlementRefresh() else {
                return
            }

            completedEntitlementRefreshRequest = max(
                completedEntitlementRefreshRequest,
                coveredRequest
            )
            remainingRounds -= 1

            guard pendingRefreshRequested else {
                return
            }
        }
    }

    private func performEntitlementRefresh() async -> Bool {
        entitlementRefreshGeneration &+= 1
        let generation = entitlementRefreshGeneration
        let previousIsPro = isPro
        let snapshot = await resolveEntitlement(previousIsPro: previousIsPro)

        guard !Task.isCancelled, generation == entitlementRefreshGeneration else {
            return false
        }
        applyEntitlement(snapshot)
        return true
    }

    private func resolveEntitlement(
        previousIsPro: Bool
    ) async -> EntitlementRefreshSnapshot {
        var entitledProductIDs = Set<String>()
        var subscriptionEntitlements: [SubscriptionEntitlementSnapshot] = []
        var encounteredUnverifiedEntitlement = false

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard ProProductID.productKind(for: transaction.productID) != nil else {
                    continue
                }
                guard transaction.revocationDate == nil else {
                    continue
                }
                entitledProductIDs.insert(transaction.productID)
                if ProProductID.productKind(for: transaction.productID) == .subscription {
                    subscriptionEntitlements.append(
                        await subscriptionEntitlementSnapshot(from: transaction)
                    )
                }
            case .unverified(let transaction, let error):
                guard ProProductID.productKind(for: transaction.productID) != nil else {
                    continue
                }
                encounteredUnverifiedEntitlement = true
                reportUnverifiedTransaction(
                    transaction,
                    error: error,
                    isUserInitiated: false
                )
            }
        }

        let currentEntitlementEvidence: EntitlementResolutionPolicy.CurrentEntitlementEvidence
        let storeReachability: EntitlementResolutionPolicy.StoreReachabilityEvidence
        let proDowngradeConfirmation: EntitlementResolutionPolicy.ProDowngradeConfirmation

        if !entitledProductIDs.isEmpty {
            currentEntitlementEvidence = .verifiedEntitlement
            storeReachability = .unavailable
            proDowngradeConfirmation = .notConfirmed
        } else {
            currentEntitlementEvidence = .noVerifiedEntitlement
            do {
                let products = try await Product.products(for: ProProductID.allIDs)
                storeReachability = EntitlementResolutionPolicy.storeReachability(
                    loadedProductCount: products.count
                )

                if storeReachability == .productsAvailable, previousIsPro {
                    proDowngradeConfirmation = await corroborateCachedProDowngrade(
                        products: products
                    )
                } else {
                    proDowngradeConfirmation = .notConfirmed
                }

                if products.isEmpty {
                    Self.logger.error("Entitlement reachability check returned no products")
                }
            } catch {
                Self.logger.error(
                    "Entitlement reachability check failed: \(String(describing: error), privacy: .public)"
                )
                storeReachability = .unavailable
                proDowngradeConfirmation = .notConfirmed
            }
        }

        return EntitlementRefreshSnapshot(
            resolution: EntitlementResolutionPolicy.resolve(
                previousIsPro: previousIsPro,
                evidence: EntitlementResolutionPolicy.Evidence(
                    currentEntitlements: currentEntitlementEvidence,
                    storeReachability: storeReachability,
                    encounteredUnverifiedEntitlement: encounteredUnverifiedEntitlement,
                    proDowngradeConfirmation: proDowngradeConfirmation
                )
            ),
            subscriptionEntitlements: subscriptionEntitlements
        )
    }

    private func corroborateCachedProDowngrade(
        products: [Product]
    ) async -> EntitlementResolutionPolicy.ProDowngradeConfirmation {
        let subscriptionGroupIDs = Set(
            products.compactMap { $0.subscription?.subscriptionGroupID }
        )

        guard await subscriptionsConfirmNoEntitlement(
            subscriptionGroupIDs: subscriptionGroupIDs
        ) else {
            return .notConfirmed
        }

        guard let lifetimeResult = await Transaction.latest(for: ProProductID.lifetimeID) else {
            return .confirmedNoEntitlement
        }

        switch lifetimeResult {
        case .verified(let transaction):
            return transaction.revocationDate == nil ? .notConfirmed : .confirmedNoEntitlement
        case .unverified(let transaction, let error):
            reportUnverifiedTransaction(
                transaction,
                error: error,
                isUserInitiated: false
            )
            return .notConfirmed
        }
    }

    private func subscriptionsConfirmNoEntitlement(
        subscriptionGroupIDs: Set<String>
    ) async -> Bool {
        if subscriptionGroupIDs.isEmpty {
            // A partial catalog can omit every subscription product. Transaction.latest still
            // provides the required independent check instead of preserving cached Pro forever.
            return await latestSubscriptionTransactionsConfirmNoEntitlement()
        }

        for groupID in subscriptionGroupIDs {
            let statuses: [Product.SubscriptionInfo.Status]
            do {
                statuses = try await Product.SubscriptionInfo.status(for: groupID)
            } catch {
                Self.logger.error(
                    "Subscription status corroboration failed: \(String(describing: error), privacy: .public)"
                )
                return false
            }

            for status in statuses {
                if status.state == .subscribed || status.state == .inGracePeriod {
                    return false
                }

                let isKnownInactiveState = status.state == .expired
                    || status.state == .revoked
                    || status.state == .inBillingRetryPeriod
                guard isKnownInactiveState else {
                    return false
                }

                if case .unverified(let transaction, let error) = status.transaction {
                    reportUnverifiedTransaction(
                        transaction,
                        error: error,
                        isUserInitiated: false
                    )
                }
            }
        }

        return true
    }

    private func latestSubscriptionTransactionsConfirmNoEntitlement() async -> Bool {
        for productID in ProProductID.allSubscriptionIDs {
            guard let result = await Transaction.latest(for: productID) else {
                continue
            }

            switch result {
            case .unverified(let transaction, let error):
                reportUnverifiedTransaction(
                    transaction,
                    error: error,
                    isUserInitiated: false
                )
                return false
            case .verified(let transaction):
                guard transaction.revocationDate == nil else {
                    continue
                }

                if let status = await transaction.subscriptionStatus {
                    if status.state == .subscribed || status.state == .inGracePeriod {
                        return false
                    }

                    let isKnownInactiveState = status.state == .expired
                        || status.state == .revoked
                        || status.state == .inBillingRetryPeriod
                    guard isKnownInactiveState else {
                        return false
                    }
                    continue
                }

                guard let expirationDate = transaction.expirationDate,
                      expirationDate <= now() else {
                    return false
                }
            }
        }

        return true
    }

    private func applyEntitlement(_ snapshot: EntitlementRefreshSnapshot) {
        let resolution = snapshot.resolution
        isPro = resolution.isPro
        hasConfirmedEntitlement = resolution.hasConfirmedEntitlement

        if resolution.hasConfirmedEntitlement {
            activeSubscriptionEntitlement = snapshot.subscriptionEntitlements.max { lhs, rhs in
                lhs.purchaseDate < rhs.purchaseDate
            }
            annualTrialEntitlement = snapshot.subscriptionEntitlements
                .filter(\.isAnnualIntroductoryTrial)
                .max { lhs, rhs in lhs.purchaseDate < rhs.purchaseDate }
            settingsStore?.entitlementCachedIsPro = resolution.isPro
            // Telemetry timestamp only. Cached Pro remains fail-open without a time limit.
            settingsStore?.entitlementCachedAt = now()
            usageWatchStore?.updateConfiguration { configuration in
                configuration.isPro = resolution.isPro
            }
        }

        entitlementRevision &+= 1
        if isPro {
            hasPendingPurchase = false
        }
        hasResolvedEntitlement = true
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

                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.refreshEntitlement()
                case .unverified(let transaction, let error):
                    self.reportUnverifiedTransaction(
                        transaction,
                        error: error,
                        isUserInitiated: false
                    )
                }
            }
        }
    }

    private func reportUnverifiedTransaction(
        _ transaction: Transaction,
        error: any Error,
        isUserInitiated: Bool
    ) {
        Self.logger.error(
            "Unverified StoreKit transaction for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)"
        )

        if isUserInitiated {
            // A direct purchase attempt must always receive feedback, even if a passive StoreKit
            // stream already reported the same product during this launch.
            reportedPassiveUnverifiedProductIDs.insert(transaction.productID)
        } else {
            guard reportedPassiveUnverifiedProductIDs.insert(transaction.productID).inserted else {
                return
            }
        }
        alertMessage = String(
            localized: "store.error.verification",
            defaultValue: "購入を確認できませんでした"
        )
        onPurchaseOrRestoreFailure?()
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

        var willAutoRenew: Bool?
        var renewalDate: Date?
        if let status = await transaction.subscriptionStatus,
           case .verified(let renewalInfo) = status.renewalInfo {
            willAutoRenew = renewalInfo.willAutoRenew
            // 自動更新がオフのとき、renewalDateは「更新日」ではなく現在の期間の終了日を指す。
            renewalDate = renewalInfo.renewalDate
        }

        return SubscriptionEntitlementSnapshot(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            originalPurchaseDate: transaction.originalPurchaseDate,
            offerType: offerType,
            willAutoRenew: willAutoRenew,
            expirationDate: transaction.expirationDate ?? renewalDate
        )
    }

    private func updateAnnualIntroOfferInfo() async {
        guard let product = activeAnnualProduct,
              let subscription = product.subscription,
              let introductoryOffer = subscription.introductoryOffer,
              introductoryOffer.paymentMode == .freeTrial else {
            annualIntroOfferText = nil
            annualIntroOfferDurationText = nil
            isEligibleForAnnualIntroOffer = false
            return
        }

        annualIntroOfferText = freeTrialText(for: introductoryOffer, product: product)
        annualIntroOfferDurationText = freeTrialDurationText(for: introductoryOffer)
        isEligibleForAnnualIntroOffer = await subscription.isEligibleForIntroOffer
    }

    private func freeTrialText(for offer: Product.SubscriptionOffer, product: Product) -> String {
        IntroOfferDisplayPolicy.planCardText(
            durationText: freeTrialDurationText(for: offer),
            zeroPriceText: zeroPriceText(for: product)
        )
    }

    /// 通貨記号はStoreKitの価格書式に決めさせる。0はJPYでもUSDでも小数部なしで見せる。
    private func zeroPriceText(for product: Product) -> String? {
        IntroOfferDisplayPolicy.normalizedZeroPriceText(
            product.priceFormatStyle.precision(.fractionLength(0)).format(0)
        )
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
