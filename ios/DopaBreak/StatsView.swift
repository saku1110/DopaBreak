import Combine
import SwiftUI
import UIKit
import DopaBreakCore

/// 週次詳細レポートの読み取り専用サービス。
///
/// SQLiteを開くのは一度きりにしたいので、View生成ごとではなくここで1つだけ保持する
/// （PaywallView・OnboardingFlowが `DefaultContainerProvider` から自前のストアを起こすのと同じ形）。
/// `static let` の遅延初期化に任せるため、記録データを開けない端末では nil のまま固定される。
///
/// 暦は `autoupdatingCurrent` を渡す。`current` はその場のタイムゾーンを写し取った値のため、
/// 一度きりの生成と組み合わせると、端末のタイムゾーンを変えても古い日境界のまま集計し続ける。
private enum WeeklyDetailStatsProvider {
    static let shared: StatsService? = {
        guard let logStore = try? SQLiteLogStore(containerProvider: DefaultContainerProvider()) else {
            return nil
        }
        return StatsService(logStore: logStore, calendar: .autoupdatingCurrent)
    }()
}

/// 7日窓の起点が動く出来事。日付の変更・タイムゾーンの変更・時刻の大きな変更をまとめて拾う。
/// `NSCalendarDayChanged` は副スレッドで届くため、購読側へ渡す前にメインへ載せ替える。
private enum StatsTimeChange {
    static let publisher = Publishers.MergeMany(
        [
            Notification.Name.NSCalendarDayChanged,
            Notification.Name.NSSystemTimeZoneDidChange,
            UIApplication.significantTimeChangeNotification
        ].map { name in
            NotificationCenter.default.publisher(for: name).map { _ in () }
        }
    )
    .receive(on: DispatchQueue.main)
}

struct StatsView: View {
    let model: AppModel

    private let injectedStatsService: StatsService?

    @Environment(\.scenePhase) private var scenePhase
    @State private var paywallPlacement: PaywallPlacement?
    @State private var weeklyDetail: WeeklyDetailReport?
    @ScaledMetric(relativeTo: .caption) private var dailyBarHeight: CGFloat = 76

    init(model: AppModel, statsService: StatsService? = nil) {
        self.model = model
        self.injectedStatsService = statsService
    }

