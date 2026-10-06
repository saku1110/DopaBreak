import DopaBreakCore
import Foundation

/// 週バーの土台。集計がまだ無い（あるいは読めなかった）ときに、直近7日ぶんの0件を並べる。
///
/// 基準日を含む7日を古い順に返す。暦は `.autoupdatingCurrent` を使う。
/// 端末側で週の始まりやタイムゾーンを変えた直後でも、画面の日付ラベルと同じ暦で並ぶようにするため。
///
/// ホーム（`HomeView`）と統計（`StatsView`）が同じ並びを出すよう、ここを正本にする。
/// 片方だけ日数や暦を変えると、同じ日を見ているのに棒の本数が違う画面ができる。
enum WeeklySummaryPlaceholder {
    static func emptyWeekDays(referenceDate: Date) -> [WeeklySummary.Day] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else {
                return nil
            }
            return WeeklySummary.Day(date: date, attempts: 0, cancelled: 0)
        }
    }
}
