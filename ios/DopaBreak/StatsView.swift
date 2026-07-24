import SwiftUI

struct StatsView: View {
    let model: AppModel

    @State private var paywallPlacement: PaywallPlacement?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                ScreenHeader(
                    eyebrow: isStatsHistoryLocked
                        ? String(localized: "stats.header.today.eyebrow", defaultValue: "STATS · 今日")
                        : String(localized: "stats.header.week.eyebrow", defaultValue: "STATS · 今週"),
                    title: isStatsHistoryLocked
                        ? String(localized: "stats.header.today.title", defaultValue: "今日の記録")
                        : String(localized: "stats.header.week.title", defaultValue: "今週の傾向")
                )
                    .padding(.top, 18)

                if isStatsHistoryLocked {
                    dailyRate
                    dailySummary
                    lockedWeeklySummary
                } else {
                    weeklyRate
                    weeklySummary
                    if model.weekAttemptCount > 0 {
                        behaviorSignal
                    }
                    allTimeSummary
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
            model.isChildModalActive = isAnyChildModalPresented
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .fullScreenCover(item: $paywallPlacement) { placement in
            PaywallView(storeService: model.storeService, placement: placement)
        }
    }

    private var isAnyChildModalPresented: Bool {
        paywallPlacement != nil
    }

    private var isStatsHistoryLocked: Bool {
        model.entitlementGate.statsDays == 1
    }

    private var dailyRate: some View {
        rateBlock(text: dailySuccessRateText)
    }

    private var weeklyRate: some View {
        rateBlock(text: weeklySuccessRateText)
    }

    private func rateBlock(text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 68, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.primaryText)
                .tracking(-2)
            Text(String(localized: "stats.rate.title", defaultValue: "開かずに戻れた割合"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private var dailySummary: some View {
        summaryCard(
            label: String(localized: "stats.summary.today.label", defaultValue: "TODAY SUMMARY"),
            attempts: model.todayAttemptCount,
            cancelled: model.todayCancelledCount
        )
    }

    private var weeklySummary: some View {
        summaryCard(
            label: String(localized: "stats.summary.week.label", defaultValue: "WEEKLY SUMMARY"),
            attempts: model.weekAttemptCount,
            cancelled: model.weekCancelledCount
        )
    }

    private func summaryCard(label: String, attempts: Int, cancelled: Int) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SmallLabel(text: label)

                if attempts == 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "stats.empty.title", defaultValue: "まだ記録がありません"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DesignTokens.primaryText)

                        Text(String(localized: "stats.empty.description", defaultValue: "開く前に選び直すたび、取り戻した記録がここに貯まります。"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .lineSpacing(4)
                    }
                } else {
                    HStack(spacing: 14) {
                        MetricBlock(
                            label: String(localized: "stats.metric.cancelled", defaultValue: "開かずに戻れた"),
                            value: String(localized: "stats.metric.count", defaultValue: "\(cancelled)回"),
                            accent: true
                        )
                        MetricBlock(
                            label: String(localized: "stats.metric.attempted", defaultValue: "開こうとした"),
                            value: String(localized: "stats.metric.count", defaultValue: "\(attempts)回")
                        )
                    }
                }
            }
        }
    }

    private var lockedWeeklySummary: some View {
        Button {
            paywallPlacement = .statsHistoryGate
        } label: {
            CardContainer {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignTokens.accent)

                    Text(String(localized: "stats.paywall.full_history", defaultValue: "記録を全期間さかのぼれる"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignTokens.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var behaviorSignal: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 15) {
                SmallLabel(text: String(localized: "stats.behavior.label", defaultValue: "BEHAVIOR SIGNAL"))
                signalRow(
                    label: String(localized: "stats.behavior.cancelled", defaultValue: "戻れた"),
                    value: weeklySuccessRate,
                    color: DesignTokens.accent
                )
                signalRow(
                    label: String(localized: "stats.behavior.opened", defaultValue: "開いた"),
                    value: 1 - weeklySuccessRate,
                    color: DesignTokens.secondaryText
                )
            }
        }
    }

    private var allTimeSummary: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 15) {
                SmallLabel(text: String(localized: "stats.all_time.label", defaultValue: "ALL TIME"))
                MetricBlock(
                    label: String(localized: "stats.all_time.cancelled", defaultValue: "これまでに開かずに戻れた"),
                    value: String(localized: "stats.metric.count", defaultValue: "\(model.allTimeCancelledCount)回"),
                    accent: true
                )
            }
        }
    }

    private func signalRow(label: String, value: CGFloat, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 52, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.hairline)
                    Capsule().fill(color).frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 6)
            Text(
                String(
                    localized: "stats.rate.percentage",
                    defaultValue: "\(Int((value * 100).rounded()))%"
                )
            )
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var weeklySuccessRate: CGFloat {
        guard model.weekAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(model.weekCancelledCount) / CGFloat(model.weekAttemptCount))
    }

    private var weeklySuccessRateText: String {
        guard model.weekAttemptCount > 0 else {
            return String(localized: "stats.rate.unavailable", defaultValue: "—")
        }
        return String(
            localized: "stats.rate.percentage",
            defaultValue: "\(Int((weeklySuccessRate * 100).rounded()))%"
        )
    }

    private var dailySuccessRate: CGFloat {
        guard model.todayAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(model.todayCancelledCount) / CGFloat(model.todayAttemptCount))
    }

    private var dailySuccessRateText: String {
        guard model.todayAttemptCount > 0 else {
            return String(localized: "stats.rate.unavailable", defaultValue: "—")
        }
        return String(
            localized: "stats.rate.percentage",
            defaultValue: "\(Int((dailySuccessRate * 100).rounded()))%"
        )
    }
}
