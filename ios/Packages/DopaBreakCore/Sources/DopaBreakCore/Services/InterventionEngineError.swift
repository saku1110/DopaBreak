import Foundation

/// InterventionEngine が投げる型付きエラー。
///
/// 状態機械の不正遷移は `invalidTransition` で (from ステップ, action 名) を運ぶ。
public enum InterventionEngineError: Error, Equatable, Sendable {
    /// 現在ステップからは許可されていない操作が呼ばれた。
    case invalidTransition(from: InterventionStep, action: String)
    /// 対象ルールが必要な操作なのに、現在の状態にルールが紐づいていない。
    case missingRule(action: String)
}

extension InterventionEngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, action):
            return "Invalid intervention transition: cannot '\(action)' from step '\(from.rawValue)'"
        case let .missingRule(action):
            return "Intervention action '\(action)' requires an active rule but none is set"
        }
    }
}
