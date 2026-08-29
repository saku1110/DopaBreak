import Combine
import DopaBreakCore
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

/// 記録画面の読み取り専用サービス。
///
/// SQLiteは画面生成ごとに開かず、既定経路では遅延初期化した1接続を共有する。
/// 撮影とテストでは `StatsView` のinitializerから決定的なサービスを注入できる。
private enum StatsDataProvider {
    static let shared: StatsService? = {
        guard let logStore = try? SQLiteLogStore(containerProvider: DefaultContainerProvider()) else {
            return nil
        }
        return StatsService(logStore: logStore, calendar: .autoupdatingCurrent)
    }()
}

/// 期間の起点が動く出来事。通知はメインスレッドへ載せ替えてからViewへ渡す。
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

private enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case today
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return String(localized: "stats.period.week", defaultValue: "今週")
        case .today:
            return String(localized: "stats.period.today", defaultValue: "今日")
        case .all:
            return String(localized: "stats.period.all", defaultValue: "全期間")
        }
    }
}

private struct StatsAppMetric: Identifiable {
    let ruleID: UUID
    let title: String
    let catalogItem: SNSAppCatalogItem?
    let applicationToken: ApplicationToken?
    let attempts: Int
    let cancelled: Int

    var id: UUID { ruleID }

    var iconSource: AppIconSource {
        if let catalogItem {
            return .catalog(catalogItem)
        }
        if let applicationToken {
            return .token(applicationToken)
        }
        return .catalog(
            SNSAppCatalogItem(
                catalogID: "stats-rule-placeholder",
                displayName: title,
                urlScheme: nil,
                automationBundleID: "",
                symbolName: "app.fill"
            )
        )
    }
}

private struct StatsIntentMetric: Identifiable {
    let category: IntentCategory
    let title: String
    let count: Int

    var id: String { category.rawValue }
}

private struct StatsDashboardData {
    var summary = AttemptSummary(attempts: 0, cancelled: 0)
    var days: [WeeklySummary.Day] = []
    var weeklyDetail: WeeklyDetailReport?
    var appMetrics: [StatsAppMetric] = []
    var reflectionCounts: [PostUseSatisfaction: Int] = [:]
    var intentMetrics: [StatsIntentMetric] = []

    static let empty = StatsDashboardData()
}

struct StatsView: View {
    let model: AppModel

    private let injectedStatsService: StatsService?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var period: StatsPeriod
    @State private var dashboard = StatsDashboardData.empty

    init(model: AppModel, statsService: StatsService? = nil) {
        self.model = model
        self.injectedStatsService = statsService
        _period = State(initialValue: .week)
    }

