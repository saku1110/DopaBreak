import SwiftUI

struct StatsView: View {
    let model: AppModel

    @State private var paywallPlacement: PaywallPlacement?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
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
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            // 自前のScreenHeaderをやめ、システムの大見出しへ寄せた。
            // スクロールでの縮小・素材効果・VoiceOverの見出し扱いが標準どおりになる。
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.large)
            .dopaScreenBackground()
        }
        .tint(DesignTokens.accent)
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

    /// 旧ScreenHeaderのeyebrowが担っていた「今日／今週」の区別は見出し本文に含める。
    private var navigationTitleText: String {
        isStatsHistoryLocked
            ? String(localized: "stats.header.today.title", defaultValue: "今日の記録")
            : String(localized: "stats.header.week.title", defaultValue: "今週の傾向")
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
                .dopaFont(68, weight: .black, design: .rounded, tracking: -2)
                .monospacedDigit()
                .foregroundStyle(DesignTokens.primaryText)
                .contentTransition(.numericText())
                .dopaDisplayClamp()
            Text(String(localized: "stats.rate.title", defaultValue: "開かずに戻れた割合"))
                .dopaFont(14, weight: .bold)
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
                            .dopaFont(20, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)

                        Text(String(localized: "stats.empty.description", defaultValue: "開く前に選び直すたび、取り戻した記録がここに貯まります。"))
                            .dopaFont(14, weight: .medium, lineSpacing: 4)
                            .foregroundStyle(DesignTokens.secondaryText)
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
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.accent)

                    Text(String(localized: "stats.paywall.full_history", defaultValue: "記録を全期間さかのぼれる"))
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .dopaFont(13, weight: .bold)
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
                .dopaFont(12, weight: .bold)
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
                .dopaFont(12, weight: .bold, design: .monospaced)
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
