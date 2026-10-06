import Foundation

/// 1日に開ける回数を決める純関数。時計を読むのは呼び出し側で、ここへは `now` を渡す。
///
/// 1日の区切りは起床時刻。区切りちょうどの時刻は新しい日に入れる。
/// 締める変更（オンにする・減らす）はすぐ効き、緩める変更（増やす・オフ）は次の区切りから効く。
public enum DailyOpenLimitPolicy {
    /// DeviceActivityが受け付ける最短の区間（15分）。
    public static let minimumWindowMinutes = 15

    /// 緊急で開くまでの待ち（秒）。手動セッションの緊急解除と同じ30秒。
    public static let emergencyWaitSeconds: TimeInterval = 30

    /// 待ち終わってから開けるまでの猶予（秒）。
    /// 待ちだけ先に済ませておき、後でいつでも待たずに開ける状態を作らせない。
    public static let emergencyReadyWindowSeconds: TimeInterval = 300

    // MARK: - 1日の区切り

    /// いまを含む「1日」の始まり（直近の起床時刻）。
    public static func dayStart(now: Date, boundaryMinutes: Int, calendar: Calendar) -> Date {
        let minutes = NightWindowPolicy.normalizedMinutes(boundaryMinutes)
        if let today = boundary(on: now, minutes: minutes, calendar: calendar), today <= now {
            return today
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           let boundary = boundary(on: yesterday, minutes: minutes, calendar: calendar) {
            return boundary
        }
        return calendar.startOfDay(for: now)
    }

    /// 次の区切り（次の起床時刻）。いまが区切りちょうどなら翌日のぶんを返す。
    public static func nextDayStart(now: Date, boundaryMinutes: Int, calendar: Calendar) -> Date {
        let minutes = NightWindowPolicy.normalizedMinutes(boundaryMinutes)
        return calendar.nextDate(
            after: now,
            matching: DateComponents(hour: minutes / 60, minute: minutes % 60),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)
    }

    private static func boundary(on day: Date, minutes: Int, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }

    // MARK: - 設定

    /// 選べる範囲へ寄せる。0以下を受け取ると「1回も開けない」になってしまうため1に寄せる。
    public static func normalizedLimit(_ value: Int) -> Int {
        min(max(value, 1), 999)
    }

    /// 予約した変更のうち、効く時刻を過ぎたものを反映する。
    public static func resolved(_ settings: DailyOpenLimitSettings, now: Date) -> DailyOpenLimitSettings {
        guard let pending = settings.pendingChange, pending.effectiveAt <= now else {
            return settings
        }
        var value = settings
        value.limit = pending.limit
        value.pendingChange = nil
        return value
    }

    /// 上限を変える。
    ///
    /// オンにする・減らすはすぐ効く。増やす・オフは次の区切りから効く。
    /// 使い切って止まった直後に設定から緩めて開く、という抜け道をふさぐため。
    /// オンにした日は、オンにした時刻より前に開いた回を数えない。
    public static func applying(
        limit newValue: Int?,
        to settings: DailyOpenLimitSettings,
        now: Date,
        boundaryMinutes: Int,
        calendar: Calendar
    ) -> DailyOpenLimitSettings {
        var value = resolved(settings, now: now)
        let newLimit = newValue.map(normalizedLimit)
        guard newLimit != value.limit else {
            value.pendingChange = nil
            return value
        }
        switch (value.limit, newLimit) {
        case (nil, let limit?):
            value.limit = limit
            value.pendingChange = nil
            value.countingStartsAt = now
        case (let current?, let limit?) where limit < current:
            value.limit = limit
            value.pendingChange = nil
        default:
            value.pendingChange = .init(
                limit: newLimit,
                effectiveAt: nextDayStart(now: now, boundaryMinutes: boundaryMinutes, calendar: calendar)
            )
        }
        return value
    }

    /// 今日の回を数え始める時刻。区切りとオンにした時刻の遅い方。
    public static func countingStart(
        settings: DailyOpenLimitSettings,
        now: Date,
        boundaryMinutes: Int,
        calendar: Calendar
    ) -> Date {
        let start = dayStart(now: now, boundaryMinutes: boundaryMinutes, calendar: calendar)
        guard let enabledAt = settings.countingStartsAt, enabledAt > start, enabledAt <= now else {
            return start
        }
        return enabledAt
    }

    public static func remaining(limit: Int, openedCount: Int) -> Int {
        max(0, limit - max(0, openedCount))
    }

    /// 画面へ渡す状態を組み立てる。`openedCount` は `countingStart` 以降に開いた回数。
    public static func status(
        settings: DailyOpenLimitSettings,
        openedCount: Int,
        now: Date,
        boundaryMinutes: Int,
        calendar: Calendar
    ) -> DailyOpenLimitStatus {
        let value = resolved(settings, now: now)
        return DailyOpenLimitStatus(
            limit: value.limit,
            pendingChange: value.pendingChange,
            openedCount: max(0, openedCount),
            dayEndsAt: nextDayStart(now: now, boundaryMinutes: boundaryMinutes, calendar: calendar)
        )
    }

    // MARK: - 使い切ったあとの窓

    /// 使い切った回の開いた時刻と決めた時間から、止まり始める時刻を出す。
    public static func blockStart(openedAt: Date, durationSeconds: Int?) -> Date {
        let seconds = durationSeconds.map { max(0, $0) } ?? DailyOpenLimitConstants.untimedLastOpenSeconds
        return openedAt.addingTimeInterval(TimeInterval(seconds))
    }

    /// 止まる窓。DeviceActivityが受け付けない15分未満は窓なしとして扱う。
    ///
    /// 窓なしのときにシールドを掛けると、解除を出す担い手（拡張の終了コールバック）がいない。
    /// 起床時刻を過ぎても開けない状態を作らないため、掛けない側へ倒す。
    public static func blockWindow(startsAt: Date, endsAt: Date) -> DateInterval? {
        guard endsAt.timeIntervalSince(startsAt) >= TimeInterval(minimumWindowMinutes * 60) else {
            return nil
        }
        return DateInterval(start: startsAt, end: endsAt)
    }

    /// いまシールドを出すか。控えに書かれた窓だけを見る。
    public static func isBlockActive(now: Date, snapshot: DailyOpenLimitShieldSnapshot) -> Bool {
        !snapshot.selectionDataList.isEmpty
            && snapshot.blockStartsAt <= now
            && now < snapshot.blockEndsAt
    }

    /// 控えを持ち続ける意味があるか。窓が終わった控えは消してよい。
    public static func isSnapshotCurrent(now: Date, snapshot: DailyOpenLimitShieldSnapshot) -> Bool {
        now < snapshot.blockEndsAt
    }

    // MARK: - 緊急で開く

    public enum EmergencyState: Equatable, Sendable {
        /// 待ちを始めていない。または猶予を過ぎて、もう一度待つ必要がある。
        case notRequested
        case waiting(remainingSeconds: Int)
        /// 待ち終わり、いま開ける。
        case ready
    }

    public static func emergencyState(requestedAt: Date?, now: Date) -> EmergencyState {
        guard let requestedAt else {
            return .notRequested
        }
        let elapsed = now.timeIntervalSince(requestedAt)
        // 時計が戻ったときは待ちを信用しない。もう一度待ってもらう。
        guard elapsed >= 0 else {
            return .notRequested
        }
        if elapsed < emergencyWaitSeconds {
            return .waiting(remainingSeconds: Int(ceil(emergencyWaitSeconds - elapsed)))
        }
        if elapsed <= emergencyWaitSeconds + emergencyReadyWindowSeconds {
            return .ready
        }
        return .notRequested
    }
}
