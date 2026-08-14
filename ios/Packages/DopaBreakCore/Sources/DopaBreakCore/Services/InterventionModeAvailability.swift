import Foundation

public extension InterventionMode {
    /// 画面に出して選ばせて良いモード。
    ///
    /// `nightOnly` は時間帯での切り替えができるまで露出を止めていた（2026-08-14に解禁）。
    /// `allCases` を直接まわすと、未実装のモードが画面に出て保存まで届くため、
    /// 露出はここで一括管理する。
    static var selectable: [InterventionMode] { [.standard, .deepFocus, .nightOnly] }

    /// 保存して良い値かどうか。
    var isSelectable: Bool {
        Self.selectable.contains(self)
    }

    /// 保存できる値へ移す。未実装のモードは標準として扱う。
    ///
    /// 画面側の列挙漏れが保存まで通らないよう、永続化の境界でもう一度落とすためのもの。
    var persistable: InterventionMode {
        isSelectable ? self : .standard
    }

    /// 完全ブロック（ManagedSettings）を使う強さかどうか。
    ///
    /// 出す時間帯は違っても、アプリを開けなくする点は同じでどちらもPro専用。
    /// 画面側の解放判定を `deepFocus` の直接比較で書くと、夜だけ強化がFreeへ素通りする。
    var usesShield: Bool {
        switch self {
        case .deepFocus, .nightOnly:
            return true
        case .standard:
            return false
        }
    }
}
