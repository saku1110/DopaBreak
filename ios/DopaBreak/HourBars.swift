import SwiftUI

struct HourBars: View {
    let counts: [Int: Int]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func peakHour(in counts: [Int: Int]) -> Int? {
        let maximum = (0..<24).map { max(0, counts[$0] ?? 0) }.max() ?? 0
        guard maximum > 0 else { return nil }
        return (0..<24).first { max(0, counts[$0] ?? 0) == maximum }
    }

    static func shouldShowPeakFact(for counts: [Int: Int]) -> Bool {
        counts.values.reduce(0) { $0 + max(0, $1) } >= 5
    }

    static func barHeight(count: Int, maximumCount: Int, availableHeight: CGFloat) -> CGFloat {
        guard count > 0 else { return 2 }
        return max(2, availableHeight * CGFloat(count) / CGFloat(max(1, maximumCount)))
    }

    static func accessibilitySummary(for counts: [Int: Int]) -> String {
        guard shouldShowPeakFact(for: counts), let peakHour = peakHour(in: counts) else {
            return String(localized: "stats.hourly.title", defaultValue: "開こうとした時間帯")
        }
        return String(
            localized: "stats.hourly.peak",
            defaultValue: "\(peakHour)時台がいちばん多い"
        )
    }

    private var maximumCount: Int {
        max(1, (0..<24).map { max(0, counts[$0] ?? 0) }.max() ?? 0)
    }

    private var peakHour: Int? {
        Self.peakHour(in: counts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        bar(for: hour, availableHeight: proxy.size.height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 56)

            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(verbatim: "\(hour)")
                        .dopaFont(11, weight: .medium, design: .monospaced)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if Self.shouldShowPeakFact(for: counts), let peakHour {
                Text(
                    String(
                        localized: "stats.hourly.peak",
                        defaultValue: "\(peakHour)時台がいちばん多い"
                    )
                )
                .dopaFont(12, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func bar(for hour: Int, availableHeight: CGFloat) -> some View {
        let count = max(0, counts[hour] ?? 0)
        let height = Self.barHeight(
            count: count,
            maximumCount: maximumCount,
            availableHeight: availableHeight
        )
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(hour == peakHour ? DesignTokens.accent : DesignTokens.secondaryText.opacity(0.32))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .animation(reduceMotion ? nil : DopaMotion.morph, value: height)
    }

    private var accessibilitySummary: String {
        Self.accessibilitySummary(for: counts)
    }
}
