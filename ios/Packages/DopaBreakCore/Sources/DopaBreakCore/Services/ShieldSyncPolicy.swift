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

/// Proのブロック設定と、呼び出し側で計算した3種類の窓を照合する純関数。
/// 本体は必ず保存済みの `blockConfiguration` を渡す。nilは旧API呼び出しの互換変換専用。
/// 権利未確定は現状維持、Free確定はルール読み込みの成否にかかわらず解除する。
/// トリガー選択の保持・権利復帰はSettingsStoreが担当する。
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
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool,
        isManualDeepFocusSessionActive: Bool = false,
        allowsNightSchedule: Bool = false,
        blockConfiguration: BlockConfiguration? = nil
    ) -> [TargetRule] {
        guard hasConfirmedEntitlement, isPro, strictModeAllowed else {
            return []
        }
        return rules.filter { rule in
            rule.isEnabled
                && shieldsNow(
                    configuration: blockConfiguration ?? (isManualDeepFocusSessionActive ? BlockConfiguration(blockEnabled: true, blockTriggers: [.manual]) : .migrating(rule.mode, weeklySchedulesDuringNightEnabled: allowsNightSchedule)),
                    isNightWindow: isNightWindow,
                    isDeepFocusWindowActive: isDeepFocusWindowActive,
                    isManualDeepFocusSessionActive: isManualDeepFocusSessionActive,
                    allowsNightSchedule: allowsNightSchedule
                )
                && !rule.activitySelectionData.isEmpty
        }
    }

    /// いまこの強さがブロックを出すか。どちらの強さも窓の外では何も出さない。
    private static func shieldsNow(
        configuration: BlockConfiguration,
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool,
        isManualDeepFocusSessionActive: Bool,
        allowsNightSchedule: Bool
    ) -> Bool {
        configuration.isActive(manual: isManualDeepFocusSessionActive,
                               weeklySchedule: isDeepFocusWindowActive,
                               night: isNightWindow)
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
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool,
        isManualDeepFocusSessionActive: Bool = false,
        allowsNightSchedule: Bool = false,
        blockConfiguration: BlockConfiguration? = nil
    ) -> ShieldSyncAction {
        guard hasConfirmedEntitlement else {
            return .preserve
        }

        let targets = rulesToShield(
            rules: rules,
            isPro: isPro,
            strictModeAllowed: strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            isNightWindow: isNightWindow,
            isDeepFocusWindowActive: isDeepFocusWindowActive,
            isManualDeepFocusSessionActive: isManualDeepFocusSessionActive,
            allowsNightSchedule: allowsNightSchedule,
            blockConfiguration: blockConfiguration
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
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool,
        isManualDeepFocusSessionActive: Bool = false,
        allowsNightSchedule: Bool = false,
        blockConfiguration: BlockConfiguration? = nil
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
            isNightWindow: isNightWindow,
            isDeepFocusWindowActive: isDeepFocusWindowActive,
            isManualDeepFocusSessionActive: isManualDeepFocusSessionActive,
            allowsNightSchedule: allowsNightSchedule,
            blockConfiguration: blockConfiguration
        )
    }
}
