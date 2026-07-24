import Foundation

/// Onboarding paywall dismissal opens a short-lived Pro experience.
/// This policy deliberately has no StoreKit or UI dependencies so the time
/// boundary and transition can be tested with a fixed clock.
public enum ReverseTrialPolicy {
    public static let reverseTrialDays = 3
    public static let reverseTrialDuration: TimeInterval = TimeInterval(reverseTrialDays) * 86_400

    public static func endDate(startedAt: Date) -> Date {
        startedAt.addingTimeInterval(reverseTrialDuration)
    }

    public static func isActive(startedAt: Date?, now: Date) -> Bool {
        guard let startedAt else {
            return false
        }
        return endDate(startedAt: startedAt) > now
    }

    /// Returns the user-facing number of calendar days remaining, rounded up.
    /// An expired or missing trial has no remaining-day value.
    public static func remainingDays(startedAt: Date?, now: Date) -> Int? {
        guard let startedAt else {
            return nil
        }
        let secondsRemaining = endDate(startedAt: startedAt).timeIntervalSince(now)
        guard secondsRemaining > 0 else {
            return nil
        }
        return max(1, Int(ceil(secondsRemaining / 86_400)))
    }

    public static func shouldPresentEndPaywall(
        startedAt: Date?,
        isPro: Bool,
        endPaywallShown: Bool,
        now: Date
    ) -> Bool {
        guard !isPro, !endPaywallShown else {
            return false
        }
        return !isActive(startedAt: startedAt, now: now) && startedAt != nil
    }
}
