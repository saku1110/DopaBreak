import Foundation

public enum DeepFocusConstants {
    /// 「いますぐ」で始めた回の終わりに拡張を起こすDeviceActivity名。繰り返さない一回きりの予定。
    public static let sessionActivityName = "dopabreak.deepfocus.session"

    /// 曜日ごとの予定に付ける名前の頭。曜日を1本の予定にまとめられないため、
    /// 選んだ曜日のぶんだけ別の活動として登録する。
    public static let scheduleActivityNamePrefix = "dopabreak.deepfocus.weekday"

    /// 完全ブロックだけを置くManagedSettingsストア名。
    /// 夜だけ強化（"dopabreak.night"）とも、旧版の常時ブロック（"dopabreak.rules"）とも分ける。
    /// 混ぜると、窓が終わったときの解除で夜のぶんまで外れる。
    public static let shieldStoreName = "dopabreak.deepfocus"

    /// 常時ブロックだった頃のストア名。窓の意味論へ移った後は誰も書かないが、
    /// 更新前に掛かったままの端末が残るため、同期のたびに空にし続ける。
    /// これを消し忘れると「窓が終わったのに開けない」が更新直後の全員に起きる。
    public static let legacyShieldStoreName = "dopabreak.rules"

    /// 予定の既定の時間帯（20:00→22:00）。夜だけ強化の既定（23:00→7:00）と重ならない位置に置く。
    public static let defaultScheduleStartMinutes = 1_200
    public static let defaultScheduleEndMinutes = 1_320

    /// `Calendar` と同じ並びの全曜日（1=日曜 … 7=土曜）。
    public static let allWeekdays = [1, 2, 3, 4, 5, 6, 7]

    public static func scheduleActivityName(weekday: Int) -> String {
        "\(scheduleActivityNamePrefix)\(weekday)"
    }

    /// 予定の活動名から曜日を戻す。範囲外の名前は受け取らない。
    public static func scheduleWeekday(activityName: String) -> Int? {
        guard activityName.hasPrefix(scheduleActivityNamePrefix) else {
            return nil
        }
        let suffix = activityName.dropFirst(scheduleActivityNamePrefix.count)
        guard let weekday = Int(suffix), allWeekdays.contains(weekday) else {
            return nil
        }
        return weekday
    }

    public static func dailyScheduleActivityName(index: Int) -> String { "dopabreak.deepfocus.daily\(index)" }

    public static func scheduleActivityName(index: Int, weekday: Int) -> String {
        index == 0 ? scheduleActivityName(weekday: weekday) : "dopabreak.deepfocus.second.weekday\(weekday)"
    }

    /// 完全ブロックの窓を動かすための活動か。拡張はこれで分岐する。
    public static func isWindowActivity(_ activityName: String) -> Bool {
        allWindowActivityNames.contains(activityName)
    }

    /// 登録しうる活動名の全部。張り直しの前に、いま要らないものまで含めて止めるために使う。
    public static var allWindowActivityNames: [String] {
        [sessionActivityName] + (0..<2).map(dailyScheduleActivityName(index:)) + (0..<2).flatMap { index in allWeekdays.map { scheduleActivityName(index: index, weekday: $0) } }
    }
}

/// いま完全ブロックの窓の中にいるかを決める純関数。
///
/// 窓は2種類ある。「いますぐ」で始めたセッションと、週に最大2本の予定。
/// どちらか一方でも開いていれば窓の中とみなす（両方が同時に開くこともある）。
/// 時計を読むのは呼び出し側で、ここへは `now` を渡す。
public enum DeepFocusWindowPolicy {
    /// DeviceActivityが受け付ける最短の区間（15分）。
    ///
    /// これを下回る予定で `startMonitoring` すると必ず `intervalTooShort` で失敗する。
    /// 失敗してから気づくのではなく、窓として成立しない時点で「窓なし」に倒す
    /// （`NightWindowPolicy` と同じ縮退）。
    public static let minimumWindowMinutes = 15

    // MARK: - 正規化