    /// 既定の解決は実際に読むときまで遅らせる。Freeのまま使い続ける端末で
    /// 週次詳細用のSQLite接続を開かせないため、初期化時には触らない。
    private var statsService: StatsService? {
        injectedStatsService ?? WeeklyDetailStatsProvider.shared
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                    if isStatsHistoryLocked {
                        dailyRate
                        dailySummary
                    } else {
                        weeklyRate
                    }

                    // 週次詳細はProの実体。Freeにはロックカードで中身を予告する。
                    if isWeeklyDetailAllowed {
                        weeklyDetailSection
                    } else {
                        lockedWeeklyDetail
                    }

                    if isStatsHistoryLocked {
                        lockedWeeklySummary
                    } else {
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
            reloadWeeklyDetail()
        }
        // 介入を1件記録するたびに日別バーも動かす。週次通知から着地した直後の再取得もここが担う。
        .onChange(of: model.weekAttemptCount) { _, _ in
            reloadWeeklyDetail()
        }
        .onChange(of: isWeeklyDetailAllowed) { _, _ in
            reloadWeeklyDetail()
        }
        // 日付やタイムゾーンが変われば、件数が同じでも7日窓の中身は変わる。
        // 画面を開いたまま日をまたぐ場合はここが、寝かせたまま日をまたぐ場合は復帰が拾う。
        .onReceive(StatsTimeChange.publisher) { _ in
            reloadWeeklyDetail()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            reloadWeeklyDetail()
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

    private var isWeeklyDetailAllowed: Bool {
        model.entitlementGate.weeklyReportAllowed
    }

    /// 旧ScreenHeaderのeyebrowが担っていた「今日／今週」の区別は見出し本文に含める。
    private var navigationTitleText: String {
        isStatsHistoryLocked
            ? String(localized: "stats.header.today.title", defaultValue: "今日の記録")
            : String(localized: "stats.header.week.title", defaultValue: "今週の傾向")
    }

    private func reloadWeeklyDetail() {
        guard isWeeklyDetailAllowed, let statsService else {
            weeklyDetail = nil
            return
        }
        weeklyDetail = try? statsService.weeklyDetailReport()
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
            Text(String(localized: "stats.rate.title", defaultValue: "開かなかった割合"))
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
                    emptyRecords
                } else {
                    metricPair(attempts: attempts, cancelled: cancelled)
                }
            }
        }
    }

    // MARK: - 週次詳細（Pro）

    /// 記録データを開けないときは週の合計だけでも欠けさせない。
    @ViewBuilder
    private var weeklyDetailSection: some View {
        if let weeklyDetail {
            weeklyDetailCard(weeklyDetail)
        } else {
            weeklySummary
        }
    }

    private func weeklyDetailCard(_ report: WeeklyDetailReport) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SmallLabel(
                    text: String(localized: "stats.weekly_detail.label", defaultValue: "WEEKLY DETAIL")
                )

                if report.isEmpty {
                    emptyRecords
                } else {
                    metricPair(attempts: report.current.attempts, cancelled: report.current.cancelled)
                    comparisonRow(report)
                    dailyBars(report)
                    legend
                }
            }
        }
    }

    private func comparisonRow(_ report: WeeklyDetailReport) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            SmallLabel(
                text: String(
                    localized: "stats.weekly_detail.comparison.label",
                    defaultValue: "VS LAST WEEK"
                )
            )
            Spacer(minLength: 8)
            Text(comparisonText(report))
                .dopaFont(13, weight: .bold)
                .foregroundStyle(
                    isComparisonImproved(report) ? DesignTokens.accent : DesignTokens.secondaryText
                )
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// 前週比は「開かなかった回数」で語る。割合の増減は画面上部の大きな数字が担う。
    private func comparisonText(_ report: WeeklyDetailReport) -> String {
        guard let delta = report.cancelledDelta else {
            return String(
                localized: "stats.weekly_detail.comparison.no_data",
                defaultValue: "先週の記録なし"
            )
        }
        if delta > 0 {
            return String(
                localized: "stats.weekly_detail.comparison.more",
                defaultValue: "先週より\(delta)回多い"
            )
        }
        if delta < 0 {
            return String(
                localized: "stats.weekly_detail.comparison.less",
                defaultValue: "先週より\(-delta)回少ない"
            )
        }
        return String(
            localized: "stats.weekly_detail.comparison.same",
            defaultValue: "先週と同じ"
        )
    }

    private func isComparisonImproved(_ report: WeeklyDetailReport) -> Bool {
        (report.cancelledDelta ?? 0) > 0
    }

    private func dailyBars(_ report: WeeklyDetailReport) -> some View {
        // 縮尺は今週と前週を通した最大値。週が変わるたびにバーの意味が変わらないようにする。
        let peak = max(report.peakDailyAttempts, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(report.current.days, id: \.date) { day in
                dayColumn(day: day, peak: peak)
            }
        }
    }

    private func dayColumn(day: WeeklySummary.Day, peak: Int) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignTokens.hairline)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignTokens.secondaryText.opacity(0.5))
                    .frame(height: barHeight(for: day.attempts, peak: peak))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignTokens.accent)
                    .frame(height: barHeight(for: day.cancelled, peak: peak))
            }
            .frame(height: dailyBarHeight)
            .animation(DopaMotion.transition, value: day)

            Text(weekdayLabel(for: day.date))
                .dopaFont(10, weight: .bold, design: .monospaced)
                .foregroundStyle(
                    Calendar.autoupdatingCurrent.isDateInToday(day.date)
                        ? DesignTokens.primaryText
                        : DesignTokens.tertiaryText
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        // 棒と曜日を別々に読ませず、その日の記録として1回で読み上げる。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayAccessibilityLabel(day))
    }

    /// 1回でも記録があった日は、縮尺で潰れても見える高さを残す。
    private func barHeight(for count: Int, peak: Int) -> CGFloat {
        guard count > 0, peak > 0 else { return 0 }
        return max(dailyBarHeight * CGFloat(count) / CGFloat(peak), 4)
    }

    private func weekdayLabel(for date: Date) -> String {
        // 集計側と同じ暦を使う。曜日ラベルだけ古いタイムゾーンで固定されるのを避ける。
        let calendar = Calendar.autoupdatingCurrent
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        guard symbols.indices.contains(index) else {
            return ""
        }
        return symbols[index]
    }

    private func dayAccessibilityLabel(_ day: WeeklySummary.Day) -> String {
        let dateText = day.date.formatted(.dateTime.month(.abbreviated).day())
        return String(
            localized: "stats.weekly_detail.day.accessibility_label",
            defaultValue: "\(dateText) 開こうとした\(day.attempts)回 開かなかった\(day.cancelled)回"
        )
    }

    /// バーの色分けの凡例。読み上げは各バーのラベルが持つので、ここは見た目だけの補助にする。
    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: DesignTokens.accent, text: cancelledMetricLabel)
            legendItem(color: DesignTokens.secondaryText.opacity(0.5), text: attemptedMetricLabel)
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .dopaFont(11, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    // MARK: - 共通部品

    private var emptyRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "stats.empty.title", defaultValue: "まだ記録がありません"))
                .dopaFont(20, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)

            Text(String(localized: "stats.empty.description", defaultValue: "開く前に選び直すたび、その記録がここに貯まります。"))
                .dopaFont(14, weight: .medium, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private func metricPair(attempts: Int, cancelled: Int) -> some View {
        HStack(spacing: 14) {
            MetricBlock(
                label: cancelledMetricLabel,
                value: countText(cancelled),
                accent: true
            )
            MetricBlock(
                label: attemptedMetricLabel,
                value: countText(attempts)
            )
        }
    }

    private var cancelledMetricLabel: String {
        String(localized: "stats.metric.cancelled", defaultValue: "開かなかった")
    }

    private var attemptedMetricLabel: String {
        String(localized: "stats.metric.attempted", defaultValue: "開こうとした")
    }

    private func countText(_ count: Int) -> String {
        String(localized: "stats.metric.count", defaultValue: "\(count)回")
    }

    /// placement は `.statsHistoryGate` を流用する。`.weekly` は自動提示側の間隔計算
    /// （`WeeklyPaywallPolicy` の `lastWeeklyPaywallShownAt`）に紐づいており、
    /// 手動タップでその時計を進めると既存の週次自動提示の挙動まで変わるため使わない。
    private var lockedWeeklyDetail: some View {
        lockRow(
            text: String(
                localized: "stats.paywall.weekly_report",
                defaultValue: "毎週のふりかえりを詳しく見られる"
            ),
            placement: .statsHistoryGate
        )
    }

    private var lockedWeeklySummary: some View {
        lockRow(
            text: String(
                localized: "stats.paywall.full_history",
                defaultValue: "記録を全期間さかのぼれる"
            ),
            placement: .statsHistoryGate
        )
    }

    private func lockRow(text: String, placement: PaywallPlacement) -> some View {
        Button {
            paywallPlacement = placement
        } label: {
            CardContainer {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.accent)

                    Text(text)
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
                    label: String(localized: "stats.behavior.cancelled", defaultValue: "開かなかった"),
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
                    label: String(localized: "stats.all_time.cancelled", defaultValue: "これまでに開かなかった"),
                    value: countText(model.allTimeCancelledCount),
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
