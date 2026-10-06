import DopaBreakCore
import Foundation

/// ホームと開かなかった画面で同じ「時間の貯金」を同じ書式にする唯一のフォーマッタ。
enum ReclaimedTimeFormatter {
    private static func formatted(
        _ key: String,
        defaultValue: String,
        arguments: [CVarArg],
        bundle: Bundle,
        locale _: Locale
    ) -> String {
        let format = bundle.localizedString(forKey: key, value: defaultValue, table: nil)
        return String(format: format, arguments: arguments)
    }

    static func string(
        seconds: Int,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let totalMinutes = max(0, seconds) / 60
        if totalMinutes < 60 {
            return formatted(
                "home.reclaimed.minutes",
                defaultValue: "%lld分",
                arguments: [totalMinutes],
                bundle: bundle,
                locale: locale
            )
        }

        let totalHours = totalMinutes / 60
        return formatted(
            "home.reclaimed.hours",
            defaultValue: "%lld時間",
            arguments: [totalHours],
            bundle: bundle,
            locale: locale
        )
    }

    static func equivalentString(
        seconds: Int,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        let totalDays = max(0, seconds) / 86_400
        guard totalDays > 0 else { return nil }

        if totalDays < 365 {
            return formatted(
                totalDays == 1
                    ? "home.hero.lifetime.days_equiv"
                    : "home.hero.lifetime.days_equiv_plural",
                defaultValue: "%lld日分",
                arguments: [totalDays],
                bundle: bundle,
                locale: locale
            )
        }

        let years = totalDays / 365
        let days = totalDays % 365
        if days == 0 {
            return formatted(
                years == 1
                    ? "home.hero.lifetime.years_equiv"
                    : "home.hero.lifetime.years_equiv_plural",
                defaultValue: "%lld年分",
                arguments: [years],
                bundle: bundle,
                locale: locale
            )
        }
        return formatted(
            days == 1
                ? "home.hero.lifetime.years_days_equiv"
                : "home.hero.lifetime.years_days_equiv_plural",
            defaultValue: "%1$lld年 %2$lld日分",
            arguments: [years, days],
            bundle: bundle,
            locale: locale
        )
    }

    static func detailedString(
        seconds: Int,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let totalMinutes = max(0, seconds) / 60
        guard totalMinutes >= 60 else {
            return formatted(
                "home.reclaimed.minutes",
                defaultValue: "%lld分",
                arguments: [totalMinutes],
                bundle: bundle,
                locale: locale
            )
        }
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return formatted(
                "home.reclaimed.hours",
                defaultValue: "%lld時間",
                arguments: [totalMinutes / 60],
                bundle: bundle,
                locale: locale
            )
        }
        return formatted(
            "home.reclaimed.hours_minutes",
            defaultValue: "%1$lld時間%2$lld分",
            arguments: [totalMinutes / 60, minutes],
            bundle: bundle,
            locale: locale
        )
    }

    static func estimatedMinutesPerCancellation(
        todayReclaimedSeconds: Int,
        todayCancellationCount: Int,
        fallbackSeconds: Int
    ) -> Int {
        let seconds = if todayReclaimedSeconds > 0 && todayCancellationCount > 0 {
            todayReclaimedSeconds / todayCancellationCount
        } else {
            fallbackSeconds
        }
        return max(1, seconds / 60)
    }
}

struct ReclaimedTimeMilestone: Equatable, Sendable {
    private static let daySeconds = 86_400
    private static let fixedThresholdSeconds = [3_600, 21_600, 43_200]

    let thresholdSeconds: Int

    var dayCount: Int? {
        guard thresholdSeconds >= Self.daySeconds else { return nil }
        return thresholdSeconds / Self.daySeconds
    }

    var hourCount: Int? {
        guard thresholdSeconds < Self.daySeconds else { return nil }
        return thresholdSeconds / 3_600
    }

    static func highestReached(seconds: Int) -> Self? {
        let normalized = max(0, seconds)
        if normalized >= daySeconds {
            return Self(thresholdSeconds: (normalized / daySeconds) * daySeconds)
        }
        return fixedThresholdSeconds
            .last(where: { $0 <= normalized })
            .map(Self.init(thresholdSeconds:))
    }

    static func nextThreshold(after seconds: Int) -> Self {
        let normalized = max(0, seconds)
        if let fixedThreshold = fixedThresholdSeconds.first(where: { $0 > normalized }) {
            return Self(thresholdSeconds: fixedThreshold)
        }
        let nextWholeDay = (normalized / daySeconds + 1) * daySeconds
        return Self(thresholdSeconds: nextWholeDay)
    }

    func celebrationText(
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        if let dayCount {
            let format = bundle.localizedString(
                forKey: "intervention.success.milestone.days",
                value: "まる%lld日ぶん 取り戻した",
                table: nil
            )
            return String(format: format, locale: locale, arguments: [dayCount])
        }
        let format = bundle.localizedString(
            forKey: "intervention.success.milestone.hours",
            value: "%lld時間ぶん 取り戻した",
            table: nil
        )
        return String(format: format, locale: locale, arguments: [hourCount ?? 0])
    }
}

struct ReclaimedTimeMilestoneProgress: Equatable, Sendable {
    let previousThresholdSeconds: Int
    let nextMilestone: ReclaimedTimeMilestone
    let remainingSeconds: Int
    let fraction: Double

    init?(seconds: Int) {
        let normalized = max(0, seconds)
        let previous = ReclaimedTimeMilestone.highestReached(seconds: normalized)?.thresholdSeconds ?? 0
        let next = ReclaimedTimeMilestone.nextThreshold(after: normalized)
        let interval = next.thresholdSeconds - previous
        guard interval > 0 else { return nil }

        previousThresholdSeconds = previous
        nextMilestone = next
        remainingSeconds = max(0, next.thresholdSeconds - normalized)
        fraction = min(1, max(0, Double(normalized - previous) / Double(interval)))
    }
}

@MainActor
enum ReclaimedTimeMilestoneTracker {
    static func claimNewMilestone(
        previousTotalSeconds: Int,
        totalSeconds: Int,
        settingsStore: SettingsStore
    ) -> ReclaimedTimeMilestone? {
        guard let reached = ReclaimedTimeMilestone.highestReached(seconds: totalSeconds) else {
            return nil
        }
        let savedThreshold = settingsStore.lastCelebratedReclaimedMilestoneSeconds
        let previousThreshold = ReclaimedTimeMilestone.highestReached(
            seconds: previousTotalSeconds
        )?.thresholdSeconds ?? 0

        guard reached.thresholdSeconds > savedThreshold else { return nil }
        settingsStore.lastCelebratedReclaimedMilestoneSeconds = reached.thresholdSeconds
        guard reached.thresholdSeconds > previousThreshold else {
            return nil
        }
        return reached
    }
}
