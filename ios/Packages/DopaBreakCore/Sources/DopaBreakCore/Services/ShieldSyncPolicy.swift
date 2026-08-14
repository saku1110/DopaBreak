import Foundation

/// 完全ブロック（ManagedSettings）へ加える操作。
///
/// `preserve` は「触らない」であって「解除しない」でもある。権利を取り直せていない状態で
/// 解除すると、通信が切れているだけの課金者から完全ブロックを剥がしてしまうため、
/// 未確定のあいだは現状を保つ。
public enum ShieldSyncAction: Equatable, Sendable {
    /// 指定ルールの対象を完全ブロックする。
    case apply(rules: [TargetRule])
    /// 完全ブロックを解除する。
    case clear
    /// 現状を維持する（適用も解除もしない）。
    case preserve
}

/// 完全ブロック（Deep Focus / 夜だけ強化）の適用可否を決める純関数。
///
/// どちらもPro専用。`deepFocus` は常時、`nightOnly` は就寝から起床までの窓のなかだけ通す。
/// いまが夜かどうかの判定は `NightWindowPolicy` が持ち、ここへは結果だけを渡す。
/// 時計を読む処理をこの純関数へ入れないため、呼び出し側が毎回明示して渡す。
///
/// **降格は非破壊で行う（2026-08-14 Fable裁定・恒久）。**
/// Freeへ戻った人には「シールドを解除する」だけで、ルールに保存された `deepFocus` は書き換えない。
/// 対象アプリのクランプが控えを持って復元できるようにしてあるのと同じ考え方で、
/// 再びProになったときに前の設定がそのまま戻るようにするため。
/// ここでルールを `standard` へ書き潰すと、復元できない永久的な設定変更になる。
public enum ShieldSyncPolicy {
    /// 完全ブロックの対象になるルールを返す。
    ///
    /// 権利が未確定のときは空を返すが、これは「解除せよ」の意味ではない。
    /// 解除・維持の判断は `action(...)` が持つ。
    public static func rulesToShield(
        rules: [TargetRule],
        isPro: Bool,
        strictModeAllowed: Bool,
        hasConfirmedEntitlement: Bool,
        isNightWindow: Bool
    ) -> [TargetRule] {
        guard hasConfirmedEntitlement, isPro, strictModeAllowed else {
            return []
        }
        return rules.filter { rule in
            rule.isEnabled
                && shieldsNow(mode: rule.mode, isNightWindow: isNightWindow)
                && !rule.activitySelectionData.isEmpty
        }
    }

    /// いまこの強さがブロックを出すか。夜だけ強化は窓の外では何も出さない。
    private static func shieldsNow(mode: InterventionMode, isNightWindow: Bool) -> Bool {
        switch mode {
        case .deepFocus:
            return true
        case .nightOnly:
            return isNightWindow
        case .standard:
            return false
        }
    }

    /// ルールを一切見ずに解除して良いか。
    ///
    /// 「Freeだと確定した」だけで解除は確定する。ルールの読み取りは解除の条件ではないため、
    /// 読み取りに失敗する端末でも解除だけは必ず通す（読み取り失敗で `return` すると、
    /// Freeへ戻った人の完全ブロックが恒久的に残る）。
    public static func requiresUnconditionalClear(
        isPro: Bool,
        strictModeAllowed: Bool,
        hasConfirmedEntitlement: Bool
    ) -> Bool {
        hasConfirmedEntitlement && (!isPro || !strictModeAllowed)
    }

    /// 完全ブロックへ加える操作を決める。
    ///
    /// - 未確定: `preserve`（現状維持）
    /// - Free確定 / 対象なし: `clear`
    /// - Pro確定かついま出す対象あり: `apply`
    public static func action(
        rules: [TargetRule],
        isPro: Bool,
        strictModeAllowed: Bool,
        hasConfirmedEntitlement: Bool,
        isNightWindow: Bool
    ) -> ShieldSyncAction {
        guard hasConfirmedEntitlement else {
            return .preserve
        }

        let targets = rulesToShield(
            rules: rules,
            isPro: isPro,
            strictModeAllowed: strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            isNightWindow: isNightWindow
        )
        return targets.isEmpty ? .clear : .apply(rules: targets)
    }

    /// ルールの取得ごと判断する。取得の成否と権利の判断を1か所に閉じるための入口。
    ///
    /// 解除が確定する条件（Freeだと確定した）では **`rulesProvider` を呼ばない**。
    /// 呼んでから判断すると、ルールを読めない端末で解除が丸ごと落ちる。
    /// 取得に失敗した場合は `preserve`（現状維持）で、適用も解除もしない。
    public static func action(
        rulesProvider: () throws -> [TargetRule],
        isPro: Bool,
        strictModeAllowed: Bool,
        hasConfirmedEntitlement: Bool,
        isNightWindow: Bool
    ) -> ShieldSyncAction {
        if requiresUnconditionalClear(
            isPro: isPro,
            strictModeAllowed: strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement
        ) {
            return .clear
        }

        guard hasConfirmedEntitlement else {
            return .preserve
        }

        let rules: [TargetRule]
        do {
            rules = try rulesProvider()
        } catch {
            return .preserve
        }

        return action(
            rules: rules,
            isPro: isPro,
            strictModeAllowed: strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            isNightWindow: isNightWindow
        )
    }
}
