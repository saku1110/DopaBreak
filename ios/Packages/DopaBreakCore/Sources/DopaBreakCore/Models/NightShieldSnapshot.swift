import Foundation

/// 夜の窓で完全ブロックする対象を、拡張が読める形で置いておくための控え。
///
/// MonitorExtensionの中では権利の判定もルールの読み取りもしない。
/// 拡張は「Proだと確定しているあいだにアプリが書いたもの」だけを見て適用する。
/// 権利を落としたときはアプリが控えごと消すため、拡張側に降格の判断を持たせずに済む。
public struct NightShieldSnapshot: Codable, Equatable, Sendable {
    /// 有効な夜だけ強化ルールの `activitySelectionData`。空のルールは含めない。
    public var selectionDataList: [Data]
    public var bedTimeMinutes: Int
    public var wakeTimeMinutes: Int
    public var updatedAt: Date

    public init(
        selectionDataList: [Data],
        bedTimeMinutes: Int,
        wakeTimeMinutes: Int,
        updatedAt: Date
    ) {
        self.selectionDataList = selectionDataList
        self.bedTimeMinutes = bedTimeMinutes
        self.wakeTimeMinutes = wakeTimeMinutes
        self.updatedAt = updatedAt
    }
}
