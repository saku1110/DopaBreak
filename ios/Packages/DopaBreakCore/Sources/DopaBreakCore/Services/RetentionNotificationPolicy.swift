import Foundation

/// StoreKit の entitlement から、継続率向け通知に必要な最小限の情報だけを渡す値。
/// StoreKit 自体には依存しないため、判定と日付計算を単体テストできる。
public struct SubscriptionEntitlementSnapshot: Equatable, Sendable {
    public enum OfferType: String, Sendable {
        case introductory
        case other
    }

    public let productID: String
    public let purchaseDate: Date
    public let originalPurchaseDate: Date?
    public let offerType: OfferType?
    public let willAutoRenew: Bool?

    public init(
        productID: String,
        purchaseDate: Date,
        originalPurchaseDate: Date? = nil,
        offerType: OfferType?,
        willAutoRenew: Bool? = nil
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.offerType = offerType
        self.willAutoRenew = willAutoRenew
    }

    public var initialPurchaseDate: Date {
        originalPurchaseDate ?? purchaseDate
    }

    public var isSubscription: Bool {
        ProProductID.productKind(for: productID) == .subscription
    }

    public var isAnnual: Bool {
        productID == ProProductID.annual.rawValue ||
            productID == ProProductID.annualLaunch.rawValue
    }

    public var isAnnualIntroductoryTrial: Bool {
        isSubscription && isAnnual && offerType == .introductory
    }
}

public enum RetentionNotificationDateCalculator {
    public static func trialDay5Date(
        from purchaseDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        dateAfterDays(5, from: purchaseDate, calendar: calendar)
    }

    public static func month1Date(
        from purchaseDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        dateAfterDays(30, from: purchaseDate, calendar: calendar)
    }

    public static func month12Date(
        from purchaseDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        dateAfterDays(358, from: purchaseDate, calendar: calendar)
    }

    public static func isFuture(_ date: Date, relativeTo now: Date) -> Bool {
        date > now
    }

    private static func dateAfterDays(
        _ days: Int,
        from date: Date,
        calendar: Calendar
    ) -> Date? {
        calendar.date(byAdding: .day, value: days, to: date)
    }
}

public enum WeeklyPaywallPolicy {
    public static let interval: TimeInterval = 7 * 24 * 60 * 60
    public static let anyPaywallCooldown: TimeInterval = 24 * 60 * 60

    public static func shouldPresent(
        isPro: Bool,
        hasResolvedEntitlement: Bool,
        onboardingCompleted: Bool,
        onboardingCompletedAt: Date?,
        lastShownAt: Date?,
        lastAnyPaywallShownAt: Date?,
        now: Date
    ) -> Bool {
        guard hasResolvedEntitlement,
              !isPro,
              onboardingCompleted,
              let onboardingCompletedAt,
              now >= onboardingCompletedAt.addingTimeInterval(interval) else {
            return false
        }

        if let lastAnyPaywallShownAt,
           now < lastAnyPaywallShownAt.addingTimeInterval(anyPaywallCooldown) {
            return false
        }

        guard let lastShownAt else {
            return true
        }
        return now >= lastShownAt.addingTimeInterval(interval)
    }
}

public enum RetentionNotificationPolicy {
    public static func shouldScheduleRenewalNotification(willAutoRenew: Bool?) -> Bool {
        willAutoRenew == true
    }
}
