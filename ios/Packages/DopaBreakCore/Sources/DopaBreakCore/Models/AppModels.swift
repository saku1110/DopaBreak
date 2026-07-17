import Foundation

public enum GoalCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case study
    case work
    case health
    case sleep
    case creative
    case other
}

public struct Goal: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var lockScreenTitle: String?
    public var category: GoalCategory
    public var displayImagePath: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String,
        lockScreenTitle: String?,
        category: GoalCategory,
        displayImagePath: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.lockScreenTitle = lockScreenTitle
        self.category = category
        self.displayImagePath = displayImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SelfCheckSnapshot: Codable, Equatable, Sendable {
    public var id: UUID
    public var usageBucket: String
    public var aimlessScrollBucket: String
    public var regretBucket: String
    public var estimatedDailyMinutes: Int
    public var estimatedYearlyDays: Int
    public var createdAt: Date

    public init(
        id: UUID,
        usageBucket: String,
        aimlessScrollBucket: String,
        regretBucket: String,
        estimatedDailyMinutes: Int,
        estimatedYearlyDays: Int,
        createdAt: Date
    ) {
        self.id = id
        self.usageBucket = usageBucket
        self.aimlessScrollBucket = aimlessScrollBucket
        self.regretBucket = regretBucket
        self.estimatedDailyMinutes = estimatedDailyMinutes
        self.estimatedYearlyDays = estimatedYearlyDays
        self.createdAt = createdAt
    }
}

public enum InterventionMode: String, Codable, Equatable, Sendable, CaseIterable {
    case deepFocus
    case standard
    case nightOnly
}

public struct ScheduleRule: Codable, Equatable, Sendable {
    public var weekdays: [Int]
    public var startTime: DateComponents
    public var endTime: DateComponents

    public init(weekdays: [Int], startTime: DateComponents, endTime: DateComponents) {
        self.weekdays = weekdays
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct TargetRule: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var activitySelectionData: Data
    public var mode: InterventionMode
    public var schedule: ScheduleRule?
    public var delaySeconds: Int
    public var maxOpensPerDay: Int?
    public var defaultDurationMinutes: Int
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        activitySelectionData: Data,
        mode: InterventionMode,
        schedule: ScheduleRule?,
        delaySeconds: Int,
        maxOpensPerDay: Int?,
        defaultDurationMinutes: Int,
        isEnabled: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.activitySelectionData = activitySelectionData
        self.mode = mode
        self.schedule = schedule
        self.delaySeconds = delaySeconds
        self.maxOpensPerDay = maxOpensPerDay
        self.defaultDurationMinutes = defaultDurationMinutes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum Decision: String, Codable, Equatable, Sendable, CaseIterable {
    case cancelled
    case opened
}

public enum IntentCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case workRequired
    case research
    case communication
    case posting
    case boredom
    case anxietyCheck
    case unconscious
    case other

    /// 目的が明確な利用は時間だけ決めてすぐ開き、反射的な利用だけに
    /// 一呼吸・利用回数・目標確認を挟む。
    public var interventionStyle: IntentInterventionStyle {
        switch self {
        case .workRequired, .research, .communication, .posting:
            return .direct
        case .boredom, .anxietyCheck, .unconscious, .other:
            return .reflective
        }
    }
}

public enum IntentInterventionStyle: Equatable, Sendable {
    case direct
    case reflective
}

public struct AttemptLog: Codable, Equatable, Sendable {
    public var id: UUID
    public var ruleId: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var decision: Decision
    public var intent: IntentCategory?
    public var selectedDurationSeconds: Int?
    public var attemptCount24h: Int
    public var opened: Bool

    public init(
        id: UUID,
        ruleId: UUID,
        startedAt: Date,
        completedAt: Date?,
        decision: Decision,
        intent: IntentCategory?,
        selectedDurationSeconds: Int?,
        attemptCount24h: Int,
        opened: Bool
    ) {
        self.id = id
        self.ruleId = ruleId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.decision = decision
        self.intent = intent
        self.selectedDurationSeconds = selectedDurationSeconds
        self.attemptCount24h = attemptCount24h
        self.opened = opened
    }
}

public enum ReflectionTrigger: String, Codable, Equatable, Sendable, CaseIterable {
    case timedSessionEnded
    case reshielded
    case appReturned
    case notification
}

public enum PostUseSatisfaction: String, Codable, Equatable, Sendable, CaseIterable {
    case satisfied
    case fun
    case nothingGained
    case lostTime
    case feltWorse
}

public enum HappinessDelta: String, Codable, Equatable, Sendable, CaseIterable {
    case increased
    case unchanged
    case decreased
}

public struct ReflectionLog: Codable, Equatable, Sendable {
    public var id: UUID
    public var attemptLogId: UUID?
    public var ruleId: UUID
    public var promptedAt: Date
    public var answeredAt: Date?
    public var trigger: ReflectionTrigger
    public var satisfaction: PostUseSatisfaction?
    public var happinessDelta: HappinessDelta?
    public var skipped: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        attemptLogId: UUID?,
        ruleId: UUID,
        promptedAt: Date,
        answeredAt: Date?,
        trigger: ReflectionTrigger,
        satisfaction: PostUseSatisfaction?,
        happinessDelta: HappinessDelta?,
        skipped: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.attemptLogId = attemptLogId
        self.ruleId = ruleId
        self.promptedAt = promptedAt
        self.answeredAt = answeredAt
        self.trigger = trigger
        self.satisfaction = satisfaction
        self.happinessDelta = happinessDelta
        self.skipped = skipped
        self.createdAt = createdAt
    }
}

