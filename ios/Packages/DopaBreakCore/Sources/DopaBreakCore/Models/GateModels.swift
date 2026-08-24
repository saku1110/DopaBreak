import Foundation

/// アプリごとの「開く回数・長さ・待ち時間」。
///
/// `tokenData` は `ApplicationToken` を `JSONEncoder` で符号化した値をそのまま持つ。
/// 表示名は取得できず、トークン自体も更新で同一性が揺れることがあるため、
/// 一致しないときは制限なしの既定値へ倒して閉じ込めを作らない。
public struct GateAppSetting: Codable, Equatable, Sendable {
    public var tokenData: Data
    public var dailyOpenLimit: Int?
    public var sessionMinutes: Int
    public var cooldownMinutes: Int
    public var updatedAt: Date

    public init(
        tokenData: Data,
        dailyOpenLimit: Int?,
        sessionMinutes: Int,
        cooldownMinutes: Int,
        updatedAt: Date
    ) {
        self.tokenData = tokenData
        self.dailyOpenLimit = dailyOpenLimit
        self.sessionMinutes = sessionMinutes
        self.cooldownMinutes = cooldownMinutes
        self.updatedAt = updatedAt
    }
}

public struct GateAppSettingsSnapshot: Codable, Equatable, Sendable {
    public var settings: [GateAppSetting]
    public var updatedAt: Date

    public init(settings: [GateAppSetting], updatedAt: Date) {
        self.settings = settings
        self.updatedAt = updatedAt
    }

    /// 完全一致する設定だけを採用する。見つからないときは制限なしへ倒す。
    public func setting(for tokenData: Data) -> GateAppSetting {
        settings.first { $0.tokenData == tokenData } ?? GateDefaults.setting(for: tokenData)
    }

    public static let empty = GateAppSettingsSnapshot(
        settings: [],
        updatedAt: .distantPast
    )
}

/// 一回の一時開放。進行中かどうかは `endsAt` と現在時刻だけで決める。
public struct GateGrant: Codable, Equatable, Sendable {
    public var id: UUID
    public var tokenData: Data
    public var ruleId: UUID
    public var startedAt: Date
    public var endsAt: Date
    public var activityName: String

    public init(
        id: UUID,
        tokenData: Data,
        ruleId: UUID,
        startedAt: Date,
        endsAt: Date,
        activityName: String
    ) {
        self.id = id
        self.tokenData = tokenData
        self.ruleId = ruleId
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.activityName = activityName
    }
}

public struct GateLedgerEntry: Codable, Equatable, Sendable {
    public var tokenData: Data
    public var dayKey: String
    public var opensToday: Int
    public var lastGrantEndedAt: Date?

    public init(
        tokenData: Data,
        dayKey: String,
        opensToday: Int,
        lastGrantEndedAt: Date?
    ) {
        self.tokenData = tokenData
        self.dayKey = dayKey
        self.opensToday = opensToday
        self.lastGrantEndedAt = lastGrantEndedAt
    }
}

public struct GateUnlockRequest: Codable, Equatable, Sendable {
    public var id: UUID
    public var tokenData: Data
    public var requestedAt: Date

    public init(id: UUID, tokenData: Data, requestedAt: Date) {
        self.id = id
        self.tokenData = tokenData
        self.requestedAt = requestedAt
    }
}

public struct GateLedger: Codable, Equatable, Sendable {
    public var entries: [GateLedgerEntry]
    public var activeGrants: [GateGrant]
    public var updatedAt: Date

    public init(
        entries: [GateLedgerEntry],
        activeGrants: [GateGrant],
        updatedAt: Date
    ) {
        self.entries = entries
        self.activeGrants = activeGrants
        self.updatedAt = updatedAt
    }

    public static let empty = GateLedger(
        entries: [],
        activeGrants: [],
        updatedAt: .distantPast
    )
}

/// ゲート対象の選択を、権利確認済みのアプリから拡張へ渡す控え。
///
/// 拡張は権利判定やルールの再解釈をせず、この控えにある選択だけを使う。
public struct GateShieldSnapshot: Codable, Equatable, Sendable {
    public var selectionDataList: [Data]
    public var updatedAt: Date

    public init(selectionDataList: [Data], updatedAt: Date) {
        self.selectionDataList = selectionDataList
        self.updatedAt = updatedAt
    }
}

/// 閉じ込めを作らないゲートの既定値。
public enum GateDefaults {
    public static let dailyOpenLimit: Int? = nil
    public static let sessionMinutes = 10
    public static let cooldownMinutes = 0

    public static func setting(for tokenData: Data) -> GateAppSetting {
        GateAppSetting(
            tokenData: tokenData,
            dailyOpenLimit: dailyOpenLimit,
            sessionMinutes: sessionMinutes,
            cooldownMinutes: cooldownMinutes,
            updatedAt: .distantPast
        )
    }
}
