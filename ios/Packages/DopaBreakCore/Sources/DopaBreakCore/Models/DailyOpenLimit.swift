import Foundation

public enum DailyOpenLimitConstants {
    /// 使い切ったあとの完全ブロックを動かすDeviceActivity名。繰り返さない一回きりの予定。
    public static let activityName = "dopabreak.openlimit"

    /// 回数上限のぶんだけを置くManagedSettingsストア名。
    /// 夜・予定・手動とは分ける。混ぜると、起床時刻の解除で他の強さまで外れる。
    public static let shieldStoreName = "dopabreak.openlimit"

    /// 設定で選べる回数。
    public static let limitChoices = [3, 5, 8, 10, 12, 15, 20, 30]

    /// 最後の1回を時間なしで開いた場合に、止まり始めるまでの長さ（秒）。
    /// 画面では最後の1回に時間なしを出さないため、通常は使われない保険。
    public static let untimedLastOpenSeconds = 30 * 60
}

/// 1日に開ける回数の設定。オフでも値の型は持ち、権利を落としても残す（非破壊降格）。
public struct DailyOpenLimitSettings: Codable, Equatable, Sendable {
    /// 緩める変更（増やす・オフ）の予約。`effectiveAt` 以降に `limit` へ移る。
    public struct PendingChange: Codable, Equatable, Sendable {
        /// `nil` はオフへの予約。
        public var limit: Int?
        public var effectiveAt: Date

        public init(limit: Int?, effectiveAt: Date) {
            self.limit = limit
            self.effectiveAt = effectiveAt
        }
    }

    /// いま効いている上限。`nil` はオフ。
    public var limit: Int?
    public var pendingChange: PendingChange?
    /// オンにした時刻。その日のうちは、この時刻より前に開いた回を数えない。
    public var countingStartsAt: Date?
    /// 緊急で開く待ちを始めた時刻。画面を閉じても待ちを短縮できないように保存する。
    public var emergencyRequestedAt: Date?
    /// 使い切ったあと、まだ開けている時間の終わり（最後の1回の決めた時間・緊急で開いた時間）。表示だけに使う。
    public var openUntil: Date?

    public init(
        limit: Int? = nil,
        pendingChange: PendingChange? = nil,
        countingStartsAt: Date? = nil,
        emergencyRequestedAt: Date? = nil,
        openUntil: Date? = nil
    ) {
        self.limit = limit
        self.pendingChange = pendingChange
        self.countingStartsAt = countingStartsAt
        self.emergencyRequestedAt = emergencyRequestedAt
        self.openUntil = openUntil
    }
}

/// 使い切ったあとの完全ブロックを、拡張が読める形で置いておく控え。
///
/// 夜・完全ブロックの窓の控えと同じく、権利の判定もルールの読み取りもアプリ側で済ませてから書く。
/// 拡張には「書いてあるものを、いま窓の内なら適用する」だけが残る。
/// 権利を落としたらアプリが控えごと消す。
public struct DailyOpenLimitShieldSnapshot: Codable, Equatable, Sendable {
    /// 完全ブロックの対象（有効なルールの `activitySelectionData`）。空のルールは含めない。
    public var selectionDataList: [Data]
    /// 止まった時点までに今日開いた回数。シールドの文言に使う。
    public var openedCount: Int
    /// 止まり始める時刻。緊急で開いたときは、その時間の終わりへずらす。
    public var blockStartsAt: Date
    /// 止まり終わる時刻（次の起床時刻）。
    public var blockEndsAt: Date
    public var updatedAt: Date

    public init(
        selectionDataList: [Data],
        openedCount: Int,
        blockStartsAt: Date,
        blockEndsAt: Date,
        updatedAt: Date
    ) {
        self.selectionDataList = selectionDataList
        self.openedCount = openedCount
        self.blockStartsAt = blockStartsAt
        self.blockEndsAt = blockEndsAt
        self.updatedAt = updatedAt
    }
}

/// 画面へ渡す、今日の回数の状態。
public struct DailyOpenLimitStatus: Equatable, Sendable {
    /// いま効いている上限。`nil` はオフ。
    public var limit: Int?
    public var pendingChange: DailyOpenLimitSettings.PendingChange?
    /// 今日（数え始め以降）に開いた回数。
    public var openedCount: Int
    /// 次の区切り（次の起床時刻）。
    public var dayEndsAt: Date

    public init(
        limit: Int?,
        pendingChange: DailyOpenLimitSettings.PendingChange?,
        openedCount: Int,
        dayEndsAt: Date
    ) {
        self.limit = limit
        self.pendingChange = pendingChange
        self.openedCount = openedCount
        self.dayEndsAt = dayEndsAt
    }

    /// 残りの回数。オフなら `nil`。
    public var remaining: Int? {
        limit.map { DailyOpenLimitPolicy.remaining(limit: $0, openedCount: openedCount) }
    }

    /// 今日の回数を使い切ったか。
    public var isExhausted: Bool { remaining == 0 }

    /// 次に開くと使い切る（最後の1回）か。
    public var isLastOpen: Bool { remaining == 1 }

    public static func off(dayEndsAt: Date) -> Self {
        Self(limit: nil, pendingChange: nil, openedCount: 0, dayEndsAt: dayEndsAt)
    }
}
