import Foundation

public enum ReflectionNotificationPolicy {
    /// 本人が宣言した終了時刻をそのまま使うため、静音時間は適用しない。
    public static func fireDate(
        promptedAt: Date,
        now: Date,
        isEnabled: Bool
    ) -> Date? {
        guard isEnabled, promptedAt > now else {
            return nil
        }
        return promptedAt
    }
}
