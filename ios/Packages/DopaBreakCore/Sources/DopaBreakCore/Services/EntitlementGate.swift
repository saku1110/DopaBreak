import Foundation

public enum ProProductKind: Equatable, Sendable {
    case subscription
    case nonConsumable
}

public enum ProProductID: String, CaseIterable, Sendable {
    case monthly = "dopabreak.pro.monthly"
    case annual = "dopabreak.pro.annual"
    case annualLaunch = "dopabreak.pro.annual.launch"
    case lifetime = "dopabreak.pro.lifetime"

    public static let allSubscriptionIDs: [String] = [
        ProProductID.monthly.rawValue,
        ProProductID.annual.rawValue,
        ProProductID.annualLaunch.rawValue
    ]

    public static let lifetimeID = ProProductID.lifetime.rawValue

    public static let allIDs: [String] = [
        ProProductID.monthly.rawValue,
        ProProductID.annual.rawValue,
        ProProductID.annualLaunch.rawValue,
        ProProductID.lifetime.rawValue
    ]

    public static func productKind(for productID: String) -> ProProductKind? {
        if allSubscriptionIDs.contains(productID) {
            return .subscription
        }

        if productID == lifetimeID {
            return .nonConsumable
        }

        return nil
    }

    public static func isSubscription(_ productID: String) -> Bool {
        productKind(for: productID) == .subscription
    }

    public static func isNonConsumable(_ productID: String) -> Bool {
        productKind(for: productID) == .nonConsumable
    }
}

public enum EntitlementTier: Equatable, Sendable {
    case free
    case pro
}

public struct EntitlementGate: Equatable, Sendable {
    private static let initialFreeWindowDuration: TimeInterval = 14 * 86_400

    public let tier: EntitlementTier
    public let now: Date
    public let firstLaunchDate: Date?

    public init(tier: EntitlementTier, now: Date, firstLaunchDate: Date?) {
        self.tier = tier
        self.now = now
        self.firstLaunchDate = firstLaunchDate
    }

    public init(isPro: Bool, now: Date, firstLaunchDate: Date?) {
        self.tier = isPro ? .pro : .free
        self.now = now
        self.firstLaunchDate = firstLaunchDate
    }

    public var heroGoalAllowed: Bool {
        true
    }

    public var yearGoalDisplayAllowed: Bool {
        tier == .pro
    }

    public var goalsLimit: Int? {
        switch tier {
        case .free:
            return 1
        case .pro:
            return nil
        }
    }

    public var targetRulesLimit: Int? {
        switch tier {
        case .free:
            return 1
        case .pro:
            return nil
        }
    }

    public var targetAppTokensLimit: Int? {
        switch tier {
        case .free:
            guard let firstLaunchDate else {
                return 1
            }
            let elapsed = now.timeIntervalSince(firstLaunchDate)
            return elapsed < Self.initialFreeWindowDuration ? 3 : 1
        case .pro:
            return nil
        }
    }

    public var statsDays: Int? {
        switch tier {
        case .free:
            return 1
        case .pro:
            return nil
        }
    }

    /// Pro向けの週次レポート詳細分析に使用する。基本件数の週次通知はFreeでも利用可能。
    public var weeklyReportAllowed: Bool {
        tier == .pro
    }

    public var strictModeAllowed: Bool {
        tier == .pro
    }

    public var themesAllowed: Bool {
        tier == .pro
    }

    public var canDisplayYearGoal: Bool {
        yearGoalDisplayAllowed
    }

    public func lockThemeAllowed(_ theme: LockTheme) -> Bool {
        switch tier {
        case .free:
            return theme == .e1
        case .pro:
            return true
        }
    }

    public func canAddRule(currentCount: Int) -> Bool {
        allowed(currentCount: currentCount, limit: targetRulesLimit)
    }

    public func canAddGoal(currentCount: Int) -> Bool {
        allowed(currentCount: currentCount, limit: goalsLimit)
    }

    public func canAddTargetTokens(currentCount: Int) -> Bool {
        allowed(currentCount: currentCount, limit: targetAppTokensLimit)
    }

    /// 保存済みの対象アプリを現在のEntitlement上限へ決定的に縮小する。
    /// 上限内またはPro（上限なし）の場合は入力順を含め、そのまま返す。
    public func clampedTargetAppCatalogIDs(_ catalogIDs: [String]) -> [String] {
        guard let limit = targetAppTokensLimit, catalogIDs.count > limit else {
            return catalogIDs
        }
        return Array(catalogIDs.prefix(limit))
    }

    private func allowed(currentCount: Int, limit: Int?) -> Bool {
        guard let limit else {
            return true
        }
        return currentCount < limit
    }
}
