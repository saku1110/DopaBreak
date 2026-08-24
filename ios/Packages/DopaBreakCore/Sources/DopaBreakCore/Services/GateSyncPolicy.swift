import Foundation

/// ゲート専用ManagedSettingsストアへ加える操作。
public enum GateSyncAction: Equatable, Sendable {
    case apply
    case clear
    case preserve
}

/// 権利確認の成否と適用対象の有無だけから同期操作を決める純関数。
///
/// 未確認時は課金者のゲートを剥がさず、Free確定時は対象ファイルを読めなくても解除する。
public enum GateSyncPolicy {
    public static func requiresUnconditionalClear(
        gateAllowed: Bool,
        hasConfirmedEntitlement: Bool
    ) -> Bool {
        hasConfirmedEntitlement && !gateAllowed
    }

    public static func action(
        gateAllowed: Bool,
        hasConfirmedEntitlement: Bool,
        hasTokensToShield: Bool
    ) -> GateSyncAction {
        guard hasConfirmedEntitlement else {
            return .preserve
        }
        guard gateAllowed else {
            return .clear
        }
        return hasTokensToShield ? .apply : .clear
    }

    /// 対象の読み取り失敗は現状維持へ倒す。ただしFree確定時は読み取り自体を行わず解除する。
    public static func action(
        tokensProvider: () throws -> Bool,
        gateAllowed: Bool,
        hasConfirmedEntitlement: Bool
    ) -> GateSyncAction {
        if requiresUnconditionalClear(
            gateAllowed: gateAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement
        ) {
            return .clear
        }
        guard hasConfirmedEntitlement else {
            return .preserve
        }

        do {
            return action(
                gateAllowed: gateAllowed,
                hasConfirmedEntitlement: hasConfirmedEntitlement,
                hasTokensToShield: try tokensProvider()
            )
        } catch {
            return .preserve
        }
    }
}
