import Foundation

public enum AppGroup {
    public static let identifier = "group.com.dopabreak.shared"
}

public enum GateConstants {
    /// 日常の一呼吸ゲートだけを置くManagedSettingsストア名。
    public static let shieldStoreName = "dopabreak.gate"

    /// 解除ごとに一意なDeviceActivity名を作るための頭。
    public static let reshieldActivityPrefix = "dopabreak.gate.reshield."

    /// 通知を要求単位で取り消せるようにするためのidentifierの頭。
    public static let unlockNotificationIdentifierPrefix = "dopabreak.gate.unlock."

    /// シールドからアプリへ移る途中の要求は10分だけ有効。
    public static let pendingRequestTTL: TimeInterval = 600

    /// DeviceActivityの監視上限に余裕を残すため、同時開放は最大5件に絞る。
    public static let maximumConcurrentGrants = 5

    /// 通知タップから要求を特定するuserInfoキー。アプリ側と拡張側で共有する。
    public static let unlockRequestUserInfoKey = "gateUnlockRequestId"

    /// 通知を出せない状態を同期表示へ渡すApp Group UserDefaultsキー。
    public static let notificationUnavailableDefaultsKey = "dopabreak.gate.notificationUnavailable"

    public static func reshieldActivityName(for grantID: UUID) -> String {
        reshieldActivityPrefix + grantID.uuidString
    }

    public static func unlockNotificationIdentifier(for requestID: UUID) -> String {
        unlockNotificationIdentifierPrefix + requestID.uuidString
    }
}

/// FamilyControlsトークンを台帳キーへ変換する唯一の符号化契約。
///
/// `ApplicationToken`自体はCoreのmacOSテストから参照できないため、Codableへ一般化する。
/// 全プロセスが同じJSONEncoder/Decoderを使うことで、同じトークンのData比較を安定させる。
public enum GateTokenCoding {
    public static func encode<Token: Encodable>(_ token: Token) throws -> Data {
        try encoder.encode(token)
    }

    public static func decode<Token: Decodable>(
        _ type: Token.Type,
        from data: Data
    ) throws -> Token {
        try decoder.decode(type, from: data)
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
