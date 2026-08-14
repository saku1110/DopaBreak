import Foundation

public extension InterventionMode {
    /// 画面に出して選ばせて良いモード。
    ///
    /// `nightOnly` は時間帯での切り替えが未実装のため出さない（docs/12 §1）。
    /// 列挙の分岐は温存したまま、露出だけをここで一括管理する。
    /// `allCases` を直接まわすと、未実装のモードが画面に出て保存まで届く。
    static var selectable: [InterventionMode] { [.standard, .deepFocus] }

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
}
