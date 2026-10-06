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

    public var impliedHappinessDelta: HappinessDelta {
        switch self {
        case .satisfied, .fun:
            return .increased
        case .nothingGained:
            return .unchanged
        case .lostTime, .feltWorse:
            return .decreased
        }
    }
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
    case gaming
    case asagiri
    case monochrome
    case liquidGlass = "liquidGlassV3"
    case kpop
    case kawaiiPink
    case note
    case blueprint
    case spiderWeb

    public init(migratingRawValue rawValue: String) {
        switch rawValue {
        case "sumi": self = .gaming
        case "shinrin": self = .monochrome
        case "yozora", "liquidGlass", "retroPop": self = .monochrome
        default: self = LockTheme(rawValue: rawValue) ?? .e1
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(migratingRawValue: try decoder.singleValueContainer().decode(String.self))
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
        case .gaming:
            return LockThemePalette(
                background: .init(10, 10, 20), card: .init(20, 20, 40),
                primaryText: .init(234, 234, 242), secondaryText: .init(138, 143, 168),
                accent: .init(0, 229, 255)
            )
        case .asagiri:
            // output/mockups/notification_themes/notif_asagiri.png
            return LockThemePalette(
                background: .init(232, 237, 242), card: .init(250, 251, 252),
                primaryText: .init(31, 37, 47), secondaryText: .init(91, 105, 119),
                accent: .init(91, 126, 153)
            )
        case .monochrome:
            return LockThemePalette(
                background: .init(250, 250, 250), card: .init(255, 255, 255),
                primaryText: .init(18, 18, 18), secondaryText: .init(118, 118, 118),
                accent: .init(18, 18, 18)
            )
        case .liquidGlass:
            return LockThemePalette(
                background: .init(62, 91, 200), card: .init(90, 111, 216),
                primaryText: .init(255, 255, 255), secondaryText: .init(216, 222, 245),
                accent: .init(255, 255, 255)
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
        case .note:
            return LockThemePalette(
                background: .init(251, 247, 239), card: .init(255, 255, 255),
                primaryText: .init(59, 52, 40), secondaryText: .init(138, 128, 112),
                accent: .init(199, 80, 80)
            )
        case .blueprint:
            return LockThemePalette(
                background: .init(22, 65, 138), card: .init(27, 76, 158),
                primaryText: .init(255, 255, 255), secondaryText: .init(185, 203, 232),
                accent: .init(255, 255, 255)
            )
        case .spiderWeb:
            return LockThemePalette(
                background: .init(163, 15, 35), card: .init(191, 20, 39),
                primaryText: .init(255, 255, 255), secondaryText: .init(249, 212, 218),
                accent: .init(66, 153, 255)
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
        theme = LockTheme(
            migratingRawValue: try container.decode(String.self, forKey: .theme)
        )
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
    public var weeklyReportNotificationTime: DateComponents
    public var weeklyReportEnabled: Bool
    public var reflectionNotificationEnabled: Bool
    public var retentionSupportNotificationsEnabled: Bool
    public var planNotificationsEnabled: Bool
    public var liveActivityEnabled: Bool
    public var liveActivityStartedAt: Date?
    public var theme: LockTheme

    public init(
        weeklyReportNotificationTime: DateComponents,
        weeklyReportEnabled: Bool,
        reflectionNotificationEnabled: Bool = true,
        retentionSupportNotificationsEnabled: Bool = true,
        planNotificationsEnabled: Bool = true,
        liveActivityEnabled: Bool,
        liveActivityStartedAt: Date?,
        theme: LockTheme
    ) {
        self.weeklyReportNotificationTime = weeklyReportNotificationTime
        self.weeklyReportEnabled = weeklyReportEnabled
        self.reflectionNotificationEnabled = reflectionNotificationEnabled
        self.retentionSupportNotificationsEnabled = retentionSupportNotificationsEnabled
        self.planNotificationsEnabled = planNotificationsEnabled
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
    case intentSelection
    case decision
    case cancelled
    case timeSelection
    case temporarilyAllowed
    case reShieldScheduled
    case postUseReflection

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // S-02/S-03統合前の保存状態。旧goalReminderは統合後のusageSummaryへ寄せ、
        // アップデート直後にintervention_state.json全体が破損扱いになるのを防ぐ。
        if rawValue == "goalReminder" {
            self = .usageSummary
            return
        }

        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown intervention step: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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

    public func hasActiveTemporaryAllowance(at date: Date, for ruleId: UUID) -> Bool {
        guard currentStep == .temporarilyAllowed,
              self.ruleId == ruleId,
              let allowedUntil else {
            return false
        }
        return date < allowedUntil
    }
}

/// 通知タップの着地先の保留（docs/18 §2f）。
///
/// 書き込み時刻を持つのは、本体が消費しないまま残るケースがあるため。
/// 通知許可はオンボーディング途中で取るので、そこで離脱した人がD1通知をタップすると
/// `OnboardingFlow` が出ている＝`RootTabView` がいないため誰も消費できない。
/// 有効期限を切らないと、数週間後にオンボーディングを終えた瞬間に設定画面へ飛ばされる。
public struct PendingNotificationDestination: Codable, Equatable, Sendable {
    /// 既定の有効期限。着地先を誰も消費できないまま持ち越さないための上限。
    public static let validityInterval: TimeInterval = 30 * 60

    /// 振り返りの着地だけは長く受ける。
    ///
    /// 宣言時間の終わりに届く通知は、手が空いてからタップされることが多い。
    /// ここを30分で切ると、`InterventionEngine` が3時間まで出せるのに着地先が先に捨てられ、
    /// 本人は一度も振り返りを見ないまま `skip` として畳まれる。
    /// エンジン側の窓をそのまま使い、片方だけ伸ばして同じ穴が空くのを防ぐ。
    public static let reflectionValidityInterval: TimeInterval =
        InterventionEngine.reflectionNotificationTapWindow

    /// 着地先ごとの有効期限。自分でアプリを開いた場合の30分の既定は変えない
    /// （これは通知タップで書かれた着地先だけを受ける窓）。
    public static func validity(for destination: NotificationDestination) -> TimeInterval {
        switch destination {
        case .reflection:
            return reflectionValidityInterval
        case .stats, .planSettings, .automationGuide:
            return validityInterval
        }
    }

    public let destination: NotificationDestination
    public let writtenAt: Date

    public init(destination: NotificationDestination, writtenAt: Date) {
        self.destination = destination
        self.writtenAt = writtenAt
    }

    public func isValid(at date: Date) -> Bool {
        let age = date.timeIntervalSince(writtenAt)
        return age >= 0 && age <= Self.validity(for: destination)
    }
}
