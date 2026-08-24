import Foundation

/// 保存済みの介入モードを、現在確定している権利で表示可能な値へ丸める。
public enum InterventionModeResolver {
    /// Freeだと確定したときだけ、シールドを使うモードを標準へ落とす。
    /// 権利が未確定のあいだは、通信失敗だけで課金者の表示を降格させない。
    public static func resolve(
        _ mode: InterventionMode,
        hasConfirmedEntitlement: Bool,
        strictModeAllowed: Bool
    ) -> InterventionMode {
        guard mode.usesShield,
              hasConfirmedEntitlement,
              !strictModeAllowed else {
            return mode
        }
        return .standard
    }
}