    /// `SettingsStore` と同じ丸め。負値や24時間超も一度 0...1439 へ寄せてから比べる。
    public static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }

    /// 曜日の集合を、範囲内・重複なし・昇順へ揃える。
    /// 控えはそのまま拡張が読むため、並びが揺れないところまで決めておく。
    public static func normalizedWeekdays(_ values: [Int]) -> [Int] {
        Array(Set(values.filter { DeepFocusConstants.allWeekdays.contains($0) })).sorted()
    }

    /// 翌日の曜日。跨日の予定で、終わりの側に使う。
    public static func nextWeekday(_ weekday: Int) -> Int {
        weekday % 7 + 1
    }

    /// 前日の曜日。跨日の予定の「朝側」が、どの曜日から続いてきたかを見るために使う。
    public static func previousWeekday(_ weekday: Int) -> Int {
        (weekday + 5) % 7 + 1
    }

    // MARK: - 予定の窓

    /// 開始から終了までの長さ（分）。跨日は翌日の終了までとして数える。
    /// 開始と終了が同時刻なら0を返す（24時間とは読まない）。
    public static func windowLengthMinutes(startMinutes: Int, endMinutes: Int) -> Int {
        let start = normalizedMinutes(startMinutes)
        let end = normalizedMinutes(endMinutes)
        return ((end - start) % 1_440 + 1_440) % 1_440
    }

    /// 時間帯として成立するか。幅ゼロと15分未満は「窓なし」に倒す。
    public static func hasWindow(startMinutes: Int, endMinutes: Int) -> Bool {
        windowLengthMinutes(startMinutes: startMinutes, endMinutes: endMinutes)
            >= minimumWindowMinutes
    }

    /// 日をまたぐ時間帯か。監視の登録で、終わりの曜日を翌日へずらすかの判定に使う。
    public static func crossesMidnight(startMinutes: Int, endMinutes: Int) -> Bool {
        normalizedMinutes(endMinutes) <= normalizedMinutes(startMinutes)
    }

    /// 予定として使える形になっているか。
    /// オフ・曜日ゼロ・15分未満のどれかなら、監視も控えも持たせない。
    public static func isScheduleUsable(_ schedule: DeepFocusSchedule) -> Bool {
        schedule.isEnabled
            && !schedule.weekdays.isEmpty
            && hasWindow(startMinutes: schedule.startMinutes, endMinutes: schedule.endMinutes)
    }

    /// いまが予定の時間帯の中か。
    ///
    /// 跨日（22:00→翌6:00）は、開始した曜日のぶんとして数える。
    /// 火曜の朝5時が「月曜の窓の続き」になるため、朝側は前日の曜日で照合する。
    public static func isScheduleActive(
        now: Date,
        schedule: DeepFocusSchedule,
        calendar: Calendar
    ) -> Bool {
        guard isScheduleUsable(schedule) else {
            return false
        }

        let start = normalizedMinutes(schedule.startMinutes)
        let end = normalizedMinutes(schedule.endMinutes)
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        guard let weekday = components.weekday else {
            return false
        }

        if start < end {
            return schedule.weekdays.contains(weekday) && minute >= start && minute < end
        }

        if schedule.weekdays.contains(weekday), minute >= start {
            return true
        }
        return schedule.weekdays.contains(previousWeekday(weekday)) && minute < end
    }

    public static func isScheduleActive(now: Date, schedules: [DeepFocusSchedule], calendar: Calendar) -> Bool {
        schedules.contains { isScheduleActive(now: now, schedule: $0, calendar: calendar) }
    }

    /// Return the end of the connected union of active and immediately following windows.
    /// Calendar dates (rather than fixed 24-hour offsets) preserve local time across DST.
    public static func scheduleWindowEnd(now: Date, schedules: [DeepFocusSchedule], calendar: Calendar, session: DeepFocusSession? = nil) -> Date? {
        var windows: [(start: Date, end: Date)] = []
        if let active = activeSession(session, now: now) {
            guard let end = active.endsAt else { return nil }
            windows.append((active.startedAt, end))
        }
        for offset in -1...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            for schedule in schedules where isScheduleUsable(schedule) && schedule.weekdays.contains(calendar.component(.weekday, from: day)) {
                guard let start = calendar.date(bySettingHour: schedule.startMinutes / 60, minute: schedule.startMinutes % 60, second: 0, of: day),
                      let endDay = calendar.date(byAdding: .day, value: crossesMidnight(startMinutes: schedule.startMinutes, endMinutes: schedule.endMinutes) ? 1 : 0, to: day),
                      let end = calendar.date(bySettingHour: schedule.endMinutes / 60, minute: schedule.endMinutes % 60, second: 0, of: endDay) else { continue }
                windows.append((start, end))
            }
        }
        var boundary = windows.filter { $0.start <= now && now < $0.end }.map(\.end).max()
        for window in windows.sorted(by: { $0.start < $1.start }) {
            if let end = boundary, window.start <= end, window.end > end { boundary = window.end }
        }
        // A week-long union has no finite next end. Do not invent an end time.
        if let end = boundary, end.timeIntervalSince(now) > 7 * 86_400 { return nil }
        return boundary
    }

    // MARK: - セッションの窓

    /// 終わる時刻を過ぎているか。「自分で戻すまで」は過ぎない。
    public static func isExpired(session: DeepFocusSession, now: Date) -> Bool {
        guard let endsAt = session.endsAt else {
            return false
        }
        return now >= endsAt
    }

    /// まだ生きているセッションだけを返す。終わった回は `nil` に潰す。
    public static func activeSession(
        _ session: DeepFocusSession?,
        now: Date
    ) -> DeepFocusSession? {
        guard let session, !isExpired(session: session, now: now) else {
            return nil
        }
        return session
    }

    public static func isSessionActive(now: Date, session: DeepFocusSession?) -> Bool {
        activeSession(session, now: now) != nil
    }

    /// 残り時間（秒）。「自分で戻すまで」と、終わった回は `nil`。
    public static func remainingSeconds(now: Date, session: DeepFocusSession?) -> TimeInterval? {
        guard let session = activeSession(session, now: now),
              let endsAt = session.endsAt else {
            return nil
        }
        return max(0, endsAt.timeIntervalSince(now))
    }

    // MARK: - まとめ

    /// いま完全ブロックを出すか。セッションと予定のどちらかが開いていればtrue。
    public static func isWindowActive(
        now: Date,
        session: DeepFocusSession?,
        schedule: DeepFocusSchedule,
        calendar: Calendar
    ) -> Bool {
        isSessionActive(now: now, session: session)
            || isScheduleActive(now: now, schedule: schedule, calendar: calendar)
    }

    /// 拡張が受け取った境界コールバックを、控えに書かれた窓で検算するための入口。
    ///
    /// DeviceActivityのコールバックは、設定を変えた後に古い予定のぶんが遅れて届くことがある。
    /// 時刻で確かめずに従うと、新しい窓のまっただ中で解除が走る。
    /// 適用も解除も「いま窓の内か外か」を見てから決める（`NightWindowPolicy` と同じ）。
    public static func isWindowActive(
        now: Date,
        snapshot: DeepFocusShieldSnapshot,
        calendar: Calendar
    ) -> Bool {
        isSessionActive(now: now, session: snapshot.session)
            || isScheduleActive(now: now, schedules: snapshot.schedules, calendar: calendar)
    }

    /// いま開いている窓に対して、拡張がシールドへ流す選択データを返す。
    ///
    /// 手動セッションは現在モードに関係なく全対象へ効き、毎週の予定は従来どおり
    /// `deepFocus` の対象だけへ効く。両方が重なるあいだは和集合、片方が終わったら
    /// 残った窓の対象だけへ戻す。
    public static func selectionDataListToShield(
        now: Date,
        snapshot: DeepFocusShieldSnapshot,
        calendar: Calendar
    ) -> [Data] {
        var result: [Data] = []
        var seen = Set<Data>()

        func appendUnique(_ values: [Data]) {
            for value in values where seen.insert(value).inserted {
                result.append(value)
            }
        }

        if isSessionActive(now: now, session: snapshot.session) {
            appendUnique(snapshot.sessionSelectionDataList ?? snapshot.selectionDataList)
        }
        if isScheduleActive(now: now, schedules: snapshot.schedules, calendar: calendar) {
            appendUnique(snapshot.selectionDataList)
        }
        return result
    }

    /// 監視と控えを持つ価値があるか。
    /// いま窓の外でも、これから開く予定があるなら控えは要る。
    /// 逆にセッションも予定も無ければ、控えを残す理由がない。
    public static func hasConfiguredWindow(
        now: Date,
        session: DeepFocusSession?,
        schedule: DeepFocusSchedule
    ) -> Bool {
        activeSession(session, now: now) != nil || isScheduleUsable(schedule)
    }
}
