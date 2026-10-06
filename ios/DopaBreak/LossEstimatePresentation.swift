import DopaBreakCore
import Foundation

/// オンボーディング（O-03r）とペイウォールで、同じ推計値を同じ書式にする唯一のフォーマッタ。
/// 2026-09-04にペイウォール見出しを人生年数へ揃えた際、`OnboardingFlow` の私有ヘルパーから切り出した。
/// 前提は docs/07 O-03r（2026-07-29 オーナー決定）と共通で、50年換算・丸めは常に切り捨て側。
enum LossEstimatePresentation {
    /// カタログ側の書式で丸め直されないよう、`ReclaimedTimeFormatter` と同じく
    /// バンドルから書式だけ取り出して引数を当てる。テストで言語を固定できるのも同じ理由。
    private static func formatted(
        _ key: String,
        defaultValue: String,
        arguments: [CVarArg],
        bundle: Bundle
    ) -> String {
        let format = bundle.localizedString(forKey: key, value: defaultValue, table: nil)
        return String(format: format, arguments: arguments)
    }

    /// 1日の利用時間。60分未満は分、割り切れるときは整数の時間、それ以外は1桁小数の時間。
    /// O-03r の免責と同じ分岐を共有するため、キーも `onboarding.result.duration.*` のまま使う。
    static func dailyTimeText(
        minutes: Int,
        bundle: Bundle = .main
    ) -> String {
        if minutes < 60 {
            return formatted(
                "onboarding.result.duration.minutes",
                defaultValue: "%lld分",
                arguments: [minutes],
                bundle: bundle
            )
        }

        let hours = Double(minutes) / 60.0
        if hours.rounded() == hours {
            return formatted(
                "onboarding.result.duration.hours",
                defaultValue: "%lld時間",
                arguments: [Int(hours)],
                bundle: bundle
            )
        }

        return formatted(
            "onboarding.result.duration.decimal_hours",
            defaultValue: "%.1lf時間",
            arguments: [hours],
            bundle: bundle
        )
    }

    /// 人生換算の年数。LossEstimator側で切り捨て済みの値を文字列にしてから差し込み、
    /// ローカライズ側の書式で丸め直されないようにする（%@で受ける）。
    static func lifetimeYearsText(yearlyDays: Int) -> String {
        String(format: "%.1f", LossEstimator.lifetimeYears(fromYearlyDays: yearlyDays))
    }
}
