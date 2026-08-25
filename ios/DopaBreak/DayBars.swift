import DopaBreakCore
import SwiftUI

struct DayBars: View {
    let days: [WeeklySummary.Day]
    var height: CGFloat = 62

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maximumCancelledCount: Int {
        days.map { max(0, $0.cancelled) }.max() ?? 0
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                dayColumn(day, isToday: index == days.count - 1)
            }
        }
    }

    private func dayColumn(_ day: WeeklySummary.Day, isToday: Bool) -> some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                cancelledBar(
                    for: day,
                    availableHeight: proxy.size.height,
                    availableWidth: proxy.size.width
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: height, alignment: .bottom)

            Text(weekdayLabel(for: day.date))
                .dopaFont(10, weight: .bold, design: .monospaced)
                .foregroundStyle(isToday ? DesignTokens.background : DesignTokens.tertiaryText)
                .frame(minWidth: 24, minHeight: 20)
                .background(isToday ? DesignTokens.accent : Color.clear)
                .overlay {
                    Capsule()
                        .stroke(isToday ? DesignTokens.accent : Color.clear, lineWidth: 1.5)
                }
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    @ViewBuilder
    private func cancelledBar(
        for day: WeeklySummary.Day,
        availableHeight: CGFloat,
        availableWidth: CGFloat
    ) -> some View {
        let cancelled = max(0, day.cancelled)

        if cancelled == 0 {
            // 0日はデータがあるように見せず、基準位置だけを中立色で示す。
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DesignTokens.hairline)
                .frame(width: 3, height: 3)
        } else {
            let barHeight = max(
                4,
                availableHeight
                    * CGFloat(cancelled)
                    / CGFloat(max(1, maximumCancelledCount))
            )

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DesignTokens.accent)
                .frame(
                    width: max(3, availableWidth * 0.62),
                    height: barHeight
                )
                .animation(reduceMotion ? nil : DopaMotion.morph, value: barHeight)
        }
    }

    private func weekdayLabel(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private func accessibilityLabel(for day: WeeklySummary.Day) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let weekdayIndex = calendar.component(.weekday, from: day.date) - 1
        let weekdayText = calendar.weekdaySymbols.indices.contains(weekdayIndex)
            ? calendar.weekdaySymbols[weekdayIndex]
            : day.date.formatted(.dateTime.month(.abbreviated).day())
        let cancelledLabel = String(
            localized: "stats.metric.cancelled",
            defaultValue: "開くのをやめた"
        )
        let attemptedLabel = String(
            localized: "stats.metric.attempted",
            defaultValue: "開こうとした"
        )
        let cancelledCount = String(
            localized: "stats.metric.count",
            defaultValue: "\(day.cancelled)回"
        )
        let attemptedCount = String(
            localized: "stats.metric.count",
            defaultValue: "\(day.attempts)回"
        )
        return "\(weekdayText) \(cancelledLabel) \(cancelledCount) \(attemptedLabel) \(attemptedCount)"
    }
}
