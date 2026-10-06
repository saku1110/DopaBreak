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

enum StatsPeriod: String, CaseIterable, Identifiable {
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

enum StatsWeekComparison: Equatable {
    case more(Int)
    case less(Int)
    case same
    case noData

    init(currentSeconds: Int, previousSeconds: Int?) {
        guard let previousSeconds else {
            self = .noData
            return
        }
        let delta = currentSeconds - previousSeconds
        if delta > 0 {
            self = .more(delta)
        } else if delta < 0 {
            self = .less(-delta)
        } else {
            self = .same
        }
    }
}

enum StatsPresentation {
    static func heroTimeText(
        seconds: Int,
        period: StatsPeriod,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        period == .all
            ? ReclaimedTimeFormatter.string(seconds: seconds, bundle: bundle, locale: locale)
            : ReclaimedTimeFormatter.detailedString(seconds: seconds, bundle: bundle, locale: locale)
    }

    static func shouldShowBasis(cancellationCount: Int) -> Bool {
        cancellationCount > 0
    }

    static func shouldShowHourlyCard(period: StatsPeriod, attempts: Int) -> Bool {
        period != .today && attempts > 0
    }

    static func shouldShowIntent(attemptCount: Int) -> Bool {
        attemptCount > 0
    }

    static func comparisonText(
        currentSeconds: Int,
        previousSeconds: Int?,
        isComparable: Bool,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let comparablePreviousSeconds = isComparable ? previousSeconds : nil
        switch StatsWeekComparison(
            currentSeconds: currentSeconds,
            previousSeconds: comparablePreviousSeconds
        ) {
        case .noData:
            return bundle.localizedString(
                forKey: "stats.weekly_detail.comparison.no_data",
                value: "先週の記録なし",
                table: nil
            )
        case let .more(delta):
            let deltaText = ReclaimedTimeFormatter.detailedString(
                seconds: delta,
                bundle: bundle,
                locale: locale
            )
            let format = bundle.localizedString(
                forKey: "stats.weekly_detail.comparison.more_time",
                value: "先週より +%@",
                table: nil
            )
            return String(format: format, locale: locale, arguments: [deltaText])
        case let .less(delta):
            let deltaText = ReclaimedTimeFormatter.detailedString(
                seconds: delta,
                bundle: bundle,
                locale: locale
            )
            let format = bundle.localizedString(
                forKey: "stats.weekly_detail.comparison.less_time",
                value: "先週より -%@",
                table: nil
            )
            return String(format: format, locale: locale, arguments: [deltaText])
        case .same:
            return bundle.localizedString(
                forKey: "stats.weekly_detail.comparison.same",
                value: "先週と同じ",
                table: nil
            )
        }
    }