public enum LockTheme: String, Codable, Equatable, Sendable, CaseIterable {
    case e1
    case sumi
    case asagiri
    case shinrin
    case yozora
    case kpop
    case kawaiiPink

    public var displayName: String {
        switch self {
        case .e1: return "E1"
        case .sumi: return "墨と灯"
        case .asagiri: return "朝霧"
        case .shinrin: return "森林"
        case .yozora: return "夜更け"
        case .kpop: return "K-POP"
        case .kawaiiPink: return "かわいいピンク"
        }
    }

    public var palette: LockThemePalette {
        switch self {
        case .e1:
            // 2026 dark editorial system: app, widgets, notifications, and Live Activity.
            return LockThemePalette(
                background: .init(11, 13, 15), card: .init(20, 23, 27),
                primaryText: .init(244, 242, 236), secondaryText: .init(139, 146, 158),
                accent: .init(184, 255, 61)
            )
        case .sumi:
            // output/mockups/notification_themes/notif_sumi.png
            return LockThemePalette(
                background: .init(14, 12, 9), card: .init(29, 24, 18),
                primaryText: .init(247, 240, 225), secondaryText: .init(171, 160, 143),
                accent: .init(229, 158, 70)
            )
        case .asagiri:
            // output/mockups/notification_themes/notif_asagiri.png
            return LockThemePalette(
                background: .init(232, 237, 242), card: .init(250, 251, 252),
                primaryText: .init(31, 37, 47), secondaryText: .init(91, 105, 119),
                accent: .init(91, 126, 153)
            )
        case .shinrin:
            // doc06 §9b names the forest theme but has no mock. Keep the E1 hierarchy
            // and use a restrained evergreen palette until an approved mock exists.
            return LockThemePalette(
                background: .init(8, 19, 15), card: .init(15, 37, 29),
                primaryText: .init(238, 246, 240), secondaryText: .init(139, 164, 149),
                accent: .init(119, 210, 139)
            )
        case .yozora:
            // output/mockups/notification_themes/notif_yozora.png
            return LockThemePalette(
                background: .init(5, 10, 22), card: .init(13, 31, 58),
                primaryText: .init(235, 239, 255), secondaryText: .init(159, 171, 202),
                accent: .init(202, 213, 255)
            )
        case .kpop:
            // output/mockups/notification_themes/notif_kpop.png
            return LockThemePalette(
                background: .init(225, 205, 247), card: .init(249, 246, 251),
                primaryText: .init(35, 31, 38), secondaryText: .init(104, 94, 108),
                accent: .init(238, 52, 137)
            )
        case .kawaiiPink:
            // output/mockups/notification_themes/notif_kawaii_pink.png (color only; no character IP)
            return LockThemePalette(
                background: .init(255, 220, 229), card: .init(255, 253, 253),
                primaryText: .init(68, 43, 49), secondaryText: .init(139, 91, 102),
                accent: .init(242, 94, 137)
            )
        }
    }
}

public struct LockThemeColor: Codable, Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct LockThemePalette: Codable, Equatable, Sendable {
    public let background: LockThemeColor
    public let card: LockThemeColor
    public let primaryText: LockThemeColor
    public let secondaryText: LockThemeColor
    public let accent: LockThemeColor

