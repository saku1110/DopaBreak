import Foundation

public struct UsageWatchConfiguration: Codable, Equatable, Sendable {
    public static let allowedQuestionIntervals = [15, 30, 60]

    public var isPro: Bool
    public var questionIntervalMinutes: Int
    public var nightModeEnabled: Bool
    public var bedTimeMinutes: Int
    public var wakeTimeMinutes: Int
    public var freeThresholdMinutes: Int
    public var continuityGapMinutes: Int
    public var dailyQuestionCap: Int

    public init(
        isPro: Bool = false,
        questionIntervalMinutes: Int = 15,
        nightModeEnabled: Bool = false,
        bedTimeMinutes: Int = 1_380,
        wakeTimeMinutes: Int = 420,
        freeThresholdMinutes: Int = 120,
        continuityGapMinutes: Int = 20,
        dailyQuestionCap: Int = 8
    ) {
        self.isPro = isPro
        self.questionIntervalMinutes = Self.allowedQuestionIntervals.contains(questionIntervalMinutes)
            ? questionIntervalMinutes
            : 15
        self.nightModeEnabled = nightModeEnabled
        self.bedTimeMinutes = Self.normalizedMinutes(bedTimeMinutes)
        self.wakeTimeMinutes = Self.normalizedMinutes(wakeTimeMinutes)
        self.freeThresholdMinutes = max(UsageWatchConstants.stepMinutes, freeThresholdMinutes)
        self.continuityGapMinutes = max(0, continuityGapMinutes)
        self.dailyQuestionCap = max(0, dailyQuestionCap)
    }

    private static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }
}

public struct UsageWatchState: Codable, Equatable, Sendable {
    public var stepEventTimestamps: [Date]
    public var mutedUntil: Date?
    public var questionsSentToday: Int
    public var freeWarningSentToday: Bool
    public var lastInterventionAt: Date?
    public var dayStart: Date?

    public init(
        stepEventTimestamps: [Date] = [],
        mutedUntil: Date? = nil,
        questionsSentToday: Int = 0,
        freeWarningSentToday: Bool = false,
        lastInterventionAt: Date? = nil,
        dayStart: Date? = nil
    ) {
        self.stepEventTimestamps = stepEventTimestamps
        self.mutedUntil = mutedUntil
        self.questionsSentToday = max(0, questionsSentToday)
        self.freeWarningSentToday = freeWarningSentToday
        self.lastInterventionAt = lastInterventionAt
        self.dayStart = dayStart
    }

    public func resettingDailyFields(at date: Date, calendar: Calendar) -> UsageWatchState {
        UsageWatchState(
            lastInterventionAt: lastInterventionAt,
            dayStart: calendar.startOfDay(for: date)
        )
    }
}

public enum UsageWatchQuestion: String, Codable, Equatable, Sendable {
    case q15
    case q30
    case q45
    case hourly
}

public enum UsageWatchDecision: Equatable, Sendable {
    case none
    case freeWarning
    case question(UsageWatchQuestion)
}

public enum UsageWatchConstants {
    public static let activityName = "dopabreak.usagewatch.daily"
    public static let eventNamePrefix = "dopabreak.usagewatch.step"
    public static let notificationIdentifierPrefix = "dopabreak.usagewatch."
    public static let notificationCategoryIdentifier = "dopabreak.usagewatch"
    public static let muteTodayActionIdentifier = "dopabreak.usagewatch.mute_today"
    public static let stepMinutes = 15
    public static let maximumStepCount = 24
    /// docs/18 §3「60分以降（1時間ごと）」。この経過を超えたら問いの間隔を1時間へ広げる。
    public static let hourlyEscalationMinutes = 60

    public static func eventName(stepIndex: Int) -> String {
        "\(eventNamePrefix)\(stepIndex)"
    }

    public static func stepIndex(eventName: String) -> Int? {
        guard eventName.hasPrefix(eventNamePrefix),
              let stepIndex = Int(eventName.dropFirst(eventNamePrefix.count)),
              (1...maximumStepCount).contains(stepIndex) else {
            return nil
        }
        return stepIndex
    }
}