    private var statsService: StatsService? {
        injectedStatsService ?? StatsDataProvider.shared
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                    periodPicker
                    if dashboard.summary.attempts == 0 {
                        emptyRecords
                    } else {
                        heroCard
                        detailContentSection
                    }
                }
                .padding(.horizontal, DesignTokens.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle(String(localized: "stats.title", defaultValue: "記録"))
            .navigationBarTitleDisplayMode(.large)
            .dopaScreenBackground()
        }
        .tint(DesignTokens.accent)
        .onAppear {
            model.refresh()
            model.isChildModalActive = false
            reloadDashboard()
        }
        .onChange(of: model.weekAttemptCount) { _, _ in
            reloadDashboard()
        }
        .onReceive(StatsTimeChange.publisher) { _ in
            model.refresh()
            reloadDashboard()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.refresh()
            reloadDashboard()
        }
    }

    // MARK: - 期間

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(StatsPeriod.allCases) { item in
                Button {
                    updatePeriod(item)
                } label: {
                    Text(item.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(period == item ? DesignTokens.accent : DesignTokens.primaryText)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
                        .background(DesignTokens.backgroundRaised)
                        .overlay {
                            Capsule()
                                .stroke(
                                    period == item ? DesignTokens.accent : DesignTokens.hairline,
                                    lineWidth: period == item ? 1.5 : 1
                                )
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == item ? .isSelected : [])
            }
        }
    }

    private func updatePeriod(_ selectedPeriod: StatsPeriod) {
        guard period != selectedPeriod else { return }
        withAnimation(reduceMotion ? nil : DopaMotion.morph) {
            period = selectedPeriod
            reloadDashboard(period: selectedPeriod)
        }
    }

    // MARK: - ヒーロー

    private var heroCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    SmallLabel(
                        text: String(localized: "stats.rate.title", defaultValue: "開かなかった割合")
                    )
                    Spacer(minLength: 8)
                    if period == .week, let report = dashboard.weeklyDetail {
                        Text(comparisonAttributedText(report))
                            .dopaFont(12, weight: .semibold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 14) {
                        rateDisplay
                            .frame(minWidth: 94, alignment: .leading)
                        periodVisualization
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        rateDisplay
                        periodVisualization
                    }
                }

                if period == .week {
                    legend
                }
            }
        }
    }

    @ViewBuilder
    private var rateDisplay: some View {
        if let percentage = successPercentage {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: "\(percentage)")
                    .dopaFont(56, weight: .black, design: .rounded, tracking: -1.8)
                Text(verbatim: "%")
                    .dopaFont(22, weight: .black, design: .rounded, tracking: -0.3)
            }
            .monospacedDigit()
            .foregroundStyle(DesignTokens.primaryText)
            .contentTransition(.numericText())
            .dopaDisplayClamp()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(percentageText(percentage))
        } else {
            Text(String(localized: "stats.rate.unavailable", defaultValue: "—"))
                .dopaFont(56, weight: .black, design: .rounded)
                .foregroundStyle(DesignTokens.primaryText)
                .dopaDisplayClamp()
        }
    }

    @ViewBuilder
    private var periodVisualization: some View {
        Group {
            switch period {
            case .week:
                DayBars(days: dashboard.days, height: 64)
            case .today:
                metricPair(
                    attempts: dashboard.summary.attempts,
                    cancelled: dashboard.summary.cancelled
                )
            case .all:
                MetricBlock(
                    label: String(
                        localized: "stats.all_time.cancelled",
                        defaultValue: "これまで開かなかった回数"
                    ),
                    value: countText(dashboard.summary.cancelled),
                    accent: true
                )
            }
        }
        .id(period)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: period)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(
                color: DesignTokens.accent,
                label: String(localized: "stats.behavior.cancelled", defaultValue: "開かなかった"),
                count: dashboard.summary.cancelled
            )
            Text("\(attemptedMetricLabel) \(countText(dashboard.summary.attempts))")
                .dopaFont(11, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("\(label) \(countText(count))")
                .dopaFont(11, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var successPercentage: Int? {
        guard dashboard.summary.attempts > 0 else { return nil }
        let rate = Double(dashboard.summary.cancelled) / Double(dashboard.summary.attempts)
        return Int((min(1, max(0, rate)) * 100).rounded())
    }

    private func percentageText(_ value: Int) -> String {
        String(localized: "stats.rate.percentage", defaultValue: "\(value)%%")
    }

    private func comparisonAttributedText(_ report: WeeklyDetailReport) -> AttributedString {
        var result = AttributedString(comparisonText(report))
        guard let delta = report.cancelledDelta, delta != 0,
              let range = result.range(of: String(abs(delta))) else {
            return result
        }
        result[range].foregroundColor = DesignTokens.accent
        return result
    }

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

    // MARK: - アプリごと

    private var detailContentSection: some View {
        VStack(spacing: DesignTokens.sectionSpacing) {
            appsCard
            reflectionCard
            intentCard
        }
    }

    private var appsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(text: String(localized: "stats.apps.title", defaultValue: "アプリごと"))

                if dashboard.appMetrics.isEmpty {
                    Text(
                        String(
                            localized: "stats.apps.empty",
                            defaultValue: "まだアプリごとの記録がありません"
                        )
                    )
                    .dopaFont(14, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .padding(.vertical, 6)
                } else {
                    ForEach(dashboard.appMetrics) { metric in
                        appRow(metric)
                    }
                }
            }
        }
    }

    private func appRow(_ metric: StatsAppMetric) -> some View {
        let ratioText = String(
            localized: "stats.apps.ratio",
            defaultValue: "\(metric.cancelled)/\(metric.attempts)"
        )
        return HStack(spacing: 10) {
            AppIconView(source: metric.iconSource, size: 30)
                .accessibilityHidden(true)

            Text(metric.title)
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
                .frame(width: 74, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.hairline)
                    Capsule()
                        .fill(DesignTokens.accent)
                        .frame(
                            width: proxy.size.width
                                * CGFloat(metric.cancelled)
                                / CGFloat(max(1, metric.attempts))
                        )
                }
            }
            .frame(height: 6)

            Text(ratioText)
                .dopaFont(12, weight: .bold, design: .monospaced)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 50, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) \(ratioText)")
    }

    // MARK: - 見たあとの気持ち

    private var reflectionCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(
                    text: String(
                        localized: "stats.reflection.title",
                        defaultValue: "見たあとの気持ち"
                    )
                )

                if reflectionAnswerCount == 0 {
                    emptyTitle
                } else {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(PostUseSatisfaction.allCases, id: \.rawValue) { satisfaction in
                            let count = dashboard.reflectionCounts[satisfaction] ?? 0
                            VStack(spacing: 5) {
                                CharacterView(
                                    satisfaction.characterExpression,
                                    size: 40,
                                    animated: false
                                )
                                .opacity(count > 0 ? 1 : 0.45)

                                Text(verbatim: "\(count)")
                                    .dopaFont(14, weight: .black, design: .rounded)
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.primaryText)

                                Text(satisfaction.displayTitle)
                                    .dopaFont(9.5, weight: .medium, lineSpacing: 1)
                                    .foregroundStyle(DesignTokens.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.68)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(satisfaction.displayTitle) \(countText(count))")
                        }
                    }
                }
            }
        }
    }

    private var reflectionAnswerCount: Int {
        dashboard.reflectionCounts.values.reduce(0, +)
    }

    // MARK: - 開こうとした理由

    private var intentCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(
                    text: String(
                        localized: "stats.intent.title",
                        defaultValue: "開こうとした理由"
                    )
                )

                if dashboard.intentMetrics.isEmpty {
                    emptyTitle
                } else {
                    StatsFlowLayout(spacing: 8) {
                        ForEach(dashboard.intentMetrics) { metric in
                            Text("\(metric.title) \(intentPercentageText(metric.count))")
                                .dopaFont(12, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(DesignTokens.backgroundRaised)
                                .overlay { Capsule().stroke(DesignTokens.hairline, lineWidth: 1) }
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func intentPercentageText(_ count: Int) -> String {
        let total = max(1, dashboard.intentMetrics.reduce(0) { $0 + $1.count })
        let percentage = Int((Double(count) * 100 / Double(total)).rounded())
        return String(format: "%d%%", locale: Locale.autoupdatingCurrent, percentage)
    }

    // MARK: - 共通表示

    private var emptyTitle: some View {
        Text(String(localized: "stats.empty.title", defaultValue: "まだ記録がありません"))
            .dopaFont(14, weight: .medium)
            .foregroundStyle(DesignTokens.secondaryText)
            .padding(.vertical, 6)
    }

    private var emptyRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "stats.empty.title", defaultValue: "まだ記録がありません"))
                .dopaFont(20, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)

            Text(
                String(
                    localized: "stats.empty.description",
                    defaultValue: "対象アプリを開こうとした回数と、開かなかった回数がここに記録されます。"
                )
            )
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

    // MARK: - 読み込み

    private func reloadDashboard(
        referenceDate: Date = Date(),
        period selectedPeriod: StatsPeriod? = nil
    ) {
        let dashboardPeriod = selectedPeriod ?? period

        guard let statsService else {
            dashboard = fallbackDashboard(
                referenceDate: referenceDate,
                period: dashboardPeriod
            )
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let report = try? statsService.weeklyDetailReport()
        let range = dateRange(
            for: dashboardPeriod,
            report: report,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let summary: AttemptSummary
        switch dashboardPeriod {
        case .week:
            summary = report.map {
                AttemptSummary(
                    attempts: $0.current.attempts,
                    cancelled: $0.current.cancelled
                )
            } ?? AttemptSummary(
                attempts: model.weekAttemptCount,
                cancelled: model.weekCancelledCount
            )
        case .today:
            summary = (try? statsService.attemptSummary(from: range.start, to: range.end))
                ?? AttemptSummary(
                    attempts: model.todayAttemptCount,
                    cancelled: model.todayCancelledCount
                )
        case .all:
            summary = AttemptSummary(
                attempts: (try? statsService.attemptsAllTime()) ?? model.allTimeAttemptCount,
                cancelled: (try? statsService.cancelledAttemptsAllTime())
                    ?? model.allTimeCancelledCount
            )
        }

        let detailed = (
            try? statsService.appRuleBreakdownDetailed(from: range.start, to: range.end)
        ) ?? [:]
        let reflectionCounts = (
            try? statsService.reflectionBreakdown(from: range.start, to: range.end)
        ) ?? [:]
        let intentCounts = (
            try? statsService.intentBreakdown(from: range.start, to: range.end)
        ) ?? [:]

        dashboard = StatsDashboardData(
            summary: summary,
            days: report?.current.days ?? emptyWeekDays(referenceDate: referenceDate),
            weeklyDetail: report,
            appMetrics: appMetrics(from: detailed),
            reflectionCounts: reflectionCounts,
            intentMetrics: intentMetrics(from: intentCounts)
        )
    }

    private func fallbackDashboard(
        referenceDate: Date,
        period dashboardPeriod: StatsPeriod
    ) -> StatsDashboardData {
        let summary: AttemptSummary
        switch dashboardPeriod {
        case .week:
            summary = AttemptSummary(
                attempts: model.weekAttemptCount,
                cancelled: model.weekCancelledCount
            )
        case .today:
            summary = AttemptSummary(
                attempts: model.todayAttemptCount,
                cancelled: model.todayCancelledCount
            )
        case .all:
            summary = AttemptSummary(
                attempts: model.allTimeAttemptCount,
                cancelled: model.allTimeCancelledCount
            )
        }
        return StatsDashboardData(
            summary: summary,
            days: emptyWeekDays(referenceDate: referenceDate)
        )
    }

    private func dateRange(
        for period: StatsPeriod,
        report: WeeklyDetailReport?,
        referenceDate: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
            ?? todayStart.addingTimeInterval(86_400)

        switch period {
        case .week:
            let start = report?.current.days.first?.date
                ?? calendar.date(byAdding: .day, value: -6, to: todayStart)
                ?? todayStart.addingTimeInterval(-6 * 86_400)
            let lastDay = report?.current.days.last?.date ?? todayStart
            let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? todayEnd
            return (start, end)
        case .today:
            return (todayStart, todayEnd)
        case .all:
            return (Date(timeIntervalSince1970: 0), todayEnd)
        }
    }

    private func emptyWeekDays(referenceDate: Date) -> [WeeklySummary.Day] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else {
                return nil
            }
            return WeeklySummary.Day(date: date, attempts: 0, cancelled: 0)
        }
    }

    private func appMetrics(
        from detailed: [UUID: (attempts: Int, cancelled: Int)]
    ) -> [StatsAppMetric] {
        let rules = (try? model.ruleStore.allRules()) ?? []
        let ruleByID = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })

        return detailed.compactMap { ruleID, breakdown -> StatsAppMetric? in
            guard let rule = ruleByID[ruleID] else { return nil }
            let title = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let catalogItem = rule.activitySelectionData.isEmpty
                ? SNSAppCatalog.all.first { $0.displayName == title }
                : nil
            let applicationToken = singleApplicationToken(from: rule.activitySelectionData)

            return StatsAppMetric(
                ruleID: ruleID,
                title: catalogItem?.displayName ?? title,
                catalogItem: catalogItem,
                applicationToken: applicationToken,
                attempts: breakdown.attempts,
                cancelled: breakdown.cancelled
            )
        }
        .sorted { lhs, rhs in
            if lhs.attempts == rhs.attempts {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return lhs.attempts > rhs.attempts
        }
    }

    private func singleApplicationToken(from selectionData: Data) -> ApplicationToken? {
        guard !selectionData.isEmpty,
              let selection = try? JSONDecoder().decode(
                  FamilyActivitySelection.self,
                  from: selectionData
              ),
              selection.applicationTokens.count == 1 else {
            return nil
        }
        return selection.applicationTokens.first
    }

    private func intentMetrics(from counts: [IntentCategory: Int]) -> [StatsIntentMetric] {
        var displayCounts = counts
        if let legacyAnxietyCount = displayCounts.removeValue(forKey: .anxietyCheck) {
            displayCounts[.communication, default: 0] += legacyAnxietyCount
        }
        let caseOrder = Dictionary(
            uniqueKeysWithValues: IntentCategory.allCases.enumerated().map { ($1, $0) }
        )
        return displayCounts.compactMap { category, count -> StatsIntentMetric? in
            guard count > 0 else { return nil }
            let title = intentTitle(category)
            return StatsIntentMetric(category: category, title: title, count: count)
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return (caseOrder[lhs.category] ?? .max) < (caseOrder[rhs.category] ?? .max)
            }
            return lhs.count > rhs.count
        }
    }

    private func intentTitle(_ category: IntentCategory) -> String {
        switch category {
        case .workRequired:
            return String(localized: "intervention.reason.work", defaultValue: "仕事で使う")
        case .research:
            return String(localized: "intervention.reason.research", defaultValue: "調べもの")
        case .communication, .anxietyCheck:
            return String(localized: "intervention.reason.communication", defaultValue: "連絡を確認")
        case .posting:
            return String(localized: "intervention.reason.posting", defaultValue: "投稿する")
        case .boredom:
            return String(localized: "intervention.reason.boredom", defaultValue: "暇つぶし")
        case .unconscious:
            return String(localized: "intervention.reason.unconscious", defaultValue: "なんとなく")
        case .other:
            return String(localized: "goal_editor.category.other", defaultValue: "その他")
        }
    }
}

/// 件数順の理由チップを、利用可能幅に合わせて左から折り返す。
private struct StatsFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            measuredWidth = max(measuredWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(
            width: availableWidth.isFinite ? availableWidth : measuredWidth,
            height: subviews.isEmpty ? 0 : y + rowHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
