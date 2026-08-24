import Combine
import DopaBreakCore
import Foundation
import SwiftUI

private enum HomeStatsProvider {
    static let shared: StatsService? = {
        guard let logStore = try? SQLiteLogStore(containerProvider: DefaultContainerProvider()) else {
            return nil
        }
        return StatsService(logStore: logStore, calendar: .autoupdatingCurrent)
    }()
}

private struct HomeAppMetric: Identifiable {
    let ruleID: UUID
    let title: String
    let catalogItem: SNSAppCatalogItem?
    let attempts: Int
    let cancelled: Int

    var id: UUID { ruleID }
}

private struct HomeDashboardData {
    var weeklySummary: WeeklySummary?
    var weeklyDetail: WeeklyDetailReport?
    var consecutiveDays = 0
    var reclaimedSeconds = 0
    var appMetrics: [HomeAppMetric] = []
    var reflectionCounts: [PostUseSatisfaction: Int] = [:]
    var recentSatisfactions: [PostUseSatisfaction] = []

    static let empty = HomeDashboardData()
}

struct HomeView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    private let injectedStatsService: StatsService?

    @State private var editorRoute: GoalEditorRoute?
    @State private var isAutomationGuidePresented = false
    @State private var isTargetPickerPresented = false
    @State private var paywallPlacement: PaywallPlacement?
    @State private var showPaywallAfterTargetPicker = false
    @State private var dashboard = HomeDashboardData.empty
    @State private var clock = Date()

    private static let dashboardTicker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(
        model: AppModel,
        settingsStore: SettingsStore,
        statsService: StatsService? = nil
    ) {
        self.model = model
        self.settingsStore = settingsStore
        injectedStatsService = statsService
    }

    private var statsService: StatsService? {
        injectedStatsService ?? HomeStatsProvider.shared
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topLine

                if !unverifiedAutomationTargets.isEmpty {
                    automationStatusBanner
                }

                heroSection

                if !isFirstDayEmpty {
                    reclaimedTimeCard
                }

                targetAppsCard

                if isFirstDayEmpty {
                    firstDayEmptySection
                        .padding(.vertical, 12)
                }

                weekCard

                if !isFirstDayEmpty,
                   (!dashboard.appMetrics.isEmpty || topSatisfaction != nil) {
                    dashboardInsightsSection
                }

                goalCard
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
            reloadDashboard()
            model.isChildModalActive = isAnyChildModalPresented
        }
        .onChange(of: model.todayAttemptCount) { _, _ in
            reloadDashboard()
        }
        .onChange(of: model.weekAttemptCount) { _, _ in
            reloadDashboard()
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .onChange(of: isTargetPickerPresented) { _, isPresented in
            guard !isPresented, showPaywallAfterTargetPicker else { return }
            showPaywallAfterTargetPicker = false
            reloadDashboard()
            paywallPlacement = .settingsTargetAppLimit
        }
        .onReceive(Self.dashboardTicker) { date in
            let didRollOver = !Calendar.autoupdatingCurrent.isDate(clock, inSameDayAs: date)
            clock = date
            if didRollOver {
                reloadDashboard(referenceDate: date)
            }
        }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
        .sheet(isPresented: $isAutomationGuidePresented) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .sheet(isPresented: $isTargetPickerPresented, onDismiss: { reloadDashboard() }) {
            TargetAppPickerSheet(model: model) {
                showPaywallAfterTargetPicker = true
            }
        }
        .fullScreenCover(item: $paywallPlacement) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
        }
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil
            || isAutomationGuidePresented
            || isTargetPickerPresented
            || paywallPlacement != nil
    }

    private var topLine: some View {
        HStack(spacing: 12) {
            SmallLabel(
                text: String(
                    localized: "home.hero.today",
                    defaultValue: "今日 ・ \(todayText)"
                )
            )
            Spacer(minLength: 8)
            if !isFirstDayEmpty {
                Text(
                    String(
                        localized: "home.hero.week_count",
                        defaultValue: "\(model.weekCancelledCount)回 / 今週"
                    )
                )
                .dopaFont(12, weight: .bold, design: .monospaced)
                .foregroundStyle(DesignTokens.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(DesignTokens.background.opacity(0.72))
                .clipShape(Capsule())
            }
        }
    }

    private var heroSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 22) {
                CharacterView(heroExpression, size: 112)
                achievementBlock
            }

            VStack(alignment: .leading, spacing: 14) {
                CharacterView(heroExpression, size: 112)
                    .frame(maxWidth: .infinity)
                achievementBlock
            }
        }
        .padding(.vertical, 6)
    }

    private var achievementBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(model.todayCancelledCount)")
                    .dopaFont(56, weight: .black, design: .rounded, tracking: -2)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.accent)
                    .contentTransition(.numericText())
                    .dopaDisplayClamp()
                Text(String(localized: "home.achievement.count_unit", defaultValue: "回"))
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.accent)
            }
            .accessibilityElement(children: .combine)
            .animation(DopaMotion.control, value: model.todayCancelledCount)

            Text(String(localized: "home.achievement.title", defaultValue: "開くのをやめた"))
                .dopaFont(20, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)

            Text(achievementSummary)
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)

            if dashboard.consecutiveDays > 0 {
                HStack(spacing: 7) {
                    Circle()
                        .fill(DesignTokens.accent)
                        .frame(width: 7, height: 7)
                    Text(
                        String(
                            localized: "home.streak.days",
                            defaultValue: "連続 \(dashboard.consecutiveDays)日"
                        )
                    )
                    .dopaFont(12, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .overlay {
                    Capsule().stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var achievementSummary: String {
        if model.todayAttemptCount == 0 {
            return String(
                localized: "home.achievement.empty_body",
                defaultValue: "今日はまだ開こうとしていません"
            )
        }
        return String(
            localized: "home.achievement.summary",
            defaultValue: "開こうとしたのは\(model.todayAttemptCount)回"
        )
    }

    private var reclaimedTimeCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(
                    text: String(localized: "home.reclaimed.title", defaultValue: "取り戻した時間")
                )

                HStack(alignment: .lastTextBaseline, spacing: 9) {
                    Text(reclaimedTimeText)
                        .dopaFont(32, weight: .black, design: .rounded, tracking: -0.7)
                        .foregroundStyle(DesignTokens.accent)
                        .contentTransition(.numericText())
                    Text(String(localized: "home.reclaimed.week_label", defaultValue: "今週"))
                        .dopaFont(13, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }

                if dashboard.reclaimedSeconds > 0 {
                    Text(
                        String(
                            localized: "home.reclaimed.yearly",
                            defaultValue: "この調子なら1年で約 \(yearlyReclaimedDaysText)日分"
                        )
                    )
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
    }

    private var targetAppsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    isTargetPickerPresented = true
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        SmallLabel(
                            text: String(
                                localized: "home.targets.title",
                                defaultValue: "止めているアプリ"
                            )
                        )

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 14) {
                                targetIcons
                                Spacer(minLength: 4)
                                targetStatus
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                targetIcons
                                targetStatus
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showsEndDeepFocusButton {
                    Button(
                        String(localized: "home.targets.focus_end", defaultValue: "いま解除する")
                    ) {
                        model.endDeepFocusSession()
                        clock = Date()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .secondary))
                } else if showsStartDeepFocusButton {
                    Button(
                        String(localized: "home.targets.focus_30", defaultValue: "30分だけ開けなくする")
                    ) {
                        startDeepFocus()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .primary))
                }
            }
        }
    }

    @ViewBuilder
    private var targetIcons: some View {
        if selectedCatalogItems.isEmpty {
            HStack(spacing: 10) {
                plusTile
                Text(
                    String(localized: "home.targets.empty", defaultValue: "止めるアプリを選ぶ")
                )
                .dopaFont(15, weight: .semibold)
                .foregroundStyle(DesignTokens.accent)
            }
        } else {
            AppIconStack(
                sources: selectedCatalogItems.map { .catalog($0) },
                size: 44,
                maxVisible: 3,
                showsStatusDots: true
            )
        }
    }

    private var plusTile: some View {
        Image(systemName: "plus")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(DesignTokens.accent)
            .frame(width: 44, height: 44)
            .background(DesignTokens.backgroundRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(DesignTokens.secondaryText, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }

    private var targetStatus: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(targetPrimaryStatus)
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(isAnyHardBlockActive ? DesignTokens.accent : DesignTokens.primaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)

            if currentMode == .nightOnly, !isNightBlockActive {
                Text(
                    String(
                        localized: "home.targets.night_line",
                        defaultValue: "\(bedTimeText)から朝まで開けません"
                    )
                )
                .dopaFont(12, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
                .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var targetPrimaryStatus: String {
        if isNightBlockActive {
            if let remaining = nightRemainingText {
                return String(
                    localized: "home.targets.focus_running",
                    defaultValue: "あと\(remaining) 開けません"
                )
            }
            return String(
                localized: "home.targets.night_line",
                defaultValue: "\(bedTimeText)から朝まで開けません"
            )
        }
        if isDeepFocusActive {
            if let remaining = deepFocusRemainingText {
                return String(
                    localized: "home.targets.focus_running",
                    defaultValue: "あと\(remaining) 開けません"
                )
            }
            return String(
                localized: "settings.deep_focus.session.open_ended.label",
                defaultValue: "自分で戻すまで"
            )
        }
        return String(
            localized: "home.targets.breath_line",
            defaultValue: "一呼吸の設定：\(settingsStore.breathDurationSeconds)秒"
        )
    }

    private var weekCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: String(localized: "home.week.eyebrow", defaultValue: "今週"))

                DayBars(days: dashboard.weeklySummary?.days ?? emptyWeekDays)

                Text(weekSummaryText)
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var weekSummaryText: String {
        let base = String(
            localized: "home.week.summary",
            defaultValue: "今週は\(model.weekCancelledCount)回、開くのをやめました"
        )
        guard let comparison = weekComparisonText else { return base }
        return "\(base) ・ \(comparison)"
    }

    private var weekComparisonText: String? {
        guard let delta = dashboard.weeklyDetail?.cancelledDelta else { return nil }
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
        return String(localized: "stats.weekly_detail.comparison.same", defaultValue: "先週と同じ")
    }

    private var dashboardInsightsSection: some View {
        ZStack {
            VStack(spacing: 16) {
                if !dashboard.appMetrics.isEmpty {
                    lockedDashboardPreview {
                        appMetricsCard
                    }
                }

                if topSatisfaction != nil {
                    lockedDashboardPreview {
                        reflectionCard
                    }
                }
            }

            if isDashboardLocked {
                weeklyReviewButton
            }
        }
    }

    private var appMetricsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: String(localized: "home.apps.title", defaultValue: "アプリごと"))

                ForEach(dashboard.appMetrics) { metric in
                    appMetricRow(metric)
                }

                Text(
                    String(
                        localized: "home.apps.legend",
                        defaultValue: "今日：開くのをやめた / 開こうとした"
                    )
                )
                .dopaFont(11, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
            }
        }
    }

    private func appMetricRow(_ metric: HomeAppMetric) -> some View {
        let ratioText = String(
            localized: "home.apps.ratio",
            defaultValue: "\(metric.cancelled) / \(metric.attempts)"
        )
        return HStack(spacing: 10) {
            if let item = metric.catalogItem {
                AppIconView(source: .catalog(item), size: 22)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.backgroundRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            }

            Text(metric.title)
                .dopaFont(12, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)

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
                .frame(width: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) \(ratioText)")
    }

    private var reflectionCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 13) {
                SmallLabel(
                    text: String(
                        localized: "reflection.satisfaction.title",
                        defaultValue: "SNSを見てどうだった？"
                    )
                )

                if let topSatisfaction {
                    Text(
                        String(
                            localized: "home.reflection.top",
                            defaultValue: "「\(topSatisfaction.displayTitle)」が多め"
                        )
                    )
                    .dopaFont(18, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                }

                HStack(spacing: 7) {
                    ForEach(Array(dashboard.recentSatisfactions.enumerated()), id: \.offset) { _, value in
                        Circle()
                            .fill(reflectionColor(value))
                            .frame(width: 10, height: 10)
                    }
                    Spacer(minLength: 8)
                    Text(reflectionCountText)
                        .dopaFont(11, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
    }

    private func lockedDashboardPreview<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
                .blur(radius: isDashboardLocked ? 10 : 0)
                .accessibilityHidden(isDashboardLocked)

            if isDashboardLocked {
                DesignTokens.backgroundRaised.opacity(0.6)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
    }

    private var weeklyReviewButton: some View {
        Button {
            paywallPlacement = .statsHistoryGate
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text(
                    String(
                        localized: "stats.paywall.weekly_report",
                        defaultValue: "毎週のふりかえりを詳しく見られる"
                    )
                )
            }
            .dopaFont(13, weight: .bold)
            .foregroundStyle(DesignTokens.primaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(DesignTokens.backgroundRaised)
            .overlay { Capsule().stroke(DesignTokens.strongHairline, lineWidth: 1) }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var goalCard: some View {
        Button {
            editorRoute = GoalEditorRoute(goal: model.goals.first)
        } label: {
            CardContainer {
                HStack(spacing: 14) {
                    goalCategoryTile

                    VStack(alignment: .leading, spacing: 7) {
                        SmallLabel(text: goalLabel)
                        Text(primaryGoalTitle)
                            .dopaFont(20, weight: .bold)
                            .foregroundStyle(hasPrimaryGoal ? DesignTokens.primaryText : DesignTokens.accent)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var goalCategoryTile: some View {
        Image(systemName: primaryGoalCategory.symbolName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DesignTokens.accent)
            .frame(width: 44, height: 44)
            .background(DesignTokens.accent.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }

    private var goalLabel: String {
        let base = String(localized: "home.goal.label", defaultValue: "あなたの目標")
        guard hasPrimaryGoal else { return base }
        return "\(base) ・ \(primaryGoalCategory.japaneseLabel)"
    }

    private var firstDayEmptySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    localized: "home.first_day.title",
                    defaultValue: "開こうとした瞬間に一呼吸が入ります"
                )
            )
            .dopaFont(30, weight: .black, tracking: -0.7, lineSpacing: 4)
            .foregroundStyle(DesignTokens.primaryText)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                String(
                    localized: "home.first_day.body",
                    defaultValue: "開くのをやめた回数がここに残ります"
                )
            )
            .dopaFont(15, weight: .semibold, lineSpacing: 4)
            .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private var automationStatusBanner: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text(automationStatusTitle)
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        localized: "home.automation_status.body",
                        defaultValue: "対象アプリを開いたときに一呼吸が出れば設定完了です。"
                    )
                )
                .dopaFont(14, weight: .semibold, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Button(
                    String(localized: "home.automation_status.action", defaultValue: "設定を確認")
                ) {
                    isAutomationGuidePresented = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var selectedCatalogItems: [SNSAppCatalogItem] {
        ((try? model.targetStore.selectedCatalogIDs()) ?? [])
            .compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var currentMode: InterventionMode {
        let persistedMode: InterventionMode
        if let rawValue = settingsStore.pendingInterventionMode,
           let mode = InterventionMode(rawValue: rawValue) {
            persistedMode = mode
        } else {
            persistedMode = (try? model.ruleStore.allRules().first?.mode) ?? .standard
        }
        return InterventionModeResolver.resolve(
            persistedMode,
            hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement,
            strictModeAllowed: model.entitlementGate.strictModeAllowed
        )
    }

    private var isNightBlockActive: Bool {
        currentMode == .nightOnly && NightWindowPolicy.isNight(
            now: clock,
            bedTimeMinutes: settingsStore.bedTimeMinutes ?? NightShieldConstants.defaultBedTimeMinutes,
            wakeTimeMinutes: settingsStore.wakeTimeMinutes ?? NightShieldConstants.defaultWakeTimeMinutes,
            calendar: .autoupdatingCurrent
        )
    }

    private var isManualDeepFocusActive: Bool {
        model.deepFocusSession != nil
    }

    private var isScheduledDeepFocusActive: Bool {
        currentMode == .deepFocus && model.isDeepFocusScheduleWindowActive
    }

    private var isDeepFocusActive: Bool {
        isManualDeepFocusActive || isScheduledDeepFocusActive
    }

    private var isAnyHardBlockActive: Bool {
        isNightBlockActive || isDeepFocusActive
    }

    private var showsEndDeepFocusButton: Bool {
        isManualDeepFocusActive && !isScheduledDeepFocusActive
    }

    private var showsStartDeepFocusButton: Bool {
        !isNightBlockActive && !isDeepFocusActive
    }

    private func startDeepFocus() {
        guard model.entitlementGate.strictModeAllowed else {
            paywallPlacement = .settingsModeGate
            return
        }
        model.startDeepFocusSession(durationMinutes: 30)
        clock = Date()
    }

    private var deepFocusRemainingText: String? {
        if isManualDeepFocusActive {
            guard let seconds = model.deepFocusSessionRemainingSeconds else { return nil }
            return Self.remainingFormatter.string(from: max(60, seconds.rounded(.up)))
        }
        guard isScheduledDeepFocusActive, let seconds = scheduleRemainingSeconds else { return nil }
        return Self.remainingFormatter.string(from: max(60, seconds.rounded(.up)))
    }

    private var scheduleRemainingSeconds: TimeInterval? {
        guard model.isDeepFocusScheduleWindowActive else { return nil }
        let calendar = Calendar.autoupdatingCurrent
        let endMinutes = DeepFocusWindowPolicy.normalizedMinutes(model.deepFocusSchedule.endMinutes)
        let startOfDay = calendar.startOfDay(for: clock)
        guard var end = calendar.date(byAdding: .minute, value: endMinutes, to: startOfDay) else {
            return nil
        }
        if end <= clock {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return max(0, end.timeIntervalSince(clock))
    }

    private var nightRemainingText: String? {
        let calendar = Calendar.autoupdatingCurrent
        let wakeMinutes = settingsStore.wakeTimeMinutes
            ?? NightShieldConstants.defaultWakeTimeMinutes
        let startOfDay = calendar.startOfDay(for: clock)
        guard var wake = calendar.date(byAdding: .minute, value: wakeMinutes, to: startOfDay) else {
            return nil
        }
        if wake <= clock {
            wake = calendar.date(byAdding: .day, value: 1, to: wake) ?? wake
        }
        return Self.remainingFormatter.string(from: max(60, wake.timeIntervalSince(clock)))
    }

    private static let remainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    private static let timeOfDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter
    }()

    private var bedTimeText: String {
        let calendar = Calendar.autoupdatingCurrent
        let minutes = settingsStore.bedTimeMinutes ?? NightShieldConstants.defaultBedTimeMinutes
        let date = calendar.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: clock
        ) ?? clock
        return Self.timeOfDayFormatter.string(from: date)
    }

    private var topSatisfaction: PostUseSatisfaction? {
        let order: [PostUseSatisfaction] = [
            .satisfied, .fun, .nothingGained, .lostTime, .feltWorse
        ]
        guard let maximum = dashboard.reflectionCounts.values.max(), maximum > 0 else {
            return nil
        }
        return order.first { dashboard.reflectionCounts[$0] == maximum }
    }

    private var reflectionCountText: String {
        let answered = dashboard.reflectionCounts.values.reduce(0, +)
        let topCount = topSatisfaction.flatMap { dashboard.reflectionCounts[$0] } ?? 0
        return String(
            localized: "home.reflection.count",
            defaultValue: "今週の\(answered)回中 \(topCount)回"
        )
    }

    private func reflectionColor(_ satisfaction: PostUseSatisfaction) -> Color {
        switch satisfaction {
        case .satisfied, .fun:
            return DesignTokens.accent
        case .nothingGained:
            return DesignTokens.tertiaryText
        case .lostTime, .feltWorse:
            return DesignTokens.danger
        }
    }

    private var reclaimedTimeText: String {
        let totalMinutes = dashboard.reclaimedSeconds / 60
        if totalMinutes < 60 {
            return String(
                localized: "home.reclaimed.minutes",
                defaultValue: "\(totalMinutes)分"
            )
        }
        return String(
            localized: "home.reclaimed.hours_minutes",
            defaultValue: "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
        )
    }

    private var yearlyReclaimedDaysText: String {
        let days = Double(dashboard.reclaimedSeconds) * 52 / 86_400
        let floored = floor(days * 10) / 10
        let format = floored.rounded(.towardZero) == floored ? "%.0f" : "%.1f"
        return String(format: format, locale: Locale.autoupdatingCurrent, floored)
    }

    private var primaryGoalTitle: String {
        model.goals.first?.title
            ?? String(localized: "home.goal.fallback", defaultValue: "タップして目標を追加")
    }

    private var primaryGoalCategory: GoalCategory {
        model.goals.first?.category ?? .other
    }

    private var hasPrimaryGoal: Bool {
        model.goals.first != nil
    }

    private var heroExpression: CharacterExpression {
        model.todayAttemptCount > 0 && model.todayCancelledCount == 0 ? .doom : .awake
    }

    private var unverifiedAutomationCatalogIDs: [String] {
        AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: (try? model.targetStore.selectedCatalogIDs()) ?? [],
            verifiedCatalogIDs: settingsStore.verifiedAutomationCatalogIDs
        )
    }

    private var unverifiedAutomationTargets: [SNSAppCatalogItem] {
        unverifiedAutomationCatalogIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var automationStatusTitle: String {
        if unverifiedAutomationTargets.count == 1,
           let target = unverifiedAutomationTargets.first {
            return String(
                localized: "home.automation_status.title_single",
                defaultValue: "\(target.displayName)の一呼吸はまだ動いていません"
            )
        }
        return String(
            localized: "home.automation_status.title_multiple",
            defaultValue: "\(unverifiedAutomationCatalogIDs.count)個のアプリで一呼吸がまだ動いていません"
        )
    }

    private var isFirstDayEmpty: Bool {
        model.todayAttemptCount == 0 && model.weekAttemptCount == 0
    }

    private var isDashboardLocked: Bool {
        !model.entitlementGate.weeklyReportAllowed
    }

    private var todayText: String {
        clock.formatted(.dateTime.month().day())
    }

    private var emptyWeekDays: [WeeklySummary.Day] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: clock)
        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else {
                return nil
            }
            return WeeklySummary.Day(date: date, attempts: 0, cancelled: 0)
        }
    }

    private func reloadDashboard(referenceDate: Date = Date()) {
        guard let statsService else {
            dashboard = .empty
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = referenceDate
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
            ?? todayStart.addingTimeInterval(86_400)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)
            ?? todayStart.addingTimeInterval(-6 * 86_400)
        let rules = (try? model.ruleStore.allRules()) ?? []
        let selectedIDs = (try? model.targetStore.selectedCatalogIDs()) ?? []
        let selectedTargets = selectedIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
        let detailed = (try? statsService.appRuleBreakdownDetailed(from: todayStart, to: todayEnd)) ?? [:]

        let rows = detailed.compactMap { ruleID, breakdown -> HomeAppMetric? in
            guard let rule = rules.first(where: { $0.id == ruleID }) else { return nil }
            let catalogItem = selectedTargets.first {
                rule.activitySelectionData.isEmpty && $0.displayName == rule.name
            }
            let trimmedName = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard catalogItem != nil || !trimmedName.isEmpty else { return nil }
            return HomeAppMetric(
                ruleID: ruleID,
                title: catalogItem?.displayName ?? trimmedName,
                catalogItem: catalogItem,
                attempts: breakdown.attempts,
                cancelled: breakdown.cancelled
            )
        }
        .sorted {
            if $0.attempts == $1.attempts {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.attempts > $1.attempts
        }

        dashboard = HomeDashboardData(
            weeklySummary: try? statsService.weeklySummary(),
            weeklyDetail: try? statsService.weeklyDetailReport(),
            consecutiveDays: (try? statsService.consecutiveDaysWithCancellations(endingOn: now)) ?? 0,
            reclaimedSeconds: (try? statsService.reclaimedSeconds(from: weekStart, to: todayEnd)) ?? 0,
            appMetrics: rows,
            reflectionCounts: (try? statsService.reflectionBreakdown(from: weekStart, to: todayEnd)) ?? [:],
            recentSatisfactions: (try? statsService.recentSatisfactions(from: weekStart, to: todayEnd, limit: 6)) ?? []
        )
    }
}

private extension GoalCategory {
    var symbolName: String {
        switch self {
        case .study: return "book.fill"
        case .work: return "briefcase.fill"
        case .health: return "figure.run"
        case .sleep: return "moon.stars.fill"
        case .creative: return "paintbrush.fill"
        case .other: return "star.fill"
        }
    }
}

private struct HomeFocusButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dopaFont(15, weight: .bold)
            .foregroundStyle(kind == .primary ? DesignTokens.background : DesignTokens.primaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                kind == .primary
                    ? DesignTokens.accent
                    : (configuration.isPressed ? DesignTokens.cardPressed : DesignTokens.backgroundRaised)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(kind == .primary ? Color.clear : DesignTokens.strongHairline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(DopaMotion.control, value: configuration.isPressed)
    }
}
