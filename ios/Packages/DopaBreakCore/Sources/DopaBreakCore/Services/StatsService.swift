import Foundation

/// 統計サービス（doc05 §9 StatsService）。AttemptLog / ReflectionLog を集計する読み取り専用サービス。
///
/// 日付の境界は注入された `calendar`、現在時刻は注入された `now` で決まる（テスト時は UTC 固定）。
/// 範囲指定メソッドの `to` は排他（`< to`）で、AttemptLog は `startedAt`、ReflectionLog は `promptedAt` で絞る。
public struct StatsService: Sendable {
    private let logStore: SQLiteLogStore
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        logStore: SQLiteLogStore,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.logStore = logStore
        self.calendar = calendar
        self.now = now
    }

    /// 今日の介入試行数（当日の 0:00〜翌 0:00）。
    public func attemptsToday() throws -> Int {
        try todaysAttempts().count
    }

    /// 今日の「開かない（cancelled）」件数。
    public func cancelledToday() throws -> Int {
        try todaysAttempts().filter { $0.decision == .cancelled }.count
    }

    /// 全期間の「開かずに戻れた（cancelled）」件数。
    public func cancelledAttemptsAllTime() throws -> Int {
        try logStore.cancelledAttemptCount()
    }

    /// 指定期間の「開かずに戻れた（cancelled）」件数。
    public func cancelledAttempts(from: Date, to: Date) throws -> Int {
        try logStore.fetchAttempts(from: from, to: to)
            .filter { $0.decision == .cancelled }
            .count
    }

    /// 指定期間の試行数と「開かずに戻れた」件数を同時に返す。
    public func attemptSummary(from: Date, to: Date) throws -> AttemptSummary {
        let attempts = try logStore.fetchAttempts(from: from, to: to)
        return AttemptSummary(
            attempts: attempts.count,
            cancelled: attempts.filter { $0.decision == .cancelled }.count
        )
    }

    /// 意図カテゴリ別の試行数。intent が nil の試行は除外する。
    public func intentBreakdown(from: Date, to: Date) throws -> [IntentCategory: Int] {
        var result: [IntentCategory: Int] = [:]
        for attempt in try logStore.fetchAttempts(from: from, to: to) {
            guard let intent = attempt.intent else { continue }
            result[intent, default: 0] += 1
        }
        return result
    }

    /// ルール別の試行数。
    public func appRuleBreakdown(from: Date, to: Date) throws -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for attempt in try logStore.fetchAttempts(from: from, to: to) {
            result[attempt.ruleId, default: 0] += 1
        }
        return result
    }

    /// 満足感別のリフレクション数（回答済みのみ）。
    public func reflectionBreakdown(from: Date, to: Date) throws -> [PostUseSatisfaction: Int] {
        var result: [PostUseSatisfaction: Int] = [:]
        for reflection in try answeredReflections(from: from, to: to) {
            guard let satisfaction = reflection.satisfaction else { continue }
            result[satisfaction, default: 0] += 1
        }
        return result
    }

    /// 幸福感変化別のリフレクション数（回答済みのみ）。
    public func happinessDeltaBreakdown(from: Date, to: Date) throws -> [HappinessDelta: Int] {
        var result: [HappinessDelta: Int] = [:]
        for reflection in try answeredReflections(from: from, to: to) {
            guard let delta = reflection.happinessDelta else { continue }
            result[delta, default: 0] += 1
        }
        return result
    }

    /// 「時間を無駄にしたと気づいた率」。回答済みリフレクションのうち
    /// satisfaction ∈ {nothingGained, lostTime, feltWorse} の割合。
    /// 回答が 0 件のときは分母 0 を避けて 0 を返す。
    public func wastedTimeRealizationRate(from: Date, to: Date) throws -> Double {
        wastedRate(of: try answeredReflections(from: from, to: to))
    }

    /// 直近 7 日（本日含む）の日次サマリー。日境界は注入 calendar で決める。
    /// `days` は古い順（index 0 = 6 日前、index 6 = 本日）。
    public func weeklySummary() throws -> WeeklySummary {
        let today = calendar.startOfDay(for: now())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let weekEnd = calendar.date(byAdding: .day, value: 1, to: today) else {
            throw CoreError.validation(message: "週次サマリーの日付計算に失敗しました")
        }
        let attempts = try logStore.fetchAttempts(from: weekStart, to: weekEnd)
        let answered = try answeredReflections(from: weekStart, to: weekEnd)

        let days = try (0..<7).map { offset -> WeeklySummary.Day in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                throw CoreError.validation(message: "週次サマリーの日付計算に失敗しました")
            }
            let dayAttempts = attempts.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
            let cancelled = dayAttempts.filter { $0.decision == .cancelled }.count
            return WeeklySummary.Day(date: dayStart, attempts: dayAttempts.count, cancelled: cancelled)
        }

        let totalCancelled = attempts.filter { $0.decision == .cancelled }.count
        let cancelRate = attempts.isEmpty ? 0 : Double(totalCancelled) / Double(attempts.count)
        return WeeklySummary(
            days: days,
            attempts: attempts.count,
            cancelled: totalCancelled,
            cancelRate: cancelRate,
            answeredReflections: answered.count,
            wastedTimeRealizationRate: wastedRate(of: answered)
        )
    }

    // MARK: - 内部処理

    private func todaysAttempts() throws -> [AttemptLog] {
        let start = calendar.startOfDay(for: now())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return try logStore.fetchAttempts(from: start, to: end)
    }

    /// 回答済みリフレクション（answeredAt が非 nil）。skipped は answeredAt=nil のため自然に除外される。
    private func answeredReflections(from: Date, to: Date) throws -> [ReflectionLog] {
        try logStore.fetchReflections(from: from, to: to).filter { $0.answeredAt != nil }
    }

    private func wastedRate(of answered: [ReflectionLog]) -> Double {
        guard !answered.isEmpty else { return 0 }
        let wasted: Set<PostUseSatisfaction> = [.nothingGained, .lostTime, .feltWorse]
        let count = answered.filter { reflection in
            guard let satisfaction = reflection.satisfaction else { return false }
            return wasted.contains(satisfaction)
        }.count
        return Double(count) / Double(answered.count)
    }
}

public struct AttemptSummary: Equatable, Sendable {
    public let attempts: Int
    public let cancelled: Int

    public init(attempts: Int, cancelled: Int) {
        self.attempts = attempts
        self.cancelled = cancelled
    }
}

/// 週次サマリー（doc05 §9 StatsService.weeklySummary）。
public struct WeeklySummary: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public let date: Date
        public let attempts: Int
        public let cancelled: Int

        public init(date: Date, attempts: Int, cancelled: Int) {
            self.date = date
            self.attempts = attempts
            self.cancelled = cancelled
        }
    }

    /// 古い順（index 0 = 6 日前、index 6 = 本日）に並んだ 7 要素。
    public let days: [Day]
    public let attempts: Int
    public let cancelled: Int
    /// 0...1。試行が 0 件のときは 0。
    public let cancelRate: Double
    public let answeredReflections: Int
    /// 0...1。回答済みリフレクションが 0 件のときは 0。
    public let wastedTimeRealizationRate: Double

    public init(
        days: [Day],
        attempts: Int,
        cancelled: Int,
        cancelRate: Double,
        answeredReflections: Int,
        wastedTimeRealizationRate: Double
    ) {
        self.days = days
        self.attempts = attempts
        self.cancelled = cancelled
        self.cancelRate = cancelRate
        self.answeredReflections = answeredReflections
        self.wastedTimeRealizationRate = wastedTimeRealizationRate
    }
}