    static func comparisonDeltaRange(
        in text: AttributedString,
        currentSeconds: Int,
        previousSeconds: Int?,
        isComparable: Bool,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> Range<AttributedString.Index>? {
        guard isComparable,
              let previousSeconds,
              currentSeconds != previousSeconds else {
            return nil
        }
        let deltaText = ReclaimedTimeFormatter.detailedString(
            seconds: abs(currentSeconds - previousSeconds),
            bundle: bundle,
            locale: locale
        )
        return text.range(of: deltaText)
    }

    static func intentMetricText(
        title: String,
        seconds: Int,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        "\(title) \(ReclaimedTimeFormatter.detailedString(seconds: seconds, bundle: bundle, locale: locale))"
    }

    static func mergedLegacyIntentValues(
        counts: [IntentCategory: Int],
        reclaimedSeconds: [IntentCategory: Int]
    ) -> (counts: [IntentCategory: Int], reclaimedSeconds: [IntentCategory: Int]) {
        var displayCounts = counts
        var displaySeconds = reclaimedSeconds
        if let legacyAnxietyCount = displayCounts.removeValue(forKey: .anxietyCheck) {
            displayCounts[.communication, default: 0] += legacyAnxietyCount
        }
        if let legacyAnxietySeconds = displaySeconds.removeValue(forKey: .anxietyCheck) {
            displaySeconds[.communication, default: 0] += legacyAnxietySeconds
        }
        return (displayCounts, displaySeconds)
    }

    static func appSortsBefore(
        title lhsTitle: String,
        seconds lhsSeconds: Int,
        than rhsTitle: String,
        rhsSeconds: Int
    ) -> Bool {
        if lhsSeconds == rhsSeconds {
            return lhsTitle.localizedStandardCompare(rhsTitle) == .orderedAscending
        }
        return lhsSeconds > rhsSeconds
    }

    static func intentSortsBefore(
        category lhsCategory: IntentCategory,
        seconds lhsSeconds: Int,
        than rhsCategory: IntentCategory,
        rhsSeconds: Int
    ) -> Bool {
        if lhsSeconds != rhsSeconds {
            return lhsSeconds > rhsSeconds
        }
        let order = Dictionary(
            uniqueKeysWithValues: IntentCategory.allCases.enumerated().map { ($1, $0) }
        )
        return (order[lhsCategory] ?? .max) < (order[rhsCategory] ?? .max)
    }

    static func appMetrics(
        from detailed: [UUID: (attempts: Int, cancelled: Int)],
        reclaimedSeconds: [UUID: Int],
        rules: [TargetRule],
        bundle: Bundle = .main
    ) -> [StatsAppMetric] {
        let ruleByID = Dictionary(rules.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let representedRuleIDs = Set(detailed.keys).union(reclaimedSeconds.keys)
        var activeMetrics: [StatsAppMetric] = []
        var removedAttempts = 0
        var removedCancelled = 0
        var removedReclaimedSeconds = 0
        var hasRemovedMetric = false

        for ruleID in representedRuleIDs {
            let breakdown = detailed[ruleID] ?? (attempts: 0, cancelled: 0)
            guard let rule = ruleByID[ruleID] else {
                hasRemovedMetric = true
                removedAttempts += breakdown.attempts
                removedCancelled += breakdown.cancelled
                removedReclaimedSeconds += reclaimedSeconds[ruleID] ?? 0
                continue
            }
            let title = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                hasRemovedMetric = true
                removedAttempts += breakdown.attempts
                removedCancelled += breakdown.cancelled
                removedReclaimedSeconds += reclaimedSeconds[ruleID] ?? 0
                continue
            }

            let catalogItem = rule.activitySelectionData.isEmpty
                ? SNSAppCatalog.all.first { $0.displayName == title }
                : nil
            let applicationToken = singleApplicationToken(from: rule.activitySelectionData)

            activeMetrics.append(StatsAppMetric(
                ruleID: ruleID,
                title: catalogItem?.displayName ?? title,
                catalogItem: catalogItem,
                applicationToken: applicationToken,
                attempts: breakdown.attempts,
                cancelled: breakdown.cancelled,
                reclaimedSeconds: reclaimedSeconds[ruleID] ?? 0
            ))
        }

        activeMetrics.sort { lhs, rhs in
            appSortsBefore(
                title: lhs.title,
                seconds: lhs.reclaimedSeconds,
                than: rhs.title,
                rhsSeconds: rhs.reclaimedSeconds
            )
        }

        if hasRemovedMetric {
            activeMetrics.append(
                StatsAppMetric(
                    ruleID: StatsAppMetric.removedAggregateRuleID,
                    title: bundle.localizedString(
                        forKey: "stats.apps.removed",
                        value: "対象から外したアプリ",
                        table: nil
                    ),
                    catalogItem: nil,
                    applicationToken: nil,
                    attempts: removedAttempts,
                    cancelled: removedCancelled,
                    reclaimedSeconds: removedReclaimedSeconds
                )
            )
        }

        return activeMetrics
    }

    private static func singleApplicationToken(from selectionData: Data) -> ApplicationToken? {
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
}

struct StatsAppMetric: Identifiable {
    static let removedAggregateRuleID = UUID(
        uuid: (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
               0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
    )

    let ruleID: UUID
    let title: String
    let catalogItem: SNSAppCatalogItem?
    let applicationToken: ApplicationToken?
    let attempts: Int
    let cancelled: Int
    let reclaimedSeconds: Int

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

struct StatsIntentMetric: Identifiable {
    let category: IntentCategory
    let title: String
    let count: Int
    let reclaimedSeconds: Int

    var id: String { category.rawValue }
}

private struct StatsDashboardData {
    var summary = AttemptSummary(attempts: 0, cancelled: 0)
    var days: [WeeklySummary.Day] = []
    var weeklyDetail: WeeklyDetailReport?
    var appMetrics: [StatsAppMetric] = []
    var reflectionCounts: [PostUseSatisfaction: Int] = [:]
    var intentMetrics: [StatsIntentMetric] = []
    var reclaimedSeconds = 0
    var estimatedSecondsPerCancellation = ReclaimedTimeEstimator.defaultSeconds
    var previousWeekReclaimedSeconds: Int?
    var hourlyAttempts: [Int: Int] = [:]

    static let empty = StatsDashboardData()
}

struct StatsView: View {
    let model: AppModel

    private let injectedStatsService: StatsService?
    private let onOpenBlockSettings: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var period: StatsPeriod
    @State private var dashboard = StatsDashboardData.empty

    init(model: AppModel, statsService: StatsService? = nil, onOpenBlockSettings: (() -> Void)? = nil) {
        self.model = model
        self.injectedStatsService = statsService
        self.onOpenBlockSettings = onOpenBlockSettings
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
                        text: String(localized: "home.reclaimed.title", defaultValue: "取り戻した時間")
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

                reclaimedTimeDisplay

                if StatsPresentation.shouldShowBasis(
                    cancellationCount: dashboard.summary.cancelled
                ) {
                    Text(
                        String(
                            localized: "home.hero.basis",
                            defaultValue: "開かなかった\(dashboard.summary.cancelled)回 × 1回約\(estimatedMinutesPerCancellation)分"
                        )
                    )
                    .dopaFont(14, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                }

                if period == .week {
                    DayBars(days: dashboard.days, height: 64)
                }

                legend
            }
        }
    }

    @ViewBuilder
    private var reclaimedTimeDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(reclaimedTimeText)
                .dopaFont(56, weight: .black, design: .rounded, tracking: -1.8)
                .monospacedDigit()
                .foregroundStyle(DesignTokens.primaryText)
                .contentTransition(.numericText())
                .dopaDisplayClamp()
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if period == .all,
               let equivalent = ReclaimedTimeFormatter.equivalentString(
                   seconds: dashboard.reclaimedSeconds
               ) {
                Text(equivalent)
                    .dopaFont(20, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(
                color: DesignTokens.accent,
                label: String(localized: "stats.behavior.cancelled", defaultValue: "開かなかった"),
                count: dashboard.summary.cancelled
            )
            Text("\(attemptedMetricLabel) \(countText(dashboard.summary.attempts))")
                .dopaFont(11, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if let percentage = successPercentage {
                Text(
                    "\(String(localized: "stats.rate.title", defaultValue: "開かなかった割合")) \(percentageText(percentage))"
                )
                .dopaFont(11, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            }
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

    private var reclaimedTimeText: String {
        StatsPresentation.heroTimeText(seconds: dashboard.reclaimedSeconds, period: period)
    }

    private var estimatedMinutesPerCancellation: Int {
        ReclaimedTimeFormatter.estimatedMinutesPerCancellation(
            todayReclaimedSeconds: dashboard.reclaimedSeconds,
            todayCancellationCount: dashboard.summary.cancelled,
            fallbackSeconds: dashboard.estimatedSecondsPerCancellation
        )
    }

    private func comparisonAttributedText(_ report: WeeklyDetailReport) -> AttributedString {
        var result = AttributedString(comparisonText(report))
        if let range = StatsPresentation.comparisonDeltaRange(
            in: result,
            currentSeconds: dashboard.reclaimedSeconds,
            previousSeconds: dashboard.previousWeekReclaimedSeconds,
            isComparable: report.isComparable
        ) {
            result[range].foregroundColor = DesignTokens.accent
        }
        return result
    }

    private func comparisonText(_ report: WeeklyDetailReport) -> String {
        StatsPresentation.comparisonText(
            currentSeconds: dashboard.reclaimedSeconds,
            previousSeconds: dashboard.previousWeekReclaimedSeconds,
            isComparable: report.isComparable
        )
    }

    // MARK: - アプリごと

    private var detailContentSection: some View {
        VStack(spacing: DesignTokens.sectionSpacing) {
            appsCard
            if StatsPresentation.shouldShowHourlyCard(
                period: period,
                attempts: dashboard.summary.attempts
            ) {
                hourlyCard
            }
            reflectionCard
            if let insight = ReflectionInsightPolicy.insight(counts: dashboard.reflectionCounts) {
                reflectionInsightCard(insight)
            }
            intentCard
        }
    }

    private var appsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(
                    text: String(
                        localized: "stats.apps.title",
                        defaultValue: "一呼吸をはさんだアプリ"
                    )
                )

                Text(
                    String(
                        localized: "stats.apps.caption",
                        defaultValue: "完全ブロックで止めたアプリは含みません"
                    )
                )
                .dopaFont(12, weight: .medium)
                .foregroundStyle(DesignTokens.secondaryText)

                if dashboard.appMetrics.isEmpty {
                    Text(
                        String(
                            localized: "stats.apps.empty",
                            defaultValue: "まだ一呼吸の記録がありません"
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
        let reclaimedTime = ReclaimedTimeFormatter.detailedString(seconds: metric.reclaimedSeconds)
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

            Text(reclaimedTime)
                .dopaFont(12, weight: .bold, design: .monospaced)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 62, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(metric.title) \(cancelledMetricLabel) \(countText(metric.cancelled)) \(attemptedMetricLabel) \(countText(metric.attempts)) \(reclaimedTime)"
        )
    }

    // MARK: - 開こうとした時間帯

    private var hourlyCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(
                    text: String(localized: "stats.hourly.title", defaultValue: "開こうとした時間帯")
                )
                HourBars(counts: dashboard.hourlyAttempts)
            }
        }
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

    private func reflectionInsightCard(_ insight: ReflectionInsight) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "stats.insight.title", defaultValue: "次の使い方を決める"))
                    .dopaFont(17, weight: .bold)
                Text(String(localized: "stats.insight.evidence", defaultValue: "この期間の回答\(insight.answerCount)件のうち\(insight.regretCount)件が「時間を失った」「気分が悪くなった」でした。"))
                    .dopaFont(14, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                Text(String(localized: "stats.insight.suggestion", defaultValue: "見たくない時間が決まっているなら、その時間だけブロックする予定を試してみませんか。設定は自分で選べます。"))
                    .dopaFont(14, weight: .medium)
                if let onOpenBlockSettings {
                    Button(String(localized: "stats.insight.action", defaultValue: "ブロックの設定を見直す"), action: onOpenBlockSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
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
                            Text(StatsPresentation.intentMetricText(
                                title: metric.title,
                                seconds: metric.reclaimedSeconds
                            ))
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
        let reclaimedSeconds: Int
        switch dashboardPeriod {
        case .today, .week:
            reclaimedSeconds = (
                try? statsService.reclaimedSecondsByStartWindow(from: range.start, to: range.end)
            ) ?? 0
        case .all:
            reclaimedSeconds = (try? statsService.reclaimedSecondsAllTime()) ?? 0
        }
        let reclaimedByRule: [UUID: Int]
        let reclaimedByIntent: [IntentCategory: Int]
        switch dashboardPeriod {
        case .today, .week:
            reclaimedByRule = (
                try? statsService.reclaimedSecondsByRuleInStartWindow(from: range.start, to: range.end)
            ) ?? [:]
            reclaimedByIntent = (
                try? statsService.reclaimedSecondsByIntentInStartWindow(from: range.start, to: range.end)
            ) ?? [:]
        case .all:
            reclaimedByRule = (
                try? statsService.reclaimedSecondsByRule(from: range.start, to: range.end)
            ) ?? [:]
            reclaimedByIntent = (
                try? statsService.reclaimedSecondsByIntent(from: range.start, to: range.end)
            ) ?? [:]
        }
        let hourlyAttempts = (
            try? statsService.hourlyAttemptBreakdown(from: range.start, to: range.end)
        ) ?? [:]
        let previousWeekReclaimedSeconds: Int? = if dashboardPeriod == .week,
                                                    let previousDays = report?.previous.days,
                                                    report?.isComparable == true,
                                                    let previousStart = previousDays.first?.date,
                                                    let previousLastDay = previousDays.last?.date,
                                                    let previousEnd = calendar.date(
                                                        byAdding: .day,
                                                        value: 1,
                                                        to: previousLastDay
                                                    ) {
            try? statsService.reclaimedSecondsByStartWindow(from: previousStart, to: previousEnd)
        } else {
            nil
        }

        dashboard = StatsDashboardData(
            summary: summary,
            days: report?.current.days ?? WeeklySummaryPlaceholder.emptyWeekDays(referenceDate: referenceDate),
            weeklyDetail: report,
            appMetrics: StatsPresentation.appMetrics(
                from: detailed,
                reclaimedSeconds: reclaimedByRule,
                rules: (try? model.ruleStore.allRules()) ?? []
            ),
            reflectionCounts: reflectionCounts,
            intentMetrics: intentMetrics(from: intentCounts, reclaimedSeconds: reclaimedByIntent),
            reclaimedSeconds: reclaimedSeconds,
            estimatedSecondsPerCancellation: (
                try? statsService.estimatedReclaimedSecondsPerCancellation(at: referenceDate)
            ) ?? ReclaimedTimeEstimator.defaultSeconds,
            previousWeekReclaimedSeconds: previousWeekReclaimedSeconds,
            hourlyAttempts: hourlyAttempts
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
            days: WeeklySummaryPlaceholder.emptyWeekDays(referenceDate: referenceDate)
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

    private func intentMetrics(
        from counts: [IntentCategory: Int],
        reclaimedSeconds: [IntentCategory: Int]
    ) -> [StatsIntentMetric] {
        let merged = StatsPresentation.mergedLegacyIntentValues(
            counts: counts,
            reclaimedSeconds: reclaimedSeconds
        )
        let displayCounts = merged.counts
        let displaySeconds = merged.reclaimedSeconds
        return displayCounts.compactMap { category, count -> StatsIntentMetric? in
            guard StatsPresentation.shouldShowIntent(attemptCount: count) else { return nil }
            let title = intentTitle(category)
            return StatsIntentMetric(
                category: category,
                title: title,
                count: count,
                reclaimedSeconds: displaySeconds[category] ?? 0
            )
        }
        .sorted { lhs, rhs in
            StatsPresentation.intentSortsBefore(
                category: lhs.category,
                seconds: lhs.reclaimedSeconds,
                than: rhs.category,
                rhsSeconds: rhs.reclaimedSeconds
            )
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
