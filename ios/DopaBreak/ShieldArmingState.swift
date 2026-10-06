import Foundation

/// 完全ブロック（夜だけ強化・ディープフォーカス）の下ごしらえが、いまどこまで進んだか。
///
/// 画面の解放は `isPro`（キャッシュ可・取得に失敗しても落とさない）で決まり、
/// 実際のブロックは `hasConfirmedEntitlement`（StoreKitへ届いたうえで解決できた）でしか始めない。
/// この2つのずれは意図してそうしてある（取得に失敗しただけの課金者を締め出さないため）。
/// ただしずれているあいだは、画面が「効いている」と名乗りながら控えも予定も一切置かれない。
/// その黙った失敗を呼び出し側へ持ち出すためだけの型で、解放条件そのものは何も変えない。
enum ShieldArmingOutcome: Equatable {
    /// 張れている、または張らないことが正しい。
    case ready
    /// 権利をStoreKitで確かめられていないため、控えも予定もまだ置いていない。
    case entitlementUnconfirmed
    /// 張ろうとして落ちた。
    case failed
}

enum ShieldArmingNoticePolicy {
    /// 「画面では有効なのに 実際のブロックが始まっていない」ことを注意行で出すか。
    ///
    /// 一度も権利の解決を試していない起動直後は出さない。取得は数秒で終わるため、
    /// そこで出すと毎回の起動で一瞬だけ光り、本当に届いていない人への合図が薄まる。
    static func shouldShowUnarmedNotice(
        outcome: ShieldArmingOutcome,
        hasAttemptedEntitlementResolution: Bool
    ) -> Bool {
        outcome == .failed || (outcome == .entitlementUnconfirmed && hasAttemptedEntitlementResolution)
    }
}
