import Foundation

/// 対象外になったアプリの自動化が発火したとき、「対象へ戻す」がどの結末になるかを決める。
///
/// 無料枠が埋まっているだけの状態を「2個目の追加」と数えると、入れ替えのつもりの操作が
/// ペイウォールに落ちる（2026-09-04にオーナー報告・シミュレータで再現）。
/// 枠が埋まっているときは押し出す相手を決めて入れ替え、課金導線はPro失効の経路だけに残す。
public enum NonTargetAutomationRestorePolicy {
    /// 自動化が対象外のまま残っている理由。
    /// アプリ側の `NonTargetAutomationReason` と1対1で対応させる。
    /// Coreは画面層の型を参照できないので、判定に要る区別だけをここに置く。
    public enum Reason: Equatable, Sendable {
        case removed
        case clampedByEntitlement
    }

    public enum Decision: Equatable, Sendable {
        /// 枠に空きがあるので、そのまま対象へ戻す。
        case add
        /// 枠が埋まっているので、押し出す相手を決めて入れ替える。
        case swap(displacedCatalogIDs: [String])
        /// Pro失効でクランプされた経路。課金導線を維持する。
        case requiresPro
    }

    /// - Parameters:
    ///   - reason: 対象外のまま自動化が残っている理由。
    ///   - restoredCatalogID: 戻そうとしているアプリのカタログID。
    ///   - selectedCatalogIDs: いま保存されている対象アプリ。
    ///   - limit: 対象アプリの上限。`nil` はPro（上限なし）。
    public static func decision(
        reason: Reason,
        restoredCatalogID: String,
        selectedCatalogIDs: [String],
        limit: Int?
    ) -> Decision {
        // Pro失効のクランプは課金の理由そのもの。ここを軽くすると再課金の動機が消えるため、
        // 2026-09-03の決定どおり常にペイウォールへ送る。
        guard reason == .removed else {
            return .requiresPro
        }

        // 戻す本人は数に入れない。選び直しただけのときに枠を1つ余計に食わないようにする。
        let others = selectedCatalogIDs.filter { $0 != restoredCatalogID }

        guard let limit, others.count >= limit else {
            return .add
        }
        // 上限0は現行のEntitlementGateでは起こらない。
        // 起きたときに入れ替えとして扱うと全対象を消したうえで対象外の一呼吸を始めてしまうので、
        // 何も保存しない課金導線へ寄せる。
        guard limit > 0 else {
            return .requiresPro
        }

        let resulting = resultingCatalogIDs(
            restoredCatalogID: restoredCatalogID,
            selectedCatalogIDs: selectedCatalogIDs,
            limit: limit
        )
        return .swap(displacedCatalogIDs: others.filter { !resulting.contains($0) })
    }

    /// 決定に対応する保存後の並び。順序は決定的にする。
    ///
    /// 戻すアプリを必ず末尾へ置いてから上限で切るので、上限1なら戻したアプリだけが残る。
    /// - Parameters:
    ///   - restoredCatalogID: 戻そうとしているアプリのカタログID。
    ///   - selectedCatalogIDs: いま保存されている対象アプリ。
    ///   - limit: 対象アプリの上限。`nil` はPro（上限なし）。
    public static func resultingCatalogIDs(
        restoredCatalogID: String,
        selectedCatalogIDs: [String],
        limit: Int?
    ) -> [String] {
        // 既に対象へ入っているアプリを戻すときも重複を作らない。
        // `InterventionTargetStore.validate` は重複でthrowするため、ここで潰しておく。
        let merged = selectedCatalogIDs.filter { $0 != restoredCatalogID } + [restoredCatalogID]

        guard let limit else {
            return merged
        }
        // 上限0は現行のEntitlementGateでは起こらない。
        // 起きたときに枠外を保存しないよう、防御的に空で返す。
        guard limit > 0 else {
            return []
        }
        return Array(merged.suffix(limit))
    }
}
