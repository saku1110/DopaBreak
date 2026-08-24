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

    /// 全期間の介入試行数。D7未活性フォールバックの発火条件（試行が一度もない）に使う。
    public func attemptsAllTime() throws -> Int {
        try logStore.attemptCount()
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

    /// ルール別の試行数と「開かなかった」件数。
    /// ホームと記録で同じ分母・分子を使えるよう、1回の走査でまとめる。
    public func appRuleBreakdownDetailed(
        from: Date,
        to: Date
    ) throws -> [UUID: (attempts: Int, cancelled: Int)] {
        var result: [UUID: (attempts: Int, cancelled: Int)] = [:]
        for attempt in try logStore.fetchAttempts(from: from, to: to) {
            let current = result[attempt.ruleId] ?? (attempts: 0, cancelled: 0)
            result[attempt.ruleId] = (
                attempts: current.attempts + 1,
                cancelled: current.cancelled + (attempt.decision == .cancelled ? 1 : 0)
            )
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

    /// 指定期間で直近に回答した満足感。返却順は古い→新しい。
    public func recentSatisfactions(
        from: Date,
        to: Date,
        limit: Int
    ) throws -> [PostUseSatisfaction] {
        guard limit > 0 else { return [] }
        let values = try answeredReflections(from: from, to: to).compactMap(\.satisfaction)
        return Array(values.suffix(limit))
    }

    /// 「開かなかった日」が何日続いているか。
    /// 当日がまだ0件なら昨日から数え、昨日も0件なら0日を返す。
    public func consecutiveDaysWithCancellations(endingOn date: Date) throws -> Int {
        let endingDay = calendar.startOfDay(for: date)
        guard let rangeEnd = calendar.date(byAdding: .day, value: 1, to: endingDay) else {
            throw CoreError.validation(message: "連続日数の日付計算に失敗しました")
        }

        let cancelledDays = Set(
            try logStore.fetchAttempts(to: rangeEnd)
                .filter { $0.decision == .cancelled }
                .map { calendar.startOfDay(for: $0.startedAt) }
        )

        var cursor = endingDay
        if !cancelledDays.contains(cursor) {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = previousDay
        }

        var count = 0
        while cancelledDays.contains(cursor) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return count
    }

    /// 指定期間に「開かなかった」ことで取り戻した推定秒数。
    /// 1件あたりの時間は、期間終端から直近30日に実際に開いた試行時間の中央値。
    /// 開いた実績がない間は5分として扱う。
    public func reclaimedSeconds(from: Date, to: Date) throws -> Int {
        guard from < to else { return 0 }
        let cancelledCount = try logStore.fetchAttempts(from: from, to: to)
            .filter { $0.decision == .cancelled }
            .count
        guard cancelledCount > 0 else { return 0 }

        let durationWindowStart = calendar.date(byAdding: .day, value: -30, to: to)
            ?? to.addingTimeInterval(-30 * 86_400)
        let openedDurations = try logStore.fetchAttempts(from: durationWindowStart, to: to)
            .filter { $0.decision == .opened }
            .compactMap(\.selectedDurationSeconds)
            .filter { $0 > 0 }
            .sorted()
        let medianDuration = median(of: openedDurations) ?? 300
        return cancelledCount * medianDuration
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

    /// 7 日窓の日次サマリー。日境界は注入 calendar で決める。
    /// `days` は古い順（index 0 = 窓の初日、index 6 = 窓の最終日）。
    ///
    /// - Parameter weeksBack: さかのぼる週数。0 は直近 7 日（本日を最終日に含む）、
    ///   1 はそのひとつ前の 7 日（13 日前〜7 日前）。窓は重ならない。
    public func weeklySummary(weeksBack: Int = 0) throws -> WeeklySummary {
        try weeklySummary(weeksBack: weeksBack, today: calendar.startOfDay(for: now()))
    }

    /// 起点の日を外から渡す内部経路。複数の窓を1回の呼び出しで作るときに、
    /// 途中で日付が変わっても窓の関係が崩れないようにする。
    private func weeklySummary(weeksBack: Int, today: Date) throws -> WeeklySummary {
        guard weeksBack >= 0 else {
            throw CoreError.validation(message: "週次サマリーの週指定が不正です")
        }
        guard let windowLastDay = calendar.date(byAdding: .day, value: -7 * weeksBack, to: today),
              let weekStart = calendar.date(byAdding: .day, value: -6, to: windowLastDay),
              let weekEnd = calendar.date(byAdding: .day, value: 1, to: windowLastDay) else {
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

    /// 週次詳細レポート（Pro）。直近 7 日と、そのひとつ前の 7 日を並べて返す。
    /// 前週比の判断材料をここで完結させ、画面側では表示だけを行う。
    /// 今週と前週で `now()` を別々に読むと、深夜 0 時をまたいだ瞬間に 2 つの窓が 1 日重なる。
    /// 起点の日はここで一度だけ確定させ、両方の窓へ同じ値を渡す。
    public func weeklyDetailReport() throws -> WeeklyDetailReport {
        let today = calendar.startOfDay(for: now())
        return WeeklyDetailReport(
            current: try weeklySummary(weeksBack: 0, today: today),
            previous: try weeklySummary(weeksBack: 1, today: today)
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

    private func median(of sortedValues: [Int]) -> Int? {
        guard !sortedValues.isEmpty else { return nil }
        let middle = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middle - 1] + sortedValues[middle]) / 2
        }
        return sortedValues[middle]
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

/// 週次詳細レポート（Pro）。直近 7 日と、そのひとつ前の 7 日の対比。
public struct WeeklyDetailReport: Equatable, Sendable {
    /// 直近 7 日（本日を最終日に含む）。
    public let current: WeeklySummary
    /// そのひとつ前の 7 日（13 日前〜7 日前）。current と日付は重ならない。
    public let previous: WeeklySummary

    public init(current: WeeklySummary, previous: WeeklySummary) {
        self.current = current
        self.previous = previous
    }

    /// 前週に試行が 1 件も無いときは比較しない。
    /// 分母 0 でつく 0 件と、実際に 0 件だった週を同じ「前週比」として見せないため。
    public var isComparable: Bool {
        previous.attempts > 0
    }

    /// 「開かなかった」件数の前週差。比較できないときは nil。
    public var cancelledDelta: Int? {
        guard isComparable else { return nil }
        return current.cancelled - previous.cancelled
    }

    /// 日別バーの高さをそろえる基準。今週と前週を通した 1 日あたりの最大試行数。
    /// 前週も含めるので、週をまたいでもバーの縮尺が変わらない。
    public var peakDailyAttempts: Int {
        let peaks = (current.days + previous.days).map(\.attempts)
        return peaks.max() ?? 0
    }

    /// 今週も前週も記録が無い状態。画面では未記録の案内に切り替える。
    public var isEmpty: Bool {
        current.attempts == 0 && previous.attempts == 0
    }
}
