import DopaBreakCore
import Foundation

/// 1日に開ける回数の表示文言。一呼吸・ホーム・設定で同じ言い方にそろえる。
enum DailyOpenLimitDisplay {
    /// 「今日は12回開きました」
    static func openedTitle(_ count: Int) -> String {
        String(localized: "open_limit.opened_title", defaultValue: "今日は\(count)回開きました")
    }

    /// 「明日 7:00 まで開けません」。同じ日のうちに終わるときは「明日」を付けない。
    static func untilLine(_ end: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let time = end.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(end, inSameDayAs: now) {
            return String(localized: "open_limit.until_today", defaultValue: "\(time) まで開けません")
        }
        return String(localized: "open_limit.until_tomorrow", defaultValue: "明日 \(time) まで開けません")
    }

    /// 最後の1回の時間選択で出す一文。
    static func lastOpenNotice(_ end: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let time = end.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(end, inSameDayAs: now) {
            return String(localized: "open_limit.last.notice_today", defaultValue: "この時間が過ぎると \(time) まで開けません")
        }
        return String(localized: "open_limit.last.notice_tomorrow", defaultValue: "この時間が過ぎると明日 \(time) まで開けません")
    }

    /// 設定の値。「オフ」「12回」。
    static func limitValue(_ limit: Int?) -> String {
        guard let limit else {
            return String(localized: "open_limit.value.off", defaultValue: "オフ")
        }
        return String(localized: "open_limit.value.count", defaultValue: "\(limit)回")
    }

    /// 設定の変更待ち。「明日 7:00 から12回になります」。深夜の変更で同じ日の朝に効くときは「明日」を付けない。
    static func pendingLine(
        _ pending: DailyOpenLimitSettings.PendingChange,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let time = pending.effectiveAt.formatted(date: .omitted, time: .shortened)
        let isToday = calendar.isDate(pending.effectiveAt, inSameDayAs: now)
        guard let limit = pending.limit else {
            return isToday
                ? String(localized: "open_limit.pending.off_today", defaultValue: "\(time) からオフになります")
                : String(localized: "open_limit.pending.off", defaultValue: "明日 \(time) からオフになります")
        }
        return isToday
            ? String(localized: "open_limit.pending.count_today", defaultValue: "\(time) から\(limit)回になります")
            : String(localized: "open_limit.pending.count", defaultValue: "明日 \(time) から\(limit)回になります")
    }

    /// 使い切ったあと、まだ開けている時間の表示。「10:20 まで開けます」
    static func openUntilLine(_ until: Date) -> String {
        let time = until.formatted(date: .omitted, time: .shortened)
        return String(localized: "open_limit.open_until", defaultValue: "\(time) まで開けます")
    }

    /// 起床時刻の表示（「7:00」）。端末の時刻表記に合わせる。
    static func wakeTimeText(minutes: Int, calendar: Calendar = .autoupdatingCurrent) -> String {
        let normalized = NightWindowPolicy.normalizedMinutes(minutes)
        let date = calendar.date(
            bySettingHour: normalized / 60,
            minute: normalized % 60,
            second: 0,
            of: Date()
        ) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// 最近の平均から、最初に試す回数を選ぶ。平均の8割以下でいちばん近い選択肢。
    static func recommendedLimit(forAverage average: Int) -> Int {
        let target = Double(average) * 0.8
        return DailyOpenLimitConstants.limitChoices.last { Double($0) <= target }
            ?? DailyOpenLimitConstants.limitChoices[0]
    }
}
