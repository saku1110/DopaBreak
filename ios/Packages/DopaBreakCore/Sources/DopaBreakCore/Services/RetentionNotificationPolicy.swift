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
    /// 現在の請求期間の終了日。自動更新オフを検知したときの「期限3日前」通知の基準になる。
    public let expirationDate: Date?

    public init(
        productID: String,
        purchaseDate: Date,
        originalPurchaseDate: Date? = nil,
        offerType: OfferType?,
        willAutoRenew: Bool? = nil,
        expirationDate: Date? = nil
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.offerType = offerType
        self.willAutoRenew = willAutoRenew
        self.expirationDate = expirationDate
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

    public var isMonthly: Bool {
        productID == ProProductID.monthly.rawValue
    }

    public var isAnnualIntroductoryTrial: Bool {
        isSubscription && isAnnual && offerType == .introductory
    }
}

/// 無料トライアル終了の何日前に知らせるかの選択肢。
/// ペイウォールでの事前選択と、保存値の正規化の両方でここを正本にする。
public enum TrialReminderLeadDays {
    /// 既定は終了2日前。従来の固定スケジュール（Day5）と同じ日に落ちる。
    public static let standard = 2
    public static let allowed = [2, 3]

    public static func normalized(_ value: Int) -> Int {
        allowed.contains(value) ? value : standard
    }
}

public enum RetentionNotificationDateCalculator {
    /// 7日間の無料トライアルの「終了`leadDays`日前」に当たる日付。
    /// 予約日はトライアル開始から `7 - leadDays` 日後になる。
    /// - Parameter leadDays: 終了何日前に知らせるか。想定は2か3だが、
    ///   保存値が壊れていても購入日以前・終了日以降へ飛ばさないよう1〜6へ丸める。
    public static func trialReminderDate(
        from purchaseDate: Date,
        leadDays: Int,
        calendar: Calendar = .current
    ) -> Date? {
        let clampedLeadDays = min(max(leadDays, 1), 6)
        return dateAfterDays(7 - clampedLeadDays, from: purchaseDate, calendar: calendar)
    }

    /// 終了2日前（開始から5日後）。`trialReminderDate` の既定値ぶんの薄い別名。
    public static func trialDay5Date(
        from purchaseDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        trialReminderDate(
            from: purchaseDate,
            leadDays: TrialReminderLeadDays.standard,
            calendar: calendar
        )
    }

    public static func nextMonthlyReportDate(
        from initialPurchaseDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let purchaseMonthStart = monthStart(
            for: initialPurchaseDate,
            calendar: calendar
        ),
        let nowMonthStart = monthStart(for: now, calendar: calendar) else {
            return nil
        }

        let elapsedMonths = calendar.dateComponents(
            [.month],
            from: purchaseMonthStart,
            to: nowMonthStart
        ).month ?? 0
        var monthOffset = max(1, elapsedMonths)

        while let anniversary = monthlyAnniversary(
            from: initialPurchaseDate,
            monthOffset: monthOffset,
            calendar: calendar
        ) {
            if NotificationQuietHours.adjustedFireDate(
                anniversary,
                calendar: calendar
            ) > now {
                return anniversary
            }
            monthOffset += 1
        }

        return nil
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

    private static func monthStart(
        for date: Date,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month], from: date)
        components.day = 1
        components.hour = 12
        return calendar.date(from: components)
    }

    private static func monthlyAnniversary(
        from initialPurchaseDate: Date,
        monthOffset: Int,
        calendar: Calendar
    ) -> Date? {
        guard let initialMonthStart = monthStart(
            for: initialPurchaseDate,
            calendar: calendar
        ),
        let targetMonthStart = calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: initialMonthStart
        ),
        let validDays = calendar.range(of: .day, in: .month, for: targetMonthStart) else {
            return nil
        }

        let original = calendar.dateComponents(
            [.day, .hour, .minute, .second, .nanosecond],
            from: initialPurchaseDate
        )
        var target = calendar.dateComponents([.era, .year, .month], from: targetMonthStart)
        target.day = min(original.day ?? 1, validDays.count)
        target.hour = original.hour
        target.minute = original.minute
        target.second = original.second
        target.nanosecond = original.nanosecond
        return calendar.date(from: target)
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