    public init(
        background: LockThemeColor,
        card: LockThemeColor,
        primaryText: LockThemeColor,
        secondaryText: LockThemeColor,
        accent: LockThemeColor
    ) {
        self.background = background
        self.card = card
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var primaryGoalTitle: String
    public var displayTitle: String
    public var todayCancelledCount: Int
    public var todayAttemptCount: Int
    public var theme: LockTheme
    public var updatedAt: Date
    public var goalTitles: [String]
    public var displayTitles: [String]

    public init(
        primaryGoalTitle: String,
        displayTitle: String,
        todayCancelledCount: Int,
        todayAttemptCount: Int,
        theme: LockTheme,
        updatedAt: Date,
        goalTitles: [String]? = nil,
        displayTitles: [String]? = nil
    ) {
        self.primaryGoalTitle = primaryGoalTitle
        self.displayTitle = displayTitle
        self.todayCancelledCount = todayCancelledCount
        self.todayAttemptCount = todayAttemptCount
        self.theme = theme
        self.updatedAt = updatedAt
        self.goalTitles = goalTitles ?? (primaryGoalTitle.isEmpty ? [] : [primaryGoalTitle])
        self.displayTitles = displayTitles ?? (displayTitle.isEmpty ? [] : [displayTitle])
    }

    private enum CodingKeys: String, CodingKey {
        case primaryGoalTitle, displayTitle, todayCancelledCount, todayAttemptCount, theme, updatedAt
        case goalTitles, displayTitles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primaryGoalTitle = try container.decode(String.self, forKey: .primaryGoalTitle)
        displayTitle = try container.decode(String.self, forKey: .displayTitle)
        todayCancelledCount = try container.decode(Int.self, forKey: .todayCancelledCount)
        todayAttemptCount = try container.decode(Int.self, forKey: .todayAttemptCount)
        theme = try container.decode(LockTheme.self, forKey: .theme)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        goalTitles = try container.decodeIfPresent([String].self, forKey: .goalTitles)
            ?? (primaryGoalTitle.isEmpty ? [] : [primaryGoalTitle])
        displayTitles = try container.decodeIfPresent([String].self, forKey: .displayTitles)
            ?? (displayTitle.isEmpty ? [] : [displayTitle])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(primaryGoalTitle, forKey: .primaryGoalTitle)
        try container.encode(displayTitle, forKey: .displayTitle)
        try container.encode(todayCancelledCount, forKey: .todayCancelledCount)
        try container.encode(todayAttemptCount, forKey: .todayAttemptCount)
        try container.encode(theme, forKey: .theme)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(goalTitles, forKey: .goalTitles)
        try container.encode(displayTitles, forKey: .displayTitles)
    }
}

public struct LockSurfaceState: Codable, Equatable, Sendable {
    public var morningNotificationEnabled: Bool
    public var morningNotificationTime: DateComponents
    public var weeklyReportEnabled: Bool
    public var liveActivityEnabled: Bool
    public var liveActivityStartedAt: Date?
    public var theme: LockTheme

    public init(
        morningNotificationEnabled: Bool,
        morningNotificationTime: DateComponents,
        weeklyReportEnabled: Bool,
        liveActivityEnabled: Bool,
        liveActivityStartedAt: Date?,
        theme: LockTheme
    ) {
        self.morningNotificationEnabled = morningNotificationEnabled
        self.morningNotificationTime = morningNotificationTime
        self.weeklyReportEnabled = weeklyReportEnabled
        self.liveActivityEnabled = liveActivityEnabled
        self.liveActivityStartedAt = liveActivityStartedAt
        self.theme = theme
    }
}

public enum InterventionStep: String, Codable, Equatable, Sendable, CaseIterable {
    case idle
    case shieldPresented
    case breathing
    case usageSummary
    case goalReminder
    case intentSelection
    case decision
    case cancelled
    case timeSelection
    case temporarilyAllowed
    case reShieldScheduled
    case postUseReflection
}

public struct InterventionState: Codable, Equatable, Sendable {
    public var currentStep: InterventionStep
    public var ruleId: UUID?
    public var startedAt: Date?
    public var updatedAt: Date
    public var allowedUntil: Date?
    /// intentSelection / decision で選択された意図（doc05 §5）。
    /// ShieldAction 拡張 ↔ 本体アプリは別プロセスのため、AttemptLog へ持ち越す意図は
    /// メモリではなく永続スナップショットに保持する必要がある。
    /// Optional のため、"intent" 欄を持たない既存 intervention_state.json も
    /// Swift 合成 Decodable の decodeIfPresent 相当で nil として後方互換にデコードされる
    /// （JSONSnapshotStore は素の JSONDecoder を使用）。
    public var intent: IntentCategory?

    public init(
        currentStep: InterventionStep,
        ruleId: UUID?,
        startedAt: Date?,
        updatedAt: Date,
        allowedUntil: Date?,
        intent: IntentCategory? = nil
    ) {
        self.currentStep = currentStep
        self.ruleId = ruleId
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.allowedUntil = allowedUntil
        self.intent = intent
    }
}
