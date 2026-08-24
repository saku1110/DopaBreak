import Foundation

/// 「いますぐ」で始めた完全ブロックの一回ぶん。
///
/// `endsAt` が `nil` のときは「自分で戻すまで」。終わる時刻を持たないだけで、
/// 進行中であることに変わりはない。時刻を持つ回だけが自動で終わる。
public struct DeepFocusSession: Codable, Equatable, Sendable {
    public var startedAt: Date
    /// 終わる時刻。`nil` は「自分で戻すまで」。
    public var endsAt: Date?

    public init(startedAt: Date, endsAt: Date?) {
        self.startedAt = startedAt
        self.endsAt = endsAt
    }
}

/// 週に1本だけ持つ、完全ブロックの時間帯。
///
/// 曜日を増やせるだけのルールビルダーにはしない（1本に固定する）。
/// 跨日（22:00→翌6:00）は開始した曜日のぶんとして数える。
public struct DeepFocusSchedule: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    /// `Calendar` と同じ並び（1=日曜 … 7=土曜）。範囲外と重複を落とした昇順で持つ。
    public var weekdays: [Int]
    public var startMinutes: Int
    public var endMinutes: Int

    public init(
        isEnabled: Bool,
        weekdays: [Int],
        startMinutes: Int,
        endMinutes: Int
    ) {
        self.isEnabled = isEnabled
        self.weekdays = DeepFocusWindowPolicy.normalizedWeekdays(weekdays)
        self.startMinutes = DeepFocusWindowPolicy.normalizedMinutes(startMinutes)
        self.endMinutes = DeepFocusWindowPolicy.normalizedMinutes(endMinutes)
    }

    /// 保存された値からそのまま組み立てるとき用。デコードでも同じ正規化を通す。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
            weekdays: try container.decode([Int].self, forKey: .weekdays),
            startMinutes: try container.decode(Int.self, forKey: .startMinutes),
            endMinutes: try container.decode(Int.self, forKey: .endMinutes)
        )
    }

    /// 未設定の既定。曜日が空なので、そのままでは窓として成立しない。
    public static let disabled = DeepFocusSchedule(
        isEnabled: false,
        weekdays: [],
        startMinutes: DeepFocusConstants.defaultScheduleStartMinutes,
        endMinutes: DeepFocusConstants.defaultScheduleEndMinutes
    )
}

/// 完全ブロックの窓を、拡張が読める形で置いておくための控え。
///
/// `NightShieldSnapshot` と同じ考え方で、権利の判定もルールの読み取りも
/// アプリ側で済ませてから書く。拡張には「書いてあるものを、いま窓の内なら適用する」
/// だけが残る。権利を落としたらアプリが控えごと消す。
public struct DeepFocusShieldSnapshot: Codable, Equatable, Sendable {
    /// 毎週の予定で使う、有効なディープフォーカスルールの `activitySelectionData`。
    /// 空のルールは含めない。
    public var selectionDataList: [Data]
    /// 手動セッション中だけ使う、有効な全モードの `activitySelectionData`。
    ///
    /// `nil` はこのフィールドを持たない旧版の控えを表す。その場合は互換性のため
    /// `selectionDataList` を手動セッションにも使う。
    public var sessionSelectionDataList: [Data]?
    public var schedule: DeepFocusSchedule
    /// 進行中のセッション。無ければ `nil`。
    public var session: DeepFocusSession?
    public var updatedAt: Date

    public init(
        selectionDataList: [Data],
        sessionSelectionDataList: [Data]? = nil,
        schedule: DeepFocusSchedule,
        session: DeepFocusSession?,
        updatedAt: Date
    ) {
        self.selectionDataList = selectionDataList
        self.sessionSelectionDataList = sessionSelectionDataList
        self.schedule = schedule
        self.session = session
        self.updatedAt = updatedAt
    }
}
