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
    public let tier: EntitlementTier
    public let now: Date

    public init(tier: EntitlementTier, now: Date) {
        self.tier = tier
        self.now = now
    }

    public init(isPro: Bool, now: Date) {
        self.tier = isPro ? .pro : .free
        self.now = now
    }

    public var heroGoalAllowed: Bool {
        true
    }

    public var yearGoalDisplayAllowed: Bool {
        tier == .pro
    }

    /// 目標はFree・Proとも無制限。2026-08-17のオーナー決定で、Freeの1件制限を撤廃した。
    /// 目標は介入体験の中核であり、件数を絞ると継続が落ちる一方で課金の押し出しは弱かったため。
    public var goalsLimit: Int? {
        nil
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
            return 1
        case .pro:
            return nil
        }
    }

    public var strictModeAllowed: Bool {
        tier == .pro
    }

    /// 日常の一呼吸ゲートはProだけに適用する。
    /// `strictModeAllowed` と現在は同値でも、機能の権利を別名で固定して将来の分岐を混ぜない。
    public var gateAllowed: Bool {
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

    /// 直近の試行回数が最多の対象アプリを残す。同数なら選択順を維持する。
    public func clampedTargetAppCatalogIDs(
        _ catalogIDs: [String],
        attemptCountsByCatalogID: [String: Int]
    ) -> [String] {
        guard let limit = targetAppTokensLimit, catalogIDs.count > limit else {
            return catalogIDs
        }
        return Self.preferredTargetAppCatalogIDs(
            catalogIDs,
            limit: limit,
            attemptCountsByCatalogID: attemptCountsByCatalogID
        )
    }

    /// 試行回数の多い順に、指定件数だけ対象アプリを残す。同数では選択順を維持する。
    public static func preferredTargetAppCatalogIDs(
        _ catalogIDs: [String],
        limit: Int,
        attemptCountsByCatalogID: [String: Int]
    ) -> [String] {
        guard limit > 0 else {
            return []
        }

        return catalogIDs
            .enumerated()
            .sorted { left, right in
                let leftCount = max(attemptCountsByCatalogID[left.element] ?? 0, 0)
                let rightCount = max(attemptCountsByCatalogID[right.element] ?? 0, 0)
                if leftCount != rightCount {
                    return leftCount > rightCount
                }
                return left.offset < right.offset
            }
            .prefix(limit)
            .map(\.element)
    }

    /// 選択順をタイブレークに使うため、同数では先に現れたIDを返す。
    public static func preferredTargetAppCatalogID(
        _ catalogIDs: [String],
        attemptCountsByCatalogID: [String: Int]
    ) -> String? {
        preferredTargetAppCatalogIDs(
            catalogIDs,
            limit: 1,
            attemptCountsByCatalogID: attemptCountsByCatalogID
        ).first
    }

    private func allowed(currentCount: Int, limit: Int?) -> Bool {
        guard let limit else {
            return true
        }
        return currentCount < limit
    }
}