public enum UsageWatchPolicy {
    public static func evaluate(
        newEventAt: Date,
        stepIndex: Int,
        state: UsageWatchState,
        config: UsageWatchConfiguration,
        calendar: Calendar
    ) -> (decision: UsageWatchDecision, state: UsageWatchState) {
        guard (1...UsageWatchConstants.maximumStepCount).contains(stepIndex) else {
            return (.none, state)
        }

        var updatedState = stateForCurrentDay(
            state,
            eventDate: newEventAt,
            calendar: calendar
        )

        if let mutedUntil = updatedState.mutedUntil, mutedUntil <= newEventAt {
            updatedState.mutedUntil = nil
        }

        updatedState.stepEventTimestamps.append(newEventAt)
        updatedState.stepEventTimestamps.sort()

        let currentRun = trailingContinuousRun(
            timestamps: updatedState.stepEventTimestamps,
            gapMinutes: config.continuityGapMinutes
        )
        let elapsedMinutes = currentRun.count * UsageWatchConstants.stepMinutes

        if let mutedUntil = updatedState.mutedUntil, newEventAt < mutedUntil {
            return (.none, updatedState)
        }

        guard config.isPro else {
            guard !updatedState.freeWarningSentToday,
                  elapsedMinutes >= config.freeThresholdMinutes else {
                return (.none, updatedState)
            }
            updatedState.freeWarningSentToday = true
            return (.freeWarning, updatedState)
        }

        guard updatedState.questionsSentToday < config.dailyQuestionCap,
              !runContainsIntervention(
                  currentRun,
                  interventionAt: updatedState.lastInterventionAt,
                  eventDate: newEventAt
              ) else {
            return (.none, updatedState)
        }

        let effectiveInterval = effectiveQuestionInterval(
            at: newEventAt,
            config: config,
            calendar: calendar
        )
        // 60分を超えたら1時間ごとへ広げる（docs/18 §3のエスカレーション表）。
        // 15分刻みのまま鳴らし続けると同じ問いの連打になり、1日上限8回も2時間で使い切る。
        let cadenceMinutes = elapsedMinutes >= UsageWatchConstants.hourlyEscalationMinutes
            ? max(effectiveInterval, UsageWatchConstants.hourlyEscalationMinutes)
            : effectiveInterval
        guard elapsedMinutes.isMultiple(of: cadenceMinutes) else {
            return (.none, updatedState)
        }

        let question: UsageWatchQuestion
        switch elapsedMinutes {
        case ...15:
            question = .q15
        case ...30:
            question = .q30
        case ...45:
            question = .q45
        default:
            question = .hourly
        }
        updatedState.questionsSentToday += 1
        return (.question(question), updatedState)
    }

    private static func stateForCurrentDay(
        _ state: UsageWatchState,
        eventDate: Date,
        calendar: Calendar
    ) -> UsageWatchState {
        let storedDate = state.dayStart ?? state.stepEventTimestamps.last
        guard let storedDate else {
            var initialized = state
            initialized.dayStart = calendar.startOfDay(for: eventDate)
            initialized.stepEventTimestamps = state.stepEventTimestamps.filter {
                calendar.isDate($0, inSameDayAs: eventDate)
            }
            return initialized
        }

        guard calendar.isDate(storedDate, inSameDayAs: eventDate) else {
            return state.resettingDailyFields(at: eventDate, calendar: calendar)
        }

        var current = state
        current.dayStart = calendar.startOfDay(for: eventDate)
        current.stepEventTimestamps = state.stepEventTimestamps.filter {
            calendar.isDate($0, inSameDayAs: eventDate)
        }
        return current
    }

    private static func trailingContinuousRun(
        timestamps: [Date],
        gapMinutes: Int
    ) -> [Date] {
        guard let last = timestamps.last else {
            return []
        }

        let maximumGap = TimeInterval(gapMinutes * 60)
        var run = [last]
        var later = last
        for timestamp in timestamps.dropLast().reversed() {
            guard later.timeIntervalSince(timestamp) <= maximumGap else {
                break
            }
            run.append(timestamp)
            later = timestamp
        }
        return run.reversed()
    }

    private static func runContainsIntervention(
        _ run: [Date],
        interventionAt: Date?,
        eventDate: Date
    ) -> Bool {
        guard let firstThresholdAt = run.first,
              let interventionAt else {
            return false
        }
        let approximateRunStart = firstThresholdAt.addingTimeInterval(
            TimeInterval(-UsageWatchConstants.stepMinutes * 60)
        )
        return interventionAt >= approximateRunStart && interventionAt <= eventDate
    }

    private static func effectiveQuestionInterval(
        at date: Date,
        config: UsageWatchConfiguration,
        calendar: Calendar
    ) -> Int {
        let baseInterval = UsageWatchConfiguration.allowedQuestionIntervals.contains(
            config.questionIntervalMinutes
        ) ? config.questionIntervalMinutes : UsageWatchConstants.stepMinutes
        guard config.nightModeEnabled,
              isInNightWindow(date: date, config: config, calendar: calendar) else {
            return baseInterval
        }
        return max(UsageWatchConstants.stepMinutes, baseInterval / 2)
    }

    private static func isInNightWindow(
        date: Date,
        config: UsageWatchConfiguration,
        calendar: Calendar
    ) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let nowMinutes = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        let start = normalizedMinutes(config.bedTimeMinutes - 60)
        let end = normalizedMinutes(config.wakeTimeMinutes)
        let length = normalizedMinutes(end - start)
        guard length > 0 else {
            return false
        }
        return normalizedMinutes(nowMinutes - start) < length
    }

    private static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }
}
